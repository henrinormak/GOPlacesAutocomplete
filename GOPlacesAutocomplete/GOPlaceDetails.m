//
//  GOPlaceDetails.m
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

#import "GOPlaceDetails.h"
#import "GOPlace.h"

#pragma mark -
#pragma mark Constants

NSString *const GOPlaceDetailsErrorDomain = @"GOTimeZoneError";

NSString *const GOPlaceDetailsResponseStatus = @"status";
NSString *const GOPlaceDetailsResponseErrorMessage = @"error_message";

NSString *const GOPlaceDetailsResponseStatusOK = @"OK";
NSString *const GOPlaceDetailsResponseStatusInvalid = @"INVALID_REQUEST";
NSString *const GOPlaceDetailsResponseStatusOverQuota = @"OVER_QUERY_LIMIT";
NSString *const GOPlaceDetailsResponseStatusDenied = @"REQUEST_DENIED";
NSString *const GOPlaceDetailsResponseStatusUnknown = @"UNKNOWN_ERROR";
NSString *const GOPlaceDetailsResponseStatusZeroResults = @"ZERO_RESULTS";

NSString *const GOPlaceDetailsResponseAttributions = @"html_attributions";

NSString *const GOPlaceDetailsResponseResult = @"result";
NSString *const GOPlaceDetailsResponseName = @"name";
NSString *const GOPlaceDetailsResponseReference = @"reference";

NSString *const GOPlaceDetailsResponseAddressComponents = @"address_components";
NSString *const GOPlaceDetailsResponseAddressComponentLongName = @"long_name";
NSString *const GOPlaceDetailsResponseAddressComponentShortName = @"short_name";
NSString *const GOPlaceDetailsResponseAddressComponentTypes = @"types";

NSString *const GOPlaceDetailsResponseGeometry = @"geometry";
NSString *const GOPlaceDetailsResponseLocation = @"location";
NSString *const GOPlaceDetailsResponseLatitude = @"lat";
NSString *const GOPlaceDetailsResponseLongitude = @"lng";

static void * GOPlaceDetailsContext = &GOPlaceDetailsContext;

@interface GOPlaceDetails ()
@property (nonatomic, readwrite, getter = isRunning) BOOL running;
@property (nonatomic, readwrite, getter = isCancelling) BOOL cancelling;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, copy) GOPlaceDetailsCompletionHandler completionHandler;

- (NSDictionary *)addressComponentsFromJSONResult:(NSDictionary *)result;
- (NSArray *)attributionsFromJSONResult:(NSDictionary *)result;

- (void)finishRequest:(GOPlace *)place error:(NSError *)error;

@end

@implementation GOPlaceDetails

#pragma mark -
#pragma mark API Key

static NSString *GOPlaceDetailsDefaultAPIKey = @"";

+ (void)setDefaultGoogleAPIKey:(NSString *)key {
    GOPlaceDetailsDefaultAPIKey = key;
}

+ (NSString *)defaultGoogleAPIKey {
    return GOPlaceDetailsDefaultAPIKey;
}

#pragma mark -
#pragma mark GOTimeZone

- (instancetype)init {
    if ((self = [super init])) {
        self.googleAPIKey = [[self class] defaultGoogleAPIKey];
    }
    
    return self;
}

- (void)requestDetailsForPlace:(GOPlace *)place completionHandler:(GOPlaceDetailsCompletionHandler)completionHandler {
    // Ignore if we are already running
    // Previous request has to be completely cancelled first
    @synchronized(self) {
        if (self.running || self.cancelling)
            return;
        
        self.running = YES;
    }
    
    // Update state
    self.completionHandler = completionHandler;
    
    // Create the connection
    NSMutableString *urlString = [NSMutableString stringWithString:@"https://maps.googleapis.com/maps/api/place/details/json?"];
    [urlString appendFormat:@"reference=%@&sensor=true&key=%@", place.reference, self.googleAPIKey];
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    
    // Start progress
    self.progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress] userInfo:nil];
    self.progress.cancellable = YES;
    self.progress.pausable = NO;
    
    // Observe progress state
    [self.progress addObserver:self forKeyPath:NSStringFromSelector(@selector(isCancelled)) options:0 context:GOPlaceDetailsContext];
    
    // Start the connection
    [self.connection start];
}

