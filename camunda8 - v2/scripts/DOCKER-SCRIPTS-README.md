# Camunda 8.4.2 Docker Image Pull Scripts

This directory contains scripts to pull all Camunda 8.4.2 components with compatible versions using Docker.

## 📋 Available Scripts

### 1. **pull-camunda8-images.sh** (Linux/macOS)
Bash script for Unix-like systems with colored output and retry logic.

```bash
# Make executable
chmod +x pull-camunda8-images.sh

# Run the script
./pull-camunda8-images.sh
```

### 2. **pull-camunda8-images.bat** (Windows)
Batch script for Windows Command Prompt.

```cmd
# Run the script
pull-camunda8-images.bat
```

### 3. **pull-camunda8-images.ps1** (PowerShell)
PowerShell script with advanced features and parameters.

```powershell
# Run with default options
.\pull-camunda8-images.ps1

# Skip Web Modeler components
.\pull-camunda8-images.ps1 -SkipWebModeler

# Skip Keycloak
.\pull-camunda8-images.ps1 -SkipKeycloak

# Skip both and force execution
.\pull-camunda8-images.ps1 -SkipWebModeler -SkipKeycloak -Force
```

### 4. **docker-compose.yml** (Local Development)
Docker Compose file for local testing with all dependencies.

```bash
# Start the complete stack
docker-compose up -d

# Stop the stack
docker-compose down

# View logs
docker-compose logs -f
```

## 🐳 Components and Versions

| Component | Image | Version | Registry |
|-----------|-------|---------|----------|
| **Core Components** |
| Zeebe | `camunda/zeebe` | 8.4.19 | docker.io |
| Operate | `camunda/operate` | 8.4.20 | docker.io |
| Tasklist | `camunda/tasklist` | 8.4.21 | docker.io |
| Optimize | `camunda/optimize` | 8.4.18 | docker.io |
| Identity | `camunda/identity` | 8.4.21 | docker.io |
| Console | `camunda/console` | 8.4.21 | docker.io |
| Connectors | `camunda/connectors-bundle` | 8.4.19 | docker.io |
| **Enterprise Components** |
| Web Modeler RestAPI | `web-modeler-ee/modeler-restapi` | 8.4.18 | registry.camunda.cloud |
| Web Modeler WebApp | `web-modeler-ee/modeler-webapp` | 8.4.18 | registry.camunda.cloud |
| Web Modeler WebSockets | `web-modeler-ee/modeler-websockets` | 8.4.18 | registry.camunda.cloud |
| **External Dependencies** |
| Keycloak | `keycloak/keycloak` | 22.0.5 | quay.io |
| PostgreSQL | `postgres` | 15 | docker.io |
| Elasticsearch | `elasticsearch/elasticsearch` | 8.11.0 | docker.elastic.co |
| Kibana | `kibana/kibana` | 8.11.0 | docker.elastic.co |

## 🔧 Prerequisites

### Docker
- Docker Engine 20.10+ installed and running
- Docker Compose 2.0+ (for local development)

### Registry Access
- **Docker Hub**: Public access for core components
- **Camunda Registry**: Enterprise authentication required for Web Modeler
- **Quay.io**: Public access for Keycloak

### Authentication
For enterprise components, you need to authenticate with Camunda's registry:

```bash
# Login to Camunda registry
docker login registry.camunda.cloud

# Enter your enterprise credentials when prompted
```

## 🚀 Usage Examples

### Pull All Components
```bash
# Linux/macOS
./pull-camunda8-images.sh

# Windows
pull-camunda8-images.bat

# PowerShell
.\pull-camunda8-images.ps1
```

### Pull Only Core Components
```bash
# PowerShell - Skip enterprise components
.\pull-camunda8-images.ps1 -SkipWebModeler -SkipKeycloak
```

### Local Development Stack
```bash
# Start complete local stack
docker-compose up -d

# Access services:
# - Zeebe Gateway: http://localhost:26500
# - Operate: http://localhost:8081
# - Tasklist: http://localhost:8082
# - Optimize: http://localhost:8083
# - Identity: http://localhost:8084
# - Console: http://localhost:8085
# - Connectors: http://localhost:8086
# - Keycloak: http://localhost:8080
# - Kibana: http://localhost:5601
```

## 🔍 Verification

### Check Pulled Images
```bash
# List all Camunda images
docker images | grep camunda

# List specific version
docker images | grep "8.4."

# Check image size
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep camunda
```

### Test Image Functionality
```bash
# Test Zeebe
docker run --rm camunda/zeebe:8.4.19 --version

# Test Operate
docker run --rm camunda/operate:8.4.20 --version

# Test Tasklist
docker run --rm camunda/tasklist:8.4.21 --version
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. **Docker Daemon Not Running**
```bash
# Error: Cannot connect to the Docker daemon
# Solution: Start Docker service
sudo systemctl start docker  # Linux
# Or start Docker Desktop on Windows/macOS
```

#### 2. **Registry Authentication Failed**
```bash
# Error: unauthorized: authentication required
# Solution: Login to registry
docker login registry.camunda.cloud
```

#### 3. **Out of Disk Space**
```bash
# Check disk usage
docker system df

# Clean up unused images
docker system prune -a

# Remove specific images
docker rmi $(docker images -q camunda/*)
```

#### 4. **Network Issues**
```bash
# Check Docker network
docker network ls

# Test connectivity
docker run --rm alpine ping -c 3 registry.camunda.cloud
```

### Script-Specific Issues

#### Bash Script (Linux/macOS)
- Ensure script is executable: `chmod +x pull-camunda8-images.sh`
- Check if Docker is in PATH: `which docker`

#### Batch Script (Windows)
- Run as Administrator if needed
- Check if Docker Desktop is running

#### PowerShell Script (Windows)
- Set execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Run in PowerShell (not Command Prompt)

## 📊 Image Sizes

| Component | Approximate Size |
|-----------|------------------|
| Zeebe | ~500MB |
| Operate | ~400MB |
| Tasklist | ~400MB |
| Optimize | ~400MB |
| Identity | ~400MB |
| Console | ~400MB |
| Connectors | ~300MB |
| Web Modeler (each) | ~200MB |
| Keycloak | ~600MB |

**Total**: ~3.5GB for all components

## 🔄 Updates

To update to newer versions:

1. **Check for new versions**:
   ```bash
   docker search camunda/zeebe
   ```

2. **Update the script** with new version numbers

3. **Pull new images**:
   ```bash
   ./pull-camunda8-images.sh
   ```

4. **Update Kubernetes manifests** with new image versions

## 📝 Notes

- **Compatibility**: All versions are tested for compatibility within the 8.4.x series
- **Security**: Always use specific version tags, not `latest`
- **Production**: These scripts are for development/testing. Use proper image management in production
- **Storage**: Ensure sufficient disk space (at least 5GB free)
- **Network**: Stable internet connection recommended for large image downloads

## 🆘 Support

If you encounter issues:

1. Check Docker daemon status
2. Verify network connectivity
3. Check available disk space
4. Review Docker logs: `docker logs <container_name>`
5. Consult Camunda documentation for component-specific issues
