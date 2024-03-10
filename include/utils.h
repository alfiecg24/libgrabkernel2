#ifndef utils_h
#define utils_h

#include <stdio.h>

#define LIBGRABKERNEL2_USE_LOG_PREFIX 1

#if LIBGRABKERNEL2_USE_LOG_PREFIX
#define LOG_PREFIX "libgrabkernel2: "
#else
#define LOG_PREFIX ""
#endif

#define log(fmt, ...) printf(LOG_PREFIX fmt, ##__VA_ARGS__)

#define error(fmt, ...) log("ERROR: " fmt, ##__VA_ARGS__)

#ifdef DEBUG
#define debug(fmt, ...) log("DEBUG: " fmt, ##__VA_ARGS__)
#else
#define debug(fmt, ...)
#endif

#endif /* utils_h */
