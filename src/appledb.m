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

NSArray *hostsNeedingAuth = @[@"adcdownload.apple.com", @"download.developer.apple.com", @"developer.apple.com"];

static NSString *getAPIURL(void) {
    NSString *osStr = nil;
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
    osStr = @"macOS";
#else
    if (NSProcessInfo.processInfo.iOSAppOnMac) {
        osStr = @"macOS";
    } else {
        switch (UIDevice.currentDevice.userInterfaceIdiom) {
            case UIUserInterfaceIdiomPad:
                if (@available(iOS 13.0, *)) {
                    osStr = @"iPadOS";
                    break;
                }
            case UIUserInterfaceIdiomPhone:
                osStr = @"iOS";
                break;
            case UIUserInterfaceIdiomTV:
                osStr = @"tvOS";
                break;
            case UIUserInterfaceIdiomMac:
                osStr = @"macOS";
                break;
            default:
                error("Unrecognized device type %d!\n", (int)UIDevice.currentDevice.userInterfaceIdiom);
                break;
        }
    }
#endif

    if (!osStr) {
        error("Unsupported platform!\n");
        return nil;
    }

    char build[256];
    size_t size = sizeof(build);
    int result = sysctlbyname("kern.osversion", &build, &size, NULL, 0);
    if (result) {
        error("Failed to get build!\n");
        return nil;
    }

    return [NSString stringWithFormat:@"https://api.appledb.dev/ios/%@;%s.json", osStr, build];
}

static NSString *getModelIdentifier(void) {
    char modelIdentifier[256];
    size_t size = sizeof(modelIdentifier);
    int result = sysctlbyname("hw.product", &modelIdentifier, &size, NULL, 0);
    if (result) {
        error("Failed to get model identifier!\n");
        return nil;
    }

    return [NSString stringWithCString:modelIdentifier encoding:NSUTF8StringEncoding];
}

static NSData *makeSynchronousRequest(NSString *url, NSError **error) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData* data = nil;
    __block NSError* taskError = nil;
    NSURLSession *session = [NSURLSession sharedSession];


    NSURLSessionDataTask* task = [session dataTaskWithURL:[NSURL URLWithString:url]
                                                   completionHandler:^(NSData* taskData, NSURLResponse* response, NSError* error) {
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

NSString *getFirmwareURL(bool *isOTA) {
    NSString *apiURL = getAPIURL();
    if (!apiURL) {
        error("Failed to get API URL!\n");
        return nil;
    }

    NSError *error = nil;
    NSData *data = makeSynchronousRequest(apiURL, &error);
    if (error) {
        error("Failed to fetch API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        error("Failed to parse API data: %s\n", error.localizedDescription.UTF8String);
        return nil;
    }

    NSString *modelIdentifier = getModelIdentifier();

    for (NSDictionary<NSString *, id> *source in json[@"sources"]) {
        if (![source[@"deviceMap"] containsObject:modelIdentifier]) {
            debug("Skipping source that does not include device: %s\n", [source[@"deviceMap"] componentsJoinedByString:@", "].UTF8String);
            continue;
        }

        if (![@[@"ota", @"ipsw"] containsObject:source[@"type"]]) {
            debug("Skipping source type: %s\n", [source[@"type"] UTF8String]);
            continue;
        }

        if ([source[@"type"] isEqualToString:@"ota"] && source[@"prerequisiteBuild"]) {
            // ignore deltas
            debug("Skipping OTA source with prerequisite build: %s\n", [source[@"prerequisiteBuild"] UTF8String]);
            continue;
        }

        for (NSDictionary<NSString *, id> *link in source[@"links"]) {
            NSURL *url = [NSURL URLWithString:link[@"url"]];
            if ([hostsNeedingAuth containsObject:url.host]) {
                debug("Skipping link that needs authentication: %s\n", url.absoluteString.UTF8String);
                continue;
            }

            if (!link[@"active"]) {
                debug("Skipping inactive link: %s\n", url.absoluteString.UTF8String);
                continue;
            }

            if (isOTA) {
                *isOTA = [source[@"type"] isEqualToString:@"ota"];
            }
            log("Found firmware URL: %s (OTA: %s)\n", url.absoluteString.UTF8String, *isOTA ? "yes" : "no");
            return link[@"url"];
        }

        debug("No suitable links found for source: %s\n", [source[@"name"] UTF8String]);
    }

    error("Failed to find a firmware URL!\n");

    return nil;
}
