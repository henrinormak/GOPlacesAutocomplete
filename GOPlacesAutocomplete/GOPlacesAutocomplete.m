//
//  GOPlacesAutocomplete.m
//  Sandbox
//
//  Created by Henri Normak on 01/04/2014.
//  Copyright (c) 2014 Henri Normak. All rights reserved.
//

#import "GOPlacesAutocomplete.h"
#import "GOPlace.h"

#pragma mark -
#pragma mark Constants

NSString *const GOPlacesAutocompleteErrorDomain = @"GOPlacesAutocompleteError";

NSString *const GOPlacesAutocompleteResponseStatus = @"status";
NSString *const GOPlacesAutocompleteResponseErrorMessage = @"error_message";

NSString *const GOPlacesAutocompleteResponseStatusOK = @"OK";
NSString *const GOPlacesAutocompleteResponseStatusInvalid = @"INVALID_REQUEST";
NSString *const GOPlacesAutocompleteResponseStatusOverQuota = @"OVER_QUERY_LIMIT";
NSString *const GOPlacesAutocompleteResponseStatusDenied = @"REQUEST_DENIED";
NSString *const GOPlacesAutocompleteResponseStatusUnknown = @"UNKNOWN_ERROR";
NSString *const GOPlacesAutocompleteResponseStatusZeroResults = @"ZERO_RESULTS";

NSString *const GOPlacesAutocompleteResponsePredictions = @"predictions";
NSString *const GOPlacesAutocompleteResponsePredictionReference = @"reference";
NSString *const GOPlacesAutocompleteResponsePredictionDescription = @"description";

static void * GOPlacesAutocompleteContext = &GOPlacesAutocompleteContext;

@interface GOPlacesAutocomplete ()
@property (nonatomic, readwrite, getter = isRunning) BOOL running;
@property (nonatomic, readwrite, getter = isCancelling) BOOL cancelling;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, copy) GOPlacesAutocompleteCompletionHandler completionHandler;

- (void)finishRequest:(NSArray *)places error:(NSError *)error;

@end

@implementation GOPlacesAutocomplete

#pragma mark -
#pragma mark API Key

static NSString *GOPlacesAutocompleteDefaultAPIKey = @"";

+ (void)setDefaultGoogleAPIKey:(NSString *)key {
    GOPlacesAutocompleteDefaultAPIKey = key;
}

+ (NSString *)defaultGoogleAPIKey {
    return GOPlacesAutocompleteDefaultAPIKey;
}

#pragma mark -
#pragma mark GOPlacesAutocomplete

- (instancetype)init {
    if ((self = [super init])) {
        self.googleAPIKey = [[self class] defaultGoogleAPIKey];
    }
    
    return self;
}

- (void)requestCompletionForQuery:(NSString *)query completionHandler:(GOPlacesAutocompleteCompletionHandler)completionHandler {
    // Query should not be empty
    NSParameterAssert([query length] > 0);
    
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
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:@"https://maps.googleapis.com/maps/api/place/autocomplete/json"];
    
    NSMutableString *queryComponent = [NSMutableString string];
    [queryComponent appendFormat:@"sensor=true&key=%@", self.googleAPIKey];
    [queryComponent appendFormat:@"&input=%@", query];
    
    if ([self.type length] > 0)
        [queryComponent appendFormat:@"&types=%@", self.type];
    
    if (self.region) {
        [queryComponent appendFormat:@"&location=%f,%f", self.region.center.latitude, self.region.center.longitude];
        if (self.region.radius < CLLocationDistanceMax)
            [queryComponent appendFormat:@"&radius=%f", self.region.radius];
    }
    
    [components setQuery:queryComponent];
    
    NSURL *url = [components URL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    
    // Start progress
    self.progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress] userInfo:nil];
    self.progress.cancellable = YES;
    self.progress.pausable = NO;
    
    // Observe progress state
    [self.progress addObserver:self forKeyPath:NSStringFromSelector(@selector(isCancelled)) options:0 context:GOPlacesAutocompleteContext];
    
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

