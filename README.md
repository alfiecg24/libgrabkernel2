# libgrabkernel2

This is a simple library to download the kernelcache for the host iOS device. It is similar to the original [libgrabkernel](https://github.com/tihmstar/libgrabkernel) by tihmstar, but it uses the AppleDB API to find the kernelcache URL, which lets it work for beta versions of iOS as well. To build, run `make` in the root directory, and the build products and headers will be in the `output` directory.

At the moment, the library only builds for iOS, due to the use of the external libraries found in `_external`:
* libpartialzip
* libcurl

Huge credit to [dhinakg](https://github.com/dhinakg) for reimplementing the API parsing in Objective-C (as it was originally in Swift).