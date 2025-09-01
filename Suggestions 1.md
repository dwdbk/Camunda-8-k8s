# Camunda-8-k8s

# Camunda 8.6 Self-Managed Kubernetes Manifests

## 1. Namespace and Common Resources

### namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: camunda
  labels:
    name: camunda
    app.kubernetes.io/part-of: camunda-platform
```

### configmap-common.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: camunda-common-config
  namespace: camunda
data:
  elasticsearch.url: "http://elasticsearch-service:9200"
  zeebe.gateway.address: "zeebe-gateway-service:26500"
  identity.base.url: "http://identity-service:8080"
  keycloak.url: "http://keycloak-service:8080"
```

### secret-common.yaml
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: camunda-common-secret
  namespace: camunda
type: Opaque
data:
  # Base64 encoded values
  admin-username: YWRtaW4=  # admin
  admin-password: YWRtaW4=  # admin
  elasticsearch-password: Y2FtdW5kYQ==  # camunda
  database-password: Y2FtdW5kYQ==  # camunda
```

## 2. Elasticsearch

### elasticsearch-deployment.yaml
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: camunda
  labels:
    app: elasticsearch
    component: elasticsearch
spec:
  serviceName: elasticsearch-headless
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
        component: elasticsearch
    spec:
      securityContext:
        fsGroup: 1000
      initContainers:
      - name: configure-sysctl
        image: docker.elastic.co/elasticsearch/elasticsearch:7.17.24
        command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        securityContext:
          privileged: true
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.17.24
        ports:
        - containerPort: 9200
          name: http
        - containerPort: 9300
          name: transport
        resources:
          requests:
            memory: 2Gi
            cpu: 1000m
          limits:
            memory: 4Gi
            cpu: 2000m
        env:
        - name: cluster.name
          value: camunda-elasticsearch
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: cluster.initial_master_nodes
          value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
        - name: discovery.seed_hosts
          value: "elasticsearch-headless"
        - name: ES_JAVA_OPTS
          value: "-Xms1g -Xmx1g"
        - name: xpack.security.enabled
          value: "false"
        - name: xpack.monitoring.collection.enabled
          value: "true"
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        - name: config
          mountPath: /usr/share/elasticsearch/config/elasticsearch.yml
          subPath: elasticsearch.yml
      volumes:
      - name: config
        configMap:
          name: elasticsearch-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 15Gi
```

### elasticsearch-configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearch-config
  namespace: camunda
data:
  elasticsearch.yml: |
    cluster.name: camunda-elasticsearch
    network.host: 0.0.0.0
    http.port: 9200
    discovery.type: zen
    discovery.zen.minimum_master_nodes: 2
    discovery.zen.ping.unicast.hosts: "elasticsearch-headless"
    xpack.security.enabled: false
    xpack.monitoring.collection.enabled: true
```

### elasticsearch-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-service
  namespace: camunda
  labels:
    app: elasticsearch
spec:
  ports:
  - port: 9200
    name: http
  - port: 9300
    name: transport
  selector:
    app: elasticsearch
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-headless
  namespace: camunda
  labels:
    app: elasticsearch
spec:
  clusterIP: None
  ports:
  - port: 9200
    name: http
  - port: 9300
    name: transport
  selector:
    app: elasticsearch
```

## 3. PostgreSQL (for Identity/Keycloak)

### postgresql-deployment.yaml
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: camunda
  labels:
    app: postgresql
    component: database
spec:
  serviceName: postgresql-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
        component: database
    spec:
      containers:
      - name: postgresql
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: camunda
        - name: POSTGRES_USER
          value: camunda
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: camunda-common-secret
              key: database-password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 512Mi
            cpu: 500m
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        - name: init-scripts
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: init-scripts
        configMap:
          name: postgresql-init-scripts
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```

### postgresql-configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-init-scripts
  namespace: camunda
data:
  init.sql: |
    -- Create databases for different services
    CREATE DATABASE IF NOT EXISTS keycloak;
    CREATE DATABASE IF NOT EXISTS identity;
    
    -- Grant permissions
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO camunda;
    GRANT ALL PRIVILEGES ON DATABASE identity TO camunda;
```

### postgresql-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-service
  namespace: camunda
  labels:
    app: postgresql
spec:
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
  selector:
    app: postgresql
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql-headless
  namespace: camunda
  labels:
    app: postgresql
