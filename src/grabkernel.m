//
//  grabkernel.c
//  libgrabkernel2
//
//  Created by Alfie on 14/02/2024.
//

#include "grabkernel.h"
#include <Foundation/Foundation.h>
#include <partial/partial.h>
#include <string.h>
#include <sys/sysctl.h>
#include "appledb.h"
#include "utils.h"

static NSString *getBoardconfig(void) {
    char boardconfig[256];
    size_t size = sizeof(boardconfig);
    int result = sysctlbyname("hw.target", &boardconfig, &size, NULL, 0);
    if (result) {
        error("Failed to get boardconfig!\n");
        return nil;
    }

    return [NSString stringWithCString:boardconfig encoding:NSUTF8StringEncoding];
}

bool download_kernelcache(NSString *zipURL, bool isOTA, NSString *outPath) {
    NSError *error = nil;
    NSString *pathPrefix = isOTA ? @"AssetData/boot" : @"";
    NSString *boardconfig = getBoardconfig();

    Partial *zip = [Partial partialZipWithURL:[NSURL URLWithString:zipURL] error:&error];
    if (!zip) {
        error("Failed to open zip file! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    log("Downloading BuildManifest.plist...\n");

    NSData *buildManifestData = [zip getFileForPath:[pathPrefix stringByAppendingPathComponent:@"BuildManifest.plist"] error:&error];
    if (!buildManifestData) {
        error("Failed to download BuildManifest.plist! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    NSDictionary *buildManifest = [NSPropertyListSerialization propertyListWithData:buildManifestData options:0 format:NULL error:&error];
    if (error) {
        error("Failed to parse BuildManifest.plist! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    NSString *kernelCachePath = nil;

    for (NSDictionary<NSString *, id> *identity in buildManifest[@"BuildIdentities"]) {
        if ([identity[@"Info"][@"Variant"] hasPrefix:@"Research"]) {
            continue;
        }
        if ([identity[@"Info"][@"DeviceClass"] isEqualToString:boardconfig.lowercaseString]) {
            kernelCachePath = [pathPrefix stringByAppendingPathComponent:identity[@"Manifest"][@"KernelCache"][@"Info"][@"Path"]];
        }
    }

    if (!kernelCachePath) {
        error("Failed to find kernelcache path in BuildManifest.plist!\n");
        return false;
    }

    log("Downloading %s to %s...\n", kernelCachePath.UTF8String, outPath.UTF8String);

    NSData *kernelCacheData = [zip getFileForPath:kernelCachePath error:&error];
    if (!kernelCacheData) {
        error("Failed to download kernelcache! %s\n", error.localizedDescription.UTF8String);
        return false;
    } else {
        log("Downloaded kernelcache!\n");
    }

    if (![kernelCacheData writeToFile:outPath atomically:YES]) {
        error("Failed to write kernelcache to %s!\n", outPath.UTF8String);
        return false;
    }

    return true;
}

bool grab_kernelcache(const char *downloadPath) {
    // Check if downloadPath is NULL
    if (!downloadPath) {
        error("Invalid download path!\n");
        return false;
    }

    // Convert the downloadPath to an NSString
    NSString *outPath = [NSString stringWithUTF8String:downloadPath];

    // Validate the outPath string to ensure it is a valid file path
    NSCharacterSet *illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/:"];
    NSRange range = [outPath rangeOfCharacterFromSet:illegalFileNameCharacters];
    if (range.location != NSNotFound) {
        error("Invalid characters in download path!\n");
        return false;
    }

    // Proceed with downloading the kernel cache
    return download_kernelcache(outPath);
}

// libgrabkernel compatibility shim
// Note that research kernel grabbing is not currently supported
int grabkernel(char *downloadPath, int isResearchKernel __unused) {
    NSString *outPath = [NSString stringWithCString:downloadPath encoding:NSUTF8StringEncoding];
    return grab_kernelcache(outPath) ? 0 : -1;
}
