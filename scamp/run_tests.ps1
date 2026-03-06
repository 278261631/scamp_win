# SCAMP Test Runner for Windows
# PowerShell script to run all tests for SCAMP Windows port
# Usage: .\run_tests.ps1 [-BuildType <Debug|Release>] [-Build] [-SkipPython] [-Help]

param(
    [Parameter(Position=0)]
    [ValidateSet("Debug", "Release")]
    [string]$BuildType = "Release",
    
    [switch]$Build,
    [switch]$SkipPython,
    [switch]$Help
)

if ($Help) {
    Write-Host "SCAMP Test Runner for Windows"
    Write-Host "=============================="
    Write-Host ""
    Write-Host "Usage: .\run_tests.ps1 [-BuildType <Debug|Release>] [-Build] [-SkipPython] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -BuildType     Build configuration (Debug or Release, default: Release)"
    Write-Host "  -Build         Build project before running tests"
    Write-Host "  -SkipPython    Skip Python integration tests"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run_tests.ps1                     # Run all tests with Release build"
    Write-Host "  .\run_tests.ps1 -BuildType Debug   # Run tests with Debug build"
    Write-Host "  .\run_tests.ps1 -Build            # Build first, then run tests"
    Write-Host ""
    exit 0
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SCAMP Windows Test Runner" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Build type: $BuildType"
Write-Host "Date: $(Get-Date)"
Write-Host ""

# Set error handling
$ErrorActionPreference = "Stop"
$global:TestFailed = $false

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
    $global:TestFailed = $true
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

# Step 1: Check if CMake is available
Write-Step "Checking prerequisites"
try {
    $cmakePath = Get-Command cmake -ErrorAction Stop | Select-Object -ExpandProperty Source
    Write-Success "CMake found: $cmakePath"
} catch {
    Write-Error "CMake not found in PATH. Please install CMake from https://cmake.org/download/"
    exit 1
}

# Step 2: Check if Visual Studio compiler is available
try {
    $clPath = Get-Command cl -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if ($clPath) {
        Write-Success "Visual Studio compiler found: $clPath"
    } else {
        Write-Info "Visual Studio compiler not found in PATH. You may need to run from 'Developer PowerShell for VS'."
    }
} catch {
    Write-Info "Visual Studio compiler not found in PATH. You may need to run from 'Developer PowerShell for VS'."
}

# Step 3: Build project if requested or if not built
Write-Step "Checking build status"
$buildDir = "build"
$scampExePath = "$buildDir\bin\$BuildType\scamp.exe"

if ($Build -or (-not (Test-Path $scampExePath))) {
    Write-Info "Building SCAMP ($BuildType)..."
    
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    }
    
    Push-Location $buildDir
    
    try {
        # Configure with CMake
        Write-Info "Configuring with CMake..."
        $cmakeArgs = @(
            "..",
            "-G", "Visual Studio 16 2019",
            "-A", "x64",
            "-DCMAKE_BUILD_TYPE=$BuildType",
            "-DUSE_OPENBLAS=ON",
            "-DENABLE_THREADS=OFF",
            "-DENABLE_PLPLOT=OFF",
            "-DBUILD_TESTS=ON"
        )
        
        & cmake @cmakeArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "CMake configuration failed"
            exit 1
        }
        
        # Build the project
        Write-Info "Building with CMake..."
        & cmake --build . --config $BuildType --parallel
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed"
            exit 1
        }
        
        Write-Success "Build completed successfully"
    } finally {
        Pop-Location
    }
} else {
    Write-Success "SCAMP already built: $scampExePath"
}

# Step 4: Check if test executables exist
Write-Step "Checking test executables"
$testExecutables = @(
    "$buildDir\tests\$BuildType\test_chealpix.exe",
    "$buildDir\tests\$BuildType\test_chealpixstore.exe",
    "$buildDir\tests\$BuildType\test_crossid_single_catalog.exe",
    "$buildDir\tests\$BuildType\test_crossid_single_catalog_moving.exe",
    "$buildDir\tests\$BuildType\test_windows_compat.exe"
)

