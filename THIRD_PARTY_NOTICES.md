# Research provenance and licenses

This personal experimental project was developed after studying Mac Mouse Fix by Noah Nuebling, in particular its research into macOS 27 Dock Swipe events. The private event protocol used here is informed by that research. Attribution does not imply endorsement.

- Upstream: https://github.com/noah-nuebling/mac-mouse-fix
- Research snapshot: `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`
- Key investigation: https://github.com/noah-nuebling/mac-mouse-fix/commit/f92d2d53a
- Upstream license: https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License

Mac Mouse Fix uses the custom **MMF License**, not the MIT License. Its terms include attribution and restrictions on publishing executables derived from its source. The reference checkout retains that license unchanged. This deliverable is a local personal-use POC, not a public distribution or an assertion of unrestricted redistribution rights. Re-evaluate those terms before publishing a derivative binary.

No upstream source files, UI, configuration, monetization components, dependencies, pointer-offset hacks, or build targets are copied into or linked into this application. The implementation is new Swift and Objective-C code. The event protocol, symbol names, and minimal ABI declarations are documented in `docs/research.md`.

Apple's published IOHIDFamily / IOKitUser interfaces were used to identify event types, field encodings, phases, and the HIDEvent Objective-C interface:

- https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/IOHIDFamily/IOHIDEventTypes.h
- https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/IOHIDFamily/IOHIDEventFieldDefs.h
- https://github.com/apple-oss-distributions/IOHIDFamily/blob/IOHIDFamily-1633.120.12/HID/HIDEvent.h

No Apple implementation source is bundled. The minimal declarations and numeric protocol constants are confined to `SystemGestureBridge.m`.
