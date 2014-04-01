GOPlacesAutocomplete
====================

`GOPlacesAutocomplete` combines two Google Places API endpoints into a single Objective-C wrapper. The wrapper allows using the [autocomplete API](https://developers.google.com/places/documentation/autocomplete) as well as the [Places Details API](https://developers.google.com/places/documentation/details), one for getting the initial place information (completing from a query) and the other to get full information, including the geographic location.

## Usage

`GOPlacesAutocomplete` operates with a simple value object, called `GOPlace`, which you can either create directly by using  the reference string from Google or by using `GOAutocomplete` to fetch a list of `GOPlaces` for a query.

```objective-c
// GOPlacesAutocomplete
GOPlacesAutocomplete *autocomplete = [[GOPlacesAutocomplete alloc] init];

// Further configuration if needed, see -type and -region

[autocomplete requestCompletionForQuery:query completionHandler:^(NSArray *places, NSError *error) {
	// Handle response
}];

// GOPlaceDetails
GOPlaceDetails *details = [[GOPlaceDetails alloc] init];

// Assuming place is a GOPlace instance
[details requestDetailsForPlace:place completionHandler:^(GOPlace *detailedPlace, NSError *error) {
	// Handle response
}];
```

### Google API Key

None of the APIs `GOPlacesAutocomplete` wraps allows anonymous requests, thus a proper API key has to be defined for the requests to succeed. API keys can be defined per instance with the ability to define a default per API.

```objective-c
// Per API approach
[GOPlaceDetails setDefaultGoogleAPIKey:key];
[GOPlacesAutocomplete setDefaultGoogleAPIKey:key];

// Per instance
GOPlaceDetails *details = ...
[details setGoogleAPIKey:key];

GOPlacesAutocomplete *autocomplete = ...;
[autocomplete setGoogleAPIKey:key];
```

### NSProgress

Both `GOPlaceDetails` and `GOPlacesAutocomplete` instances support `NSProgress` by reporting the progress of their network request.

Cancellation is supported, but pausing is not. Cancellation is handled as if `-cancelRequest` had been called.

The network traffic is mostly minimal (i.e usually the data arrives in a single chunk), but due to latency the process may take a while, thus progress reporting was added.

## Installation

Simply add the files in the `GOPlacesAutocomplete` folder to your project:
GOPlace.{h,m})
GOPlaceDetails.{h,m}
GOPlacesAutocomplete.{h,m}

`GOPlacesAutocomplete` works on both OS X and iOS, with minimal differences (`CLRegion` vs `CLCircularRegion` being the most obvious when it comes to `GOPlacesAutocomplete`). The wrapper requires OS X 10.9 and iOS 7 respectively.

## Limitations

Each `GOPlaceDetails` and `GOPlacesAutocomplete` instance can handle at most one request at a time, again following a similar pattern from `CLGeocoder`. Thus in order to start a new request the previous one should be cancelled via `-cancelRequest` method. Keep in mind that cancelling might take a moment and that the completion handler of the previous call will get invoked no matter what.

---

## Contact

Henri Normak

- http://github.com/henrinormak
- http://twitter.com/henrinormak

## License

`GOPlacesAutocomplete` is licensed under the MIT license, see LICENSE file for more info.
