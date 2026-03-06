# SCAMP CMake Build System for Windows
cmake_minimum_required(VERSION 3.15)
project(scamp VERSION 2.14.1 LANGUAGES C)

# Set current date for config.h
string(TIMESTAMP CMAKE_DATE "%Y-%m-%d")

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Windows-specific settings
if(WIN32)
    add_definitions(-D_WIN32 -DWIN32 -D_CRT_SECURE_NO_WARNINGS)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    
    # Disable warnings about unsafe functions for now
    if(MSVC)
        add_compile_options(/wd4996 /wd4267 /wd4244 /wd4018)
    endif()
endif()

# Configuration options
option(ENABLE_THREADS "Enable thread support (requires pthreads-win32)" OFF)
option(ENABLE_PLPLOT "Enable PLPlot graphics support" OFF)
option(USE_OPENBLAS "Use OpenBLAS instead of ATLAS" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
option(BUILD_TESTS "Build test programs" ON)

# User-configurable library paths
set(FFTW_ROOT "" CACHE PATH "Path to FFTW installation")
set(OPENBLAS_ROOT "" CACHE PATH "Path to OpenBLAS installation")
set(CURL_ROOT "" CACHE PATH "Path to cURL installation")
set(PLPLOT_ROOT "" CACHE PATH "Path to PLPlot installation")
set(PTHREADS_ROOT "" CACHE PATH "Path to pthreads-win32 installation")

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/fits
    ${CMAKE_CURRENT_SOURCE_DIR}/src/wcs
)

# Collect source files
file(GLOB_RECURSE SCAMP_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/fits/*.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/wcs/*.c
)

# Remove test files from main build
list(FILTER SCAMP_SOURCES EXCLUDE REGEX ".*test.*\\.c$")
list(FILTER SCAMP_SOURCES EXCLUDE REGEX ".*/tests/.*\\.c$")

# Add win32_compat files
list(APPEND SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/win32_compat.c)

# Remove url.c if cURL not found
if(NOT HAVE_CURL)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/url.c)
endif()

# Remove PLPlot-related files if PLPlot not enabled
if(NOT ENABLE_PLPLOT)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/astrcplot.c)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/photcplot.c)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/cplot.c)
endif()

# Remove FFT-related files if FFTW not found
if(NOT HAVE_FFTW)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/fft.c)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/makeit.c)
    list(REMOVE_ITEM SCAMP_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/match.c)
endif()

