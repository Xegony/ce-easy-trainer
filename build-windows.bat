@echo off
REM ============================================================
REM CE Easy Trainer - Windows Build Script
REM Requires: Lazarus 2.2+ with FPC 3.2.2
REM ============================================================

setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0
set OUTPUT_DIR=%PROJECT_ROOT%build
set BIN_DIR=%OUTPUT_DIR%\bin

echo.
echo ========================================
echo   CE Easy Trainer - Windows Build
echo ========================================
echo.

REM Check for lazbuild
where lazbuild >nul 2>&1
if errorlevel 1 (
    echo [ERROR] lazbuild not found in PATH
    echo Please install Lazarus and add it to PATH
    echo Download: https://sourceforge.net/projects/lazarus/
    pause
    exit /b 1
)

REM Create output directories
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%OUTPUT_DIR%\lib" mkdir "%OUTPUT_DIR%\lib"

echo [1/3] Cleaning previous build...
del /q "%OUTPUT_DIR%\lib\*.*" 2>nul

echo [2/3] Building CE Easy Trainer...
cd /d "%PROJECT_ROOT%"
lazbuild CheatEngineEasyTrainer.lpi -B --build-mode=Default

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    echo Check the error messages above.
    pause
    exit /b 1
)

echo.
echo [3/3] Copying output...
if exist "bin\CEEasyTrainer.exe" (
    copy /y "bin\CEEasyTrainer.exe" "%BIN_DIR%\" >nul
    echo.
    echo ========================================
    echo   Build Successful!
    ========================================
    echo.
    echo Output: %BIN_DIR%\CEEasyTrainer.exe
    echo.
) else (
    echo [ERROR] Output file not found!
    pause
    exit /b 1
)

echo Press any key to exit...
pause >nul
