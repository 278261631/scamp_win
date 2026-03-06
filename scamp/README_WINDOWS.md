# SCAMP Windows Build Guide

This document provides instructions for building SCAMP on Windows using Visual Studio and CMake.

## Prerequisites

### 1. Required Software
- **Visual Studio 2019 or later** (Community edition is fine)
  - Include "Desktop development with C++" workload
- **CMake 3.15 or later** (https://cmake.org/download/)
- **Git** (for cloning the repository)

### 2. Optional Dependencies

SCAMP can run without external dependencies, but with limited functionality:

| Library | Purpose | Required | Download Source |
|---------|---------|----------|-----------------|
| **FFTW** | Fourier transforms | Optional (but recommended) | [Precompiled Windows binaries](http://www.fftw.org/install/windows.html) |
| **OpenBLAS** | Linear algebra | Optional (but recommended) | [OpenBLAS Windows binaries](https://github.com/xianyi/OpenBLAS/releases) |
| **cURL** | HTTP downloads | Optional | [curl for Windows](https://curl.se/windows/) |
| **PLPlot** | Graphics/plotting | Optional | [PLPlot Windows binaries](http://plplot.sourceforge.net/) |
| **pthreads-win32** | Thread support | Optional | [pthreads-win32](ftp://sourceware.org/pub/pthreads-win32/) |

## Quick Start (Minimal Build)

For a minimal build without external dependencies:

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/astromatic/scamp.git
   cd scamp
   ```

2. **Run the build script**:
   ```bash
   build_windows.bat
   ```

   This will:
   - Configure CMake with default settings (no external dependencies)
   - Build SCAMP in Release mode
   - Place the executable in `build/bin/Release/scamp.exe`

## Full Build with Dependencies

### Step 1: Install Dependencies

#### Method A: Manual Installation (Recommended for first-time users)

1. **FFTW**:
   - Download precompiled binaries from http://www.fftw.org/install/windows.html
   - Extract to `C:\Libraries\fftw`
   - The directory should contain:
     - `libfftw3-3.lib` (or similar)
     - `fftw3.h`

2. **OpenBLAS**:
   - Download from https://github.com/xianyi/OpenBLAS/releases
   - Look for `OpenBLAS-*.zip` with Windows binaries
   - Extract to `C:\Libraries\openblas`
   - Should contain `libopenblas.lib` and `cblas.h`

3. **cURL**:
   - Download from https://curl.se/windows/
   - Extract to `C:\Libraries\curl`
   - Should contain `libcurl.lib` and `curl/curl.h`

#### Method B: Using vcpkg (Advanced users)

```bash
# Install vcpkg if not already installed
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat

# Install dependencies
.\vcpkg install fftw3 openblas curl plplot pthreads
```

### Step 2: Configure the Build

Open a command prompt in the SCAMP directory and run:

```bash
# Create build directory
mkdir build
cd build

# Configure with CMake (adjust paths as needed)
cmake .. -G "Visual Studio 16 2019" -A x64 ^
    -DFFTW_ROOT="C:\Libraries\fftw" ^
    -DOPENBLAS_ROOT="C:\Libraries\openblas" ^
    -DCURL_ROOT="C:\Libraries\curl" ^
    -DUSE_OPENBLAS=ON ^
    -DENABLE_THREADS=OFF ^
    -DENABLE_PLPLOT=OFF
```

### Step 3: Build

```bash
# Build Release version
cmake --build . --config Release --parallel

# Or build Debug version
cmake --build . --config Debug --parallel
```

### Step 4: Install (Optional)

```bash
# Install to default location
cmake --install . --config Release

# Or specify custom location
cmake --install . --config Release --prefix "C:\Program Files\SCAMP"
```

## Build Options

Configure CMake with these options:

| Option | Description | Default |
|--------|-------------|---------|
| `-DUSE_OPENBLAS=ON/OFF` | Use OpenBLAS for linear algebra | ON |
| `-DENABLE_THREADS=ON/OFF` | Enable thread support (requires pthreads-win32) | OFF |
| `-DENABLE_PLPLOT=ON/OFF` | Enable PLPlot graphics | OFF |
| `-DBUILD_SHARED_LIBS=ON/OFF` | Build as shared library | OFF |
| `-DFFTW_ROOT="path"` | Path to FFTW installation | "" |
| `-DOPENBLAS_ROOT="path"` | Path to OpenBLAS installation | "" |
| `-DCURL_ROOT="path"` | Path to cURL installation | "" |

## Visual Studio Integration

You can also open the generated solution in Visual Studio:

1. After running CMake, open `build/scamp.sln`
2. Set `scamp` as the startup project
3. Build from within Visual Studio

## Testing the Build

After building, test the executable:

```bash
cd build/bin/Release
scamp.exe --help
```

You should see SCAMP's help output with version information.

## Troubleshooting

### Common Issues

1. **"Cannot find FFTW library"**
   - Ensure `FFTW_ROOT` points to the correct directory
   - Check that `libfftw3-3.lib` exists in the `lib` subdirectory
   - For vcpkg users: run `vcpkg integrate install`

2. **"Cannot find OpenBLAS"**
   - OpenBLAS Windows binaries are 32-bit by default
   - For 64-bit builds, compile OpenBLAS from source or find 64-bit binaries
   - Alternative: Disable OpenBLAS with `-DUSE_OPENBLAS=OFF`

3. **Linker errors with Visual Studio**
   - Ensure you're using the same architecture (x64) consistently
   - Clean the build directory and reconfigure
   - Check for mixed Debug/Release configurations

4. **Missing pthreads-win32**
   - Thread support is optional; disable with `-DENABLE_THREADS=OFF`
   - Or download from ftp://sourceware.org/pub/pthreads-win32/

5. **CMake generator not found**
   - Specify the correct Visual Studio version: `-G "Visual Studio 17 2022"`
   - List available generators: `cmake --help`

## Performance Notes

- **OpenBLAS vs ATLAS**: OpenBLAS is recommended for Windows as it provides better performance and easier installation
- **Threading**: Disabled by default due to pthreads dependency; enable if you need parallel processing
- **FFTW**: Significantly improves performance for Fourier transforms

## File Locations

- **Executable**: `build/bin/(Debug|Release)/scamp.exe`
- **Installed files**: `install/bin/scamp.exe`
- **Generated config**: `build/config.h`
- **Build logs**: `build/CMakeFiles/CMakeOutput.log`

## Support

For issues with the Windows build:
- Check the [original SCAMP documentation](https://astromatic.net/software/scamp)
- Report issues on GitHub (if applicable)
- Consult the [CMake documentation](https://cmake.org/documentation/)

## License

SCAMP is distributed under the GNU General Public License v3 (GPLv3).
See the `COPYING` file for details.