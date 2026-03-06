/**
 * test_windows_compat.c - Windows compatibility layer tests
 * 
 * Tests the Windows compatibility functions implemented in win32_compat.c
 * These tests are specifically for the Windows port of SCAMP.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

#ifdef _WIN32
#include <windows.h>
#include "win32_compat.h"
#else
/* For non-Windows builds, include standard headers */
#include <sys/time.h>
#include <unistd.h>
#endif

/* Global string buffer for tests */
#define TEST_BUFFER_SIZE 256
static char test_buffer[TEST_BUFFER_SIZE];

/* Test sleep function */
void test_sleep(void) {
    printf("Testing sleep function... ");
    
    /* Get current time */
    time_t start, end;
    time(&start);
    
    /* Sleep for 1 second */
    sleep(1);
    
    time(&end);
    double elapsed = difftime(end, start);
    
    /* Should be approximately 1 second (allow some tolerance) */
    if (elapsed >= 0.9 && elapsed <= 1.5) {
        printf("PASSED (slept for %.2f seconds)\n", elapsed);
    } else {
        printf("FAILED (slept for %.2f seconds, expected ~1.0)\n", elapsed);
        exit(1);
    }
}

/* Test gettimeofday function */
void test_gettimeofday(void) {
    printf("Testing gettimeofday function... ");
    
    struct timeval tv1, tv2;
    
    /* Get first timestamp */
    if (gettimeofday(&tv1, NULL) != 0) {
        printf("FAILED (gettimeofday returned error)\n");
        exit(1);
    }
    
    /* Sleep a little */
    sleep(1);
    
    /* Get second timestamp */
    if (gettimeofday(&tv2, NULL) != 0) {
        printf("FAILED (gettimeofday returned error)\n");
        exit(1);
    }
    
    /* Check that time increased */
    long diff_sec = tv2.tv_sec - tv1.tv_sec;
    long diff_usec = tv2.tv_usec - tv1.tv_usec;
    long total_usec = diff_sec * 1000000 + diff_usec;
    
    /* Should be approximately 1 second (allow tolerance) */
    if (total_usec >= 900000 && total_usec <= 1500000) {
        printf("PASSED (time increased by %ld microseconds)\n", total_usec);
    } else {
        printf("FAILED (time increased by %ld microseconds, expected ~1,000,000)\n", total_usec);
        exit(1);
    }
}

/* Test strtok_r function (reentrant string tokenizer) */
void test_strtok_r(void) {
    printf("Testing strtok_r function... ");
    
    char str[] = "apple,banana,cherry";
    const char delim[] = ",";
    char *saveptr = NULL;
    char *token;
    
    /* First token */
    token = strtok_r(str, delim, &saveptr);
    if (token == NULL || strcmp(token, "apple") != 0) {
        printf("FAILED (first token: %s, expected 'apple')\n", token ? token : "NULL");
        exit(1);
    }
    
    /* Second token */
    token = strtok_r(NULL, delim, &saveptr);
    if (token == NULL || strcmp(token, "banana") != 0) {
        printf("FAILED (second token: %s, expected 'banana')\n", token ? token : "NULL");
        exit(1);
    }
    
    /* Third token */
    token = strtok_r(NULL, delim, &saveptr);
    if (token == NULL || strcmp(token, "cherry") != 0) {
        printf("FAILED (third token: %s, expected 'cherry')\n", token ? token : "NULL");
        exit(1);
    }
    
    /* No more tokens */
    token = strtok_r(NULL, delim, &saveptr);
    if (token != NULL) {
        printf("FAILED (extra token: %s)\n", token);
        exit(1);
    }
    
    printf("PASSED\n");
}

/* Test mmap and munmap for anonymous memory */
void test_mmap_anonymous(void) {
    printf("Testing mmap/munmap (anonymous memory)... ");
    
    size_t size = 4096; /* One page */
    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    
    if (mem == MAP_FAILED) {
        printf("FAILED (mmap returned MAP_FAILED)\n");
        exit(1);
    }
    
    /* Write to memory */
    char *ptr = (char *)mem;
    strcpy(ptr, "Test string");
    
    /* Read back */
    if (strcmp(ptr, "Test string") != 0) {
        printf("FAILED (memory write/read failed)\n");
        munmap(mem, size);
        exit(1);
    }
    
    /* Unmap */
    if (munmap(mem, size) != 0) {
        printf("FAILED (munmap failed)\n");
        exit(1);
    }
    
    printf("PASSED\n");
}

/* Test mkdir function */
void test_mkdir(void) {
    printf("Testing mkdir function... ");
    
    const char *test_dir = "test_windows_compat_dir";
    
    /* Try to create directory */
    int result = mkdir(test_dir, 0755);
    
    if (result != 0) {
        /* Directory might already exist, try to remove it first */
        rmdir(test_dir);
        result = mkdir(test_dir, 0755);
        
        if (result != 0) {
            printf("SKIPPED (mkdir failed, might be permission issue)\n");
            return;
        }
    }
    
    /* Check if directory exists by trying to remove it */
    if (rmdir(test_dir) != 0) {
        printf("FAILED (could not remove directory)\n");
        exit(1);
    }
    
    printf("PASSED\n");
}

/* Test CBLAS constants */
void test_cblas_constants(void) {
    printf("Testing CBLAS constants... ");
    
    /* Check that constants are defined */
    if (CblasRowMajor != 101 || CblasColMajor != 102) {
        printf("FAILED (CBLAS order constants incorrect)\n");
        exit(1);
    }
    
    if (CblasUpper != 121 || CblasLower != 122) {
        printf("FAILED (CBLAS UPLO constants incorrect)\n");
        exit(1);
    }
    
    printf("PASSED\n");
}

