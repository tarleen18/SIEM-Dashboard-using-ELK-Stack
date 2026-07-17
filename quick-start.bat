@echo off
REM ===============================================
REM SIEM ELK Stack - Quick Start Script (Windows)
REM ===============================================
REM This script sets up and starts the ELK Stack
REM ===============================================

setlocal enabledelayedexpansion

cls
echo.
echo ========================================
echo    SIEM ELK Stack - Quick Start
echo ========================================
echo.

REM Step 1: Check Docker
echo [*] Step 1: Checking Docker Installation...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [!] ERROR: Docker is not installed
    echo Please install Docker Desktop from: https://docs.docker.com/get-docker/
    pause
    exit /b 1
)
echo [+] Docker is installed

docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo [!] ERROR: Docker Compose is not installed
    echo Please install Docker Compose from: https://docs.docker.com/compose/install/
    pause
    exit /b 1
)
echo [+] Docker Compose is installed
echo.

REM Step 2: Check Docker daemon
echo [*] Step 2: Checking Docker Daemon...
docker info >nul 2>&1
if errorlevel 1 (
    echo [!] ERROR: Docker daemon is not running
    echo Please start Docker Desktop
    pause
    exit /b 1
)
echo [+] Docker daemon is running
echo.

REM Step 3: Create directory structure
echo [*] Step 3: Creating Directory Structure...
if not exist "elasticsearch\config" mkdir elasticsearch\config
if not exist "elasticsearch\data" mkdir elasticsearch\data
if not exist "kibana\config" mkdir kibana\config
if not exist "logstash\config" mkdir logstash\config
if not exist "logstash\pipeline" mkdir logstash\pipeline
if not exist "filebeat" mkdir filebeat
if not exist "sample-logs" mkdir sample-logs
echo [+] Directory structure created
echo.

REM Step 4: Pull Docker images
echo [*] Step 4: Pulling Docker Images (this may take a few minutes)...
echo [*] Please wait...
docker-compose pull
if errorlevel 1 (
    echo [!] ERROR: Failed to pull Docker images
    pause
    exit /b 1
)
echo [+] Docker images pulled successfully
echo.

REM Step 5: Start services
echo [*] Step 5: Starting ELK Stack Services...
docker-compose up -d
if errorlevel 1 (
    echo [!] ERROR: Failed to start containers
    pause
    exit /b 1
)
echo [+] Docker containers started
echo.

REM Step 6: Wait for services
echo [*] Step 6: Waiting for Services to Be Healthy...
echo [*] This may take 1-2 minutes...
echo.

REM Wait for Elasticsearch
echo [*] Waiting for Elasticsearch...
setlocal enabledelayedexpansion
for /l %%i in (1,1,30) do (
    curl -s http://localhost:9200/ >nul 2>&1
    if not errorlevel 1 (
        echo [+] Elasticsearch is ready!
        goto :ES_READY
    )
    echo [*] Still waiting... %%i seconds
    timeout /t 2 /nobreak
)
:ES_READY

REM Wait for Kibana
echo [*] Waiting for Kibana...
for /l %%i in (1,1,30) do (
    curl -s http://localhost:5601/api/status >nul 2>&1
    if not errorlevel 1 (
        echo [+] Kibana is ready!
        goto :KIBANA_READY
    )
    echo [*] Still waiting... %%i seconds
    timeout /t 2 /nobreak
)
:KIBANA_READY

REM Step 7: Verify services
echo.
echo [*] Step 7: Verifying Services...
echo.
docker-compose ps
echo.

REM Success message
echo.
echo ========================================
echo    SETUP SUCCESSFUL!
echo ========================================
echo.
echo Available Services:
echo   - Elasticsearch: http://localhost:9200
echo   - Kibana:        http://localhost:5601
echo   - Logstash:      localhost:5044 (Beats)
echo.
echo Next Steps:
echo   1. Open Kibana in your browser: http://localhost:5601
echo   2. Setup Filebeat on your systems to collect logs
echo   3. Create index patterns in Kibana
echo   4. Build visualizations and dashboards
echo.
echo For testing (send sample logs):
echo   cat sample-logs\auth.log ^| nc.exe localhost 5000
echo.
echo Documentation:
echo   See SIEM-ELK-STACK-COMPLETE-GUIDE.md for detailed instructions
echo.
echo Useful Commands:
echo   - View logs:         docker-compose logs -f
echo   - Stop services:     docker-compose down
echo   - Restart services:  docker-compose restart
echo.

REM Ask if user wants to test
set /p TEST="Do you want to test the system now? (y/n): "
if /i "%TEST%"=="y" (
    echo.
    echo [*] Running System Tests...
    echo.
    
    echo [*] Testing Elasticsearch...
    curl -s http://localhost:9200/ 2>nul | find "version" >nul
    if not errorlevel 1 (
        echo [+] Elasticsearch is working
    ) else (
        echo [!] Elasticsearch connection failed
    )
    
    echo [*] Testing Kibana...
    curl -s http://localhost:5601/api/status 2>nul | find "ok" >nul
    if not errorlevel 1 (
        echo [+] Kibana is working
    ) else (
        echo [!] Kibana connection failed
    )
    
    echo [*] Testing Logstash...
    curl -s http://localhost:9600/_node/stats 2>nul | find "logstash" >nul
    if not errorlevel 1 (
        echo [+] Logstash is working
    ) else (
        echo [!] Logstash connection failed
    )
    echo.
)

echo [*] For troubleshooting, check logs with:
echo     docker-compose logs elasticsearch
echo     docker-compose logs kibana
echo     docker-compose logs logstash
echo.

pause
