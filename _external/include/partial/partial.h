//
//  partial.h
//  partial
//
//  Created by Dhinak G on 3/27/24.
//

#ifndef partial_h
#define partial_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Partial : NSObject {
    NSURL* _url;
    NSURLSession* _session;

    BOOL _isZip64;

    struct zip_end_of_central_directory* _endOfCentralDirectory;
    struct zip64_end_of_central_directory* _endOfCentralDirectory64;

    struct zip_central_directory_file_header* _centralDirectory;
    NSUInteger _centralDirectoryCount;

    NSMutableDictionary<NSString*, NSValue*>* _fileHeaders;
}


@property(readonly) NSUInteger size;
// TODO: Make this an NSDictionary and expose file properties
// NOTE: Order is *not* maintained, as internally this is implemented as the keys of a dictionary
@property(readonly) NSArray<NSString*>* files;

- (nullable instancetype)initWithURL:(NSURL*)url error:(NSError**)error;
+ (nullable instancetype)partialZipWithURL:(NSURL*)url error:(NSError**)error;

- (nullable NSData*)getFileForPath:(NSString*)path error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END

#endif /* partial_h */