# Collect header files (for IDE support)
file(GLOB_RECURSE SCAMP_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/fits/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/wcs/*.h
)

# Dependency detection
set(HAVE_FFTW 0)
set(HAVE_OPENBLAS 0)
set(HAVE_CURL 0)
set(HAVE_PLPLOT 0)
set(HAVE_PTHREAD 0)

# 1. FFTW library
if(FFTW_ROOT)
    find_library(FFTW_LIBRARY NAMES fftw3 fftw3-3
        PATHS ${FFTW_ROOT}
        PATH_SUFFIXES lib lib64)
    find_path(FFTW_INCLUDE_DIR fftw3.h
        PATHS ${FFTW_ROOT}
        PATH_SUFFIXES include)
else()
    find_library(FFTW_LIBRARY NAMES fftw3 fftw3-3)
    find_path(FFTW_INCLUDE_DIR fftw3.h)
endif()

if(FFTW_LIBRARY AND FFTW_INCLUDE_DIR)
    message(STATUS "Found FFTW: ${FFTW_LIBRARY}")
    include_directories(${FFTW_INCLUDE_DIR})
    set(HAVE_FFTW 1)
    add_definitions(-DHAVE_FFTW)
else()
    message(WARNING "FFTW not found. Fourier transforms will be disabled.")
endif()

# 2. OpenBLAS library
if(USE_OPENBLAS)
    if(OPENBLAS_ROOT)
        find_library(OPENBLAS_LIBRARY NAMES openblas
            PATHS ${OPENBLAS_ROOT}
            PATH_SUFFIXES lib lib64)
        find_path(OPENBLAS_INCLUDE_DIR cblas.h
            PATHS ${OPENBLAS_ROOT}
            PATH_SUFFIXES include)
    else()
        find_library(OPENBLAS_LIBRARY NAMES openblas)
        find_path(OPENBLAS_INCLUDE_DIR cblas.h)
    endif()
    
    if(OPENBLAS_LIBRARY AND OPENBLAS_INCLUDE_DIR)
        message(STATUS "Found OpenBLAS: ${OPENBLAS_LIBRARY}")
        include_directories(${OPENBLAS_INCLUDE_DIR})
        set(HAVE_OPENBLAS 1)
        add_definitions(-DHAVE_OPENBLAS -DHAVE_OPENBLASP)
    else()
        message(WARNING "OpenBLAS not found. Linear algebra operations will be limited.")
    endif()
endif()

# 3. cURL library
if(CURL_ROOT)
    find_library(CURL_LIBRARY NAMES curl libcurl
        PATHS ${CURL_ROOT}
        PATH_SUFFIXES lib lib64)
    find_path(CURL_INCLUDE_DIR curl/curl.h
        PATHS ${CURL_ROOT}
        PATH_SUFFIXES include)
else()
    find_library(CURL_LIBRARY NAMES curl libcurl)
    find_path(CURL_INCLUDE_DIR curl/curl.h)
endif()

if(CURL_LIBRARY AND CURL_INCLUDE_DIR)
    message(STATUS "Found cURL: ${CURL_LIBRARY}")
    include_directories(${CURL_INCLUDE_DIR})
    set(HAVE_CURL 1)
    add_definitions(-DHAVE_CURL)
else()
    message(WARNING "cURL not found. HTTP functionality will be disabled.")
endif()

# 4. PLPlot library
if(ENABLE_PLPLOT)
    if(PLPLOT_ROOT)
        find_library(PLPLOT_LIBRARY NAMES plplot
            PATHS ${PLPLOT_ROOT}
            PATH_SUFFIXES lib lib64)
        find_path(PLPLOT_INCLUDE_DIR plplot.h
            PATHS ${PLPLOT_ROOT}
            PATH_SUFFIXES include)
    else()
        find_library(PLPLOT_LIBRARY NAMES plplot)
        find_path(PLPLOT_INCLUDE_DIR plplot.h)
    endif()
    
    if(PLPLOT_LIBRARY AND PLPLOT_INCLUDE_DIR)
        message(STATUS "Found PLPlot: ${PLPLOT_LIBRARY}")
        include_directories(${PLPLOT_INCLUDE_DIR})
        set(HAVE_PLPLOT 1)
        add_definitions(-DHAVE_PLPLOT -DUSE_PLPLOT)
    else()
        message(WARNING "PLPlot not found. Plotting functionality will be disabled.")
    endif()
endif()

# 5. pthreads for Windows
if(ENABLE_THREADS AND WIN32)
    if(PTHREADS_ROOT)
        find_library(PTHREAD_LIBRARY NAMES pthreadVC2 pthreadVC2_x64
            PATHS ${PTHREADS_ROOT}
            PATH_SUFFIXES lib Pre-built.2/lib/x64 Pre-built.2/lib/x86)
        find_path(PTHREAD_INCLUDE_DIR pthread.h
            PATHS ${PTHREADS_ROOT}
            PATH_SUFFIXES include Pre-built.2/include)
    else()
        find_library(PTHREAD_LIBRARY NAMES pthreadVC2 pthreadVC2_x64)
        find_path(PTHREAD_INCLUDE_DIR pthread.h)
    endif()
    
    if(PTHREAD_LIBRARY AND PTHREAD_INCLUDE_DIR)
        message(STATUS "Found pthreads-win32: ${PTHREAD_LIBRARY}")
        include_directories(${PTHREAD_INCLUDE_DIR})
        set(HAVE_PTHREAD 1)
        add_definitions(-DHAVE_PTHREAD -DUSE_THREADS)
    else()
        message(WARNING "pthreads-win32 not found. Thread support disabled.")
        set(ENABLE_THREADS OFF)
    endif()
elseif(ENABLE_THREADS AND NOT WIN32)
    find_package(Threads REQUIRED)
    if(Threads_FOUND)
        set(HAVE_PTHREAD 1)
        add_definitions(-DHAVE_PTHREAD -DUSE_THREADS)
    endif()
endif()

# Generate config.h from template
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/config.h
    @ONLY
)

# Add binary directory to include path for generated config.h
include_directories(${CMAKE_CURRENT_BINARY_DIR})

# Create executable
add_executable(scamp ${SCAMP_SOURCES} ${SCAMP_HEADERS})

# Set target properties
set_target_properties(scamp PROPERTIES
    OUTPUT_NAME scamp
    VERSION ${PROJECT_VERSION}
)

# Link libraries
if(WIN32)
    target_link_libraries(scamp ws2_32)  # Winsock
endif()

if(HAVE_FFTW)
    target_link_libraries(scamp ${FFTW_LIBRARY})
endif()

if(HAVE_OPENBLAS)
    target_link_libraries(scamp ${OPENBLAS_LIBRARY})
endif()

if(HAVE_CURL)
    target_link_libraries(scamp ${CURL_LIBRARY})
endif()

if(HAVE_PLPLOT)
    target_link_libraries(scamp ${PLPLOT_LIBRARY})
endif()

if(HAVE_PTHREAD)
    if(WIN32)
        target_link_libraries(scamp ${PTHREAD_LIBRARY})
    else()
        target_link_libraries(scamp Threads::Threads)
    endif()
endif()

# Create Visual Studio solution folder structure
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(TARGET scamp PROPERTY FOLDER "Executables")

# Install rules (optional)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/install CACHE PATH "Install prefix" FORCE)
endif()

install(TARGETS scamp
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

# Build test programs
if(BUILD_TESTS)
    # Test source files
    set(TEST_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_chealpix.c
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_chealpixstore.c
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_crossid_single_catalog.c
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_crossid_single_catalog_moving.c
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_windows_compat.c
    )
    
    # Common test dependencies (object files needed by tests)
    file(GLOB_RECURSE TEST_COMMON_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/src/*.c
        ${CMAKE_CURRENT_SOURCE_DIR}/src/fits/*.c
        ${CMAKE_CURRENT_SOURCE_DIR}/src/wcs/*.c
    )
    
    # Remove main program files from test builds
    list(FILTER TEST_COMMON_SOURCES EXCLUDE REGEX ".*main\\.c$")
    list(FILTER TEST_COMMON_SOURCES EXCLUDE REGEX ".*/tests/.*\\.c$")
    
    # Apply same exclusions as main build
    if(NOT HAVE_CURL)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/url.c)
    endif()
    
    if(NOT ENABLE_PLPLOT)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/astrcplot.c)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/photcplot.c)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/cplot.c)
    endif()
    
    if(NOT HAVE_FFTW)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/fft.c)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/makeit.c)
        list(REMOVE_ITEM TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/match.c)
    endif()
    
    # Add win32_compat for Windows
    list(APPEND TEST_COMMON_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/src/win32_compat.c)
    
    # Create test executables
    foreach(test_src ${TEST_SOURCES})
        get_filename_component(test_name ${test_src} NAME_WE)
        add_executable(${test_name} ${test_src} ${TEST_COMMON_SOURCES})
        set_target_properties(${test_name} PROPERTIES FOLDER "Tests")
        
        # Link libraries (same as main executable)
        if(WIN32)
            target_link_libraries(${test_name} ws2_32)
        endif()
        
        if(HAVE_FFTW)
            target_link_libraries(${test_name} ${FFTW_LIBRARY})
        endif()
        
        if(HAVE_OPENBLAS)
            target_link_libraries(${test_name} ${OPENBLAS_LIBRARY})
        endif()
        
        if(HAVE_CURL)
            target_link_libraries(${test_name} ${CURL_LIBRARY})
        endif()
        
        if(HAVE_PLPLOT)
            target_link_libraries(${test_name} ${PLPLOT_LIBRARY})
        endif()
        
        if(HAVE_PTHREAD)
            if(WIN32)
                target_link_libraries(${test_name} ${PTHREAD_LIBRARY})
            else()
                target_link_libraries(${test_name} Threads::Threads)
            endif()
        endif()
        
        # Install test binaries (optional)
        install(TARGETS ${test_name}
            RUNTIME DESTINATION tests
        )
    endforeach()
    
    message(STATUS "Test programs will be built: test_chealpix, test_chealpixstore, test_crossid_single_catalog, test_crossid_single_catalog_moving, test_windows_compat")
