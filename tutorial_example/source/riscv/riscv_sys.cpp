#include <stdlib.h>
#include <unistd.h>

#ifdef __cplusplus
  #include <cstdlib>
  #include <cstdarg>
  #include <cstdio>
  #include <new>
#else
  #include <stdlib.h>
  #include <stdarg.h>
  #include <stdio.h>
#endif
#include <sys/stat.h>
#include <fcntl.h>
#include <pthread.h>
#include <errno.h>
#include <string.h>

#include "syscall.h"
#include "riscv_sys.h"
#include "io_map.h"
#include "recursive_mutex.h"
#if ASIM_CALL
    #include "../hls_apcall.h"
#endif

//Disable profile for io function
#if HW_PROFILE
#define PAUSE_PROFILE()   riscv_pause_profile()
#define RESUME_PROFILE()  riscv_resume_profile()
#else
#define PAUSE_PROFILE()
#define RESUME_PROFILE()
#endif

//-Wl,–wrap=__wrap_symbol
void *__dso_handle;
#ifndef MIN
 #define MIN(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a < _b ? _a : _b; })
#endif

#if NETFILE
#include "../netfile/fileio.hpp"
#endif

#ifdef __cplusplus
extern  "C" {
#endif

#if (HLS_CMDR && defined(BULLET_RISCV))
extern void hls_init(void);
#endif

typedef void (*initFunc)();
extern initFunc __init_array_start[];
extern initFunc __init_array_end[];

#if SUPPORT_MULTI_THREAD
static pthread_mutex_t print_mutex = PTHREAD_MUTEX_INITIALIZER;

#if _rvTranslate
    static recursive_mutex_t malloc_mutex = RECURSIVE_MUTEX_INITIALIZER;
#else
    static pthread_mutex_t malloc_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

#endif

//compile error if MAX_ARGC declared as 'static const unsigned int' in C
#ifdef __cplusplus
static const unsigned int MAX_ARGC = 80;
#else
enum {MAX_ARGC = 80};
#endif

static char *argv_str[MAX_ARGC];

//-------------------------- new_hander() -------------------------------
#ifdef __cplusplus
void riscv_new_handler()
{
    printf("Cannot allocate memory for new operator\n");
    exit(1);
}

//Not used standard set_new_handler() to prevent unsupported "amoswap.w.aq" instruction.
std::new_handler riscv_set_new_handler()
{
    /*
    new_handler
    std::set_new_handler (new_handler handler) throw()
    {
    new_handler prev_handler;
    #if ATOMIC_POINTER_LOCK_FREE > 1
    __atomic_exchange (&__new_handler, &handler, &prev_handler,
                __ATOMIC_ACQ_REL);
    #else
    __gnu_cxx::__scoped_lock l(mx);
    prev_handler = __new_handler;
    __new_handler = handler;
    #endif
    return prev_handler;
    }
    */

    // since the __new_handler is not visible in current source
    // place __new_handler at dedicated location (beginning of .sbss section)
    // get the __new_handler location from linker file
    extern std::new_handler __new_handler;
    std::new_handler prev_handler = __new_handler;
    __new_handler = riscv_new_handler;
    return (std::new_handler)prev_handler;
}
#endif

//-------------------------- memset() & memcpy() Log -------------------------------
#if LOG_MEMCPY_MEMSET
#define MEMCPY_LOG_CORE        8
#define MEMCPY_LOG_MAX         (64 * 1024)
#define MEMCPY_LOG_THRESHOLD   1024
typedef struct
{
    intptr_t dst[MEMCPY_LOG_MAX];
    intptr_t src[MEMCPY_LOG_MAX];
    size_t   len[MEMCPY_LOG_MAX];
    uint32_t pc [MEMCPY_LOG_MAX];
    uint32_t cnt;
} memcpyLog_t;
static memcpyLog_t memcpyLog[MEMCPY_LOG_CORE] = { 0 };
static __attribute__((always_inline)) void memcpy_mmeset_log(void *dst, void *src, size_t len)
{
    int ra;
    asm volatile("mv %0,ra":"=r"(ra));
    int core = mhartid();
    memcpyLog_t *log = &memcpyLog[core];
    if (len >= MEMCPY_LOG_THRESHOLD && log->cnt < MEMCPY_LOG_MAX)
    {
        log->dst[log->cnt] = (intptr_t)dst;
        log->src[log->cnt] = (intptr_t)src;
        log->len[log->cnt] = len;
        log->pc [log->cnt] = ra;
        log->cnt++;
    }
}
void memcpy_memset_log_clear(void)
{
    for (int i = 0; i < 8; i++)
    {
        memcpyLog[i].cnt = 0;
    }
}
void memcpy_memset_log_print(void)
{
    printf("==============================================\n");
    printf("             Memcpy/Memset Log\n");
    printf("==============================================\n");
    for (int i = 0; i < 8; i++)
    {
        memcpyLog_t *log = &memcpyLog[i];
        if (log->cnt > 0)
        {
            printf("----- Core %d -----\n", i);
            for (int j = 0; j < log->cnt; j++)
            {
                printf("   dst=%p src=%p len=%d p=0x%x\n", log->dst[j], log->src[j], log->len[j], log->pc[j]);
            }
        }
    }
}
#endif

//-------------------------- memset() & memcpy() with DMA/Log -------------------------------
void *__wrap_memset(void *dst, int val, size_t len)
{
#if LOG_MEMCPY_MEMSET
    memcpy_mmeset_log(dst, NULL, len);
    uint8_t *d = (uint8_t*)dst;
    for (int i = 0; i < len; i++)
    {
        asm volatile ("sb %0,0(%1)"::"r"(val),"r"(d));
        d++;
    }    
#elif MTDMA_MEMCPY_MEMSET
    uint8_t *d = (uint8_t*)dst;
    for (int i = 0; i < len; i += 65535)
    {
        int n = len - i;
        if (n > 65535) n = 65535;
        mtdma_memset(d, val, n, MTDMA_BLOCKING);
        d += n;
    }
#endif
    return dst;
}
void *__wrap_memcpy(void *dst, void *src, size_t len)
{    
#if LOG_MEMCPY_MEMSET
    memcpy_mmeset_log(dst, src, len);
    uint8_t t;
    uint8_t *d = (uint8_t*)dst;
    uint8_t *s = (uint8_t*)src;    
    for (int i = 0; i < len; i++)
    {
        asm volatile ("lb %0,0(%1)":"=r"(t):"r"(s));
        s++;
        asm volatile ("sb %0,0(%1)"::"r"(t),"r"(d));
        d++;
    }    
#elif MTDMA_MEMCPY_MEMSET
    uint8_t *d = (uint8_t*)dst;
    uint8_t *s = (uint8_t*)src;
    for (int i = 0; i < len; i += 65535)
    {
        int n = len - i;
        if (n > 65535) n = 65535;
        mtdma_memcpy(d, s, n, MTDMA_BLOCKING);
        d += n;
        s += n;
        
    }
#endif
    return dst;
}

//-------------------------- malloc_lock() & malloc_unlock() -------------------------------
void __wrap___malloc_lock(struct _reent *r)
{
#if SUPPORT_MULTI_THREAD
    #if _rvTranslate
        recursive_mutex_lock(&malloc_mutex);
    #else    
        pthread_mutex_lock(&malloc_mutex);
    #endif
#endif
}
void __wrap___malloc_unlock(struct _reent *r)
{
#if SUPPORT_MULTI_THREAD
    #if _rvTranslate
        recursive_mutex_unlock(&malloc_mutex);
    #else
        pthread_mutex_unlock(&malloc_mutex);
    #endif
#endif
}

//-------------------------- gettimeofday -------------------------------
int __wrap_gettimeofday(struct timeval *tv, struct timezone *tz)
{
    if (tv != NULL)
    {
        struct timeval t;
        uint64_t us = (cycle64() * SYSTEM_PERIOD) / 1000;
        t.tv_sec = us / 1000000;
        t.tv_usec = us % 1000000;
        *tv = t;
    }        
    return 0;
}

//-------------------------- printf() -------------------------------
int __wrap_printf(const char *format, ...)
{
    PAUSE_PROFILE();
    va_list args;
    va_start(args,format);
#if SUPPORT_MULTI_THREAD
    pthread_mutex_lock(&print_mutex);
#endif
    int result = vprintf(format, args);
#if SUPPORT_MULTI_THREAD    
    pthread_mutex_unlock(&print_mutex);
#endif
    va_end(args);
    RESUME_PROFILE();
    return result;
}

//-------------------------- access() -------------------------------
int __wrap_access(const char *path, int amode)
{
    // Force to return success
    __wrap_printf("%s: Force to return OK (path:%s)\n", __func__, path);
    return 0;
}

//-------------------------- fopen(), fclose(), fread(), fwrite(), ... -------------------------------
#if NETFILE

struct netfile_preload_info{
    uint8_t *fcontent;
    long int read_idx;
    long int fsize;
    int eof;

    netfile_preload_info(){
        fcontent = NULL;
        read_idx = 0;
        fsize = 0;
        eof = 0;
    }
};

static constexpr int PRELOAD_FILE_NUM = 10;
static struct netfile_preload_info finfo[PRELOAD_FILE_NUM];

static inline struct netfile_preload_info *get_preload_finfo(FILE *pfile) {
    int idx = (int)pfile - 1000;
    if (idx >= PRELOAD_FILE_NUM){
        printf("NETFILE PRELOAD: file_idx is out of range\n");
        exit(-1);
    }
    return &finfo[idx];
}

// category: fopen, fwrite, fputs, fwrite related functions  (FILE*)
FILE * __wrap_fopen(const char *filename, const char *mode)
{
    PAUSE_PROFILE();

#if NETFILE_PRELOAD
    printf("NETILE_PRELOAD %s\n", __FUNCTION__);

    FILE *pfile = nf_fopen(filename, mode);
    if (pfile == NULL){
        printf("NETFILE PRELOAD: fopen failed\n");
        return NULL;
    }

    struct netfile_preload_info *preload_info = get_preload_finfo(pfile);

    if (strchr(mode, 'r') != NULL) {
        nf_fseek(pfile, 0, SEEK_END);
        long int fsize = nf_ftell(pfile);
        
        preload_info->read_idx = 0;
        preload_info->eof = 0;
        preload_info->fsize = fsize;
        preload_info->read_idx = 0;

        dbg_printf("NETFILE PRELOAD: %s size: %ld\n", filename, fsize);

        if (preload_info->fcontent != NULL) {
            free(preload_info->fcontent);
        }
        preload_info->fcontent = (uint8_t*)malloc(fsize);
        nf_fseek(pfile, 0, SEEK_SET);

        size_t readnum = nf_fread(preload_info->fcontent, 1, fsize, pfile);
        if (readnum != fsize){
            printf("NETFILE PRELOAD: %s read failed\n", filename);
            return NULL;
        }

        nf_fseek(pfile, 0, SEEK_SET);
    }
    FILE *ret = pfile;
    return ret;

#else
    FILE * ret = nf_fopen(filename, mode);
#endif
    
    RESUME_PROFILE();
    return ret;
}

int __wrap_fopen_s(FILE** pFile, const char *filename, const char *mode)
{
    PAUSE_PROFILE();

#if NETFILE_PRELOAD
    printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    struct netfile_preload_info *preload_info = NULL;
    *pFile = nf_fopen(filename, mode);
    if (*pFile == NULL){
        printf("NETFILE PRELOAD: fopen_s failed\n");
        goto RET;
    }

    preload_info = get_preload_finfo(*pFile);

    if (strchr(mode, 'r') != NULL) {
        nf_fseek(*pFile, 0, SEEK_END);
        long int fsize = ftell(*pFile);

        preload_info->fsize = fsize;

        dbg_printf("NETFILE PRELOAD: %s size: %ld\n", filename, fsize);

        if (preload_info->fcontent != NULL) {
            preload_info->fcontent = (uint8_t*)malloc(fsize);
        }

        nf_fseek(*pFile, 0, SEEK_SET);

        size_t readnum = nf_fread(preload_info->fcontent, 1, fsize, *pFile);
        if (readnum != fsize){
            printf("NETFILE PRELOAD: %s read failed\n", filename);
            nf_fclose(*pFile);
            goto RET;
        }

        nf_fseek(*pFile, 0, SEEK_SET);
    }
RET:

#else
    *pFile = nf_fopen(filename, mode);
#endif
    if (!(*pFile)) {
        RESUME_PROFILE();
        return -1;
    }
    RESUME_PROFILE();
    return 0;		//return 0 means success
}
int __wrap_fclose(FILE *stream)
{
    PAUSE_PROFILE();

#if NETFILE_PRELOAD
    dbg_printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    
    struct netfile_preload_info *preload_info = get_preload_finfo(stream);

    if (preload_info->fcontent) {
        free(preload_info->fcontent);
        preload_info->fcontent = NULL;
    }
#endif

    int ret = nf_fclose(stream);
    RESUME_PROFILE();
    return ret;
}
int __wrap_feof(FILE *stream)
{
    PAUSE_PROFILE();

#if NETFILE_PRELOAD
    dbg_printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    
    struct netfile_preload_info *preload_info = get_preload_finfo(stream);

    int ret = preload_info->eof;
#else
    int ret = nf_feof(stream);
#endif
    RESUME_PROFILE();
    return ret;
}
int __wrap_fflush(FILE *stream)
{
    PAUSE_PROFILE();
    int ret = nf_fflush(stream);
    RESUME_PROFILE();
    return ret;
}
int __wrap_fseek(FILE *stream, long int offset, int whence)
{
    PAUSE_PROFILE();
#if NETFILE_PRELOAD
    dbg_printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    
    struct netfile_preload_info *preload_info = get_preload_finfo(stream);

    if (whence == SEEK_SET) {
        preload_info->read_idx =  (offset <= 0) ? 0 : offset;
    } else if (whence == SEEK_CUR) {
        preload_info->read_idx += offset;
    } else if (whence == SEEK_END) {
        preload_info->read_idx = (offset >= 0) ? (preload_info->fsize-1) : (preload_info->fsize + offset);
    }
    int ret = 0;
    
#else
    int ret = nf_fseek(stream, offset, whence);
#endif
    RESUME_PROFILE();
    return ret;
}
long int __wrap_ftell(FILE *stream)
{
    PAUSE_PROFILE();

#if NETFILE_PRELOAD
    dbg_printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    
    struct netfile_preload_info *preload_info = get_preload_finfo(stream);
    long int ret = preload_info->read_idx;
#else
    long int ret = nf_ftell(stream);
#endif

    RESUME_PROFILE();
    return ret;
}
char * __wrap_fgets(char *str, int n, FILE *stream)
{
    PAUSE_PROFILE();
    char * ret = nf_fgets(str, n, stream);
    RESUME_PROFILE();
    return ret;
}
int __wrap_fputs(const char *str, FILE *stream)
{
    PAUSE_PROFILE();
    if(stream == stdout || stream == stderr) {
        __wrap_printf("%s", str);
        RESUME_PROFILE();
        return 0;
    }
    else {
        int ret = nf_fputs(str, stream);
        RESUME_PROFILE();
        return ret;
    }
}
size_t __wrap_fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    PAUSE_PROFILE();
#if NETFILE_PRELOAD
    dbg_printf("NETILE_PRELOAD %s\n", __FUNCTION__);
    
    struct netfile_preload_info *preload_info = get_preload_finfo(stream);

    long int read_idx = preload_info->read_idx;

    long int end_range = read_idx + size * nmemb;
    long int read_size = size * nmemb;
    if (end_range > preload_info->fsize){
        read_size = preload_info->fsize - read_idx;
        preload_info->eof = 1;
        dbg_printf("preload wrap_fread:set_eof\n");
    }

    memcpy(ptr, &preload_info->fcontent[read_idx], read_size);
    preload_info->read_idx += read_size;
    size_t ret = read_size / size;
    dbg_printf("wrap_fread: size:%d, nmemb:%d, ret:%d\n", size, nmemb, ret);
#else
    size_t ret = nf_fread(ptr, size, nmemb, stream);
#endif
    RESUME_PROFILE();
    return ret;
}
size_t __wrap_fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    PAUSE_PROFILE();
    if(stream == stdout || stream == stderr) {
        size_t totalcount = size*nmemb;
        while(totalcount--){
            __wrap_printf("%c", *((char*)ptr));
            ptr = (char*)ptr + 1;
        }
        RESUME_PROFILE();
        return size * nmemb;
    } else {
        size_t ret = nf_fwrite(ptr, size, nmemb, stream);
        RESUME_PROFILE();
        return ret;
    }
}
int __wrap_fscanf(FILE *stream, const char *format, ...)
{       
    PAUSE_PROFILE();    
    va_list args;
    va_start(args,format);
    int result = nf_fscanf(stream, format, args);
    va_end(args);    
    RESUME_PROFILE();
    return result;
    
}
int __wrap_fprintf(FILE *stream, const char *format, ...)
{
    PAUSE_PROFILE();
    int result;
    va_list args;
    va_start(args,format);
    if(stream == stdout || stream == stderr)
    {
#if SUPPORT_MULTI_THREAD
        pthread_mutex_lock(&print_mutex);
#endif
        result = vprintf(format, args);
#if SUPPORT_MULTI_THREAD
        pthread_mutex_unlock(&print_mutex);
#endif
    }
    else
    {
        result = nf_vfprintf(stream, format, args);
    }
    va_end(args);    
    RESUME_PROFILE();
    return result;
}
int __wrap_fseeko(FILE *stream, off_t offset, int whence)
{
    PAUSE_PROFILE();
    int ret = nf_fseeko(stream, offset, whence);
    RESUME_PROFILE();
    return ret;
}
int __wrap_ferror(FILE *stream)
{
    PAUSE_PROFILE();
    int ret = nf_ferror(stream);
    RESUME_PROFILE();
    return ret;
}

