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

static bool ensureWritableDirectory(NSString *dir) {
    if (dir.length == 0) {
        dir = @".";
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        ERRLOG("Failed to create output directory %s! %s\n", dir.UTF8String, error.localizedDescription.UTF8String);
        return false;
    }
    if (![fm isWritableFileAtPath:dir]) {
        ERRLOG("Output directory %s is not writable!\n", dir.UTF8String);
        return false;
    }
    return true;
}

static bool fetchAndWrite(Partial *zip, NSString *name, NSString *zipPath, NSString *outPath) {
    NSError *error = nil;

    LOG("Downloading %s to %s...\n", zipPath.UTF8String, outPath.UTF8String);

    NSData *data = [zip getFileForPath:zipPath error:&error];
    if (!data) {
        ERRLOG("Failed to download %s! %s\n", name.UTF8String, error.localizedDescription.UTF8String);
        return false;
    }

    if (![data writeToFile:outPath options:NSDataWritingAtomic error:&error]) {
        ERRLOG("Failed to write %s to %s! %s\n", name.UTF8String, outPath.UTF8String, error.localizedDescription.UTF8String);
        return false;
    }

    LOG("Downloaded %s!\n", name.UTF8String);
    return true;
}

static bool downloadImages(NSString *boardconfig, NSString *zipURL, bool isOTA, NSString *kernelOutPath, NSString *extrasOutDir) {
    NSError *error = nil;
    NSString *pathPrefix = isOTA ? @"AssetData/boot" : @"";

    if (!boardconfig) {
        ERRLOG("Missing boardconfig!\n");
        return false;
    }

    if (!zipURL) {
        ERRLOG("Missing firmware URL!\n");
        return false;
    }

    if (!kernelOutPath) {
        ERRLOG("Missing output path!\n");
        return false;
    }

    if (!ensureWritableDirectory([kernelOutPath stringByDeletingLastPathComponent])) {
        return false;
    }

    if (extrasOutDir && !ensureWritableDirectory(extrasOutDir)) {
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
    if (!buildManifest) {
        ERRLOG("Failed to parse BuildManifest.plist! %s\n", error.localizedDescription.UTF8String);
        return false;
    }

    NSString *kernelCachePath = nil, *securePageTableMonitorPath = nil, *trustedExecutionMonitorPath = nil;

    for (NSDictionary<NSString *, id> *identity in buildManifest[@"BuildIdentities"]) {
        if ([identity[@"Info"][@"Variant"] hasPrefix:@"Research"]) {
            continue;
        }
        if ([identity[@"Info"][@"DeviceClass"] isEqualToString:boardconfig.lowercaseString]) {
            NSDictionary *manifest = identity[@"Manifest"];
            kernelCachePath = [pathPrefix stringByAppendingPathComponent:manifest[@"KernelCache"][@"Info"][@"Path"]];

            if (extrasOutDir) {
                if (manifest[@"Ap,SecurePageTableMonitor"]) {
                    securePageTableMonitorPath = [pathPrefix stringByAppendingPathComponent:manifest[@"Ap,SecurePageTableMonitor"][@"Info"][@"Path"]];
                }

                if (manifest[@"Ap,TrustedExecutionMonitor"]) {
                    trustedExecutionMonitorPath = [pathPrefix stringByAppendingPathComponent:manifest[@"Ap,TrustedExecutionMonitor"][@"Info"][@"Path"]];
                }
            }
            break;
        }
    }

    if (!kernelCachePath) {
        ERRLOG("Failed to find kernelcache path in BuildManifest.plist!\n");
        return false;
    }

    if (!fetchAndWrite(zip, @"kernelcache", kernelCachePath, kernelOutPath)) {
        return false;
    }

    if (securePageTableMonitorPath &&
        !fetchAndWrite(zip, @"SecurePageTableMonitor", securePageTableMonitorPath, [extrasOutDir stringByAppendingPathComponent:@"sptm.im4p"])) {
        return false;
    }

    if (trustedExecutionMonitorPath &&
        !fetchAndWrite(zip, @"TrustedExecutionMonitor", trustedExecutionMonitorPath, [extrasOutDir stringByAppendingPathComponent:@"txm.im4p"])) {
        return false;
    }

    return true;
}

bool download_kernelcache_for(NSString *boardconfig, NSString *zipURL, bool isOTA, NSString *outPath) {
    return downloadImages(boardconfig, zipURL, isOTA, outPath, nil);
}

bool download_images_for(NSString *boardconfig, NSString *zipURL, bool isOTA, NSString *outDir) {
    if (!outDir) {
        ERRLOG("Missing output directory!\n");
        return false;
    }
    return downloadImages(boardconfig, zipURL, isOTA, [outDir stringByAppendingPathComponent:@"kernelcache"], outDir);
}

bool download_kernelcache(NSString *zipURL, bool isOTA, NSString *outPath) {
    NSString *boardconfig = getBoardconfig();

    if (!boardconfig) {
        ERRLOG("Failed to get boardconfig!\n");
        return false;
    }

    return download_kernelcache_for(boardconfig, zipURL, isOTA, outPath);
}

bool download_images(NSString *zipURL, bool isOTA, NSString *outDir) {
    NSString *boardconfig = getBoardconfig();

    if (!boardconfig) {
        ERRLOG("Failed to get boardconfig!\n");
        return false;
    }

    return download_images_for(boardconfig, zipURL, isOTA, outDir);
}

// TODO: Only require one of model identifier/boardconfig and use API to get the other?
bool grab_kernelcache_for(NSString *osStr, NSString *build, NSString *modelIdentifier, NSString *boardconfig, NSString *outPath) {
    bool isOTA = NO;
    NSString *firmwareURL = getFirmwareURLFor(osStr, build, modelIdentifier, &isOTA);
    if (!firmwareURL) {
        ERRLOG("Failed to get firmware URL!\n");
        return false;
    }

    return download_kernelcache_for(boardconfig, firmwareURL, isOTA, outPath);
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

bool grab_kernelcache_for_build_number(NSString *build, NSString *outPath) {
    bool isOTA = NO;
    NSString *firmwareURL = getFirmwareURLFor(getOsStr(), build, getModelIdentifier(), &isOTA);
    if (!firmwareURL) {
        ERRLOG("Failed to get firmware URL for build number!\n");
        return false;
    }

    return download_kernelcache(firmwareURL, isOTA, outPath);
}

bool grab_images_for(NSString *osStr, NSString *build, NSString *modelIdentifier, NSString *boardconfig, NSString *outDir) {
    bool isOTA = NO;
    NSString *firmwareURL = getFirmwareURLFor(osStr, build, modelIdentifier, &isOTA);
    if (!firmwareURL) {
        ERRLOG("Failed to get firmware URL!\n");
        return false;
    }

    return download_images_for(boardconfig, firmwareURL, isOTA, outDir);
}

bool grab_images(NSString *outDir) {
    bool isOTA = NO;
    NSString *firmwareURL = getFirmwareURL(&isOTA);
    if (!firmwareURL) {
        ERRLOG("Failed to get firmware URL!\n");
        return false;
    }

    return download_images(firmwareURL, isOTA, outDir);
}

// libgrabkernel compatibility shim
// Note that research kernel grabbing is not currently supported
int grabkernel(char *downloadPath, int isResearchKernel __unused) {
    NSString *outPath = [NSString stringWithCString:downloadPath encoding:NSUTF8StringEncoding];
    return grab_kernelcache(outPath) ? 0 : -1;
}