spec:
  clusterIP: None
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgresql
```

## 4. Zeebe Broker

### zeebe-configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: zeebe-config
  namespace: camunda
data:
  application.yaml: |
    zeebe:
      broker:
        cluster:
          clusterId: camunda-zeebe
          nodeId: ${ZEEBE_NODE_ID}
          partitionsCount: 3
          replicationFactor: 3
          clusterSize: 3
        network:
          host: 0.0.0.0
          port: 26501
          internalApi:
            host: 0.0.0.0
            port: 26502
        data:
          directory: /usr/local/zeebe/data
        exporters:
          elasticsearch:
            className: io.camunda.zeebe.exporter.ElasticsearchExporter
            args:
              url: http://elasticsearch-service:9200
              bulk:
                size: 1000
              index:
                prefix: zeebe-record
                createTemplate: true
    logging:
      level:
        ROOT: INFO
        io.camunda.zeebe: INFO
```

### zeebe-deployment.yaml
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zeebe-broker
  namespace: camunda
  labels:
    app: zeebe-broker
    component: zeebe
spec:
  serviceName: zeebe-broker-headless
  replicas: 3
  selector:
    matchLabels:
      app: zeebe-broker
  template:
    metadata:
      labels:
        app: zeebe-broker
        component: zeebe
    spec:
      containers:
      - name: zeebe-broker
        image: camunda/zeebe:8.6.0
        ports:
        - containerPort: 26501
          name: command
        - containerPort: 26502
          name: internal
        - containerPort: 9600
          name: monitoring
        env:
        - name: ZEEBE_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS
          value: "zeebe-broker-0.zeebe-broker-headless.camunda.svc.cluster.local:26502,zeebe-broker-1.zeebe-broker-headless.camunda.svc.cluster.local:26502,zeebe-broker-2.zeebe-broker-headless.camunda.svc.cluster.local:26502"
        - name: ZEEBE_BROKER_NETWORK_ADVERTISEDHOST
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: JAVA_OPTS
          value: "-Xms1g -Xmx1g"
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m
        volumeMounts:
        - name: data
          mountPath: /usr/local/zeebe/data
        - name: config
          mountPath: /usr/local/zeebe/config/application.yaml
          subPath: application.yaml
        livenessProbe:
          httpGet:
            path: /ready
            port: 9600
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 9600
          initialDelaySeconds: 30
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: zeebe-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### zeebe-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: zeebe-broker-service
  namespace: camunda
  labels:
    app: zeebe-broker
spec:
  ports:
  - port: 26501
    name: command
  - port: 26502
    name: internal
  - port: 9600
    name: monitoring
  selector:
    app: zeebe-broker
---
apiVersion: v1
kind: Service
metadata:
  name: zeebe-broker-headless
  namespace: camunda
  labels:
    app: zeebe-broker
spec:
  clusterIP: None
  ports:
  - port: 26501
    name: command
  - port: 26502
    name: internal
  - port: 9600
    name: monitoring
  selector:
    app: zeebe-broker
```

## 5. Zeebe Gateway

### zeebe-gateway-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zeebe-gateway
  namespace: camunda
  labels:
    app: zeebe-gateway
    component: zeebe
spec:
  replicas: 2
  selector:
    matchLabels:
      app: zeebe-gateway
  template:
    metadata:
      labels:
        app: zeebe-gateway
        component: zeebe
    spec:
      containers:
      - name: zeebe-gateway
        image: camunda/zeebe:8.6.0
        command: ["/usr/local/zeebe/bin/gateway"]
        ports:
        - containerPort: 26500
          name: gateway
        - containerPort: 9600
          name: monitoring
        env:
        - name: ZEEBE_GATEWAY_CLUSTER_CONTACTPOINT
          value: "zeebe-broker-headless:26502"
        - name: ZEEBE_GATEWAY_NETWORK_HOST
          value: "0.0.0.0"
        - name: ZEEBE_GATEWAY_NETWORK_PORT
          value: "26500"
        - name: ZEEBE_GATEWAY_CLUSTER_HOST
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        resources:
          requests:
            memory: 512Mi
            cpu: 400m
          limits:
            memory: 1Gi
            cpu: 800m
        livenessProbe:
          httpGet:
            path: /ready
            port: 9600
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 9600
          initialDelaySeconds: 10
          periodSeconds: 5
```

