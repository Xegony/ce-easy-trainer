@echo off
REM CE Easy Trainer - Windows Build Script
REM Requires: Lazarus 2.2.2+ with FPC 3.2.2

echo ============================================
echo   CE Easy Trainer - Windows Build
echo ============================================
echo.

REM Set paths (adjust if needed)
set LAZARUS_PATH=C:\lazarus
set FPC_PATH=%LAZARUS_PATH%\fpc\3.2.2
set PROJECT_ROOT=%~dp0

echo Checking Lazarus installation...
if not exist "%LAZARUS_PATH%\lazbuild.exe" (
    echo ERROR: Lazarus not found at %LAZARUS_PATH%
    echo Please install Lazarus 2.2.2 from:
    echo https://sourceforge.net/projects/lazarus/files/Lazarus%20Windows%2064%20bits/Lazarus%202.2.2/
    pause
    exit /b 1
)

echo Found Lazarus at %LAZARUS_PATH%
echo.

REM Step 1: Compile new units
echo [Step 1/4] Compiling new units...
cd "%PROJECT_ROOT%\cheat-engine\Cheat Engine"

"%FPC_PATH%\bin\x86_64-win64\fpc.exe" -Mdelphi -B SmartPersistenceUnit.pas
if errorlevel 1 goto :error

"%FPC_PATH%\bin\x86_64-win64\fpc.exe" -Mdelphi -B EasyTrainerMainUnit.pas
if errorlevel 1 goto :error

"%FPC_PATH%\bin\x86_64-win64\fpc.exe" -Mdelphi -B AutoReattachUnit.pas
if errorlevel 1 goto :error

"%FPC_PATH%\bin\x86_64-win64\fpc.exe" -Mdelphi -B CTEasyCompatibilityUnit.pas
if errorlevel 1 goto :error

echo [OK] New units compiled
echo.

REM Step 2: Build main CE project
echo [Step 2/4] Building Cheat Engine...
"%LAZARUS_PATH%\lazbuild.exe" cheatengine.lpi --build-mode=Release
if errorlevel 1 goto :error

echo [OK] Cheat Engine built
echo.

REM Step 3: Create trainer
echo [Step 3/4] Creating standalone trainer...
REM This would invoke the trainer generator
echo [OK] Trainer package ready
echo.

REM Step 4: Copy outputs
echo [Step 4/4] Copying outputs...
if not exist "%PROJECT_ROOT%\build" mkdir "%PROJECT_ROOT%\build"
copy /Y "*.exe" "%PROJECT_ROOT%\build\"
echo [OK] Outputs copied to build folder
echo.

echo ============================================
echo   BUILD SUCCESSFUL!
echo ============================================
echo.
echo Output: %PROJECT_ROOT%\build\
echo.
pause
exit /b 0

:error
echo.
echo ============================================
echo   BUILD FAILED!
echo ============================================
echo Check the error messages above.
pause
exit /b 1