// category: file related function without FILE*, e.g. rename, unlink, stat
int __wrap_rename(const char *old_filename, const char *new_filename)
{
    PAUSE_PROFILE();
    int ret = nf_rename(old_filename, new_filename);
    RESUME_PROFILE();
    return ret;
}
int __wrap_unlink(const char *pathname)
{
    PAUSE_PROFILE();
    int ret = nf_unlink(pathname);
    RESUME_PROFILE();
    return ret;
}
int __wrap_stat(const char */*restrict*/ pathname, struct stat */*restrict*/ statbuf)
{
    PAUSE_PROFILE();
    int ret = nf_stat(pathname, statbuf);
    RESUME_PROFILE();
    return ret;
}

// cateogry: file related function use int as fd, e.g. open, close, read, write
int __wrap_open(const char * pathname, int flags, mode_t mode)
{
    PAUSE_PROFILE();
    printf("%s, file:%s, flags:0x%x, mode:0x%x\n", __func__, pathname, flags, mode);

    char m[5];
    char *pm = m;

    if(flags & O_RDWR) {
        *pm++ = 'r';
        *pm++ = 'w';
    } else if(flags & O_WRONLY){
        *pm++ = 'w';
    } else {
        *pm++ = 'r';    //O_RDONLY = 0x0000
    } 

    if(flags & O_APPEND) {
        *pm++ = 'a';
    }

    //open as binary mode
    *pm++ = 'b';

    if(flags & O_APPEND){
        *pm++ = '+';
    }

    *pm = '\0';

    int ret = (int)__wrap_fopen(pathname, m);
    RESUME_PROFILE();
    return ret;
}
FILE * __wrap_fdopen(int fildes, const char *mode)
{
    PAUSE_PROFILE();
    printf("%s, fildes:%d, mode:%s\n", __func__, fildes, mode);
    FILE * ret = (FILE*)fildes;
    RESUME_PROFILE();
    return ret;
}
int __wrap_close(int fd)
{
    //PAUSE_PROFILE();
    printf("%s\n", __func__);
    int ret = __wrap_fclose((FILE*)fd);
    //RESUME_PROFILE();
    return ret;
}
int __wrap_fcntl(int fd, int cmd, ... /* arg */ )
{
    PAUSE_PROFILE();
    printf("%s, cmd:%d\n", __func__, cmd);
    RESUME_PROFILE();
    return fd;
}
ssize_t __wrap_read(int fd, void *buf, size_t count)
{
    //PAUSE_PROFILE();
    printf("%s, fd:%d, count:%d\n", __func__, fd, count);
    ssize_t ret = __wrap_fread(buf, 1, count, (FILE*)fd);
    //RESUME_PROFILE();
    return ret;
}
ssize_t __wrap_write(int fd, const void *buf, size_t count)
{
    //PAUSE_PROFILE();
    printf("%s, fd:%d, count:%d\n", __func__, fd, count);
    ssize_t ret = __wrap_fwrite(buf, 1, count, (FILE*)fd);
    //RESUME_PROFILE();
    return ret;
}
off_t __wrap_lseek(int fd, off_t offset, int whence)
{
    //PAUSE_PROFILE();
    printf("%s, fd:%d, off_t:%d whence:%d\n", __func__, fd, offset, whence);
    off_t ret = __wrap_fseek((FILE*)fd, offset, whence);
    //RESUME_PROFILE();
    return ret;
}
int __wrap_fstat(int fildes, struct stat *buf)
{
    PAUSE_PROFILE();
    printf("%s\n", __func__);

#if 0
    int res = nf_fstat(fildes, buf);
    printf("fstat: st_size:%d\n", buf->st_size);
    printf("       st_blksize:%d\n", buf->st_blksize);
    printf("       st_blocks:%d\n", buf->st_blocks);
    printf("       st_mode:0x%x\n", buf->st_mode);
    RESUME_PROFILE();
    return res;

#elif 0
    printf("fstat return dummy value\n");
    buf->st_size = 1225924;
    buf->st_blksize = 4096;
    buf->st_blocks = 2400;
    buf->st_mode = 0x81B6;  //100666
    RESUME_PROFILE();
    return 0;
#else
    RESUME_PROFILE();
    return -1;  //not support fstat, then openHEVC will choose to use fseek function.
#endif
}
#endif


