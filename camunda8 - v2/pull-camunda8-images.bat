@echo off
setlocal enabledelayedexpansion

REM Camunda 8.7 Docker Image Pull Script for Windows
REM This script pulls all Camunda 8 components with compatible versions

echo ==========================================
echo Camunda 8.7 Docker Image Pull Script
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

call :pull_image "docker.io/camunda/zeebe:8.7.13"
call :pull_image "docker.io/camunda/operate:8.7.13"
call :pull_image "docker.io/camunda/tasklist:8.7.13"
call :pull_image "docker.io/camunda/optimize:8.7.9"
call :pull_image "docker.io/camunda/identity:8.7.6"
call :pull_image "docker.io/camunda/console:8.7.72"
call :pull_image "docker.io/camunda/connectors-bundle:8.7.8"

echo.
echo [SUCCESS] Core components pulled successfully
echo.

REM Web Modeler Components
echo [INFO] Pulling Web Modeler Components...
echo.

call :pull_image "docker.io/camunda/web-modeler-restapi:8.7.9"
call :pull_image "docker.io/camunda/web-modeler-webapp:8.7.9"
call :pull_image "docker.io/camunda/web-modeler-websockets:8.7.9"

echo.
echo [SUCCESS] Web Modeler components pulled successfully
echo.

REM Keycloak
echo [INFO] Pulling Keycloak...
call :pull_image "docker.io/camunda/keycloak:26.3.2"
echo [SUCCESS] Keycloak pulled successfully
echo.

REM Display pulled images
echo [INFO] Displaying pulled Camunda 8 images...
echo.
docker images | findstr /i "camunda" | findstr "8.7. 26.3."

echo.
echo [SUCCESS] ==========================================
echo [SUCCESS] Camunda 8.7 Image Pull Complete!
echo [SUCCESS] ==========================================
echo.

echo [INFO] Version Compatibility Matrix:
echo ┌─────────────────┬─────────────────────────────┬─────────┐
echo │ Component       │ Image                        │ Version │
echo ├─────────────────┼─────────────────────────────┼─────────┤
echo │ Zeebe           │ camunda/zeebe                │ 8.7.13  │
echo │ Operate         │ camunda/operate              │ 8.7.13  │
echo │ Tasklist        │ camunda/tasklist             │ 8.7.13  │
echo │ Optimize        │ camunda/optimize             │ 8.7.9   │
echo │ Identity        │ camunda/identity             │ 8.7.6   │
echo │ Console         │ camunda/console              │ 8.7.72  │
echo │ Connectors      │ camunda/connectors-bundle    │ 8.7.8   │
echo │ Web Modeler API │ camunda/web-modeler-restapi  │ 8.7.9   │
echo │ Web Modeler UI  │ camunda/web-modeler-webapp   │ 8.7.9   │
echo │ Web Modeler WS  │ camunda/web-modeler-websockets │ 8.7.9   │
echo │ Keycloak        │ camunda/keycloak             │ 26.3.2  │
echo └─────────────────┴─────────────────────────────┴─────────┘
echo.

echo [INFO] Next steps:
echo 1. Update your Kubernetes manifests with the correct image versions
echo 2. Configure external dependencies (PostgreSQL, Elasticsearch, Kibana)
echo 3. Deploy using: kubectl apply -k .
echo 4. Or use ArgoCD to deploy from your Git repository
echo.
echo [WARNING] Note: Make sure to replace all [PLACEHOLDER] values in your manifests
echo [WARNING] with actual configuration values before deployment.
echo.
pause