### zeebe-gateway-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: zeebe-gateway-service
  namespace: camunda
  labels:
    app: zeebe-gateway
spec:
  type: ClusterIP
  ports:
  - port: 26500
    targetPort: 26500
    name: gateway
  - port: 9600
    targetPort: 9600
    name: monitoring
  selector:
    app: zeebe-gateway
```

## 6. Keycloak

### keycloak-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: camunda
  labels:
    app: keycloak
    component: identity
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
        component: identity
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0.7
        args: ["start", "--http-enabled=true", "--import-realm"]
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: camunda-common-secret
              key: admin-password
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://postgresql-service:5432/keycloak
        - name: KC_DB_USERNAME
          value: camunda
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: camunda-common-secret
              key: database-password
        - name: KC_HOSTNAME_STRICT
          value: "false"
        - name: KC_HOSTNAME_STRICT_HTTPS
          value: "false"
        - name: KC_HTTP_ENABLED
          value: "true"
        resources:
          requests:
            memory: 1Gi
            cpu: 500m
          limits:
            memory: 2Gi
            cpu: 1000m
        volumeMounts:
        - name: realm-config
          mountPath: /opt/keycloak/data/import
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
      volumes:
      - name: realm-config
        configMap:
          name: keycloak-realm-config
```

### keycloak-configmap.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-realm-config
  namespace: camunda
data:
  camunda-realm.json: |
    {
      "realm": "camunda-platform",
      "enabled": true,
      "displayName": "Camunda Platform",
      "clients": [
        {
          "clientId": "camunda-identity",
          "enabled": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "camunda-identity-secret",
          "standardFlowEnabled": true,
          "directAccessGrantsEnabled": true,
          "serviceAccountsEnabled": true,
          "publicClient": false,
          "redirectUris": ["*"],
          "webOrigins": ["*"]
        },
        {
          "clientId": "tasklist",
          "enabled": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "tasklist-secret",
          "standardFlowEnabled": true,
          "directAccessGrantsEnabled": true,
          "redirectUris": ["*"],
          "webOrigins": ["*"]
        },
        {
          "clientId": "operate",
          "enabled": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "operate-secret",
          "standardFlowEnabled": true,
          "directAccessGrantsEnabled": true,
          "redirectUris": ["*"],
          "webOrigins": ["*"]
        }
      ],
      "users": [
        {
          "username": "admin",
          "enabled": true,
          "credentials": [
            {
              "type": "password",
              "value": "admin",
              "temporary": false
            }
          ],
          "realmRoles": ["offline_access", "uma_authorization"],
          "clientRoles": {
            "account": ["manage-account", "view-profile"]
          }
        }
      ]
    }
```

### keycloak-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak-service
  namespace: camunda
  labels:
    app: keycloak
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: keycloak
```

## 7. Identity

### identity-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: identity
  namespace: camunda
  labels:
    app: identity
    component: identity
spec:
  replicas: 1
  selector:
    matchLabels:
      app: identity
  template:
    metadata:
      labels:
        app: identity
        component: identity
    spec:
      containers:
      - name: identity
        image: camunda/identity:8.6.0
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8082
          name: management
        env:
        - name: SERVER_PORT
          value: "8080"
        - name: KEYCLOAK_URL
          value: "http://keycloak-service:8080"
        - name: IDENTITY_AUTH_PROVIDER_BACKEND_URL
          value: "http://keycloak-service:8080/auth/realms/camunda-platform"
        - name: KEYCLOAK_SETUP_USER
          value: "admin"
        - name: KEYCLOAK_SETUP_PASSWORD
          valueFrom:
            secretKeyRef:
              name: camunda-common-secret
              key: admin-password
        - name: IDENTITY_DATABASE_HOST
          value: "postgresql-service"
        - name: IDENTITY_DATABASE_PORT
          value: "5432"
        - name: IDENTITY_DATABASE_NAME
          value: "identity"
        - name: IDENTITY_DATABASE_USERNAME
          value: "camunda"
        - name: IDENTITY_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: camunda-common-secret
              key: database-password
        resources:
          requests:
            memory: 1Gi
            cpu: 600m
          limits:
            memory: 2Gi
            cpu: 1200m
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8082
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8082
          initialDelaySeconds: 30
          periodSeconds: 10
