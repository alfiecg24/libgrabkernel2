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
        ERRLOG("Failed to get boardconfig!\n");
        return nil;
    }

    return [NSString stringWithCString:boardconfig encoding:NSUTF8StringEncoding];
}

bool download_kernelcache(NSString *zipURL, bool isOTA, NSString *outPath) {
    NSError *error = nil;
    NSString *pathPrefix = isOTA ? @"AssetData/boot" : @"";
    NSString *boardconfig = getBoardconfig();

    if (!zipURL) {
        ERRLOG("Missing firmware URL!\n");
        return false;
    }

    if (!outPath) {
        ERRLOG("Missing output path!\n");
        return false;
    }

    if (![[NSFileManager defaultManager] isWritableFileAtPath:outPath.stringByDeletingLastPathComponent]) {
        ERRLOG("Output directory is not writable!\n");
        return false;
    }

    if (!boardconfig) {
        ERRLOG("Failed to get boardconfig!\n");
        return false;
    }

    Partial *zip = [Partial partialZipWithURL:[NSURL URLWithString:zipURL] error:&error];
    if (!zip) {
        ERRLOG("Failed to open zip file! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    LOG("Downloading BuildManifest.plist...\n");

    NSData *buildManifestData = [zip getFileForPath:[pathPrefix stringByAppendingPathComponent:@"BuildManifest.plist"] error:&error];
    if (!buildManifestData) {
        ERRLOG("Failed to download BuildManifest.plist! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    NSDictionary *buildManifest = [NSPropertyListSerialization propertyListWithData:buildManifestData options:0 format:NULL error:&error];
    if (error) {
        ERRLOG("Failed to parse BuildManifest.plist! %s\n", error.localizedDescription.UTF8String);
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
        ERRLOG("Failed to find kernelcache path in BuildManifest.plist!\n");
        return false;
    }

    LOG("Downloading %s to %s...\n", kernelCachePath.UTF8String, outPath.UTF8String);

    NSData *kernelCacheData = [zip getFileForPath:kernelCachePath error:&error];
    if (!kernelCacheData) {
        ERRLOG("Failed to download kernelcache! %s\n", error.localizedDescription.UTF8String);
        return false;
    } else {
        LOG("Downloaded kernelcache!\n");
    }

    if (![kernelCacheData writeToFile:outPath options:NSDataWritingAtomic error:&error]) {
        ERRLOG("Failed to write kernelcache to %s! %s\n", outPath.UTF8String, error.localizedDescription.UTF8String);
        return false;
    }

    return true;
}

bool grab_kernelcache(NSString *outPath) {
    bool isOTA = NO;
    NSString *firmwareURL = getFirmwareURL(&isOTA);
    if (!firmwareURL) {
        ERRLOG("Failed to get firmware URL!\n");
        return false;
    }

    return download_kernelcache(firmwareURL, isOTA, outPath);
}

// libgrabkernel compatibility shim
// Note that research kernel grabbing is not currently supported
int grabkernel(char *downloadPath, int isResearchKernel __unused) {
    NSString *outPath = [NSString stringWithCString:downloadPath encoding:NSUTF8StringEncoding];
    return grab_kernelcache(outPath) ? 0 : -1;
}