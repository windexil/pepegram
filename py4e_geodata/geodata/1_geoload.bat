@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
where py >nul 2>nul
if %errorlevel%==0 (py geoload.py) else (python geoload.py)
echo.
echo ===== Done. Scroll up to the stars (****) and take a screenshot =====
pause