```

### identity-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: identity-service
  namespace: camunda
  labels:
    app: identity
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  - port: 8082
    targetPort: 8082
    name: management
  selector:
    app: identity
```

## 8. Tasklist

### tasklist-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tasklist
  namespace: camunda
  labels:
    app: tasklist
    component: tasklist
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tasklist
  template:
    metadata:
      labels:
        app: tasklist
        component: tasklist
    spec:
      containers:
      - name: tasklist
        image: camunda/tasklist:8.6.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: CAMUNDA_TASKLIST_ZEEBE_GATEWAYADDRESS
          value: "zeebe-gateway-service:26500"
        - name: CAMUNDA_TASKLIST_ELASTICSEARCH_URL
          value: "http://elasticsearch-service:9200"
        - name: CAMUNDA_TASKLIST_ZEEBEELASTICSEARCH_URL
          value: "http://elasticsearch-service:9200"
        - name: SPRING_PROFILES_ACTIVE
          value: "identity-auth"
        - name: CAMUNDA_TASKLIST_IDENTITY_BASEURL
          value: "http://identity-service:8080"
        - name: CAMUNDA_TASKLIST_IDENTITY_CLIENTID
          value: "tasklist"
        - name: CAMUNDA_TASKLIST_IDENTITY_CLIENTSECRET
          value: "tasklist-secret"
        - name: CAMUNDA_TASKLIST_IDENTITY_AUDIENCE
          value: "tasklist-api"
        resources:
          requests:
            memory: 1Gi
            cpu: 400m
          limits:
            memory: 2Gi
            cpu: 800m
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

### tasklist-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: tasklist-service
  namespace: camunda
  labels:
    app: tasklist
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: tasklist
```

## 9. Operate

### operate-deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: operate
  namespace: camunda
  labels:
    app: operate
    component: operate
spec:
  replicas: 1
  selector:
    matchLabels:
      app: operate
  template:
    metadata:
      labels:
        app: operate
        component: operate
    spec:
      containers:
      - name: operate
        image: camunda/operate:8.6.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: CAMUNDA_OPERATE_ZEEBE_GATEWAYADDRESS
          value: "zeebe-gateway-service:26500"
        - name: CAMUNDA_OPERATE_ELASTICSEARCH_URL
          value: "http://elasticsearch-service:9200"
        - name: CAMUNDA_OPERATE_ZEEBEELASTICSEARCH_URL
          value: "http://elasticsearch-service:9200"
        - name: SPRING_PROFILES_ACTIVE
          value: "identity-auth"
        - name: CAMUNDA_OPERATE_IDENTITY_BASEURL
          value: "http://identity-service:8080"
        - name: CAMUNDA_OPERATE_IDENTITY_CLIENTID
          value: "operate"
        - name: CAMUNDA_OPERATE_IDENTITY_CLIENTSECRET
          value: "operate-secret"
        - name: CAMUNDA_OPERATE_IDENTITY_AUDIENCE
          value: "operate-api"
        resources:
          requests:
            memory: 1Gi
            cpu: 600m
          limits:
            memory: 2Gi
            cpu: 1200m
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
```

### operate-service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: operate-service
  namespace: camunda
  labels:
    app: operate
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: operate
```

## 10. Network Policies

### network-policy-elasticsearch.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: elasticsearch-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: elasticsearch
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          component: zeebe
    - podSelector:
        matchLabels:
          component: tasklist
    - podSelector:
        matchLabels:
          component: operate
    ports:
    - protocol: TCP
      port: 9200
    - protocol: TCP
      port: 9300
  - from:
    - podSelector:
        matchLabels:
          app: elasticsearch
    ports:
    - protocol: TCP
      port: 9300
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: elasticsearch
    ports:
    - protocol: TCP
      port: 9300
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: operate-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: operate
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []  # Allow from any source
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: zeebe-gateway
    ports:
    - protocol: TCP
      port: 26500
  - to:
    - podSelector:
        matchLabels:
          app: elasticsearch
    ports:
    - protocol: TCP
      port: 9200
  - to:
    - podSelector:
        matchLabels:
          app: identity
    ports:
    - protocol: TCP
      port: 8080
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: identity-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: identity
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          component: tasklist
    - podSelector:
        matchLabels:
          component: operate
    - podSelector: {}  # Allow from any pod in namespace
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: keycloak
    ports:
    - protocol: TCP
      port: 8080
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: keycloak-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: identity
    - podSelector: {}  # Allow from any pod in namespace for admin access
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: keycloak
    - podSelector:
        matchLabels:
          app: identity
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

## 11. Ingress Resources

### ingress-camunda.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: camunda-ingress
  namespace: camunda
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
  - host: tasklist.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tasklist-service
            port:
              number: 8080
  - host: operate.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: operate-service
            port:
              number: 8080
  - host: identity.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: identity-service
            port:
              number: 8080
  - host: keycloak.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak-service
            port:
              number: 8080
```

