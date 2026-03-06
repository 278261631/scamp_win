@echo off
REM SCAMP Test Runner for Windows (Batch version)
REM Usage: run_tests.bat [build_type] [/BUILD] [/SKIPPYTHON] [/HELP]
REM   build_type: Debug or Release (default: Release)
REM   /BUILD: Build project before running tests
REM   /SKIPPYTHON: Skip Python integration tests
REM   /HELP: Show help message

setlocal enabledelayedexpansion

REM Set default values
set BUILD_TYPE=Release
set DO_BUILD=0
set SKIP_PYTHON=0
set SHOW_HELP=0

REM Parse command line arguments
:parse_args
if "%~1"=="" goto args_done

if /i "%~1"=="/HELP" (
    set SHOW_HELP=1
) else if /i "%~1"=="/BUILD" (
    set DO_BUILD=1
) else if /i "%~1"=="/SKIPPYTHON" (
    set SKIP_PYTHON=1
) else if /i "%~1"=="Debug" (
    set BUILD_TYPE=Debug
) else if /i "%~1"=="Release" (
    set BUILD_TYPE=Release
) else (
    echo Unknown argument: %~1
    echo Use /HELP for usage information
    exit /b 1
)

shift
goto parse_args

:args_done

if %SHOW_HELP%==1 (
    echo SCAMP Test Runner for Windows
    echo ==============================
    echo.
    echo Usage: run_tests.bat [build_type] [/BUILD] [/SKIPPYTHON] [/HELP]
    echo.
    echo Options:
    echo   build_type     Build configuration (Debug or Release, default: Release)
    echo   /BUILD         Build project before running tests
    echo   /SKIPPYTHON    Skip Python integration tests
    echo   /HELP          Show this help message
    echo.
    echo Examples:
    echo   run_tests.bat                     ^# Run all tests with Release build
    echo   run_tests.bat Debug              ^# Run tests with Debug build
    echo   run_tests.bat /BUILD             ^# Build first, then run tests
    echo.
    exit /b 0
)

echo ==========================================
echo SCAMP Windows Test Runner (Batch)
echo ==========================================
echo Build type: %BUILD_TYPE%
echo Date: %DATE% %TIME%
echo.

REM Step 1: Check if CMake is available
echo == Checking prerequisites ==
where cmake >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [✗] CMake not found in PATH. Please install CMake from https://cmake.org/download/
    exit /b 1
)
echo [✓] CMake found

REM Step 2: Check if Visual Studio compiler is available
where cl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [i] Visual Studio compiler not found in PATH. You may need to run from "Developer Command Prompt for VS".
) else (
    echo [✓] Visual Studio compiler found
)

REM Step 3: Build project if requested or if not built
echo.
echo == Checking build status ==
set BUILD_DIR=build
set SCAMP_EXE=%BUILD_DIR%\bin\%BUILD_TYPE%\scamp.exe

if %DO_BUILD%==1 (
    set SHOULD_BUILD=1
) else (
    if exist "%SCAMP_EXE%" (
        set SHOULD_BUILD=0
        echo [✓] SCAMP already built: %SCAMP_EXE%
    ) else (
        set SHOULD_BUILD=1
    )
)

if %SHOULD_BUILD%==1 (
    echo [i] Building SCAMP (%BUILD_TYPE%)...
    
    if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
    cd "%BUILD_DIR%"
    
    echo [i] Configuring with CMake...
    cmake .. -G "Visual Studio 16 2019" -A x64 ^
        -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
        -DUSE_OPENBLAS=ON ^
        -DENABLE_THREADS=OFF ^
        -DENABLE_PLPLOT=OFF ^
        -DBUILD_TESTS=ON
    
    if %ERRORLEVEL% neq 0 (
        echo [✗] CMake configuration failed
        cd ..
        exit /b 1
    )
    
    echo [i] Building with CMake...
    cmake --build . --config %BUILD_TYPE% --parallel
    
    if %ERRORLEVEL% neq 0 (
        echo [✗] Build failed
        cd ..
        exit /b 1
    )
    
    echo [✓] Build completed successfully
    cd ..
)

REM Step 4: Check if test executables exist
echo.
echo == Checking test executables ==
set TEST_EXES[0]=%BUILD_DIR%\tests\%BUILD_TYPE%\test_chealpix.exe
set TEST_EXES[1]=%BUILD_DIR%\tests\%BUILD_TYPE%\test_chealpixstore.exe
set TEST_EXES[2]=%BUILD_DIR%\tests\%BUILD_TYPE%\test_crossid_single_catalog.exe
set TEST_EXES[3]=%BUILD_DIR%\tests\%BUILD_TYPE%\test_crossid_single_catalog_moving.exe
set TEST_EXES[4]=%BUILD_DIR%\tests\%BUILD_TYPE%\test_windows_compat.exe

