//
//  grabkernel.h
//  libgrabkernel2
//
//  Created by Alfie on 14/02/2024.
//

#ifndef grabkernel_h
#define grabkernel_h

#include <Foundation/Foundation.h>

bool download_kernelcache_for(NSString *boardconfig, NSString *zipURL, bool isOTA, NSString *outPath);
bool grab_kernelcache_for(NSString *osStr, NSString *build, NSString *modelIdentifier, NSString *boardconfig, NSString *outPath);

// Uses details of the current device
bool download_kernelcache(NSString *zipURL, bool isOTA, NSString *outPath);
bool grab_kernelcache(NSString *outPath);

// Uses details of the current device, but allows you to override the build number
bool grab_kernelcache_for_build_number(NSString *build, NSString *outPath);

// libgrabkernel compatibility shim
// Note that research kernel grabbing is not currently supported
int grabkernel(char *downloadPath, int isResearchKernel);

#endif /* grabkernel_h */
