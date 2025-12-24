:: VER=11
@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
set "TARGET_DIR=C:\"
set "RESTART_AFTER_UPDATE=1"
set "RESTART_DOCKER_DESKTOP=0"
set "DELETE_LIST=C:\NetWatch\CoreService.bat"
set "HEARTBEAT_SCRIPT="
set "DOCKER_DESKTOP_EXE=C:\Program Files\Docker\Docker\Docker Desktop.exe"
set "ZIP_URL=https://github.com/yao666999/heartbeat/releases/download/heartbeat/NetWatch.zip"
if defined DELETE_LIST call :DELETE_FILES "%DELETE_LIST%"
set "ZIP_FILE=%TEMP%\NetWatch_%RANDOM%.zip"
powershell -Command "$ProgressPreference='SilentlyContinue'; (New-Object System.Net.WebClient).DownloadFile('%ZIP_URL%', '%ZIP_FILE%')" >nul 2>&1
if not exist "%ZIP_FILE%" exit /b 1
powershell -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%TARGET_DIR%' -Force" >nul 2>&1
if not exist "C:\NetWatch" (del "%ZIP_FILE%" >nul 2>&1 & exit /b 1)
del "%ZIP_FILE%" >nul 2>&1
if exist "%HEARTBEAT_SCRIPT%" (cd /d "C:\NetWatch\heartbeat" && start /min "" cmd /c "%HEARTBEAT_SCRIPT%")
for /r "C:\NetWatch" %%F in (run.bat) do if exist "%%F" (cd /d "%%~dpF" && start /min "" cmd /c "%%F")
call :MAYBE_RESTART_DOCKER_DESKTOP
call :MAYBE_RESTART
exit /b 0
:MAYBE_RESTART_DOCKER_DESKTOP
if not "%RESTART_DOCKER_DESKTOP%"=="1" goto :EOF
if not exist "%DOCKER_DESKTOP_EXE%" goto :EOF
call :KILL_PROCESS "Docker Desktop.exe"
timeout /t 8 /nobreak >nul 2>&1
start "" "%DOCKER_DESKTOP_EXE%" >nul 2>&1
goto :EOF
:KILL_PROCESS
set "PROC_NAME=%~1"
if "%PROC_NAME%"=="" goto :EOF
taskkill /f /im "%PROC_NAME%" >nul 2>&1
taskkill /f /im "%PROC_NAME%" /t >nul 2>&1
taskkill /f /im "%PROC_NAME%" >nul 2>&1
goto :EOF
:MAYBE_RESTART
if "%RESTART_AFTER_UPDATE%"=="1" shutdown /r /t 120 /f >nul 2>&1
goto :EOF
:DELETE_FILES
setlocal EnableDelayedExpansion
set "paths=%~1"
if "%paths%"=="" (endlocal & goto :EOF)
for %%P in ("%paths:;=" "%") do (
set "path=%%~P"
if exist "!path!" (
if exist "!path!\*" (rd /s /q "!path!" 2>nul) else (del /f /q "!path!" 2>nul)
)
)
endlocal
goto :EOF

