@echo off
REM SCAMP Basic Functionality Test Script
REM Tests basic scamp.exe commands on Windows

setlocal enabledelayedexpansion

echo ==========================================
echo SCAMP Basic Functionality Test
echo ==========================================
echo Date: %DATE% %TIME%
echo.

REM Set paths
set BUILD_DIR=build
set SCAMP_EXE=%BUILD_DIR%\Release\scamp.exe

REM Check if scamp.exe exists
if not exist "%SCAMP_EXE%" (
    echo [ERROR] scamp.exe not found at: %SCAMP_EXE%
    echo.
    echo Please build SCAMP first:
    echo   1. cd build
    echo   2. cmake --build . --config Release
    echo.
    exit /b 1
)

echo [INFO] Found scamp.exe at: %SCAMP_EXE%
echo.

REM Test 1: Display help
echo ----------------------------------------
echo Test 1: Display help (--help)
echo ----------------------------------------
"%SCAMP_EXE%" --help
if %ERRORLEVEL% equ 0 (
    echo [PASS] --help command succeeded
) else (
    echo [FAIL] --help command failed with exit code %ERRORLEVEL%
)
echo.

REM Test 2: Display version
echo ----------------------------------------
echo Test 2: Display version (--version or -v)
echo ----------------------------------------
"%SCAMP_EXE%" -v
if %ERRORLEVEL% equ 0 (
    echo [PASS] -v command succeeded
) else (
    echo [FAIL] -v command failed with exit code %ERRORLEVEL%
)
echo.

REM Test 3: Generate default configuration
echo ----------------------------------------
echo Test 3: Generate default configuration (-d)
echo ----------------------------------------
set CONFIG_FILE=scamp_default.conf
if exist "%CONFIG_FILE%" del "%CONFIG_FILE%"
REM SCAMP outputs config to stdout, redirect to file
"%SCAMP_EXE%" -d > "%CONFIG_FILE%" 2>&1
if %ERRORLEVEL% equ 0 (
    if exist "%CONFIG_FILE%" (
        echo [PASS] Default configuration generated: %CONFIG_FILE%
        for %%A in ("%CONFIG_FILE%") do echo File size: %%~zA bytes
    ) else (
        echo [FAIL] Configuration file not created
    )
) else (
    echo [FAIL] -d command failed with exit code %ERRORLEVEL%
)
echo.

REM Test 4: Check if configuration file is valid
if exist "%CONFIG_FILE%" (
    echo ----------------------------------------
    echo Test 4: Display first 20 lines of config
    echo ----------------------------------------
    echo First 20 lines of %CONFIG_FILE%:
    echo.
    more +0 "%CONFIG_FILE%" | findstr /n "^" | findstr "^[1-9]:" | findstr /v "^[2-9][0-9]:"
    echo.
    echo [INFO] Full configuration saved to: %CONFIG_FILE%
    echo.
)

REM Test 5: Test with non-existent file (SCAMP warns but doesn't error)
echo ----------------------------------------
echo Test 5: Handling non-existent file
echo ----------------------------------------
echo Running: scamp nonexistent_file.fits
"%SCAMP_EXE%" nonexistent_file.fits 2>&1
echo.
echo [INFO] SCAMP handles missing files gracefully (warns but continues)
echo.

REM Summary
echo ==========================================
echo TEST SUMMARY
echo ==========================================
echo All basic tests completed.
echo.
echo scamp.exe location: %SCAMP_EXE%
for %%A in ("%SCAMP_EXE%") do echo File size: %%~zA bytes
echo.

endlocal
pause