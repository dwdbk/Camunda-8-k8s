#!/bin/bash

# Camunda 8.4.2 Docker Image Pull Script
# This script pulls all Camunda 8 components with compatible versions

set -e

echo "=========================================="
echo "Camunda 8.4.2 Docker Image Pull Script"
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to pull image with retry
pull_image() {
    local image=$1
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_status "Pulling $image (attempt $attempt/$max_attempts)..."
        
        if docker pull "$image"; then
            print_success "Successfully pulled $image"
            return 0
        else
            print_error "Failed to pull $image (attempt $attempt/$max_attempts)"
            if [ $attempt -eq $max_attempts ]; then
                print_error "Failed to pull $image after $max_attempts attempts"
                return 1
            fi
            sleep 5
            ((attempt++))
        fi
    done
}

# Check if Docker is running
print_status "Checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running. Please start Docker and try again."
    exit 1
fi
print_success "Docker daemon is running"

# Core Camunda 8 Components
print_status "Pulling Core Camunda 8 Components..."

# Zeebe (Workflow Engine)
pull_image "docker.io/camunda/zeebe:8.4.19"

# Operate (Process Monitoring)
pull_image "docker.io/camunda/operate:8.4.20"

# Tasklist (Task Management)
pull_image "docker.io/camunda/tasklist:8.4.21"

# Optimize (Process Optimization)
pull_image "docker.io/camunda/optimize:8.4.18"

# Identity (Identity Management)
pull_image "docker.io/camunda/identity:8.4.21"

# Console (Management Console)
pull_image "docker.io/camunda/console:8.4.21"

# Connectors Bundle
pull_image "docker.io/camunda/connectors-bundle:8.4.19"

print_success "Core components pulled successfully"

# Web Modeler Components (Enterprise)
print_status "Pulling Web Modeler Components (Enterprise)..."

# Check if user has access to enterprise registry
print_warning "Web Modeler components require enterprise authentication."
print_warning "Make sure you are logged in to the Camunda registry:"
print_warning "docker login registry.camunda.cloud"

read -p "Do you want to pull Web Modeler components? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Web Modeler RestAPI
    pull_image "registry.camunda.cloud/web-modeler-ee/modeler-restapi:8.4.18"
    
    # Web Modeler WebApp
    pull_image "registry.camunda.cloud/web-modeler-ee/modeler-webapp:8.4.18"
    
    # Web Modeler WebSockets
    pull_image "registry.camunda.cloud/web-modeler-ee/modeler-websockets:8.4.18"
    
    print_success "Web Modeler components pulled successfully"
else
    print_warning "Skipping Web Modeler components"
fi

# Optional: Pull Keycloak (if you want to use the official image)
print_status "Pulling Keycloak (Optional)..."
read -p "Do you want to pull Keycloak? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pull_image "quay.io/keycloak/keycloak:22.0.5"
    print_success "Keycloak pulled successfully"
else
    print_warning "Skipping Keycloak (using external instance)"
fi

# Display pulled images
print_status "Displaying pulled Camunda 8 images..."
echo
docker images | grep -E "(camunda|keycloak)" | grep -E "(8\.4\.|22\.0\.)" | sort

echo
print_success "=========================================="
print_success "Camunda 8.4.2 Image Pull Complete!"
print_success "=========================================="

# Display version compatibility matrix
echo
print_status "Version Compatibility Matrix:"
echo "┌─────────────────┬─────────────────────────────┬─────────┐"
echo "│ Component       │ Image                        │ Version │"
echo "├─────────────────┼─────────────────────────────┼─────────┤"
echo "│ Zeebe           │ camunda/zeebe                │ 8.4.19  │"
echo "│ Operate         │ camunda/operate              │ 8.4.20  │"
echo "│ Tasklist        │ camunda/tasklist             │ 8.4.21  │"
echo "│ Optimize        │ camunda/optimize             │ 8.4.18  │"
echo "│ Identity        │ camunda/identity             │ 8.4.21  │"
echo "│ Console         │ camunda/console              │ 8.4.21  │"
echo "│ Connectors      │ camunda/connectors-bundle    │ 8.4.19  │"
echo "│ Web Modeler API │ web-modeler-ee/modeler-restapi │ 8.4.18  │"
echo "│ Web Modeler UI  │ web-modeler-ee/modeler-webapp  │ 8.4.18  │"
echo "│ Web Modeler WS  │ web-modeler-ee/modeler-websockets │ 8.4.18  │"
echo "│ Keycloak        │ quay.io/keycloak/keycloak    │ 22.0.5  │"
echo "└─────────────────┴─────────────────────────────┴─────────┘"

echo
print_status "Next steps:"
echo "1. Update your Kubernetes manifests with the correct image versions"
echo "2. Configure external dependencies (PostgreSQL, Elasticsearch, Kibana, Keycloak)"
echo "3. Deploy using: kubectl apply -k ."
echo "4. Or use ArgoCD to deploy from your Git repository"

echo
print_warning "Note: Make sure to replace all [PLACEHOLDER] values in your manifests"
print_warning "with actual configuration values before deployment."
