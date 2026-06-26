@echo off
TITLE Stop GBIF Validator

echo Stopping GBIF Validator...
docker stop gbif-validator
docker rm gbif-validator

echo.
echo App stopped.
pause
