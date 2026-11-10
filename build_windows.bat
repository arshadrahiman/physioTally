@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo    PhysioTally - Windows Release & Installer Builder
echo ======================================================
echo.

:: 1. Check Flutter installation
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not found in your PATH!
    echo Please install Flutter and ensure it is in your system PATH.
    pause
    exit /b 1
)

:: 2. Clean and get dependencies
echo [1/3] Resolving Flutter dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Failed to get flutter dependencies.
    pause
    exit /b 1
)

:: 3. Build Windows Desktop Release
echo [2/3] Compiling Windows release binary...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Flutter Windows build failed. Ensure Visual Studio with 'Desktop development with C++' is installed.
    pause
    exit /b 1
)

:: 4. Build Inno Setup Installer
echo [3/3] Packaging installer...
set "ISCC="

if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
) else (
    where iscc >nul 2>nul
    if %errorlevel% equ 0 (
        set "ISCC=iscc"
    )
)

if defined ISCC (
    echo Compiling installer with Inno Setup...
    "%ISCC%" windows\packaging\inno_setup.iss
    if %errorlevel% equ 0 (
        echo.
        echo ======================================================
        echo [SUCCESS] Windows Installer created successfully!
        echo Location: build\installer\
        echo ======================================================
        explorer build\installer
    ) else (
        echo [WARNING] Inno Setup compilation failed.
    )
) else (
    echo.
    echo [INFO] Inno Setup 6 was not detected on this machine.
    echo [INFO] You can install Inno Setup 6 from: https://jrsoftware.org/isdl.php
    echo.
    echo [INFO] Alternatively, your compiled portable application is ready at:
    echo        build\windows\x64\runner\Release\
    echo.
    echo Creating portable ZIP bundle...
    powershell -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'build\PhysioTally_Windows_Portable.zip' -Force"
    if exist "build\PhysioTally_Windows_Portable.zip" (
        echo [SUCCESS] Created portable zip: build\PhysioTally_Windows_Portable.zip
        explorer build
    )
)

pause

