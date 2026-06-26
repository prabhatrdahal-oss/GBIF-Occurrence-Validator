@echo off
echo ==========================================
echo Building GBIF Validator Docker image...
echo ==========================================
docker build -t gbif-validator .
echo.
echo ==========================================
echo Build complete!
echo To run: docker-compose up
echo ==========================================
pause