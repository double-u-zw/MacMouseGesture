# Third-party notices — review pending

**License status is under review.** This is a local Beta Preview, not a grant of redistribution rights or a final licensing determination. No project-wide license has been selected.

## Mac Mouse Fix

- Author: Noah Nuebling.
- Repository: https://github.com/noah-nuebling/mac-mouse-fix
- Research snapshot: `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`.
- Reviewed license: [custom MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License), not MIT, Apache or GPL.

Early research into macOS system gestures included studying Mac Mouse Fix. The Bridge through Build 14 was conservatively classified as structurally derived in its two event constructors. Input coalescing and gesture semantics also drew conceptual inspiration. This historical acknowledgement remains applicable to those earlier sources and binaries; their obligations are not removed by replacing the current implementation.

For Build 15, both constructors were removed and replaced with `SystemGestureEventBuilder`, written from this project's functional interface specification and behavior contracts, recorded ABI/protocol facts, and runtime readback. No MMF or comparison-project source was used as a coding template during this replacement. The current source-tree engineering review found no remaining MMF code-level derivative. This is not a legal guarantee, a claim of never having studied MMF, or an attribution-based grant of permission. MMF attribution here identifies historical research and earlier code, rather than describing the new builder as MMF-derived. See [current and historical provenance](docs/system-gesture-provenance.md).

## Apple open-source interfaces

Minimal ABI declarations and numeric event protocol constants were informed by [IOHIDFamily](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12), including IOHIDEventTypes.h, IOHIDEventFieldDefs.h and HIDEvent.h. The audit identified APSL notices on relevant headers, while the precise covered scope of minimal declarations remains under review. No complete Apple implementation source is bundled. This is not a final APSL compliance conclusion.

## App icon

The project icon was newly generated with the built-in image generation tool from a user-supplied visual direction, then packaged at macOS icon sizes. It depicts a generic mouse, not a branded product photograph. Source, prompt and generation notes are in `design/README.md`. This provenance note does not assign a project-wide license.
