//
//  grabkernel.h
//  libgrabkernel2
//
//  Created by Alfie on 14/02/2024.
//

#ifndef grabkernel_h
#define grabkernel_h

#include <Foundation/Foundation.h>

bool download_kernelcache(NSString *zipURL, bool isOTA, NSString *outPath);
bool grab_kernelcache(NSString *outPath);

#endif /* grabkernel_h */
