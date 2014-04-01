//
//  GOPlace.m
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

#import "GOPlace.h"

@interface GOPlace ()
@property (nonatomic, copy) NSDictionary *addressComponents;
@end

@implementation GOPlace

#pragma mark -
#pragma mark GOPlace

- (instancetype)initWithReference:(NSString *)reference {
    NSParameterAssert([reference length] > 0);
    
    if ((self = [super init])) {
        _reference = [reference copy];
    }
    
    return self;
}

- (instancetype)initWithReference:(NSString *)reference location:(CLLocation *)location addressComponents:(NSDictionary *)components attributions:(NSArray *)attributions {
    if ((self = [self initWithReference:reference])) {
        // Additional properties
        _location = [location copy];
        _attributions = [attributions copy];
        
        // Address components
        NSArray *keys = @[NSStringFromSelector(@selector(name)), NSStringFromSelector(@selector(thoroughfare)),
                          NSStringFromSelector(@selector(subThoroughfare)), NSStringFromSelector(@selector(locality)),
                          NSStringFromSelector(@selector(subLocality)), NSStringFromSelector(@selector(administrativeArea)),
                          NSStringFromSelector(@selector(subAdministrativeArea)), NSStringFromSelector(@selector(postalCode)),
                          NSStringFromSelector(@selector(ISOcountryCode)), NSStringFromSelector(@selector(country))];
        
        NSMutableDictionary *filteredComponents = [NSMutableDictionary dictionary];
        for (NSString *key in keys) {
            id value = [components objectForKey:key];
            if (value) {
                [filteredComponents setObject:value forKey:key];
            }
        }
        self.addressComponents = filteredComponents;
    }
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (NSString *)name {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(name))];
}

- (NSString *)thoroughfare {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(thoroughfare))];
}

- (NSString *)subThoroughfare {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(subThoroughfare))];
}

- (NSString *)locality {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(locality))];
}

- (NSString *)subLocality {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(subLocality))];
}

- (NSString *)administrativeArea {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(administrativeArea))];
}

- (NSString *)subAdministrativeArea {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(subAdministrativeArea))];
}

- (NSString *)postalCode {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(postalCode))];
}

- (NSString *)ISOcountryCode {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(ISOcountryCode))];
}

- (NSString *)country {
    return [self.addressComponents objectForKey:NSStringFromSelector(@selector(country))];
}

#pragma mark -
#pragma mark NSCoding/NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.reference forKey:NSStringFromSelector(@selector(reference))];
    [aCoder encodeObject:self.addressComponents forKey:NSStringFromSelector(@selector(addressComponents))];
    [aCoder encodeObject:self.location forKey:NSStringFromSelector(@selector(location))];
    [aCoder encodeObject:self.attributions forKey:NSStringFromSelector(@selector(attributions))];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    // Make sure to use decodeObjectOfClass:forKey: to properly implement NSSecureCopying
    NSString *reference = [aDecoder decodeObjectOfClass:[NSString class] forKey:NSStringFromSelector(@selector(reference))];
    NSDictionary *addressComponents = [aDecoder decodeObjectOfClass:[NSDictionary class] forKey:NSStringFromSelector(@selector(addressComponents))];
    CLLocation *location = [aDecoder decodeObjectOfClass:[CLLocation class] forKey:NSStringFromSelector(@selector(location))];
    NSArray *attributions = [aDecoder decodeObjectOfClass:[NSArray class] forKey:NSStringFromSelector(@selector(attributions))];
    
    return [self initWithReference:reference location:location addressComponents:addressComponents attributions:attributions];
}

#pragma mark -
#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark -
#pragma mark NSObject

// Equality and hashing based on ideas from
// https://www.mikeash.com/pyblog/friday-qa-2010-06-18-implementing-equality-and-hashing.html

#ifndef NSUINT_BIT
#define NSUINT_BIT (CHAR_BIT * sizeof(NSUInteger))
#endif
#ifndef NSUINTROTATE
#define NSUINTROTATE(val, howmuch) ((((NSUInteger)val) << howmuch) | (((NSUInteger)val) >> (NSUINT_BIT - howmuch)))
#endif

- (BOOL)isEqual:(id)object {
    if (![super isEqual:object])
        return NO;
    
    if (![object isKindOfClass:[GOPlace class]])
        return NO;
    
    // Notice that the comparison does not use address components, as those can be refetched to always be the same values
    GOPlace *other = (GOPlace *)object;
    return [self.reference isEqualToString:other.reference] &&
            (self.location == other.location || [self.location isEqual:other.location]);
}

- (NSUInteger)hash {
    return NSUINTROTATE([self.reference hash], NSUINT_BIT / 2) ^ [self.location hash];
}

- (NSString *)description {
    return [[super description] stringByAppendingFormat:@" reference: %@, location: %@, address components: %@", self.reference, [self.location description], [self.addressComponents description]];
}

@end
