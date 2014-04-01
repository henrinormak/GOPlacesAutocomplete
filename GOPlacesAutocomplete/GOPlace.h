//
//  GOPlace.h
//
//  A simple model object to represent Google Places API "place"
//  Used as an intermediary between different Places API endpoints
//  storing information and offering a way to persist that information locally
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

NS_CLASS_AVAILABLE(10_8, 6_0)
@interface GOPlace : NSObject <NSCopying, NSSecureCoding>

/**
 *  Designated initialiser
 *  Initialise a new place with a given reference
 *  All other information about the place is empty and unknown
 *
 *  @param reference Google Places reference, required and has to be non-empty
 *
 *  @return GOPlace
 */
- (instancetype)initWithReference:(NSString *)reference;

/**
 *  Creates a fully configured new GOPlace
 *
 *  @param reference    Google Places reference for the location, has to be non-empty
 *  @param location     Geographic location this place represents
 *  @param components   Address components listed below
 *  @param attributions Attributions, which should be presented to the user, see -attributions
 *
 *  @return GOPlace
 */
- (instancetype)initWithReference:(NSString *)reference location:(CLLocation *)location addressComponents:(NSDictionary *)components attributions:(NSArray *)attributions;

// The reference Google APIs use, uniquely identifies the place
@property (nonatomic, readonly, copy) NSString *reference;

// Geographic location of the place
@property (nonatomic, readonly, copy) CLLocation *location;

// Address components
// Follows pattern from CLPlacemark, offering a subset of those properties
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *thoroughfare;
@property (nonatomic, readonly) NSString *subThoroughfare;
@property (nonatomic, readonly) NSString *locality;
@property (nonatomic, readonly) NSString *subLocality;
@property (nonatomic, readonly) NSString *administrativeArea;
@property (nonatomic, readonly) NSString *subAdministrativeArea;
@property (nonatomic, readonly) NSString *postalCode;
@property (nonatomic, readonly) NSString *ISOcountryCode;
@property (nonatomic, readonly) NSString *country;

// Attributions, NSAttributedStrings which if present should be presented to the user
@property (nonatomic, readonly, copy) NSArray *attributions;

@end
