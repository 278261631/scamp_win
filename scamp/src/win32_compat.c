/*
 * win32_compat.c - Windows compatibility implementation for SCAMP
 *
 * Implementation of POSIX functions for Windows builds
 */

#ifdef _WIN32

#include "win32_compat.h"
#include "define.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

/* Track memory allocations for anonymous mappings */
typedef struct {
    void *addr;
    size_t size;
} mem_allocation;

static mem_allocation *allocations = NULL;
static size_t alloc_count = 0;
static size_t alloc_capacity = 0;

/* Windows implementation of mmap */
void *win32_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset) {
    (void)addr; /* addr hint not supported */
    (void)prot; /* protection flags not fully supported */
    
    /* Anonymous mapping (MAP_ANONYMOUS) */
    if (fd == -1 && (flags & MAP_ANONYMOUS)) {
        void *mem = malloc(length);
        if (mem == NULL) {
            errno = ENOMEM;
            return MAP_FAILED;
        }
        
        /* Track allocation for munmap */
        if (alloc_count >= alloc_capacity) {
            size_t new_capacity = alloc_capacity == 0 ? 16 : alloc_capacity * 2;
            mem_allocation *new_allocations = realloc(allocations, 
                                                      new_capacity * sizeof(mem_allocation));
            if (new_allocations == NULL) {
                free(mem);
                errno = ENOMEM;
                return MAP_FAILED;
            }
            allocations = new_allocations;
            alloc_capacity = new_capacity;
        }
        
        allocations[alloc_count].addr = mem;
        allocations[alloc_count].size = length;
        alloc_count++;
        
        return mem;
    }
    
    /* File mapping */
    if (fd != -1) {
        HANDLE hFile = (HANDLE)_get_osfhandle(fd);
        if (hFile == INVALID_HANDLE_VALUE) {
            errno = EBADF;
            return MAP_FAILED;
        }
        
        DWORD protect = 0;
        if (prot & PROT_WRITE) {
            protect = PAGE_READWRITE;
        } else if (prot & PROT_READ) {
            protect = PAGE_READONLY;
        } else {
            protect = PAGE_NOACCESS;
        }
        
        HANDLE hMap = CreateFileMapping(hFile, NULL, protect, 
                                        (DWORD)((length + offset) >> 32),
                                        (DWORD)((length + offset) & 0xFFFFFFFF),
                                        NULL);
        if (hMap == NULL) {
            errno = EACCES;
            return MAP_FAILED;
        }
        
        DWORD access = 0;
        if (prot & PROT_WRITE) {
            access = FILE_MAP_WRITE;
        } else if (prot & PROT_READ) {
            access = FILE_MAP_READ;
        } else {
            access = FILE_MAP_ALL_ACCESS;
        }
        
        void *mem = MapViewOfFile(hMap, access, 
                                  (DWORD)(offset >> 32), 
                                  (DWORD)(offset & 0xFFFFFFFF), 
                                  length);
        CloseHandle(hMap);
        
        if (mem == NULL) {
            errno = EACCES;
            return MAP_FAILED;
        }
        
        /* Store HANDLE in allocation tracking? For now, just return */
        return mem;
    }
    
    /* Unsupported mapping type */
    errno = EINVAL;
    return MAP_FAILED;
}

/* Windows implementation of munmap */
int win32_munmap(void *addr, size_t length) {
    (void)length; /* length parameter not always needed */
    
    /* Check if this is an anonymous allocation */
    for (size_t i = 0; i < alloc_count; i++) {
        if (allocations[i].addr == addr) {
            free(addr);
            /* Remove from tracking array */
            for (size_t j = i; j < alloc_count - 1; j++) {
                allocations[j] = allocations[j + 1];
            }
            alloc_count--;
            return 0;
        }
    }
    
    /* Assume it's a file mapping and try to unmap */
    if (UnmapViewOfFile(addr)) {
        return 0;
    }
    
    /* Not a valid mapping */
    errno = EINVAL;
    return -1;
}

/* Global string buffer for error messages */
char gstr[MAXCHAR];

/* strtok_r implementation for Windows */
char *strtok_r(char *str, const char *delim, char **saveptr) {
    char *token;
    
    if (str != NULL) {
        *saveptr = str;
    }
    
    token = *saveptr;
    if (token == NULL) {
        return NULL;
    }
    
    /* Skip leading delimiters */
    token += strspn(token, delim);
    if (*token == '\0') {
        *saveptr = NULL;
        return NULL;
    }
    
    /* Find end of token */
    char *end = token + strcspn(token, delim);
    if (*end != '\0') {
        *end = '\0';
        *saveptr = end + 1;
    } else {
        *saveptr = NULL;
    }
    
    return token;
}

/* popen/pclose stubs for Windows */
FILE *popen(const char *command, const char *mode) {
    (void)command; (void)mode;
    /* Not implemented on Windows */
    return NULL;
}

int pclose(FILE *stream) {
    (void)stream;
    return -1;
}

/* time functions */
static char thetime_buffer[64];
static char thetime2_buffer[64];

char *thetime(void) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(thetime_buffer, sizeof(thetime_buffer), "%Y-%m-%dT%H:%M:%S", tm_info);
    return thetime_buffer;
}

char *thetime2(void) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    strftime(thetime2_buffer, sizeof(thetime2_buffer), "%Y%m%d-%H%M%S", tm_info);
    return thetime2_buffer;
}

/* CBLAS/LAPACK function stubs */
int clapack_dposv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo,
                  const int N, const int NRHS, double *A, const int lda,
                  double *B, const int ldb) {
    (void)Order; (void)Uplo; (void)N; (void)NRHS; (void)A; (void)lda; (void)B; (void)ldb;
    /* Stub - returns error */
    return -1;
}

int clapack_dgesv(const enum CBLAS_ORDER Order, const int N, const int NRHS,
                  double *A, const int lda, int *ipiv, double *B, const int ldb) {
    (void)Order; (void)N; (void)NRHS; (void)A; (void)lda; (void)ipiv; (void)B; (void)ldb;
    /* Stub - returns error */
    return -1;
}

int clapack_dpotri(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo,
                   const int N, double *A, const int lda) {
    (void)Order; (void)Uplo; (void)N; (void)A; (void)lda;
    /* Stub - returns error */
    return -1;
}

/* makeit stub for when FFTW is not available */
void makeit(void) {
    /* Do nothing - FFT initialization not available */
}

#endif /* _WIN32 */