## 12. Horizontal Pod Autoscalers

### hpa-zeebe-gateway.yaml
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: zeebe-gateway-hpa
  namespace: camunda
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: zeebe-gateway
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### hpa-tasklist.yaml
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tasklist-hpa
  namespace: camunda
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tasklist
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### hpa-operate.yaml
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: operate-hpa
  namespace: camunda
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: operate
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 13. Pod Disruption Budgets

### pdb-elasticsearch.yaml
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: elasticsearch-pdb
  namespace: camunda
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: elasticsearch
```

### pdb-zeebe-broker.yaml
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: zeebe-broker-pdb
  namespace: camunda
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: zeebe-broker
```

### pdb-zeebe-gateway.yaml
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: zeebe-gateway-pdb
  namespace: camunda
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: zeebe-gateway
```

## 14. Monitoring Resources

### servicemonitor-zeebe.yaml
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zeebe-broker-metrics
  namespace: camunda
  labels:
    app: zeebe-broker
spec:
  selector:
    matchLabels:
      app: zeebe-broker
  endpoints:
  - port: monitoring
    path: /actuator/prometheus
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: zeebe-gateway-metrics
  namespace: camunda
  labels:
    app: zeebe-gateway
spec:
  selector:
    matchLabels:
      app: zeebe-gateway
  endpoints:
  - port: monitoring
    path: /actuator/prometheus
    interval: 30s
```

### servicemonitor-apps.yaml
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tasklist-metrics
  namespace: camunda
  labels:
    app: tasklist
spec:
  selector:
    matchLabels:
      app: tasklist
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: operate-metrics
  namespace: camunda
  labels:
    app: operate
spec:
  selector:
    matchLabels:
      app: operate
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: identity-metrics
  namespace: camunda
  labels:
    app: identity
spec:
  selector:
    matchLabels:
      app: identity
  endpoints:
  - port: management
    path: /actuator/prometheus
    interval: 30s
```

## 15. RBAC Resources

### rbac.yaml
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: camunda-service-account
  namespace: camunda
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: camunda
  name: camunda-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: camunda-rolebinding
  namespace: camunda
subjects:
- kind: ServiceAccount
  name: camunda-service-account
  namespace: camunda
roleRef:
  kind: Role
  name: camunda-role
  apiGroup: rbac.authorization.k8s.io
```

## 16. Storage Classes (Optional)

### storageclass-ssd.yaml
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: camunda-ssd
provisioner: kubernetes.io/gce-pd  # Change based on your cloud provider
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Retain
```

## 17. Deployment Order and Commands

### deploy.sh
```bash
#!/bin/bash

# Deployment script for Camunda 8.6 Self-Managed

echo "Deploying Camunda 8.6 Self-Managed..."

# Create namespace and common resources
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f configmap-common.yaml
kubectl apply -f secret-common.yaml

# Deploy storage class (if needed)
kubectl apply -f storageclass-ssd.yaml

# Deploy databases first
echo "Deploying databases..."
kubectl apply -f postgresql-configmap.yaml
kubectl apply -f postgresql-deployment.yaml
kubectl apply -f postgresql-service.yaml

# Wait for PostgreSQL
echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n camunda --timeout=300s

# Deploy Elasticsearch
echo "Deploying Elasticsearch..."
kubectl apply -f elasticsearch-configmap.yaml
kubectl apply -f elasticsearch-deployment.yaml
kubectl apply -f elasticsearch-service.yaml

# Wait for Elasticsearch
echo "Waiting for Elasticsearch to be ready..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n camunda --timeout=600s

# Deploy Keycloak
echo "Deploying Keycloak..."
kubectl apply -f keycloak-configmap.yaml
kubectl apply -f keycloak-deployment.yaml
kubectl apply -f keycloak-service.yaml

