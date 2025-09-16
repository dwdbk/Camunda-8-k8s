# Camunda 8.4.2 Self-Managed Full Stack Deployment

This directory contains Kubernetes manifests for deploying Camunda 8.4.2 self-managed full stack solution using ArgoCD.

## Components

| Component | Image Repository | Version |
|-----------|------------------|---------|
| Zeebe | `docker.io/camunda/zeebe` | 8.4.19 |
| Zeebe Broker | `docker.io/camunda/zeebe` | 8.4.19 |
| Zeebe Gateway | `docker.io/camunda/zeebe` | 8.4.19 |
| Operate | `docker.io/camunda/operate` | 8.4.20 |
| Tasklist | `docker.io/camunda/tasklist` | 8.4.21 |
| Optimize | `docker.io/camunda/optimize` | 8.4.18 |
| Identity | `docker.io/camunda/identity` | 8.4.21 |
| Console | `docker.io/camunda/console` | 8.4.21 |
| Connectors Bundle | `docker.io/camunda/connectors-bundle` | 8.4.19 |
| Web Modeler RestAPI | `registry.camunda.cloud/web-modeler-ee/modeler-restapi` | 8.4.18 |
| Web Modeler WebApp | `registry.camunda.cloud/web-modeler-ee/modeler-webapp` | 8.4.18 |
| Web Modeler WebSockets | `registry.camunda.cloud/web-modeler-ee/modeler-websockets` | 8.4.18 |

## Prerequisites

- Kubernetes cluster (1.19+)
- ArgoCD installed and configured
- External PostgreSQL database
- External Elasticsearch cluster
- External Kibana instance
- External Keycloak instance
- Docker registry access for enterprise images (Web Modeler)

## Configuration

### Required Placeholders

Replace the following placeholders in all manifest files with your actual values:

#### PostgreSQL Configuration
- `[POSTGRES_URL]` - Full PostgreSQL connection URL (e.g., `jdbc:postgresql://postgres-host:5432/camunda`)
- `[POSTGRES_USER]` - PostgreSQL username
- `[POSTGRES_PASSWORD]` - PostgreSQL password

#### Elasticsearch Configuration
- `[ELASTICSEARCH_URL]` - Elasticsearch cluster URL (e.g., `http://elasticsearch:9200`)
- `[ELASTIC_INDEX]` - Index prefix for Camunda data (e.g., `camunda-record`)

#### Keycloak Configuration
- `[KEYCLOAK_URL]` - External Keycloak server URL (e.g., `http://keycloak.example.com:8080`)

## Directory Structure

```
.
├── zeebe/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── zeebe-broker/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── networkpolicy.yaml
├── zeebe-gateway/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── networkpolicy.yaml
├── operate/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── tasklist/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── optimize/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── identity/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── console/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   ├── secret.yaml
│   └── configmap.yaml
├── connectors/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── networkpolicy.yaml
│   └── secret.yaml
├── web-modeler/
│   ├── restapi-deployment.yaml
│   ├── restapi-service.yaml
│   ├── webapp-deployment.yaml
│   ├── webapp-service.yaml
│   ├── websockets-deployment.yaml
│   ├── websockets-service.yaml
│   ├── networkpolicy.yaml
│   └── secrets.yaml
├── kustomization.yaml
├── namespace.yaml
├── values-template.yaml
└── README.md
```

## Deployment

### Using ArgoCD

1. Create an ArgoCD application pointing to this directory
2. Replace all placeholders with actual values
3. Sync the application

### Using kubectl

1. Replace all placeholders with actual values
2. Apply manifests in order:
   ```bash
   kubectl apply -k .
   ```

### Using Kustomize

```bash
kustomize build . | kubectl apply -f -
```

## External Dependencies

### PostgreSQL
- Create databases for each component
- Ensure proper user permissions
- Configure connection pooling if needed

### Elasticsearch
- Create required indices (automatically created by Zeebe exporter)
- Configure index templates if needed
- Set up proper authentication if required

### Kibana
- Configure to connect to the same Elasticsearch instance
- Import Camunda dashboards if available
- Set up proper authentication if required

### Keycloak
- Configure external Keycloak instance
- Set up proper authentication and authorization
- Configure client applications for Camunda components

## Security Considerations

- All sensitive data is managed via Kubernetes Secrets
- NetworkPolicies restrict inter-pod communication
- RBAC configurations are excluded (add separately if needed)
- Use proper TLS certificates for production deployments
- External Keycloak integration for authentication

## Monitoring

- Configure monitoring for all components
- Set up alerts for critical services
- Monitor resource usage and performance

## Troubleshooting

1. Check pod logs for startup issues
2. Verify network connectivity between components
3. Ensure external dependencies are accessible
4. Check resource limits and requests
5. Verify Keycloak connectivity and configuration

## Notes

- Web Modeler images require enterprise authentication
- All manifests are ArgoCD compatible
- External PostgreSQL, Elasticsearch, Kibana, and Keycloak are not included
- RBAC configurations are excluded as requested
- Zeebe is split into Broker and Gateway components for better scalability