//
//  AppDelegate.m
//  GOPlacesAutocomplete iOS Example
//
//  Created by Henri Normak on 01/04/2014.
//  Copyright (c) 2014 Henri Normak. All rights reserved.
//

#import "AppDelegate.h"

#import "GOPlace.h"
#import "GOPlaceDetails.h"
#import "GOPlacesAutocomplete.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    
    UIViewController *viewController = [[UIViewController alloc] init];
    self.window.rootViewController = viewController;
    
    // Set up
#warning Fill in with your Google API key
    [GOPlacesAutocomplete setDefaultGoogleAPIKey:@""];
    [GOPlaceDetails setDefaultGoogleAPIKey:@""];
    
    // Autocomplete a query "Goog"
    NSString *query = @"goog";
    GOPlacesAutocomplete *autocomplete = [[GOPlacesAutocomplete alloc] init];

    // Bias the results to Paris, France with radius of 10km
    [autocomplete setRegion:[[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(48.856614, 2.3522219) radius:10000.0 identifier:nil]];
    
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
    
    return YES;
}

@end
