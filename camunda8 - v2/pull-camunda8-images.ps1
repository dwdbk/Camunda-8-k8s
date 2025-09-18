# Camunda 8.7 Docker Image Pull Script for PowerShell
# This script pulls all Camunda 8 components with compatible versions

param(
    [switch]$Force
)

# Color functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Camunda 8.7 Docker Image Pull Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Info "Checking Docker daemon..."
try {
    docker info | Out-Null
    Write-Success "Docker daemon is running"
} catch {
    Write-Error "Docker daemon is not running. Please start Docker and try again."
    exit 1
}

# Function to pull image with retry
function Pull-Image {
    param(
        [string]$Image,
        [int]$MaxAttempts = 3
    )
    
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        Write-Info "Pulling $Image (attempt $attempt/$MaxAttempts)..."
        
        try {
            docker pull $Image
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Successfully pulled $Image"
                return $true
            } else {
                throw "Docker pull failed with exit code $LASTEXITCODE"
            }
        } catch {
            Write-Error "Failed to pull $Image (attempt $attempt/$MaxAttempts)"
            if ($attempt -eq $MaxAttempts) {
                Write-Error "Failed to pull $Image after $MaxAttempts attempts"
                return $false
            }
            Start-Sleep -Seconds 5
            $attempt++
        }
    }
    return $false
}

# Core Camunda 8 Components
Write-Info "Pulling Core Camunda 8 Components..."
Write-Host ""

$coreImages = @(
    "docker.io/camunda/zeebe:8.7.13",
    "docker.io/camunda/operate:8.7.13",
    "docker.io/camunda/tasklist:8.7.13",
    "docker.io/camunda/optimize:8.7.9",
    "docker.io/camunda/identity:8.7.6",
    "docker.io/camunda/console:8.7.72",
    "docker.io/camunda/connectors-bundle:8.7.8"
)

$failedImages = @()
foreach ($image in $coreImages) {
    if (-not (Pull-Image -Image $image)) {
        $failedImages += $image
    }
}

if ($failedImages.Count -eq 0) {
    Write-Success "Core components pulled successfully"
} else {
    Write-Error "Failed to pull some core components: $($failedImages -join ', ')"
}

Write-Host ""

# Web Modeler Components
Write-Info "Pulling Web Modeler Components..."
Write-Host ""

$webModelerImages = @(
    "docker.io/camunda/web-modeler-restapi:8.7.9",
    "docker.io/camunda/web-modeler-webapp:8.7.9",
    "docker.io/camunda/web-modeler-websockets:8.7.9"
)

foreach ($image in $webModelerImages) {
    if (-not (Pull-Image -Image $image)) {
        $failedImages += $image
    }
}

if ($webModelerImages | Where-Object { $failedImages -notcontains $_ }) {
    Write-Success "Web Modeler components pulled successfully"
}

Write-Host ""

# Keycloak
Write-Info "Pulling Keycloak..."
if (Pull-Image -Image "docker.io/camunda/keycloak:26.3.2") {
    Write-Success "Keycloak pulled successfully"
} else {
    $failedImages += "docker.io/camunda/keycloak:26.3.2"
}

Write-Host ""

# Display pulled images
Write-Info "Displaying pulled Camunda 8 images..."
Write-Host ""
docker images | Select-String -Pattern "camunda" | Select-String -Pattern "(8\.7\.|26\.3\.)"

Write-Host ""
Write-Success "=========================================="
Write-Success "Camunda 8.7 Image Pull Complete!"
Write-Success "=========================================="
Write-Host ""

Write-Info "Version Compatibility Matrix:"
Write-Host "┌─────────────────┬─────────────────────────────┬─────────┐"
Write-Host "│ Component       │ Image                        │ Version │"
Write-Host "├─────────────────┼─────────────────────────────┼─────────┤"
Write-Host "│ Zeebe           │ camunda/zeebe                │ 8.7.13  │"
Write-Host "│ Operate         │ camunda/operate              │ 8.7.13  │"
Write-Host "│ Tasklist        │ camunda/tasklist             │ 8.7.13  │"
Write-Host "│ Optimize        │ camunda/optimize             │ 8.7.9   │"
Write-Host "│ Identity        │ camunda/identity             │ 8.7.6   │"
Write-Host "│ Console         │ camunda/console              │ 8.7.72  │"
Write-Host "│ Connectors      │ camunda/connectors-bundle    │ 8.7.8   │"
Write-Host "│ Web Modeler API │ camunda/web-modeler-restapi  │ 8.7.9   │"
Write-Host "│ Web Modeler UI  │ camunda/web-modeler-webapp   │ 8.7.9   │"
Write-Host "│ Web Modeler WS  │ camunda/web-modeler-websockets │ 8.7.9   │"
Write-Host "│ Keycloak        │ camunda/keycloak             │ 26.3.2  │"
Write-Host "└─────────────────┴─────────────────────────────┴─────────┘"
Write-Host ""

Write-Info "Next steps:"
Write-Host "1. Update your Kubernetes manifests with the correct image versions"
Write-Host "2. Configure external dependencies (PostgreSQL, Elasticsearch, Kibana)"
Write-Host "3. Deploy using: kubectl apply -k ."
Write-Host "4. Or use ArgoCD to deploy from your Git repository"
Write-Host ""
Write-Warning "Note: Make sure to replace all [PLACEHOLDER] values in your manifests"
Write-Warning "with actual configuration values before deployment."

if ($failedImages.Count -gt 0) {
    Write-Host ""
    Write-Error "Some images failed to pull. Please check your Docker configuration and try again."
    exit 1
}
