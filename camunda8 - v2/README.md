# Camunda 8.7 Self-Managed Full Stack Deployment

This directory contains Kubernetes manifests for deploying Camunda 8.7 self-managed full stack solution using ArgoCD.

## Components

| Component | Image Repository | Version |
|-----------|------------------|---------|
| Zeebe | `docker.io/camunda/zeebe` | 8.7.13 |
| Zeebe Broker | `docker.io/camunda/zeebe` | 8.7.13 |
| Zeebe Gateway | `docker.io/camunda/zeebe` | 8.7.13 |
| Operate | `docker.io/camunda/operate` | 8.7.13 |
| Tasklist | `docker.io/camunda/tasklist` | 8.7.13 |
| Optimize | `docker.io/camunda/optimize` | 8.7.9 |
| Identity | `docker.io/camunda/identity` | 8.7.6 |
| Console | `docker.io/camunda/console` | 8.7.72 |
| Connectors Bundle | `docker.io/camunda/connectors-bundle` | 8.7.8 |
| Web Modeler RestAPI | `docker.io/camunda/web-modeler-restapi` | 8.7.9 |
| Web Modeler WebApp | `docker.io/camunda/web-modeler-webapp` | 8.7.9 |
| Web Modeler WebSockets | `docker.io/camunda/web-modeler-websockets` | 8.7.9 |
| Keycloak | `docker.io/camunda/keycloak` | 26.3.2 |

## Prerequisites

- Kubernetes cluster (1.19+)
- ArgoCD installed and configured
- External PostgreSQL database
- External Elasticsearch cluster
- External Kibana instance
- Docker registry access for all images

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
- `[KEYCLOAK_URL]` - Keycloak server URL (e.g., `http://keycloak:80`)
- `[KEYCLOAK_ADMIN_USER]` - Keycloak admin username
- `[KEYCLOAK_ADMIN_PASSWORD]` - Keycloak admin password
- `[POSTGRES_HOST]` - PostgreSQL host for Keycloak database
- `[POSTGRES_DATABASE]` - PostgreSQL database name for Keycloak

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
├── keycloak/
│   ├── deployment.yaml
│   ├── service.yaml
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
- Keycloak is now included in the deployment
- Configure authentication and authorization
- Set up client applications for Camunda components

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

- All images are available from Docker Hub
- All manifests are ArgoCD compatible
- External PostgreSQL, Elasticsearch, and Kibana are not included
- Keycloak is included in the deployment
- RBAC configurations are excluded as requested
- Zeebe is split into Broker and Gateway components for better scalability