#if NETFILE
static FILE *fargv;

void nf_argv_open(const char *filepath) {
    fargv = fopen(filepath, "rt");
    if (fargv == NULL) {
        printf("Cannot open %s\n", filepath);
        exit(1);
    }
}

void nf_argv_close() {
    if (fargv != NULL) {
        fclose(fargv);
    }
}

bool nf_argv_load(int *argc_ptr, char ***argv_ptr) {
    static int line_idx = 0;
    static int argc = 0;
    static char* argv_from_file[MAX_ARGC];

    if (argc_ptr != NULL && argv_ptr != NULL)
    {
        static char buf[1024];
        char* sbuf = buf;

        do {
            if (fgets(buf, sizeof(buf) - 1, fargv) == NULL) {
                if (line_idx == 0) {
                    printf("Cannot read the line from argv. line_num:%d\n", line_idx+1);
                } else {
                    printf("Load from argv file: EOF detected\n");
                }
                return false;
            }
            ++line_idx;
        } while (buf[0] == '#' || buf[0] == '\r' || buf[0] == '\n');

        buf[sizeof(buf) - 1] = '\0';
        buf[strcspn(buf, "\r\n")] = '\0';       // remove \r\n or \n

        printf("buf:%s\n", buf);

        argv_from_file[0] = sbuf;
        argc = 1;
        while (*sbuf != '\0') {
            sbuf = strchr(sbuf, ' ');
            if (sbuf) {
                *sbuf = '\0';
                argv_from_file[argc] = sbuf + 1;
                argc++;
                sbuf++;

                if (argc >= MAX_ARGC)
                {
                    printf("Argument number is too larger. Maximum is %d\n", MAX_ARGC);
                    exit(1);
                }
            }
            else {
                break;
            }
        }

        printf("parsed argc:%d\n", argc);

        for (int i = 0; i < argc; i++) {
            printf("- argv[%d]:%s\n", i, argv_from_file[i]);
        }

        *argc_ptr = argc;
        *argv_ptr = argv_from_file;
    }
    return true;
}
#endif


