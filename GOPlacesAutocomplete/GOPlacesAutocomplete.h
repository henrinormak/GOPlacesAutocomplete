//
//  GOPlacesAutocomplete.h
//  Wrapper around Google Places Autocomplete API, allowing query based
//  search for Places, represented by GOPlace value objects
//
//  GOPlacesAutocomplete supports NSProgress, reporting the progress during
//  network activity
//
//  Copyright (c) 2014 Henri Normak
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

@import Foundation;
@import CoreLocation;
@class GOPlace;

// Returned GOPlace objects have reference and name populated, other properties are likely blank
typedef void(^GOPlacesAutocompleteCompletionHandler)(NSArray *places, NSError *error);

NS_CLASS_AVAILABLE(10_9, 7_0)
@interface GOPlacesAutocomplete : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, readonly, getter = isRunning) BOOL running;

// API key this instance uses
@property (nonatomic, copy) NSString *googleAPIKey;

// Type string, refer to Google API documentation for valid types
// https://developers.google.com/places/documentation/autocomplete#place_types
// By default empty, and thus returns all types
@property (nonatomic, copy) NSString *type;

// Region to bias results to, use CLLocationDistanceMax to ignore the radius parameter
// Information on location biasing
// https://developers.google.com/places/documentation/autocomplete#location_biasing
@property (nonatomic, copy) CLCircularRegion *region;

/**
 *  Change the default API key to be used by any future requests
 *  Initially empty string
 *
 *  @param key The new key to use, not validated in any way
 */
+ (void)setDefaultGoogleAPIKey:(NSString *)key;

/**
 *  Request control flow, only one request at a time per GOPlacesAutocomplete instance is handled, attempting to start
 *  another request before first has completed/been cancelled will be ignored.
 *
 *  Query should not be empty, if it is an exception is thrown (as that request would be invalid)
 *
 *  Completion block will be called even if the request fails or is cancelled, the block is called on the main queue
 */
- (void)requestCompletionForQuery:(NSString *)query completionHandler:(GOPlacesAutocompleteCompletionHandler)completionHandler;
- (void)cancelRequest;

@end

#pragma mark -
#pragma mark Error

extern NSString *const GOPlacesAutocompleteErrorDomain;

typedef NS_ENUM(NSUInteger, GOPlacesAutocompleteErrorCode) {
    kGOPlacesAutocompleteErrorNetwork,
    kGOPlacesAutocompleteErrorFoundNoResult,
    kGOPlacesAutocompleteErrorCancelled,
    kGOPlacesAutocompleteErrorDenied,         // If the API responds with an error, likely due to quota or invalid API key
    kGOPlacesAutocompleteErrorDataCorrupt,
};
