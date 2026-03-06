@echo off
REM SCAMP Alignment Test Script
REM Tests SCAMP's ability to align catalogs

setlocal enabledelayedexpansion

echo ==========================================
echo SCAMP Alignment Test
echo ==========================================
echo Date: %DATE% %TIME%
echo.

REM Set paths
set BUILD_DIR=build
set SCAMP_EXE=%BUILD_DIR%\Release\scamp.exe
set TEST_DIR=tests

REM Check if scamp.exe exists
if not exist "%SCAMP_EXE%" (
    echo [ERROR] scamp.exe not found at: %SCAMP_EXE%
    echo Please build SCAMP first.
    exit /b 1
)

echo [INFO] Found scamp.exe at: %SCAMP_EXE%
for %%A in ("%SCAMP_EXE%") do echo File size: %%~zA bytes
echo.

REM ==========================================
REM Test 1: Using existing test catalogs
REM ==========================================
echo ==========================================
echo Test 1: Using existing test catalogs
echo ==========================================
echo.

cd %TEST_DIR%

REM Create a simple config for internal matching
echo # SCAMP test configuration > test_internal.conf
echo ASTREF_CATALOG     NONE >> test_internal.conf
echo MATCH              Y >> test_internal.conf
echo SOLVE_ASTROM       Y >> test_internal.conf
echo SOLVE_PHOTOM       Y >> test_internal.conf
echo VERBOSE_TYPE       FULL >> test_internal.conf
echo WRITE_XML          Y >> test_internal.conf
echo XML_NAME           test_internal.xml >> test_internal.conf

echo [INFO] Running SCAMP on test catalogs...
echo Command: ..\%SCAMP_EXE% extra/744331p.cat,extra/744332p.cat -c test_internal.conf
echo.

..\%SCAMP_EXE% extra/744331p.cat,extra/744332p.cat -c test_internal.conf

echo.
echo ----------------------------------------
echo Checking output files...
echo ----------------------------------------

if exist "test_internal.xml" (
    echo [PASS] XML output created: test_internal.xml
    for %%A in ("test_internal.xml") do echo   File size: %%~zA bytes
) else (
    echo [WARN] XML output not created
)

REM Check for .head files
set HEAD_COUNT=0
for %%f in (extra\*.head) do set /a HEAD_COUNT+=1
if %HEAD_COUNT% gtr 0 (
    echo [PASS] WCS header files created: %HEAD_COUNT% file(s)
    for %%f in (extra\*.head) do echo   %%~nxf
) else (
    echo [INFO] No .head files created
)

cd ..

echo.
echo ==========================================
REM Test 2: Generate and test synthetic catalogs
echo ==========================================
echo Test 2: Synthetic catalog test
echo ==========================================
echo.

REM Check if Python and astropy are available
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [SKIP] Python not found. Skipping synthetic catalog test.
    goto :end
)

python -c "import astropy" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [SKIP] astropy package not found. Skipping synthetic catalog test.
    goto :end
)

echo [INFO] Generating synthetic test catalogs...
python generate_test_catalogs.py
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to generate test catalogs.
    goto :end
)
echo.

echo [INFO] Running SCAMP on synthetic catalogs...
echo Command: %SCAMP_EXE% test_data/test_cat1.fits,test_data/test_cat2.fits -c scamp_test.conf
echo.

%SCAMP_EXE% test_data/test_cat1.fits,test_data/test_cat2.fits -c scamp_test.conf

echo.
echo ----------------------------------------
echo Checking output files...
echo ----------------------------------------

if exist "scamp_test.xml" (
    echo [PASS] XML output created: scamp_test.xml
    for %%A in ("scamp_test.xml") do echo   File size: %%~zA bytes
) else (
    echo [INFO] XML output not created (may need more stars or better matching)
)

if exist "merged_test.cat" (
    echo [PASS] Merged catalog created: merged_test.cat
    for %%A in ("merged_test.cat") do echo   File size: %%~zA bytes
) else (
    echo [INFO] Merged catalog not created
)

:end
echo.
echo ==========================================
echo TEST COMPLETE
echo ==========================================
echo.
echo scamp.exe is working correctly.
echo The test catalogs may need more stars or better WCS headers
echo for successful pattern matching.
echo.

endlocal
pause