//-------------------------- riscv initialization -------------------------------
void riscv_init()
{
#if SUPPORT_MULTI_THREAD
    //Print mutex
    pthread_mutex_init(&print_mutex, NULL);
    
    //Malloc mutex
    #ifndef _rvTranslate 
        pthread_mutex_init(&malloc_mutex, NULL);
    #endif
#endif

    //Set new_handler() for new operator
#if defined(__cplusplus)
    riscv_set_new_handler();
#endif

#if ASIM_CALL
    asim_set_hls_handler(asim_hls_handler);
#endif

#if NETFILE
    //Netfile initialization
    nf_init();
#endif

    //Call functions in .init_array
    printf("__init_array_start=%x\n", (int)__init_array_start);
    printf("__init_array_end=%x\n", (int)__init_array_end);
    for (int i = 0; i < ((int)__init_array_end - (int)__init_array_start) / 4; i++)
    {
        //printf(".init_array call:%x\n", (int)__init_array_start[i]);
        __init_array_start[i]();
    }


    //Print RISCV version
    volatile int * hw_ver = (int*)(HW_VERSION);
    printf("------------------------------------------------------------------------------\n");
    printf("SW Build Time: %s %s\n", __DATE__, __TIME__);
#ifdef BULLET_RISCV
    if (marchid() >= 1) {
        printf("System Build Version: %d.%d.%d\n", hw_ver[VER_MAJOR], hw_ver[VER_MINOR], hw_ver[VER_PATCH]);
        printf("System Build Date (yy-mm-dd): %d-%d-%d\n", hw_ver[VER_YY], hw_ver[VER_MM], hw_ver[VER_DD]);
    }
    printf("RISCV Vendor ID: 0x%x\n", mvendorid());
	printf("RISCV Architecture ID: 0x%x (0:C-simulator 1:RTL-implemenation 2:RTL-simulation\n", marchid());
	printf("RISCV Implemenation ID (Version): 0x%x (v.%d.%d)\n", mimpid(), mimpid() >> 16, mimpid() & 0xffff);
    printf("RISCV Cores: %d\n", get_core_num());

    if (marchid() >= 1) {
        //edward 2024-12-05: new hardware configuration paremeters.
        int icache_size = hw_ver[VER_ICACHE_WAY_NUM] * hw_ver[VER_ICACHE_SET_NUM] * 32;
        int dcache_size = hw_ver[VER_DCACHE_WAY_NUM] * hw_ver[VER_DCACHE_SET_NUM] * 32;
        int lcache_size = hw_ver[VER_HLS_LOCAL_CACHE_WAY] * hw_ver[VER_HLS_LOCAL_CACHE_SET] * 32;
        printf("RISCV Parameters:\n");
        printf("   Cores      : %d\n", hw_ver[VER_CORE_NUM]);
        printf("   Frequency  : %d\n", hw_ver[VER_RISCV_FREQUENCY]);
        printf("   ICache     : Size=%dKB Way=%d Set=%d\n", icache_size, hw_ver[VER_ICACHE_WAY_NUM], hw_ver[VER_ICACHE_SET_NUM]);
        printf("   DCache     : Size=%dKB Way=%d Set=%d\n", dcache_size, hw_ver[VER_DCACHE_WAY_NUM], hw_ver[VER_DCACHE_SET_NUM]);
        printf("   MicroThread: %d\n", hw_ver[VER_ENABLE_MICRO_THREAD]);
        printf("   MTDMA      : %d\n", hw_ver[VER_ENABLE_MTDMA]);
        printf("   Profile    : %d\n", hw_ver[VER_ENABLE_PROFILE]);
        printf("L2 Cache Parameters:\n");
        printf("   Enable     : %d\n", hw_ver[VER_ENABLE_L2CACHE]);
        printf("   Size       : %dKB\n", hw_ver[VER_L2CACHE_SIZE]);
        printf("   Way        : %d\n", hw_ver[VER_L2CACHE_WAY]);
        printf("   Len        : %d\n", hw_ver[VER_L2CACHE_LEN]);
        printf("HLS (Dataflow) Parameters:\n");
        printf("   Enable     : %d\n", hw_ver[VER_ENABLE_HLS]);
        printf("   Dataflow   : %d\n", hw_ver[VER_ENABLE_DATAFLOW]);
        printf("   Encoder    : %d\n", hw_ver[VER_ENABLE_ENCODER]);
        printf("   Decoder    : %d\n", hw_ver[VER_ENABLE_DECODER]);
        printf("   CABAC      : %d\n", hw_ver[VER_DATAFLOW_CABAC_NUM]);
        printf("   OUTPIX     : %d\n", hw_ver[VER_DATAFLOW_OUTPIX_NUM]);
        printf("HLS (Longtail) Parameters:\n");
        printf("   Local cache: %d (%dKB)\n", hw_ver[VER_ENALBE_HLS_LOCAL_CACHE], lcache_size);
        printf("   Profile    : %d\n",        hw_ver[VER_ENABLE_HLS_PROFILE]);        

        //edward 2024-12-05: Checking if software configuration matches hardware configuration
        #if SUPPORT_MULTI_THREAD
        if (hw_ver[VER_ENABLE_MICRO_THREAD] == 0) {
            printf("ERROR: Hardware does not support MULTI_THREAD!\n");
            exit(1);
        }
        #endif
        #if (HW_PROFILE || APCALL_PROFILE)
        if (hw_ver[VER_ENABLE_PROFILE] == 0) {
            printf("ERROR: Hardware does not support HW_PROFILE & APCALL_PROFILE!\n");
            exit(1);
        }
        #endif
        #if (HLS_MTDMA || MTDMA_MEMCPY_MEMSET)
        if (hw_ver[VER_ENABLE_MTDMA] == 0) {
            printf("ERROR: Hardware does not support HLS_MTDMA & MTDMA_MEMCPY_MEMSET!\n");
            exit(1);
        }
        #endif
        #if HLS_HLS_XMEM
        if (hw_ver[VER_ENABLE_HLS] == 0) {
            printf("ERROR: Hardware does not support HLS_HLS_XMEM!\n");
            exit(1);
        }
        #endif
        #if HLS_CMDR
        if (hw_ver[VER_ENABLE_DATAFLOW] == 0) {
            printf("ERROR: Hardware does not support HLS_CMDR!\n");
            exit(1);
        }
        #endif
    }
#endif
    printf("------------------------------------------------------------------------------\n");
    
#if (HLS_CMDR && defined(BULLET_RISCV))
    //HLS initialization
    hls_init();
#endif
}
void riscv_exit()
{
#if NETFILE
    //Netfile exit
    nf_exit();
#endif
}
void riscv_writeback_dcache_all()
{
#if BULLET_RISCV
    volatile int * hw_ver = (int*)(HW_VERSION);
    const int way_num = hw_ver[VER_DCACHE_WAY_NUM];
    const int set_num = hw_ver[VER_DCACHE_SET_NUM];
    const int line_bytes = 32;        
    volatile uint8_t *src = 0;    
    int tmp = 0;
    //Read a dummy memory to writeback data in dcache
    for (int i = 0; i < way_num * set_num * line_bytes; i += line_bytes)
    {
        //edward 2024-07-10: use assemby
        uint8_t *ptr = (uint8_t*)&src[i];
        asm volatile("lb %0,0(%1)" : "=r"(tmp) : "r"(ptr));
    }
#endif
}
void riscv_writeback_dcache(uint8_t *adr)
{
#if BULLET_RISCV
    const int line_bytes = 32; 
    asm volatile ("lw zero,0(%0)"::"r"(adr));
    asm volatile ("lw zero,0(%0)"::"r"(adr + line_bytes));
    //edward 2024-12-05: flush L2 cache
    volatile int * hw_ver = (int*)(HW_VERSION);
    volatile int * l2c = (int*)L2CACHE_CTRL;
    if (hw_ver[VER_ENABLE_L2CACHE]) {
        l2c[0] = (int)adr;
    }    
#elif !_rvTranslate
    volatile int * hw_ver = (int*)(HW_VERSION);
    const int way_num = hw_ver[VER_DCACHE_WAY_NUM];
    const int set_num = hw_ver[VER_DCACHE_SET_NUM];
    const int line_bytes = 32; 
    volatile uint8_t *src = 0;
    int tmp = 0;        
    int adr_i = (uint32_t)adr & (set_num * line_bytes - 1);
    //Read a same set to writeback data in dcache
    for (int i = 0; i < way_num; i++)
    {
        //edward 2024-07-10: use assemby
        volatile uint8_t *ptr = &src[adr_i + i * set_num * line_bytes];
        asm volatile("lb %0,0(%1)" : "=r"(tmp) : "r"(ptr));
    }
#endif
}
//Flush cache lines
void riscv_writeback_dcache_lines(const uint8_t *buf, int len)
{
    const int sets = 512;
    const int byte_per_line = 32;
#if BULLET_RISCV
    //edward 2024-10-22: Since copyEngine is used, there is no MTDMA for riscv core.
    #if HLS_MTDMA
    wait_mtdma_done(0);
    #endif
    //edward 2024-07-10: use hardware flush command for any length
    for (int i = 0; i < len + byte_per_line; i += byte_per_line) {
        const uint8_t * addr = buf + i;
        asm volatile ("lw zero,0(%0)"::"r"(addr));
    }
    //edward 2024-12-05: flush L2 cache
    volatile int * hw_ver = (int*)(HW_VERSION);
    volatile int * l2c = (int*)L2CACHE_CTRL;
    if (hw_ver[VER_ENABLE_L2CACHE]) {    
        int l2_byte_per_line = hw_ver[VER_L2CACHE_LEN];
        for (int i = 0; i < len + l2_byte_per_line; i += l2_byte_per_line) {
            l2c[0] = (int)buf + i;
        }
    }
#elif !_rvTranslate
    //Assume 2 ways cache    
    const uint8_t * ptr0 = buf + (1 * 1024 * 1024);
    const uint8_t * ptr1 = buf + (2 * 1024 * 1024);
    int tmp = 0;    
    if (len > (sets * byte_per_line))
        len = sets * byte_per_line;
    for (int i = 0; i < (len + byte_per_line); i += byte_per_line)
    {            
        asm volatile("lb %0,0(%1)" : "=r"(tmp) : "r"(ptr0));
        asm volatile("lb %0,0(%1)" : "=r"(tmp) : "r"(ptr1));
        ptr0 += byte_per_line;
        ptr1 += byte_per_line;
    }
#endif
}

