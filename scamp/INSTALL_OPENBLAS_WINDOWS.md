# OpenBLAS Installation Guide for Windows

This guide provides multiple methods to install OpenBLAS on Windows for SCAMP compilation.

## Why OpenBLAS is Required

SCAMP uses OpenBLAS (or ATLAS) for linear algebra operations, which are essential for:
- Solving linear equations in mosaic image processing
- Matrix operations in astronomical calculations
- Performance optimization for large datasets

## Method 1: Using vcpkg (Recommended)

vcpkg is Microsoft's package manager for C++ libraries. It handles dependencies and linking automatically.

### Step 1: Install vcpkg
```powershell
# Clone vcpkg repository
cd C:\
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg

# Bootstrap vcpkg
.\bootstrap-vcpkg.bat

# Integrate with Visual Studio (optional but recommended)
.\vcpkg integrate install
```

### Step 2: Install OpenBLAS
```powershell
# Install OpenBLAS for x64 architecture
.\vcpkg install openblas:x64-windows

# For static linking (recommended for distribution)
.\vcpkg install openblas:x64-windows-static
```

### Step 3: Configure CMake for vcpkg
```powershell
cd d:\github\scamp_win\scamp\build

# Clean existing build
rmdir /s /q .
mkdir build
cd build

# Configure with vcpkg toolchain
cmake .. -G "Visual Studio 16 2019" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="C:/vcpkg/scripts/buildsystems/vcpkg.cmake" ^
    -DUSE_OPENBLAS=ON ^
    -DENABLE_THREADS=OFF ^
    -DENABLE_PLPLOT=OFF
```

## Method 2: Manual Installation with Precompiled Binaries

### Step 1: Download OpenBLAS
Download precompiled OpenBLAS for Windows from one of these sources:

1. **SourceForge** (Official): https://sourceforge.net/projects/openblas/
   - Look for files like `OpenBLAS-v0.3.25-x64.zip`
   
2. **GitHub Releases**: https://github.com/xianyi/OpenBLAS/releases
   - Download the latest release with Windows binaries

3. **Alternative download links**:
   - https://github.com/xianyi/OpenBLAS/releases/download/v0.3.25/OpenBLAS-0.3.25-x64.zip
   - https://download.openblas.net/release/OpenBLAS-0.3.25-x64.zip

### Step 2: Extract and Install
```powershell
# Create libraries directory
mkdir C:\Libraries
cd C:\Libraries

# Extract the downloaded zip file
# Assuming you downloaded OpenBLAS-0.3.25-x64.zip
# Use PowerShell or 7-Zip to extract

# Expected directory structure:
# C:\Libraries\openblas\
#   ├── bin\           # DLL files (if dynamic linking)
#   ├── lib\           # .lib files
#   │   ├── openblas.lib
#   │   └── openblas.dll.lib (if dynamic)
#   └── include\       # Header files
#       ├── cblas.h
#       ├── openblas_config.h
#       └── ...
```

### Step 3: Configure CMake
```powershell
cd d:\github\scamp_win\scamp\build

# Clean existing build
rmdir /s /q .
mkdir build
cd build

# Configure with OpenBLAS path
cmake .. -G "Visual Studio 16 2019" -A x64 ^
    -DOPENBLAS_ROOT="C:/Libraries/openblas" ^
    -DUSE_OPENBLAS=ON ^
    -DENABLE_THREADS=OFF ^
    -DENABLE_PLPLOT=OFF
```

## Method 3: Compile from Source

### Step 1: Install Build Tools
```powershell
# Install MSYS2 (if not already installed)
# Download from: https://www.msys2.org/

# Update MSYS2 packages
pacman -Syu

# Install MinGW-w64 toolchain
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake ^
          mingw-w64-x86_64-make mingw-w64-x86_64-ninja
```

