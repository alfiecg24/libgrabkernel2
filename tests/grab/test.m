#import <Foundation/Foundation.h>
#import "grabkernel.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSLog(@"Hello, World!");
        bool result = grab_kernelcache([NSTemporaryDirectory() stringByAppendingPathComponent:@"kc"]);
        NSLog(@"result: %@", result ? @"success" : @"failure");

        // This device only got this build as an RC, so the code should fall back to the main.json
        result &= grab_kernelcache_for(@"iOS", @"19H218", @"iPhone13,4", @"D54pAP",
                                       [NSTemporaryDirectory() stringByAppendingPathComponent:@"kc"]);
        NSLog(@"result: %@", result ? @"success" : @"failure");

        // This device has SPTM and TXM, so the code should grab them as well
        result &= grab_images_for(@"iOS", @"21C66", @"iPhone15,4", @"d37ap",
                                  [NSTemporaryDirectory() stringByAppendingPathComponent:@"images"]);
        NSLog(@"result: %@", result ? @"success" : @"failure");
        return !result;
    }
}
