@echo off
chcp 65001 >nul
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
where py >nul 2>nul
if %errorlevel%==0 (py geodump.py) else (python geodump.py)
echo.
echo ===== Done. Scroll up to the stars (****) and take a screenshot =====
pause