### Step 2: Compile OpenBLAS
```bash
# In MSYS2 MINGW64 terminal
cd /c/Libraries
git clone https://github.com/xianyi/OpenBLAS.git
cd OpenBLAS

# Compile for 64-bit Windows
make DYNAMIC_ARCH=1 TARGET=HASWELL BINARY=64 USE_THREAD=1 ^
     NO_LAPACK=0 NO_AFFINITY=1 NUM_THREADS=8

# Install to local directory
make PREFIX=/c/Libraries/openblas install
```

### Step 3: Configure CMake (same as Method 2)

## Method 4: Using Conda (Alternative)

If you have Anaconda or Miniconda installed:

```powershell
# Install OpenBLAS via conda
conda install -c conda-forge openblas

# Find the installation path
# Usually in: C:\Users\<username>\Anaconda3\Library
# or: C:\ProgramData\Anaconda3\Library

# Configure CMake with the conda path
cmake .. -DOPENBLAS_ROOT="C:/Users/<username>/Anaconda3/Library"
```

## Verification Steps

### 1. Check OpenBLAS Installation
```powershell
# Verify .lib file exists
dir "C:\Libraries\openblas\lib\openblas.lib"

# Verify header files
dir "C:\Libraries\openblas\include\cblas.h"
```

### 2. Test CMake Detection
```powershell
cd d:\github\scamp_win\scamp\build
cmake .. -DUSE_OPENBLAS=ON -DENABLE_THREADS=OFF -DENABLE_PLPLOT=OFF

# Look for this message in CMake output:
# -- Found OpenBLAS: C:/Libraries/openblas/lib/openblas.lib
```

### 3. Build SCAMP with OpenBLAS
```powershell
cmake --build . --config Release --parallel

# Check for successful build
dir .\Release\scamp.exe
```

## Troubleshooting

### Common Issues

#### 1. "OpenBLAS not found" in CMake
- Ensure `OPENBLAS_ROOT` points to the correct directory
- Check that `lib/openblas.lib` exists in that directory
- Verify 64-bit vs 32-bit architecture matches your build

#### 2. Linker Errors
- For dynamic linking: Ensure `openblas.dll` is in PATH or next to `scamp.exe`
- For static linking: Use `openblas.lib` (static library)

#### 3. Missing Header Files
- Ensure `cblas.h` is in `include/` directory
- Check for `openblas_config.h`

#### 4. Architecture Mismatch
- SCAMP is built for x64 (64-bit)
- OpenBLAS must also be 64-bit
- Mixing 32-bit and 64-bit libraries causes linker errors

### Environment Variables (Optional)
```powershell
# Add OpenBLAS to PATH for dynamic linking
setx PATH "%PATH%;C:\Libraries\openblas\bin"

# Set environment variable for CMake
setx OPENBLAS_ROOT "C:\Libraries\openblas"
```

## Post-Installation

After successful OpenBLAS installation:

1. **Rebuild SCAMP**:
   ```powershell
   cd d:\github\scamp_win\scamp\build
   cmake --build . --config Release --clean-first --parallel
   ```

2. **Test SCAMP**:
   ```powershell
   .\Release\scamp.exe --help
   ```

3. **Verify Linear Algebra Functions**:
   Run SCAMP on a test dataset to ensure mosaic processing works correctly.

## Alternative: Disable OpenBLAS (Not Recommended)

If OpenBLAS installation fails, you can build SCAMP with limited functionality:

```powershell
cmake .. -DUSE_OPENBLAS=OFF

# This will exclude mosaic.c from the build
# SCAMP will work but without advanced linear algebra
```

## Resources

- **OpenBLAS Official Website**: https://www.openblas.net/
- **OpenBLAS GitHub**: https://github.com/xianyi/OpenBLAS
- **vcpkg Documentation**: https://vcpkg.io/
- **MSYS2**: https://www.msys2.org/
- **SCAMP Documentation**: https://astromatic.net/software/scamp

## Support

For issues with OpenBLAS installation on Windows:
1. Check the [OpenBLAS GitHub Issues](https://github.com/xianyi/OpenBLAS/issues)
2. Refer to the [SCAMP Windows Build Guide](README_WINDOWS.md)
3. Contact the SCAMP maintainers or community forums