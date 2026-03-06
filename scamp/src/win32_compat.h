/*
 * win32_compat.h - Windows compatibility layer for SCAMP
 *
 * Provides POSIX compatibility functions for Windows builds
 */

#ifndef WIN32_COMPAT_H
#define WIN32_COMPAT_H

#ifdef _WIN32

#include <windows.h>
#include <io.h>
#include <direct.h>
#include <process.h>
#include <sys/types.h>
#include <time.h>

/* Map POSIX signals to Windows equivalents where possible */
#ifndef SIGBUS
#define SIGBUS 7  /* Not actually used on Windows */
#endif

/* sys/time.h compatibility - timeval provided by winsock.h */
struct timezone {
    int tz_minuteswest; /* minutes west of Greenwich */
    int tz_dsttime;     /* type of DST correction */
};

/* mmap/munmap compatibility */
#ifdef __cplusplus
extern "C" {
#endif

/* For anonymous memory mapping (MAP_ANONYMOUS) */
#define MAP_ANONYMOUS 0x20
#define MAP_ANON MAP_ANONYMOUS
#define MAP_PRIVATE 0x02
#define MAP_SHARED 0x01
#define PROT_READ 0x1
#define PROT_WRITE 0x2
#define PROT_EXEC 0x4

/* mmap flags for Windows */
#define MAP_FAILED ((void *)-1)

/* Windows implementation of mmap for file mapping */
void *win32_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int win32_munmap(void *addr, size_t length);

/* For compatibility with existing code */
#define mmap win32_mmap
#define munmap win32_munmap

/* File descriptor functions */
#define fileno _fileno

/* unlink compatibility */
#define unlink _unlink

/* Directory operations */
#define mkdir(path, mode) _mkdir(path)

/* sleep function - Windows uses milliseconds */
static inline void sleep(unsigned int seconds) {
    Sleep(seconds * 1000);
}

/* gettimeofday implementation for Windows */
static inline int gettimeofday(struct timeval *tv, struct timezone *tz) {
    (void)tz; /* timezone not supported */
    
    if (tv) {
        FILETIME ft;
        ULARGE_INTEGER uli;
        
        GetSystemTimeAsFileTime(&ft);
        uli.LowPart = ft.dwLowDateTime;
        uli.HighPart = ft.dwHighDateTime;
        
        /* Convert to microseconds since 1601-01-01 to seconds since 1970-01-01 */
        uli.QuadPart -= 116444736000000000ULL;
        tv->tv_sec = (long)(uli.QuadPart / 10000000ULL);
        tv->tv_usec = (long)((uli.QuadPart % 10000000ULL) / 10ULL);
    }
    
    return 0;
}

/* CBLAS constants (if not defined by OpenBLAS/ATLAS) */
#ifndef CblasRowMajor
#define CblasRowMajor 101
#define CblasColMajor 102
#endif

#ifndef CblasUpper
#define CblasUpper 121
#define CblasLower 122
#endif

/* WCS function compatibility */
#if defined(_WIN32) && !defined(wcsset)
/* Windows has different signatures for wcsset and wcsrev */
#include <wchar.h>
/* These functions might already be defined */
#endif

/* Missing header macros for Windows build */
#ifndef PLPLOT_H
#define PLPLOT_H "win32_compat.h"
#endif

#ifndef PLPLOTP_H
#define PLPLOTP_H "win32_compat.h"
#endif

#ifndef FFTW_H
#define FFTW_H "win32_compat.h"
#endif

#ifndef MKL_H
#define MKL_H "win32_compat.h"
#endif

#ifndef CURL_H
#define CURL_H "win32_compat.h"
#endif

#ifndef CBLAS_H
#define CBLAS_H "win32_compat.h"
#endif

#ifndef LAPACKE_H
#define LAPACKE_H "win32_compat.h"
#endif

/* POSIX header stubs for Windows */
#ifndef _NETDB_H
#define _NETDB_H
/* Stub for netdb.h - minimal definitions */
#ifndef _WINSOCKAPI_
struct hostent {
    char *h_name;
    char **h_aliases;
    int h_addrtype;
    int h_length;
    char **h_addr_list;
};
#define h_addr h_addr_list[0]
#endif
#endif

#ifndef _DLFCN_H
#define _DLFCN_H
/* Stub for dlfcn.h - dynamic loading not supported on Windows */
#define RTLD_LAZY   0
#define RTLD_NOW    0
#define RTLD_GLOBAL 0
#define RTLD_LOCAL  0

static inline void *dlopen(const char *filename, int flag) {
    (void)filename; (void)flag;
    return NULL;
}
static inline char *dlerror(void) {
    return "dlopen not supported on Windows";
}
static inline void *dlsym(void *handle, const char *symbol) {
    (void)handle; (void)symbol;
    return NULL;
}
static inline int dlclose(void *handle) {
    (void)handle;
    return 0;
}
#endif

#ifndef _PTHREAD_H
#define _PTHREAD_H
/* Stub for pthread.h - threading disabled in Windows build */
typedef void *pthread_t;
typedef void *pthread_attr_t;
typedef void *pthread_mutex_t;
typedef void *pthread_mutexattr_t;
typedef void *pthread_cond_t;
typedef void *pthread_condattr_t;

static inline int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                                 void *(*start_routine)(void *), void *arg) {
    (void)thread; (void)attr; (void)start_routine; (void)arg;
    return -1; /* Threading not supported */
}
static inline int pthread_join(pthread_t thread, void **retval) {
    (void)thread; (void)retval;
    return 0;
}
static inline int pthread_mutex_init(pthread_mutex_t *mutex,
                                     const pthread_mutexattr_t *attr) {
    (void)mutex; (void)attr;
    return 0;
}
static inline int pthread_mutex_destroy(pthread_mutex_t *mutex) {
    (void)mutex;
    return 0;
}
static inline int pthread_mutex_lock(pthread_mutex_t *mutex) {
    (void)mutex;
    return 0;
}
static inline int pthread_mutex_unlock(pthread_mutex_t *mutex) {
    (void)mutex;
    return 0;
}
#endif

/* Missing function declarations for Windows */
char *strtok_r(char *str, const char *delim, char **saveptr);

FILE *popen(const char *command, const char *mode);
int pclose(FILE *stream);

char *thetime(void);
char *thetime2(void);

/* CBLAS/LAPACK function declarations */
int clapack_dposv(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo,
                  const int N, const int NRHS, double *A, const int lda,
                  double *B, const int ldb);

int clapack_dgesv(const enum CBLAS_ORDER Order, const int N, const int NRHS,
                  double *A, const int lda, int *ipiv, double *B, const int ldb);

int clapack_dpotri(const enum CBLAS_ORDER Order, const enum CBLAS_UPLO Uplo,
                    const int N, double *A, const int lda);

/* makeit declaration */
void makeit(void);

#ifdef __cplusplus
}
#endif

#endif /* _WIN32 */

#endif /* WIN32_COMPAT_H */