# Wait for Keycloak
echo "Waiting for Keycloak to be ready..."
kubectl wait --for=condition=ready pod -l app=keycloak -n camunda --timeout=300s

# Deploy Identity
echo "Deploying Identity..."
kubectl apply -f identity-deployment.yaml
kubectl apply -f identity-service.yaml

# Wait for Identity
echo "Waiting for Identity to be ready..."
kubectl wait --for=condition=ready pod -l app=identity -n camunda --timeout=300s

# Deploy Zeebe
echo "Deploying Zeebe Broker..."
kubectl apply -f zeebe-configmap.yaml
kubectl apply -f zeebe-deployment.yaml
kubectl apply -f zeebe-service.yaml

# Deploy Zeebe Gateway
echo "Deploying Zeebe Gateway..."
kubectl apply -f zeebe-gateway-deployment.yaml
kubectl apply -f zeebe-gateway-service.yaml

# Wait for Zeebe components
echo "Waiting for Zeebe components to be ready..."
kubectl wait --for=condition=ready pod -l app=zeebe-broker -n camunda --timeout=600s
kubectl wait --for=condition=ready pod -l app=zeebe-gateway -n camunda --timeout=300s

# Deploy Applications
echo "Deploying Tasklist..."
kubectl apply -f tasklist-deployment.yaml
kubectl apply -f tasklist-service.yaml

echo "Deploying Operate..."
kubectl apply -f operate-deployment.yaml
kubectl apply -f operate-service.yaml

# Wait for applications
echo "Waiting for applications to be ready..."
kubectl wait --for=condition=ready pod -l app=tasklist -n camunda --timeout=300s
kubectl wait --for=condition=ready pod -l app=operate -n camunda --timeout=300s

# Apply network policies
echo "Applying network policies..."
kubectl apply -f network-policy-elasticsearch.yaml
kubectl apply -f network-policy-zeebe.yaml
kubectl apply -f network-policy-apps.yaml

# Apply HPA and PDB
echo "Applying HPA and PDB..."
kubectl apply -f hpa-zeebe-gateway.yaml
kubectl apply -f hpa-tasklist.yaml
kubectl apply -f hpa-operate.yaml
kubectl apply -f pdb-elasticsearch.yaml
kubectl apply -f pdb-zeebe-broker.yaml
kubectl apply -f pdb-zeebe-gateway.yaml

# Apply monitoring (if Prometheus operator is installed)
echo "Applying monitoring resources..."
kubectl apply -f servicemonitor-zeebe.yaml
kubectl apply -f servicemonitor-apps.yaml

# Apply ingress (optional)
echo "Applying ingress..."
kubectl apply -f ingress-camunda.yaml

echo "Deployment completed!"
echo ""
echo "Access URLs (if using ingress with /etc/hosts entries):"
echo "- Tasklist: http://tasklist.local"
echo "- Operate: http://operate.local"
echo "- Identity: http://identity.local"
echo "- Keycloak: http://keycloak.local"
echo ""
echo "Or use port forwarding:"
echo "kubectl port-forward -n camunda svc/tasklist-service 8080:8080"
echo "kubectl port-forward -n camunda svc/operate-service 8081:8080"
echo "kubectl port-forward -n camunda svc/identity-service 8082:8080"
echo "kubectl port-forward -n camunda svc/keycloak-service 8083:8080"
```

### cleanup.sh
```bash
#!/bin/bash

# Cleanup script for Camunda 8.6 Self-Managed

echo "Cleaning up Camunda 8.6 Self-Managed..."

# Remove applications first
kubectl delete -f hpa-zeebe-gateway.yaml --ignore-not-found=true
kubectl delete -f hpa-tasklist.yaml --ignore-not-found=true
kubectl delete -f hpa-operate.yaml --ignore-not-found=true
kubectl delete -f pdb-elasticsearch.yaml --ignore-not-found=true
kubectl delete -f pdb-zeebe-broker.yaml --ignore-not-found=true
kubectl delete -f pdb-zeebe-gateway.yaml --ignore-not-found=true

kubectl delete -f tasklist-deployment.yaml --ignore-not-found=true
kubectl delete -f tasklist-service.yaml --ignore-not-found=true
kubectl delete -f operate-deployment.yaml --ignore-not-found=true
kubectl delete -f operate-service.yaml --ignore-not-found=true