set MISSING_COUNT=0
for %%i in (0,1,2,3,4) do (
    if exist "!TEST_EXES[%%i]!" (
        for %%f in ("!TEST_EXES[%%i]!") do echo [✓] Found: %%~nxf
    ) else (
        for %%f in ("!TEST_EXES[%%i]!") do echo [i] Missing: %%~nxf
        set /a MISSING_COUNT+=1
    )
)

if %MISSING_COUNT% gtr 0 (
    echo [i] Some test executables are missing. They may not have been built.
    echo [i] Try rebuilding with /BUILD flag: run_tests.bat /BUILD
)

REM Step 5: Run C unit tests
echo.
echo == Running C unit tests ==
set TESTS_PASSED=0
set TESTS_FAILED=0
set TEST_FAILED=0

for %%i in (0,1,2,3,4) do (
    if exist "!TEST_EXES[%%i]!" (
        for %%f in ("!TEST_EXES[%%i]!") do set TEST_NAME=%%~nf
        echo   Running !TEST_NAME!... 
        
        REM Change to tests directory for data files
        pushd tests
        "!TEST_EXES[%%i]!" >nul 2>&1
        set EXIT_CODE=!ERRORLEVEL!
        popd
        
        if !EXIT_CODE!==0 (
            echo   PASSED
            set /a TESTS_PASSED+=1
        ) else (
            echo   FAILED (exit code: !EXIT_CODE!)
            set /a TESTS_FAILED+=1
            set TEST_FAILED=1
        )
    )
)

echo.
if %TESTS_FAILED%==0 (
    echo C Unit Tests Summary: %TESTS_PASSED% passed, %TESTS_FAILED% failed
) else (
    echo C Unit Tests Summary: %TESTS_PASSED% passed, %TESTS_FAILED% failed
)

REM Step 6: Run Python integration test (if not skipped)
if %SKIP_PYTHON%==0 (
    echo.
    echo == Checking Python integration test ==
    
    REM Check if Python is available
    where python >nul 2>nul
    if %ERRORLEVEL%==0 (
        echo [✓] Python found
        
        REM Check Python version
        python --version 2>&1
        echo [i] Checking for required Python packages...
        
        REM Create a temporary Python script to check dependencies
        echo try: > check_python.py
        echo     import numpy >> check_python.py
        echo     import astropy >> check_python.py
        echo     print("OK") >> check_python.py
        echo except ImportError as e: >> check_python.py
        echo     print("ERROR: " + str(e)) >> check_python.py
        
        for /f "delims=" %%a in ('python check_python.py 2^>^&1') do set PYTHON_RESULT=%%a
        del check_python.py
        
        if "!PYTHON_RESULT!"=="OK" (
            echo [✓] Required Python packages (numpy, astropy) are available
            
            REM Run the integration test
            echo [i] Running Python integration test...
            pushd tests
            echo   Running test_integration01.py...
            python test_integration01.py
            set EXIT_CODE=!ERRORLEVEL!
            popd
            
            if !EXIT_CODE!==0 (
                echo   PASSED
            ) else (
                echo   FAILED (exit code: !EXIT_CODE!)
                set TEST_FAILED=1
            )
        ) else (
            echo [i] Python dependencies not available: !PYTHON_RESULT!
            echo [i] Skipping Python integration test. Install with: pip install numpy astropy
        )
    ) else (
        echo [i] Python not found. Skipping integration test.
    )
) else (
    echo.
    echo [i] Python integration test skipped (per user request)
)

REM Step 7: Run basic SCAMP functionality test
echo.
echo == Testing basic SCAMP functionality ==
echo [i] Testing scamp.exe --help...
"%BUILD_DIR%\bin\%BUILD_TYPE%\scamp.exe" --help >nul 2>&1
if %ERRORLEVEL%==0 (
    echo [✓] SCAMP basic functionality test passed
) else (
    echo [✗] SCAMP basic functionality test failed
    set TEST_FAILED=1
)

REM Final summary
echo.
echo ==========================================
echo TEST SUMMARY
echo ==========================================

if %TEST_FAILED%==1 (
    echo Some tests FAILED!
    endlocal
    exit /b 1
) else (
    echo All tests PASSED!
    endlocal
    exit /b 0
)