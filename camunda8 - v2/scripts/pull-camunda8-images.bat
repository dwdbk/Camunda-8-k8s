@echo off
setlocal enabledelayedexpansion

REM Camunda 8.4.2 Docker Image Pull Script for Windows
REM This script pulls all Camunda 8 components with compatible versions

echo ==========================================
echo Camunda 8.4.2 Docker Image Pull Script
echo ==========================================
echo.

REM Check if Docker is running
echo [INFO] Checking Docker daemon...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker daemon is not running. Please start Docker and try again.
    pause
    exit /b 1
)
echo [SUCCESS] Docker daemon is running
echo.

REM Function to pull image with retry
:pull_image
set image=%1
set max_attempts=3
set attempt=1

:retry_pull
echo [INFO] Pulling %image% (attempt %attempt%/%max_attempts%)...
docker pull %image%
if %errorlevel% equ 0 (
    echo [SUCCESS] Successfully pulled %image%
    goto :eof
) else (
    echo [ERROR] Failed to pull %image% (attempt %attempt%/%max_attempts%)
    if %attempt% equ %max_attempts% (
        echo [ERROR] Failed to pull %image% after %max_attempts% attempts
        exit /b 1
    )
    timeout /t 5 /nobreak >nul
    set /a attempt+=1
    goto retry_pull
)

REM Core Camunda 8 Components
echo [INFO] Pulling Core Camunda 8 Components...
echo.

call :pull_image "docker.io/camunda/zeebe:8.4.19"
call :pull_image "docker.io/camunda/operate:8.4.20"
call :pull_image "docker.io/camunda/tasklist:8.4.21"
call :pull_image "docker.io/camunda/optimize:8.4.18"
call :pull_image "docker.io/camunda/identity:8.4.21"
call :pull_image "docker.io/camunda/console:8.4.21"
call :pull_image "docker.io/camunda/connectors-bundle:8.4.19"

echo.
echo [SUCCESS] Core components pulled successfully
echo.

REM Web Modeler Components (Enterprise)
echo [INFO] Pulling Web Modeler Components (Enterprise)...
echo [WARNING] Web Modeler components require enterprise authentication.
echo [WARNING] Make sure you are logged in to the Camunda registry:
echo [WARNING] docker login registry.camunda.cloud
echo.
set /p pull_webmodeler="Do you want to pull Web Modeler components? (y/N): "
if /i "%pull_webmodeler%"=="y" (
    call :pull_image "registry.camunda.cloud/web-modeler-ee/modeler-restapi:8.4.18"
    call :pull_image "registry.camunda.cloud/web-modeler-ee/modeler-webapp:8.4.18"
    call :pull_image "registry.camunda.cloud/web-modeler-ee/modeler-websockets:8.4.18"
    echo [SUCCESS] Web Modeler components pulled successfully
) else (
    echo [WARNING] Skipping Web Modeler components
)
echo.

REM Optional: Pull Keycloak
echo [INFO] Pulling Keycloak (Optional)...
set /p pull_keycloak="Do you want to pull Keycloak? (y/N): "
if /i "%pull_keycloak%"=="y" (
    call :pull_image "quay.io/keycloak/keycloak:22.0.5"
    echo [SUCCESS] Keycloak pulled successfully
) else (
    echo [WARNING] Skipping Keycloak (using external instance)
)
echo.

REM Display pulled images
echo [INFO] Displaying pulled Camunda 8 images...
echo.
docker images | findstr /i "camunda keycloak" | findstr "8.4. 22.0."

echo.
echo [SUCCESS] ==========================================
echo [SUCCESS] Camunda 8.4.2 Image Pull Complete!
echo [SUCCESS] ==========================================
echo.

echo [INFO] Version Compatibility Matrix:
echo ┌─────────────────┬─────────────────────────────┬─────────┐
echo │ Component       │ Image                        │ Version │
echo ├─────────────────┼─────────────────────────────┼─────────┤
echo │ Zeebe           │ camunda/zeebe                │ 8.4.19  │
echo │ Operate         │ camunda/operate              │ 8.4.20  │
echo │ Tasklist        │ camunda/tasklist             │ 8.4.21  │
echo │ Optimize        │ camunda/optimize             │ 8.4.18  │
echo │ Identity        │ camunda/identity             │ 8.4.21  │
echo │ Console         │ camunda/console              │ 8.4.21  │
echo │ Connectors      │ camunda/connectors-bundle    │ 8.4.19  │
echo │ Web Modeler API │ web-modeler-ee/modeler-restapi │ 8.4.18  │
echo │ Web Modeler UI  │ web-modeler-ee/modeler-webapp  │ 8.4.18  │
echo │ Web Modeler WS  │ web-modeler-ee/modeler-websockets │ 8.4.18  │
echo │ Keycloak        │ quay.io/keycloak/keycloak    │ 22.0.5  │
echo └─────────────────┴─────────────────────────────┴─────────┘
echo.

echo [INFO] Next steps:
echo 1. Update your Kubernetes manifests with the correct image versions
echo 2. Configure external dependencies (PostgreSQL, Elasticsearch, Kibana, Keycloak)
echo 3. Deploy using: kubectl apply -k .
echo 4. Or use ArgoCD to deploy from your Git repository
echo.
echo [WARNING] Note: Make sure to replace all [PLACEHOLDER] values in your manifests
echo [WARNING] with actual configuration values before deployment.
echo.
pause