endif()

# Create a simple test to verify build
enable_testing()
add_test(NAME scamp_version
    COMMAND scamp --help
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

# Add tests for test programs if they are built
if(BUILD_TESTS)
    # Unit tests
    add_test(NAME test_chealpix
        COMMAND test_chealpix
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
    )
    
    add_test(NAME test_chealpixstore
        COMMAND test_chealpixstore
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
    )
    
    add_test(NAME test_crossid_single_catalog
        COMMAND test_crossid_single_catalog
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
    )
    
    add_test(NAME test_crossid_single_catalog_moving
        COMMAND test_crossid_single_catalog_moving
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
    )
    
    add_test(NAME test_windows_compat
        COMMAND test_windows_compat
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
    )
    
    # Python integration test (if Python and dependencies are available)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_Interpreter_FOUND)
        # Check for required Python packages
        execute_process(
            COMMAND ${Python3_EXECUTABLE} -c "import numpy, astropy; print('OK')"
            OUTPUT_VARIABLE PYTHON_DEPS_CHECK
            ERROR_VARIABLE PYTHON_DEPS_ERROR
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        
        if(PYTHON_DEPS_CHECK STREQUAL "OK")
            add_test(NAME test_integration01
                COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/test_integration01.py
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests
            )
            message(STATUS "Python integration test will be run: test_integration01.py")
        else()
            message(STATUS "Python dependencies (numpy, astropy) not found. Skipping integration test.")
        endif()
    else()
        message(STATUS "Python 3 not found. Skipping integration test.")
    endif()
endif()

# Create a batch file for Windows users to set up environment
if(WIN32)
    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/build_windows.bat.in
        ${CMAKE_CURRENT_BINARY_DIR}/build_windows.bat
        @ONLY
    )
endif()

# Summary message
message(STATUS "==========================================")
message(STATUS "SCAMP Windows Build Configuration Summary")
message(STATUS "==========================================")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Thread support: ${ENABLE_THREADS}")
message(STATUS "PLPlot support: ${ENABLE_PLPLOT}")
message(STATUS "OpenBLAS: ${USE_OPENBLAS}")
message(STATUS "")
message(STATUS "Build configuration:")
message(STATUS "  Tests: ${BUILD_TESTS}")
message(STATUS "")
message(STATUS "Found libraries:")
message(STATUS "  FFTW: ${HAVE_FFTW}")
message(STATUS "  OpenBLAS: ${HAVE_OPENBLAS}")
message(STATUS "  cURL: ${HAVE_CURL}")
message(STATUS "  PLPlot: ${HAVE_PLPLOT}")
message(STATUS "  pthreads: ${HAVE_PTHREAD}")
message(STATUS "==========================================")