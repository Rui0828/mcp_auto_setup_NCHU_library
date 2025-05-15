@echo off
setlocal ENABLEEXTENSIONS

REM 變數設置
set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%Claude-Setup-x64.exe"
set "DOWNLOAD_URL=https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"

cd /d C:\

REM 步驟 1: 安裝 Claude Desktop
echo.
echo [1/8] Installing Claude Desktop...

if not exist "%INSTALLER%" (
    echo [INFO] Claude installer not found, downloading...
    curl -L -o "%INSTALLER%" "%DOWNLOAD_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download Claude installer!
        pause
        exit /b 1
    )
    echo powershell -Command  "Write-Host 'Claude installer downloaded successfully!' -ForegroundColor Green"
) else (
    echo Claude installer found, skipping download.
)

start /wait "" "%INSTALLER%"
if errorlevel 1 (
    echo [ERROR] Claude Desktop installation failed!
    pause
)

echo.
echo [2/8] Installing uv...
powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
if errorlevel 1 (
    echo [ERROR] uv installation command failed!
    pause
)

REM Check if uv is installed successfully
where uv >nul 2>&1
if errorlevel 1 (
    echo [ERROR] uv installation failed, please check manually.
    pause
)

echo.
echo [3/8] Creating virtual environment...

if exist "C:\library\pyproject.toml" (
    echo [INFO] Project already initialized, skipping uv init.
) else (
    uv init library
    if errorlevel 1 (
        echo [ERROR] uv init library failed!
        pause
    )
)

cd library

uv venv
if errorlevel 1 (
    echo [ERROR] uv venv creation failed!
    pause
)

echo.
echo [4/8] Setting execution policy to RemoteSigned...

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
)

echo.
echo [5/8] Activating virtual environment...
call .venv\Scripts\activate
if errorlevel 1 (
    echo [ERROR] Failed to activate virtual environment!
    pause
)

echo.
echo [6/8] Installing dependencies with uv add...
uv add "mcp[cli]" httpx requests
if errorlevel 1 (
    echo [ERROR] Dependency installation failed!
    pause
)

echo.
echo [7/8] Copying library_api.py to library directory...
copy /Y "%SCRIPT_DIR%library_api.py" "C:\library\library_api.py"
if errorlevel 1 (
    echo [ERROR] Failed to copy library_api.py!
    pause
)
uv run mcp install library_api.py
if errorlevel 1 (
    echo [ERROR] uv run mcp install library_api.py failed!
    pause
)

echo.
echo [8/8] Writing Claude config to file...
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

REM 檢查檔案是否成功建立且非空
if not exist "%CLAUDE_CONFIG%" (
    echo [ERROR] Claude config file was not created!
    pause
) else (
    for %%I in ("%CLAUDE_CONFIG%") do if %%~zI equ 0 (
        echo [ERROR] Claude config file is empty!
        pause
    )
)

echo.
powershell -Command "Write-Host 'All steps completed successfully!' -ForegroundColor Green"
pause