$missingTests = @()
foreach ($testExe in $testExecutables) {
    if (Test-Path $testExe) {
        Write-Success "Found: $(Split-Path $testExe -Leaf)"
    } else {
        Write-Info "Missing: $(Split-Path $testExe -Leaf)"
        $missingTests += $testExe
    }
}

if ($missingTests.Count -gt 0) {
    Write-Info "Some test executables are missing. They may not have been built."
    Write-Info "Try rebuilding with -Build flag: .\run_tests.ps1 -Build"
}

# Step 5: Run C unit tests
Write-Step "Running C unit tests"
$testsPassed = 0
$testsFailed = 0

foreach ($testExe in $testExecutables) {
    if (Test-Path $testExe) {
        $testName = (Get-Item $testExe).BaseName
        Write-Host -NoNewline "  Running $testName... "
        
        # Change to tests directory for data files
        $oldDir = Get-Location
        Set-Location "tests"
        
        try {
            & $testExe 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "PASSED" -ForegroundColor Green
                $testsPassed++
            } else {
                Write-Host "FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
                $testsFailed++
                $global:TestFailed = $true
            }
        } catch {
            Write-Host "ERROR: $_" -ForegroundColor Red
            $testsFailed++
            $global:TestFailed = $true
        } finally {
            Set-Location $oldDir
        }
    }
}

Write-Host ""
Write-Host "C Unit Tests Summary: $testsPassed passed, $testsFailed failed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })

# Step 6: Run Python integration test (if not skipped)
if (-not $SkipPython) {
    Write-Step "Checking Python integration test"
    
    # Check if Python is available
    try {
        $pythonExe = Get-Command python -ErrorAction Stop | Select-Object -ExpandProperty Source
        Write-Success "Python found: $pythonExe"
        
        # Check Python version
        $pythonVersion = & python --version 2>&1
        Write-Info "Python version: $pythonVersion"
        
        # Check for required packages
        Write-Info "Checking for required Python packages..."
        $checkScript = @"
try:
    import numpy
    import astropy
    print("OK")
except ImportError as e:
    print(f"ERROR: {e}")
"@
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $checkScript | Out-File -FilePath $tempFile -Encoding UTF8
        
        $pythonResult = & python $tempFile 2>&1
        Remove-Item $tempFile
        
        if ($pythonResult -eq "OK") {
            Write-Success "Required Python packages (numpy, astropy) are available"
            
            # Run the integration test
            Write-Info "Running Python integration test..."
            $oldDir = Get-Location
            Set-Location "tests"
            
            try {
                Write-Host -NoNewline "  Running test_integration01.py... "
                & python "test_integration01.py"
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "PASSED" -ForegroundColor Green
                } else {
                    Write-Host "FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
                    $global:TestFailed = $true
                }
            } finally {
                Set-Location $oldDir
            }
        } else {
            Write-Info "Python dependencies not available: $pythonResult"
            Write-Info "Skipping Python integration test. Install with: pip install numpy astropy"
        }
    } catch {
        Write-Info "Python not found. Skipping integration test."
    }
} else {
    Write-Info "Python integration test skipped (per user request)"
}

# Step 7: Run basic SCAMP functionality test
Write-Step "Testing basic SCAMP functionality"
Write-Info "Testing scamp.exe --help..."
& "$buildDir\bin\$BuildType\scamp.exe" --help 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Success "SCAMP basic functionality test passed"
} else {
    Write-Error "SCAMP basic functionality test failed"
}

# Final summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($global:TestFailed) {
    Write-Host "Some tests FAILED!" -ForegroundColor Red -BackgroundColor Black
    exit 1
} else {
    Write-Host "All tests PASSED!" -ForegroundColor Green -BackgroundColor Black
    exit 0
}