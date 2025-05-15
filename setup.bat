@echo off
setlocal ENABLEEXTENSIONS

REM === Variable Setup ===
set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%Claude-Setup-x64.exe"
set "DOWNLOAD_URL=https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"
set "PROJECT_DIR=C:\library"

cd /d C:\

echo.
echo [1/9] Installing uv...
powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"

REM === Add uv install location to PATH immediately ===
set "PATH=%USERPROFILE%\.local\bin;%PATH%"

where uv >nul 2>&1
if errorlevel 1 (
    echo [ERROR] uv installation failed, please check manually.
    pause
    exit /b 1
)

echo.
echo [2/9] Creating virtual environment...

if exist "%PROJECT_DIR%\pyproject.toml" (
    echo [INFO] Project already initialized, skipping uv init.
) else (
    mkdir "%PROJECT_DIR%" >nul 2>&1
    cd /d "%PROJECT_DIR%"
    uv init
    if errorlevel 1 (
        echo [ERROR] uv init failed!
        pause
        exit /b 1
    )
)

cd /d "%PROJECT_DIR%"
uv venv
if errorlevel 1 (
    echo [ERROR] uv venv creation failed!
    pause
    exit /b 1
)

echo.
echo [3/9] Setting execution policy to RemoteSigned...
powershell -Command ^
"if ((Get-ExecutionPolicy -Scope CurrentUser) -ne 'RemoteSigned') { ^
    Write-Host 'Setting execution policy to RemoteSigned...'; ^
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force ^
} else { ^
    Write-Host 'Execution policy is already RemoteSigned, skipping.' ^
}"
if errorlevel 1 (
    echo [ERROR] Failed to set execution policy!
    pause
    exit /b 1
)

echo.
echo [4/9] Skipping venv activation (not needed with uv)...

echo.
echo [5/9] Installing dependencies with uv add...
uv add "mcp[cli]" httpx requests
if errorlevel 1 (
    echo [ERROR] Dependency installation failed!
    pause
    exit /b 1
)

echo.
echo [6/9] Copying library_api.py to project directory...
copy /Y "%SCRIPT_DIR%library_api.py" "%PROJECT_DIR%\library_api.py"
if errorlevel 1 (
    echo [ERROR] Failed to copy library_api.py!
    pause
    exit /b 1
)

echo.
echo [7/9] Installing Claude Desktop...

if not exist "%INSTALLER%" (
    echo [INFO] Claude installer not found, downloading...
    curl -L -o "%INSTALLER%" "%DOWNLOAD_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download Claude installer!
        pause
        exit /b 1
    )
    powershell -Command "Write-Host 'Claude installer downloaded successfully!' -ForegroundColor Green"
) else (
    echo Claude installer found, skipping download.
)

start /wait "" "%INSTALLER%"
if errorlevel 1 (
    echo [ERROR] Claude Desktop installation failed!
    pause
    exit /b 1
)

echo.
echo [8/9] Installing library_api.py via uv run...
uv run mcp install library_api.py
if errorlevel 1 (
    echo [ERROR] uv run mcp install library_api.py failed!
    pause
    exit /b 1
)

echo.
echo [9/9] Writing Claude config to file...
set "CLAUDE_CONFIG=%APPDATA%\Claude\claude_desktop_config.json"
mkdir "%APPDATA%\Claude" >nul 2>&1

> "%CLAUDE_CONFIG%" (
    echo {
    echo     "mcpServers": {
    echo         "NCHU_library": {
    echo             "command": "uv",
    echo             "args": [
    echo                 "--directory",
    echo                 "C:\\library",
    echo                 "run",
    echo                 "library_api.py"
    echo             ]
    echo         }
    echo     }
    echo }
)

REM Check if config file exists and is not empty
if not exist "%CLAUDE_CONFIG%" (
    echo [ERROR] Claude config file was not created!
    pause
    exit /b 1
) else (
    for %%I in ("%CLAUDE_CONFIG%") do if %%~zI equ 0 (
        echo [ERROR] Claude config file is empty!
        pause
        exit /b 1
    )
)

echo.
powershell -Command "Write-Host 'All steps completed successfully!' -ForegroundColor Green"
pause