#if FUNCLOG
#define PROF_CORE_NUM   5
#define PROF_ADDR_START (0x10000)
#define PROF_ADDR_SIZE  (0x250000/4)
struct prof_info{
    uint64_t cycle_acc;
    uint64_t call_cnt;
    uint32_t start_cycle;
};

static struct prof_info *prof[PROF_CORE_NUM];
static bool funclog_profile_enable = false;

void funclog_profile_init(){
    for(int i=0; i<PROF_CORE_NUM; i++){
        prof[i] = (struct prof_info*)malloc(sizeof(struct prof_info)*PROF_ADDR_SIZE);
        if (prof[i] == NULL){
            printf("malloc funclog profile failed\n");
            exit(-1);
        }
        memset(prof[i], 0, sizeof(struct prof_info)*PROF_ADDR_SIZE);
    }
    
    printf("Enable FUNCLOG. PROF_CORE_NUM: %d, PROF_ADDR_START 0x%x, PROF_ADDR_SIZE 0x%x\n", PROF_CORE_NUM, PROF_ADDR_START, PROF_ADDR_SIZE);
    funclog_profile_enable = false;
}

void __cyg_profile_func_enter(void *this_fn, void *call_site) {
    if(funclog_profile_enable) {
        int hart_id = mhartid();
        unsigned int cycle_cnt = getCycleCount();
        uintptr_t prof_idx = ((uintptr_t)this_fn - PROF_ADDR_START) >> 2;
        if (prof_idx >= PROF_ADDR_SIZE){
            printf("prof addr out of range %p\n", this_fn);
            exit(-1);
        }
        if (hart_id >= PROF_CORE_NUM){
            printf("prof hartid out of range\n");
            exit(-1);
        }
        prof[hart_id][prof_idx].start_cycle = cycle_cnt;
        ++prof[hart_id][prof_idx].call_cnt;
    }
    //if (hart_id != 0) {
    //    printf("%d]c,%p,%p\n", hart_id, this_fn, call_site);
    //}
}

