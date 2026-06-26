@echo off
TITLE Restart GBIF Validator

echo Restarting GBIF Validator...
docker stop gbif-validator
docker rm gbif-validator

echo Starting app...
call launch_app.bat
