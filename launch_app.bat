@echo off
TITLE GBIF Validator - Docker Launcher

echo ==========================================
echo GBIF Validator - Docker Launcher
echo ==========================================
echo.

REM Check if Docker is running
echo [1/5] Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not installed or not running.
    echo.
    echo Please install Docker Desktop from:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    echo Then run this script again.
    pause
    exit /b 1
)
echo [OK] Docker is installed and running
echo.

REM Check if the image exists
echo [2/5] Checking Docker image...
docker image inspect prabs330/gbif-validator:latest >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Image not found locally. Pulling from Docker Hub...
    docker pull prabs330/gbif-validator:latest
    if errorlevel 1 (
        echo [ERROR] Failed to pull image. Check your internet connection.
        pause
        exit /b 1
    )
    echo [OK] Image pulled successfully
) else (
    echo [OK] Image found locally
)
echo.

REM Check if credentials folder exists
echo [3/5] Checking credentials...
if not exist "%CD%\credentials" (
    echo [WARNING] Credentials folder not found.
    echo Creating credentials folder...
    mkdir credentials
    echo.
    echo Please place your Earth Engine credentials file in:
    echo %CD%\credentials\
    echo.
    pause
)
echo [OK] Credentials folder exists
echo.

REM Stop any existing container on port 3838
echo [4/5] Checking for existing containers on port 3838...
for /f "tokens=*" %%a in ('docker ps -q --filter "publish=3838"') do (
    echo Stopping existing container: %%a
    docker stop %%a >nul 2>&1
    docker rm %%a >nul 2>&1
)
echo [OK] Port 3838 is available
echo.

REM Launch the container
echo [5/5] Starting GBIF Validator...
docker run -d -p 3838:3838 ^
    -v "%CD%\app_full.R:/srv/shiny-server/app.R" ^
    -v "%CD%\credentials:/root/.config/earthengine" ^
    --name gbif-validator ^
    prabs330/gbif-validator:latest ^
    R -e "shiny::runApp('/srv/shiny-server/app.R', host='0.0.0.0', port=3838)"

if errorlevel 1 (
    echo [ERROR] Failed to start container.
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo APP IS RUNNING!
echo ==========================================
echo.
echo Opening browser...
timeout /t 2 /nobreak >nul
start http://localhost:3838
echo.
echo To stop the app, run: docker stop gbif-validator
echo To restart, run this script again.
echo.
echo ==========================================
pause