- (void)cancelRequest {
    // If not running, or already in the middle of cancelling, then ignore
    @synchronized(self) {
        if (!self.isRunning || self.isCancelling)
            return;
        
        self.cancelling = YES;
    }
    
    // Cancel the connection
    [self.connection cancel];
}

- (void)finishRequest:(GOPlace *)place error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.completionHandler)
            self.completionHandler(place, error);
        
        self.data = nil;
        self.connection = nil;
        self.completionHandler = nil;
        
        self.running = NO;
        self.cancelling = NO;
        
        // Make sure the progress reporting is complete
        [self.progress setCompletedUnitCount:self.progress.totalUnitCount];
        [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(isCancelled)) context:GOPlaceDetailsContext];
        self.progress = nil;
    });
}

#pragma mark -
#pragma mark Helper

- (NSDictionary *)addressComponentsFromJSONResult:(NSDictionary *)result {
    // Go over all the components we have
    NSArray *components = [result objectForKey:GOPlaceDetailsResponseAddressComponents];
    NSMutableDictionary *addressComponents = [NSMutableDictionary dictionary];
    
    for (NSDictionary *component in components) {
        NSArray *types = [component objectForKey:GOPlaceDetailsResponseAddressComponentTypes];
        NSString *longName = [component objectForKey:GOPlaceDetailsResponseAddressComponentLongName];
        NSString *shortName = [component objectForKey:GOPlaceDetailsResponseAddressComponentShortName];
        
        if (!longName)
            continue;
        
        if ([types containsObject:@"street_number"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(subThoroughfare))];
        } else if ([types containsObject:@"route"]) {
            // Combine with the subthoroughfare
            NSString *streetAddress = [[addressComponents objectForKey:NSStringFromSelector(@selector(subThoroughfare))] stringByAppendingFormat:@" %@", longName];
            [addressComponents setObject:streetAddress forKey:NSStringFromSelector(@selector(thoroughfare))];
        } else if ([types containsObject:@"street_address"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(thoroughfare))];
        } else if ([types containsObject:@"locality"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(locality))];
        } else if ([types containsObject:@"sublocality"] || [types containsObject:@"neighborhood"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(subLocality))];
        } else if ([types containsObject:@"administrative_area_level_1"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(administrativeArea))];
        } else if ([types containsObject:@"administrative_area_level_2"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(subAdministrativeArea))];
        } else if ([types containsObject:@"country"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(country))];
            if (shortName)
                [addressComponents setObject:shortName forKey:NSStringFromSelector(@selector(ISOcountryCode))];
        } else if ([types containsObject:@"postal_code"]) {
            [addressComponents setObject:longName forKey:NSStringFromSelector(@selector(postalCode))];
        }
    }
    
    NSString *name = [result objectForKey:GOPlaceDetailsResponseName];
    if (name)
        [addressComponents setObject:name forKey:NSStringFromSelector(@selector(name))];
    
    return [NSDictionary dictionaryWithDictionary:addressComponents];
}

- (NSArray *)attributionsFromJSONResult:(NSDictionary *)result {
    // Go over all the attribution strings
    NSArray *attributions = [result objectForKey:GOPlaceDetailsResponseAttributions];
    
    NSMutableArray *attributedStrings = [NSMutableArray array];
    for (NSString *attribution in attributions) {
        // Presumably the attribution strings may contain HTML, use NSAttributedString
        // to parse the HTML into attributes
        NSData *data = [attribution dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                  NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithData:data
                                                                                options:options
                                                                     documentAttributes:NULL error:NULL];
        if (attributedString)
            [attributedStrings addObject:attributedString];
    }
    
    return [NSArray arrayWithArray:attributedStrings];
}

