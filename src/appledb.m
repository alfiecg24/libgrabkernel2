//
//  appledb.m
//  libgrabkernel2
//
//  Created by Dhinak G on 3/4/24.
//

#import <Foundation/Foundation.h>
#import <sys/utsname.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import <sys/sysctl.h>
#import "utils.h"

#define BASE_URL @"https://api.appledb.dev/ios/"
#define ALL_VERSIONS BASE_URL @"main.json.xz"

NSArray *hostsNeedingAuth = @[@"adcdownload.apple.com", @"download.developer.apple.com", @"developer.apple.com"];

static inline NSString *apiURLForBuild(NSString *osStr, NSString *build) {
    return [NSString stringWithFormat:@"https://api.appledb.dev/ios/%@;%@.json", osStr, build];
}

static NSData *makeSynchronousRequest(NSString *url, NSError **error) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *data = nil;
    __block NSError *taskError = nil;
    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:url]
                                        completionHandler:^(NSData *taskData, NSURLResponse *response, NSError *error) {
                                            data = taskData;
                                            taskError = error;
                                            dispatch_semaphore_signal(semaphore);
                                        }];
    [task resume];

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    if (error) {
        *error = taskError;
    }

    return data;
}

static NSString *bestLinkFromSources(NSArray<NSDictionary<NSString *, id> *> *sources, NSString *modelIdentifier, bool *isOTA) {
    for (NSDictionary<NSString *, id> *source in sources) {
        if (![source[@"deviceMap"] containsObject:modelIdentifier]) {
            DBGLOG("Skipping source that does not include device: %s\n", [source[@"deviceMap"] componentsJoinedByString:@", "].UTF8String);
            continue;
        }

        if (![@[@"ota", @"ipsw"] containsObject:source[@"type"]]) {
            DBGLOG("Skipping source type: %s\n", [source[@"type"] UTF8String]);
            continue;
        }

        if ([source[@"type"] isEqualToString:@"ota"] && source[@"prerequisiteBuild"]) {
            // ignore deltas
            DBGLOG("Skipping OTA source with prerequisite build: %s\n", [source[@"prerequisiteBuild"] UTF8String]);
            continue;
        }

        for (NSDictionary<NSString *, id> *link in source[@"links"]) {
            NSURL *url = [NSURL URLWithString:link[@"url"]];
            if ([hostsNeedingAuth containsObject:url.host]) {
                DBGLOG("Skipping link that needs authentication: %s\n", url.absoluteString.UTF8String);
                continue;
            }

            if (!link[@"active"]) {
                DBGLOG("Skipping inactive link: %s\n", url.absoluteString.UTF8String);
                continue;
            }

            if (isOTA) {
                *isOTA = [source[@"type"] isEqualToString:@"ota"];
            }
            LOG("Found firmware URL: %s (OTA: %s)\n", url.absoluteString.UTF8String, *isOTA ? "yes" : "no");
            return link[@"url"];
        }

        DBGLOG("No suitable links found for source: %s\n", [source[@"name"] UTF8String]);
    }

    return nil;
}

static NSString *getFirmwareURLFromAll(NSString *osStr, NSString *build, NSString *modelIdentifier, bool *isOTA) {
    NSError *error = nil;
    NSData *compressed = makeSynchronousRequest(ALL_VERSIONS, &error);
    if (error) {
        ERRLOG("Failed to fetch API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSData *decompressed = [compressed decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZMA error:&error];
    if (error) {
        ERRLOG("Failed to decompress API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSArray *json = [NSJSONSerialization JSONObjectWithData:decompressed options:0 error:&error];
    if (error) {
        ERRLOG("Failed to parse API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    for (NSDictionary<NSString *, id> *firmware in json) {
        if ([firmware[@"osStr"] isEqualToString:osStr] && [firmware[@"build"] isEqualToString:build]) {
            NSString *firmwareURL = bestLinkFromSources(firmware[@"sources"], modelIdentifier, isOTA);
            if (!firmwareURL) {
                DBGLOG("No suitable links found for firmware: %s\n", [firmware[@"key"] UTF8String]);
            } else {
                return firmwareURL;
            }
        }
    }

    return nil;
}

static NSString *getFirmwareURLFromDirect(NSString *osStr, NSString *build, NSString *modelIdentifier, bool *isOTA) {
    NSString *apiURL = apiURLForBuild(osStr, build);
    if (!apiURL) {
        ERRLOG("Failed to get API URL!\n");
        return nil;
    }

    NSError *error = nil;
    NSData *data = makeSynchronousRequest(apiURL, &error);
    if (error) {
        ERRLOG("Failed to fetch API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        ERRLOG("Failed to parse API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSString *firmwareURL = bestLinkFromSources(json[@"sources"], modelIdentifier, isOTA);
    if (!firmwareURL) {
        return nil;
    }

    return firmwareURL;
}

NSString *getFirmwareURLFor(NSString *osStr, NSString *build, NSString *modelIdentifier, bool *isOTA) {
    NSString *firmwareURL = getFirmwareURLFromDirect(osStr, build, modelIdentifier, isOTA);
    if (!firmwareURL) {
        DBGLOG("Failed to get firmware URL from direct API, checking all versions...\n");
        firmwareURL = getFirmwareURLFromAll(osStr, build, modelIdentifier, isOTA);
    }

    if (!firmwareURL) {
        ERRLOG("Failed to find a firmware URL!\n");
        return nil;
    }

    return firmwareURL;
}

NSString *getFirmwareURL(bool *isOTA) {
    NSString *osStr = getOsStr();
    NSString *build = getBuild();
    NSString *modelIdentifier = getModelIdentifier();

    if (!osStr || !build || !modelIdentifier) {
        return nil;
    }

    return getFirmwareURLFor(osStr, build, modelIdentifier, isOTA);
}