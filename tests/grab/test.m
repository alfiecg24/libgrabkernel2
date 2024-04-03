#import <Foundation/Foundation.h>
#include "grabkernel.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSLog(@"Hello, World!");
        bool result = grab_kernelcache([NSTemporaryDirectory() stringByAppendingPathComponent:@"kc"]);
        NSLog(@"result: %@", result ? @"success" : @"failure");
        return !result;
    }
}