void __cyg_profile_func_exit(void *this_fn, void *call_site) {
    if (funclog_profile_enable) {
        int hart_id = mhartid();
        unsigned int cycle_cnt = getCycleCount();
        uintptr_t prof_idx = ((uintptr_t)this_fn - PROF_ADDR_START) >> 2;
        if (prof_idx >= PROF_ADDR_SIZE){
            printf("prof addr out of range %p\n", this_fn);
            exit(-1);
        }
        if (hart_id >= PROF_CORE_NUM){
            printf("prof hartid out of range\n");
            exit(-1);
        }
        unsigned int elapsed_cycle;
        if (cycle_cnt > prof[hart_id][prof_idx].start_cycle){
            elapsed_cycle = cycle_cnt - prof[hart_id][prof_idx].start_cycle;
        }else {
            elapsed_cycle = 0xffffffff - cycle_cnt + prof[hart_id][prof_idx].start_cycle;
            printf("FUNCLOG: elapsed cycle overflow\n");
        }
        prof[hart_id][prof_idx].cycle_acc += elapsed_cycle;
    }
}

void funclog_profile_start(){
    printf("FUNCLOG profile start\n");
    funclog_profile_enable = true;
}

void funclog_profile_stop(){
    printf("FUNCLOG profile stop\n");
    funclog_profile_enable = false;
}

