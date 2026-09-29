# Third-party notices — review pending

**License status is under review.** This is a local Beta Preview, not a grant of redistribution rights or a final licensing determination. No project-wide license has been selected.

## Mac Mouse Fix

- Author: Noah Nuebling.
- Repository: https://github.com/noah-nuebling/mac-mouse-fix
- Research snapshot: `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`.
- Reviewed license: [custom MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License), not MIT, Apache or GPL.

SystemGestureBridge's DockSwipe event construction, phase encoding, progress/flavor/motion fields, terminal velocity child and event attachment were informed by and conservatively classified as adapted from MMF research/implementation. Input coalescing and gesture semantics also drew conceptual inspiration. Renaming or rewriting in another wrapper is not proof of independent origin. No claim is made that all code is wholly independently original.

The copied-expression/derivative scope and source/binary publication conditions still require confirmation. Attribution does not imply endorsement or permission. See [the per-file audit](docs/third-party-audit.md). Do not publish the repository or binary on the assumption that a free Beta is exempt.

## Apple open-source interfaces

Minimal ABI declarations and numeric event protocol constants were informed by [IOHIDFamily](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12), including IOHIDEventTypes.h, IOHIDEventFieldDefs.h and HIDEvent.h. The audit identified APSL notices on relevant headers, while the precise covered scope of minimal declarations remains under review. No complete Apple implementation source is bundled. This is not a final APSL compliance conclusion.

## App icon

The project icon was newly generated with the built-in image generation tool from a user-supplied visual direction, then packaged at macOS icon sizes. It depicts a generic mouse, not a branded product photograph. Source, prompt and generation notes are in `design/README.md`. This provenance note does not assign a project-wide license.
