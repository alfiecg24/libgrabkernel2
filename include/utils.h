#ifndef utils_h
#define utils_h

#include <stdio.h>

#define log(fmt, ...) printf("libgrabkernel2: " fmt, ##__VA_ARGS__)

#define error(fmt, ...) log("ERROR: " fmt, ##__VA_ARGS__)

#ifdef DEBUG
#define debug(fmt, ...) log("DEBUG: " fmt, ##__VA_ARGS__)
#else
#define debug(fmt, ...)
#endif

#endif /* utils_h */
