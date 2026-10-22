@echo off
setlocal
cd /d "%~dp0.."

echo Starting GHarvest backend and Flutter web app...

where py >nul 2>nul
if errorlevel 1 (
  echo Python launcher ^(py^) was not found. Install Python or activate your virtual environment first.
  exit /b 1
)

if not exist "backend\.env" (
  echo backend\.env was not found.
  echo Copy backend\.env.example to backend\.env and add your Paystack keys there.
  exit /b 1
)

start "GHarvest Backend" cmd /k "cd /d "%~dp0..\backend" ^&^& py -m uvicorn main:app --reload --host 127.0.0.1 --port 8000"
start "GHarvest Flutter" cmd /k "cd /d "%~dp0.." ^&^& flutter run -d web-server --web-port 3000"

echo Backend: http://127.0.0.1:8000
 echo Flutter: http://localhost:3000
endlocal