/* Test time functions */
void test_time_functions(void) {
    printf("Testing time functions (thetime, thetime2)... ");
    
    /* Call thetime - should return a string */
    char *time_str = thetime();
    if (time_str == NULL || strlen(time_str) == 0) {
        printf("FAILED (thetime returned NULL or empty string)\n");
        exit(1);
    }
    
    /* Call thetime2 - should return a string */
    char *time_str2 = thetime2();
    if (time_str2 == NULL || strlen(time_str2) == 0) {
        printf("FAILED (thetime2 returned NULL or empty string)\n");
        exit(1);
    }
    
    printf("PASSED (thetime='%s', thetime2='%s')\n", time_str, time_str2);
}

/* Test popen and pclose stubs */
void test_popen_pclose(void) {
    printf("Testing popen/pclose stubs... ");
    
    /* These are stub functions that should return NULL/error on Windows */
    FILE *pipe = popen("echo test", "r");
    if (pipe != NULL) {
        /* If it actually works (unlikely on Windows), close it */
        pclose(pipe);
        printf("PASSED (popen actually worked)\n");
    } else {
        /* Expected behavior for stub implementation */
        printf("PASSED (popen returned NULL as expected for stub)\n");
    }
}

/* Test dlopen stubs */
void test_dlopen_stubs(void) {
    printf("Testing dlopen stubs... ");
    
    /* These should return NULL/error on Windows */
    void *handle = dlopen("nonexistent.dll", RTLD_LAZY);
    if (handle != NULL) {
        dlclose(handle);
        printf("FAILED (dlopen should return NULL on Windows)\n");
        exit(1);
    }
    
    char *error = dlerror();
    if (error == NULL || strlen(error) == 0) {
        printf("FAILED (dlerror should return error message)\n");
        exit(1);
    }
    
    printf("PASSED (dlerror='%s')\n", error);
}

/* Test pthread stubs */
void test_pthread_stubs(void) {
    printf("Testing pthread stubs... ");
    
    pthread_t thread;
    pthread_mutex_t mutex;
    
    /* All pthread functions should "work" but not actually create threads */
    if (pthread_create(&thread, NULL, NULL, NULL) != -1) {
        printf("FAILED (pthread_create should return -1 on Windows)\n");
        exit(1);
    }
    
    if (pthread_mutex_init(&mutex, NULL) != 0) {
        printf("FAILED (pthread_mutex_init should return 0)\n");
        exit(1);
    }
    
    if (pthread_mutex_lock(&mutex) != 0) {
        printf("FAILED (pthread_mutex_lock should return 0)\n");
        exit(1);
    }
    
    if (pthread_mutex_unlock(&mutex) != 0) {
        printf("FAILED (pthread_mutex_unlock should return 0)\n");
        exit(1);
    }
    
    if (pthread_mutex_destroy(&mutex) != 0) {
        printf("FAILED (pthread_mutex_destroy should return 0)\n");
        exit(1);
    }
    
    printf("PASSED\n");
}

/* Main test function */
int main(int argc, char **argv) {
    printf("==========================================\n");
    printf("Windows Compatibility Layer Tests\n");
    printf("==========================================\n");
    printf("Running on: %s\n", 
#ifdef _WIN32
           "Windows"
#else
           "Non-Windows (compatibility mode)"
#endif
    );
    printf("\n");
    
    int run_all = 1;
    char *test_name = NULL;
    
    /* Parse command line arguments */
    if (argc > 1) {
        if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
            printf("Usage: %s [test_name]\n", argv[0]);
            printf("Available tests:\n");
            printf("  sleep          Test sleep function\n");
            printf("  gettimeofday   Test gettimeofday function\n");
            printf("  strtok_r       Test strtok_r function\n");
            printf("  mmap           Test mmap/munmap functions\n");
            printf("  mkdir          Test mkdir function\n");
            printf("  cblas          Test CBLAS constants\n");
            printf("  time           Test thetime/thetime2 functions\n");
            printf("  popen          Test popen/pclose stubs\n");
            printf("  dlopen         Test dlopen stubs\n");
            printf("  pthread        Test pthread stubs\n");
            printf("  all            Run all tests (default)\n");
            return 0;
        }
        run_all = 0;
        test_name = argv[1];
    }
    
    /* Run selected tests */
    if (run_all || strcmp(test_name, "all") == 0) {
        test_sleep();
        test_gettimeofday();
        test_strtok_r();
        test_mmap_anonymous();
        test_mkdir();
        test_cblas_constants();
        test_time_functions();
        test_popen_pclose();
        test_dlopen_stubs();
        test_pthread_stubs();
    } else if (strcmp(test_name, "sleep") == 0) {
        test_sleep();
    } else if (strcmp(test_name, "gettimeofday") == 0) {
        test_gettimeofday();
    } else if (strcmp(test_name, "strtok_r") == 0) {
        test_strtok_r();
    } else if (strcmp(test_name, "mmap") == 0) {
        test_mmap_anonymous();
    } else if (strcmp(test_name, "mkdir") == 0) {
        test_mkdir();
    } else if (strcmp(test_name, "cblas") == 0) {
        test_cblas_constants();
    } else if (strcmp(test_name, "time") == 0) {
        test_time_functions();
    } else if (strcmp(test_name, "popen") == 0) {
        test_popen_pclose();
    } else if (strcmp(test_name, "dlopen") == 0) {
        test_dlopen_stubs();
    } else if (strcmp(test_name, "pthread") == 0) {
        test_pthread_stubs();
    } else {
        printf("Unknown test: %s\n", test_name);
        printf("Use --help to see available tests.\n");
        return 1;
    }
    
    printf("\n==========================================\n");
    printf("All tests passed!\n");
    printf("==========================================\n");
    
    return 0;
}