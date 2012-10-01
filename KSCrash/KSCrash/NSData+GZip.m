//
//  NSData+GZip.m
//
//  Created by Karl Stenerud on 2012-02-19.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import "NSData+GZip.h"

#import <zlib.h>


#if __has_feature(objc_arc)
    #define as_autorelease(X)        (X)
#else
    #define as_autorelease(X)       [(X) autorelease]
#endif


#define kBufferSize 4096


static NSString* zlibError(int errorCode)
{
    switch (errorCode)
    {
        case Z_OK:
            return @"OK";
        case Z_STREAM_END:
            return @"End of stream";
        case Z_NEED_DICT:
            return @"NEED_DICT";
        case Z_ERRNO:
            return [NSString stringWithFormat:@"errno: %s", strerror(errno)];
        case Z_STREAM_ERROR:
            return @"Invalid stream state";
        case Z_DATA_ERROR:
            return @"Invalid data";
        case Z_MEM_ERROR:
            return @"Insufficient memory";
        case Z_BUF_ERROR:
            return @"Output buffer too small";
        case Z_VERSION_ERROR:
            return @"Incorrect zlib version";
    }
    return [NSString stringWithFormat:@"Unknown error: %d", errorCode];
}

/** Fill out a pointer-to-error.
 *
 * @param error The error to fill out. Ignored if nil.
 *
 * @param fmt The printf-formatted string + args. If nil, *error is cleared to
 *            nil (unless error is nil as well).
 *
 * @return always false (to keep the analyzer happy).
 */
static BOOL fillError(NSError** error, NSString* fmt, ...)
{
    if(error == nil)
    {
        return false;
    }

    if(fmt == nil)
    {
        *error = nil;
        return false;
    }

    va_list args;
    va_start(args, fmt);

    NSString* desc = as_autorelease([[NSString alloc] initWithFormat:fmt
                                                           arguments:args]);
    va_end(args);

    *error = [NSError errorWithDomain:@"JSONCodec"
                                 code:1
                             userInfo:[NSDictionary dictionaryWithObject:desc
                                                                  forKey:NSLocalizedDescriptionKey]];
    return false;
}

@implementation NSData (GZip)

- (NSData*) gzippedWithCompressionLevel:(int) compressionLevel
                                  error:(NSError**) error
{
    uInt length = (uInt)[self length];
    if(length == 0)
    {
        fillError(error, nil);
        return [NSData data];
    }

    z_stream stream = {0};
    stream.next_in = (Bytef*)[self bytes];
    stream.avail_in = length;

    int err;

    err = deflateInit2(&stream,
                       compressionLevel,
                       Z_DEFLATED,
                       (16+MAX_WBITS),
                       9,
                       Z_DEFAULT_STRATEGY);
    if(err != Z_OK)
    {
        fillError(error, @"deflateInit2: %@", zlibError(err));
        return nil;
    }

    NSMutableData* compressedData = [NSMutableData dataWithLength:(NSUInteger)(length * 1.02 + 50)];
    Bytef* compressedBytes = [compressedData mutableBytes];
    NSUInteger compressedLength = [compressedData length];

    while(err == Z_OK)
    {
        stream.next_out = compressedBytes + stream.total_out;
        stream.avail_out = (uInt)(compressedLength - stream.total_out);
        err = deflate(&stream, Z_FINISH);
    }

    if(err != Z_STREAM_END)
    {
        fillError(error, @"deflate: %@", zlibError(err));
        deflateEnd(&stream);
        return nil;
    }

    [compressedData setLength:stream.total_out];

    fillError(error, nil);
    deflateEnd(&stream);
    return compressedData;
}

- (NSData*) gunzippedWithError:(NSError**) error
{
    uInt length = (uInt)[self length];
    if(length == 0)
    {
        fillError(error, nil);
        return [NSData data];
    }

    z_stream stream = {0};
    stream.next_in = (Bytef*)[self bytes];
    stream.avail_in = length;

    int err;

    err = inflateInit2(&stream, 16+MAX_WBITS);
    if(err != Z_OK)
    {
        fillError(error, @"inflateInit2: %@", zlibError(err));
        return nil;
    }

    NSMutableData* expandedData = [NSMutableData dataWithCapacity:length * 2];
    Bytef buffer[kBufferSize];
    stream.avail_out = sizeof(buffer);

    while(err != Z_STREAM_END)
    {
        stream.avail_out = sizeof(buffer);
        stream.next_out = buffer;
        err = inflate(&stream, Z_NO_FLUSH);
        if(err != Z_OK && err != Z_STREAM_END)
        {
            fillError(error, @"inflate: %@", zlibError(err));
            inflateEnd(&stream);
            return nil;
        }
        [expandedData appendBytes:buffer
                           length:sizeof(buffer) - stream.avail_out];
    }

    fillError(error, nil);
    inflateEnd(&stream);
    return expandedData;
}

@end

// Make this category auto-link
@interface NSData_GZIP_A0THJ4 : NSObject @end @implementation NSData_GZIP_A0THJ4 @end