#pragma mark -
#pragma mark NSURLConnectionDelegates

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)[cachedResponse response];
    
    // Check if caching is protocol based, in which case make sure the protocol included necessary headers
    if([connection currentRequest].cachePolicy == NSURLRequestUseProtocolCachePolicy) {
        NSDictionary *headers = [httpResponse allHeaderFields];
        NSString *cacheControl = [headers valueForKey:@"Cache-Control"];
        NSString *expires = [headers valueForKey:@"Expires"];
        if((cacheControl == nil) && (expires == nil)) {
            return nil;
        }
    }
    
    return cachedResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
    
    if ([HTTPResponse statusCode] == 200) {
        NSUInteger length = (NSUInteger)[response expectedContentLength];
        if (length != NSURLResponseUnknownLength) {
            [self.progress setTotalUnitCount:length];
            self.data = [NSMutableData dataWithCapacity:length];
        } else {
            // No concrete length, just give an arbitrary estimate (which we'll grow with every chunk of new data we get)
            [self.progress setTotalUnitCount:1];
            self.data = [NSMutableData data];
        }
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
    NSUInteger units = self.progress.completedUnitCount + [data length];
    
    // Make sure the progress is not "completed" prematurely due to some miscalculation
    // in the expected length
    if (self.progress.totalUnitCount <= units)
        [self.progress setTotalUnitCount:units+1];
    
    [self.progress setCompletedUnitCount:units];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self finishRequest:nil error:[NSError errorWithDomain:GOPlaceDetailsErrorDomain code:kGOPlaceDetailsErrorNetwork userInfo:error.userInfo]];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *error;
    GOPlace *place;
    
    // Check if we have any data
    if (self.data == nil) {
        error = [NSError errorWithDomain:GOPlaceDetailsErrorDomain code:kGOPlaceDetailsErrorNetwork userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"Place details API request returned no data", nil)}];
    } else {
        // We have data, try to parse the data
        NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&error];
        if (!JSON) {
            error = [NSError errorWithDomain:GOPlaceDetailsErrorDomain code:kGOPlaceDetailsErrorDataCorrupt userInfo:error.userInfo];
        } else {
            // Parse the JSON output
            NSString *status = [JSON objectForKey:GOPlaceDetailsResponseStatus];
            if ([status isEqualToString:GOPlaceDetailsResponseStatusOK]) {
                // Everything was fine, create the place object
                NSDictionary *result = [JSON objectForKey:GOPlaceDetailsResponseResult];
                
                // Reference
                NSString *reference = [result objectForKey:GOPlaceDetailsResponseReference];
                
                // Location
                CLLocationDegrees lat = [[[[result objectForKey:GOPlaceDetailsResponseGeometry] objectForKey:GOPlaceDetailsResponseLocation] objectForKey:GOPlaceDetailsResponseLatitude] doubleValue];
                CLLocationDegrees lng = [[[[result objectForKey:GOPlaceDetailsResponseGeometry] objectForKey:GOPlaceDetailsResponseLocation] objectForKey:GOPlaceDetailsResponseLongitude] doubleValue];
                CLLocation *location = [[CLLocation alloc] initWithLatitude:lat longitude:lng];
                
                // Address components
                NSDictionary *components = [self addressComponentsFromJSONResult:result];
                
                // Attributions
                NSArray *attributions = [self attributionsFromJSONResult:result];

                place = [[GOPlace alloc] initWithReference:reference location:location addressComponents:components attributions:attributions];
            } else if ([status isEqualToString:GOPlaceDetailsResponseStatusZeroResults]) {
                // No matches
                error = [NSError errorWithDomain:GOPlaceDetailsErrorDomain code:kGOPlaceDetailsErrorFoundNoResult userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"Place details API request returned zero results", nil)}];
            } else {
                // Generic error, simply claim as denied
                NSDictionary *userinfo;
                NSString *errorMessage = [JSON objectForKey:GOPlaceDetailsResponseErrorMessage];
                if (errorMessage)
                    userinfo = @{NSLocalizedDescriptionKey : errorMessage};
                
                error = [NSError errorWithDomain:GOPlaceDetailsErrorDomain code:kGOPlaceDetailsErrorDenied userInfo:userinfo];
            }
        }
    }
    
    [self finishRequest:place error:error];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == GOPlaceDetailsContext) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(isCancelled))]) {
            if ([object isCancelled])
                [self cancelRequest];   // Cancel the request
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
