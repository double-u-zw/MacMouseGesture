# Third-party notices

Project-owned source code is licensed under the [MIT License](LICENSE). This does not change the terms applicable to third-party sources or historical material. The notices below preserve attribution and the boundaries of the recorded engineering review.

## Mac Mouse Fix

- Author: Noah Nuebling.
- Repository: [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix).
- Research snapshot: `a7ac3ecc86acf4ddb309ce1007472439a2f9d42a`.
- Reviewed license: [custom MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/0c0fc99e65b3b09e083cbedc71c4d83fe21d1075/License), not MIT, Apache or GPL.

Early system gesture research studied Mac Mouse Fix. The Bridge through Build 14 was conservatively classified as structurally derived in its two event constructors; input coalescing and gesture semantics also drew conceptual inspiration. This acknowledgement remains applicable to those earlier sources and binaries. Replacing the current implementation does not remove their applicable obligations.

For Build 15, both constructors were replaced with `SystemGestureEventBuilder`, written from this project's functional specification, behavior contracts, recorded ABI/protocol facts and runtime readback. MMF and comparison-project source were not used as coding templates during that replacement. The recorded current-tree engineering review found no remaining MMF code-level derivative. This is not a legal guarantee or a claim that MMF was never studied. Attribution alone does not grant additional permissions. See [current and historical provenance](docs/system-gesture-provenance.md).

## Apple open-source interfaces

Minimal ABI declarations and numeric event protocol constants were informed by [IOHIDFamily-1633.120.12](https://github.com/apple-oss-distributions/IOHIDFamily/tree/IOHIDFamily-1633.120.12), including `IOHIDEventTypes.h`, `IOHIDEventFieldDefs.h` and `HIDEvent.h`. The recorded audit identified APSL notices on relevant headers. The precise covered scope of the minimal declarations remains under review; no complete Apple implementation source is bundled. The project's MIT license does not relicense Apple material or establish an APSL compliance conclusion.

## App icon

The icon was generated with the built-in image generation tool from a user-supplied visual direction, then packaged at macOS icon sizes. It depicts a generic mouse rather than a branded product photograph. The source image, prompt and generation notes are retained in [design/README.md](design/README.md) and `design/app-icon-source.png`.