- (void)finishRequest:(NSArray *)places error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.completionHandler)
            self.completionHandler(places, error);
        
        self.data = nil;
        self.connection = nil;
        self.completionHandler = nil;
        
        self.running = NO;
        self.cancelling = NO;
        
        // Make sure the progress reporting is complete
        [self.progress setCompletedUnitCount:self.progress.totalUnitCount];
        [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(isCancelled)) context:GOPlacesAutocompleteContext];
        self.progress = nil;
    });
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
        long long length = [response expectedContentLength];
        if (length != NSURLResponseUnknownLength) {
            [self.progress setTotalUnitCount:length];
            self.data = [NSMutableData dataWithLength:(NSUInteger)length];
        } else {
            // No concrete length, just give an arbitrary estimate (which we'll grow with every chunk of new data we get)
            [self.progress setTotalUnitCount:1];
            self.data = [NSMutableData data];
        }
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
    long long units = self.progress.completedUnitCount + [data length];
    
    // Make sure the progress is not "completed" prematurely due to some miscalculation
    // in the expected length
    if (self.progress.totalUnitCount <= units)
        [self.progress setTotalUnitCount:units+1];
    
    [self.progress setCompletedUnitCount:units];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self finishRequest:nil error:[NSError errorWithDomain:GOPlacesAutocompleteErrorDomain code:kGOPlacesAutocompleteErrorNetwork userInfo:error.userInfo]];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *error;
    NSArray *places;
    
    // Check if we have any data
    if (self.data == nil) {
        error = [NSError errorWithDomain:GOPlacesAutocompleteErrorDomain code:kGOPlacesAutocompleteErrorNetwork userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"Places autocomplete API request returned no data", nil)}];
    } else {
        // We have data, try to parse the data
        NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&error];
        if (!JSON) {
            error = [NSError errorWithDomain:GOPlacesAutocompleteErrorDomain code:kGOPlacesAutocompleteErrorDataCorrupt userInfo:error.userInfo];
        } else {
            // Parse the JSON output
            NSString *status = [JSON objectForKey:GOPlacesAutocompleteResponseStatus];
            if ([status isEqualToString:GOPlacesAutocompleteResponseStatusOK]) {
                // Build the results array
                NSArray *predictions = [JSON objectForKey:GOPlacesAutocompleteResponsePredictions];
                NSMutableArray *results = [NSMutableArray array];
                for (NSDictionary *prediction in predictions) {
                    NSString *name = [prediction objectForKey:GOPlacesAutocompleteResponsePredictionDescription];
                    NSString *reference = [prediction objectForKey:GOPlacesAutocompleteResponsePredictionReference];
                    
                    GOPlace *place = [[GOPlace alloc] initWithReference:reference location:nil addressComponents:@{NSStringFromSelector(@selector(name)) : name} attributions:nil];
                    
                    if (place)
                        [results addObject:place];
                }
                
                places = [NSArray arrayWithArray:results];
            } else if ([status isEqualToString:GOPlacesAutocompleteResponseStatusZeroResults]) {
                // No matches
                error = [NSError errorWithDomain:GOPlacesAutocompleteErrorDomain code:kGOPlacesAutocompleteErrorFoundNoResult userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(@"Places Autocomplete API request returned zero results", nil)}];
            } else {
                // Generic error, simply claim as denied
                NSDictionary *userinfo;
                NSString *errorMessage = [JSON objectForKey:GOPlacesAutocompleteResponseErrorMessage];
                if (errorMessage)
                    userinfo = @{NSLocalizedDescriptionKey : errorMessage};
                
                error = [NSError errorWithDomain:GOPlacesAutocompleteErrorDomain code:kGOPlacesAutocompleteErrorDenied userInfo:userinfo];
            }
        }
    }
    
    [self finishRequest:places error:error];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == GOPlacesAutocompleteContext) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(isCancelled))]) {
            if ([object isCancelled])
                [self cancelRequest];   // Cancel the request
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