kubectl delete -f zeebe-gateway-deployment.yaml --ignore-not-found=true
kubectl delete -f zeebe-gateway-service.yaml --ignore-not-found=true
kubectl delete -f zeebe-deployment.yaml --ignore-not-found=true
kubectl delete -f zeebe-service.yaml --ignore-not-found=true

kubectl delete -f identity-deployment.yaml --ignore-not-found=true
kubectl delete -f identity-service.yaml --ignore-not-found=true
kubectl delete -f keycloak-deployment.yaml --ignore-not-found=true
kubectl delete -f keycloak-service.yaml --ignore-not-found=true

kubectl delete -f elasticsearch-deployment.yaml --ignore-not-found=true
kubectl delete -f elasticsearch-service.yaml --ignore-not-found=true
kubectl delete -f postgresql-deployment.yaml --ignore-not-found=true
kubectl delete -f postgresql-service.yaml --ignore-not-found=true

# Remove network policies
kubectl delete -f network-policy-elasticsearch.yaml --ignore-not-found=true
kubectl delete -f network-policy-zeebe.yaml --ignore-not-found=true
kubectl delete -f network-policy-apps.yaml --ignore-not-found=true

# Remove ingress
kubectl delete -f ingress-camunda.yaml --ignore-not-found=true

# Remove monitoring
kubectl delete -f servicemonitor-zeebe.yaml --ignore-not-found=true
kubectl delete -f servicemonitor-apps.yaml --ignore-not-found=true

# Remove ConfigMaps and Secrets
kubectl delete -f zeebe-configmap.yaml --ignore-not-found=true
kubectl delete -f elasticsearch-configmap.yaml --ignore-not-found=true
kubectl delete -f keycloak-configmap.yaml --ignore-not-found=true
kubectl delete -f postgresql-configmap.yaml --ignore-not-found=true
kubectl delete -f configmap-common.yaml --ignore-not-found=true
kubectl delete -f secret-common.yaml --ignore-not-found=true

# Remove RBAC
kubectl delete -f rbac.yaml --ignore-not-found=true

# Optionally remove namespace (this will delete all remaining resources)
read -p "Do you want to delete the entire camunda namespace? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace camunda
fi

echo "Cleanup completed!"
```

## Usage Instructions

1. **Prepare your environment**: Ensure you have a Kubernetes 1.28+ cluster with sufficient resources
2. **Make scripts executable**: `chmod +x deploy.sh cleanup.sh`
3. **Deploy**: `./deploy.sh`
4. **Access applications**: Use port forwarding or configure ingress with proper DNS
5. **Cleanup when needed**: `./cleanup.sh`

## Important Notes

- Default credentials: admin/admin for all applications
- Persistent volumes will retain data between deployments
- Network policies restrict inter-pod communication for security
- HPA will scale components based on CPU/memory usage
- All components include health checks and monitoring endpoints
- Storage class should be adjusted based on your cloud provider: UDP
      port: 53
```

### network-policy-zeebe.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zeebe-broker-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: zeebe-broker
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: zeebe-gateway
    ports:
    - protocol: TCP
      port: 26501
  - from:
    - podSelector:
        matchLabels:
          app: zeebe-broker
    ports:
    - protocol: TCP
      port: 26502
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: zeebe-broker
    ports:
    - protocol: TCP
      port: 26502
  - to:
    - podSelector:
        matchLabels:
          app: elasticsearch
    ports:
    - protocol: TCP
      port: 9200
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zeebe-gateway-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: zeebe-gateway
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          component: tasklist
    - podSelector:
        matchLabels:
          component: operate
    - podSelector: {}  # Allow from any pod in namespace
    ports:
    - protocol: TCP
      port: 26500
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: zeebe-broker
    ports:
    - protocol: TCP
      port: 26501
    - protocol: TCP
      port: 26502
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### network-policy-apps.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tasklist-netpol
  namespace: camunda
spec:
  podSelector:
    matchLabels:
      app: tasklist
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []  # Allow from any source
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: zeebe-gateway
    ports:
    - protocol: TCP
      port: 26500
  - to:
    - podSelector:
        matchLabels:
          app: elasticsearch
    ports:
    - protocol: TCP
      port: 9200
  - to:
    - podSelector:
        matchLabels:
          app: identity
    ports:
    - protocol: TCP
      port: 8080
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol
