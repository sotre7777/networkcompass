@echo off
cd /d "%~dp0"
where python >nul 2>nul && (python webapp\server.py) || (py webapp\server.py)
pause
