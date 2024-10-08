# libgrabkernel2

This is a simple library to download the kernelcache for the host iOS/macOS device. It is similar to the original [libgrabkernel](https://github.com/tihmstar/libgrabkernel) by tihmstar, but it uses the AppleDB API to find the kernelcache URL, which lets it work for beta versions of iOS/macOS as well.

libgrabkernel2 also contains a compatibility shim for the original libgrabkernel's `grabkernel()` function. This means that you can swap a libgrabkernel dylib for a libgrabkernel2 one in a pre-compiled project without issues.

## Building

Run `make` in the root directory.

- Add `TARGET=macos` for macOS (the default is iOS)
- Add `DEBUG=1` for a debug build.

The build products and headers will be in the `output` directory.

Huge credit to [dhinakg](https://github.com/dhinakg) for reimplementing the API parsing in Objective-C (as it was originally in Swift).
