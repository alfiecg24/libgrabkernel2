#ifndef utils_h
#define utils_h

#include <stdio.h>

#define LIBGRABKERNEL2_USE_LOG_PREFIX 1

#if LIBGRABKERNEL2_USE_LOG_PREFIX
#define LOG_PREFIX "libgrabkernel2: "
#else
#define LOG_PREFIX ""
#endif

#define LOG(fmt, ...) printf(LOG_PREFIX fmt, ##__VA_ARGS__)

#define ERRLOG(fmt, ...) LOG("ERROR: " fmt, ##__VA_ARGS__)

#ifdef DEBUG
#define DBGLOG(fmt, ...) LOG("DEBUG: " fmt, ##__VA_ARGS__)
#else
#define DBGLOG(fmt, ...)
#endif

#endif /* utils_h */
