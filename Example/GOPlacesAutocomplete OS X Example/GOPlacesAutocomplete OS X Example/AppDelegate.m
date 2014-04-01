//
//  AppDelegate.m
//  GOPlacesAutocomplete OS X Example
//
//  Created by Henri Normak on 01/04/2014.
//  Copyright (c) 2014 Henri Normak. All rights reserved.
//

#import "AppDelegate.h"

#import "GOPlace.h"
#import "GOPlacesAutocomplete.h"
#import "GOPlaceDetails.h"

@import CoreLocation;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
#warning Fill in with your Google API key
    [GOPlacesAutocomplete setDefaultGoogleAPIKey:@""];
    [GOPlaceDetails setDefaultGoogleAPIKey:@""];
    
    // Autocomplete a query "Goog"
    NSString *query = @"goog";
    GOPlacesAutocomplete *autocomplete = [[GOPlacesAutocomplete alloc] init];
    
    // Bias the results to Paris, France with radius of 10km
    [autocomplete setRegion:[[CLRegion alloc] initCircularRegionWithCenter:CLLocationCoordinate2DMake(48.856614, 2.3522219) radius:10000.0 identifier:nil]];
    
    // Limit results to establishments
    [autocomplete setType:@"establishment"];
    
    [autocomplete requestCompletionForQuery:query completionHandler:^(NSArray *places, NSError *error) {
        if (places) {
            // Grab the first result and fetch details for it
            GOPlace *place = [places firstObject];
            
            GOPlaceDetails *details = [[GOPlaceDetails alloc] init];
            [details requestDetailsForPlace:place completionHandler:^(GOPlace *detailedPlace, NSError *error) {
                if (detailedPlace) {
                    NSLog(@"Detailed place for query %@ => %@", query, detailedPlace);
                } else {
                    NSLog(@"Places Details error => %@", error);
                }
            }];
        } else {
            NSLog(@"Autocomplete error => %@", error);
        }
    }];
}

@end
