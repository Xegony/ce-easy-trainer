@echo off
REM CE Easy Trainer - Windows 构建脚本
REM
REM 前置要求：
REM 1. Lazarus 2.2.6+ 或 FPC 3.2.2+
REM 2. Cheat Engine 源码在 ..\cheat-engine 目录
REM
REM 使用方法：
REM   build-all.bat          - 编译所有单元
REM   build-all.bat test     - 运行测试
REM   build-all.bat clean    - 清理编译产物

setlocal enabledelayedexpansion

set FPC=fpc
set LAZARUS=lazbuild
set CE_ROOT=cheat-engine\Cheat Engine
set SRC_DIR=src
set BUILD_DIR=build
set DIST_DIR=dist

if "%1"=="clean" goto :clean
if "%1"=="test" goto :test
goto :build

:clean
echo 清理编译产物...
if exist %BUILD_DIR% rd /s /q %BUILD_DIR%
if exist %SRC_DIR%\*.o del /q %SRC_DIR%\*.o
if exist %SRC_DIR%\*.ppu del /q %SRC_DIR%\*.ppu
if exist %SRC_DIR%\*.exe del /q %SRC_DIR%\*.exe
echo 清理完成
goto :eof

:test
echo 运行测试...
%FPC% -Mdelphi %SRC_DIR%\test_ce_easy_units.pas -o%BUILD_DIR%\test_ce_easy_units.exe
if errorlevel 1 (
    echo 测试编译失败
    exit /b 1
)
%BUILD_DIR%\test_ce_easy_units.exe
if errorlevel 1 (
    echo 测试运行失败
    exit /b 1
)
echo 测试通过
goto :eof

:build
echo 构建 CE Easy Trainer...

REM 创建构建目录
if not exist %BUILD_DIR% mkdir %BUILD_DIR%
if not exist %DIST_DIR% mkdir %DIST_DIR%

REM 步骤 1: 编译核心单元（无 CE 依赖）
echo [1/3] 编译核心单元...
%FPC% -Mdelphi -FU%BUILD_DIR% %SRC_DIR%\SmartPersistenceUnit.pas
if errorlevel 1 goto :error

%FPC% -Mdelphi -FU%BUILD_DIR% %SRC_DIR%\EasyTrainerMainUnit.pas
if errorlevel 1 goto :error

%FPC% -Mdelphi -FU%BUILD_DIR% %SRC_DIR%\CTEasyCompatibilityUnit.pas
if errorlevel 1 goto :error

%FPC% -Mdelphi -FU%BUILD_DIR% %SRC_DIR%\AutoReattachUnit.pas
if errorlevel 1 goto :error

REM 步骤 2: 编译适配器（需要 CE 源码）
echo [2/3] 编译适配器...
if not exist "%CE_ROOT%\MainUnit.pas" (
    echo 警告: CE 源码未找到，跳过适配器编译
    echo 如需完整集成，请确保 CE 源码在 %CE_ROOT% 目录
    goto :skip_adapter
)

%FPC% -Mdelphi -FU%BUILD_DIR% -FI"%CE_ROOT%" %SRC_DIR%\CEBackendAdapter.pas
if errorlevel 1 (
    echo 警告: 适配器编译失败，可能缺少 CE 依赖
    echo 继续构建其他组件...
)

:skip_adapter

REM 步骤 3: 打包发布
echo [3/3] 打包发布...
copy %SRC_DIR%\*.pas %DIST_DIR%\
copy docs\*.md %DIST_DIR%\

echo.
echo ====================================
echo 构建完成！
echo 输出目录: %DIST_DIR%
echo ====================================
goto :eof

:error
echo 构建失败！
exit /b 1