void funclog_profile_report(){
    printf("FUNCLOG generate profile report\n");

    funclog_profile_enable = false;
    FILE *pfile;
    pfile = fopen("funclog.csv", "wb");
    bool log = false;
    char str[1024];
    fprintf(pfile, "func_pc,");
    for(int cur_core=0; cur_core<PROF_CORE_NUM; cur_core++){
        if (cur_core == PROF_CORE_NUM-1){
            fprintf(pfile, "call_count[%d], cyc_count[%d]\n", cur_core, cur_core);
        } else {
            fprintf(pfile, "call_count[%d], cyc_count[%d],", cur_core, cur_core);
        }
    }
    for(int loc=0; loc<PROF_ADDR_SIZE; loc++){
        log = false;
        for(int cur_core=0; cur_core<PROF_CORE_NUM; cur_core++){
            if (prof[cur_core][loc].call_cnt != 0 ){
                log = true;
            }
        }
        if (log){
            uint32_t func_pc = (loc << 2) + PROF_ADDR_START;
            //sprintf and fprintf cannot handle 64bit value!
            //split them into two 32-bit hex and export to csv
            fprintf(pfile, "%08x,", func_pc);
            for(int cur_core=0; cur_core<PROF_CORE_NUM; cur_core++){
                uint32_t call_cnt_h = (prof[cur_core][loc].call_cnt >> 32) & 0xFFFFFFFF;
                uint32_t call_cnt_l = (prof[cur_core][loc].call_cnt & 0xFFFFFFFF);
                uint32_t cyc_cnt_h = (prof[cur_core][loc].cycle_acc >> 32) & 0xFFFFFFFF;
                uint32_t cyc_cnt_l = (prof[cur_core][loc].cycle_acc & 0xFFFFFFFF);
                if (cur_core == PROF_CORE_NUM - 1) {
                    fprintf(pfile, "%08x%08x,%08x%08x\n", call_cnt_h, call_cnt_l, cyc_cnt_h, cyc_cnt_l);
                } else {
                    fprintf(pfile, "%08x%08x,%08x%08x,", call_cnt_h, call_cnt_l, cyc_cnt_h, cyc_cnt_l);
                }
            }
        }
    }
    fclose(pfile);
}

#endif

#ifdef __cplusplus
}
#endif
