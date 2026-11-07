@echo off
cd /d "%~dp0"
set "GIT=C:\Users\51902\Documents\deepseek-harness\default-workspace\tools\MinGit\cmd\git.exe"
echo.
echo   Pushing to GitHub: BIPAB/myDSH
echo   ----------------------------------------
"%GIT%" config http.proxy "http://127.0.0.1:7890" >nul 2>&1
"%GIT%" config https.proxy "http://127.0.0.1:7890" >nul 2>&1
"%GIT%" push -u origin main
echo.
if %ERRORLEVEL%==0 (echo   [OK] pushed) else (echo   [FAILED] send the error above)
echo.
pause
