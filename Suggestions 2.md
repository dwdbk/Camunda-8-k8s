# Camunda 8.6 Self-Managed Kubernetes Manifests (No RBAC)

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
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: operate-netpol
  namespace: camunda
