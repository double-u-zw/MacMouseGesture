# Private macOS interface dependency

Classification: **PUBLIC_DOC**. Technical/product decision record, not legal advice or an authorization statement.

## Current implementation

MacMouseGesture uses private `HID.framework` / `HIDEvent`, SkyLight's `SLEventSetIOHIDEvent` and `SLEventCopyIOHIDEvent`, and undocumented gesture protocol fields to create continuous Spaces, Mission Control and App Exposé events. `dlopen`/`dlsym` and public event-posting APIs do not turn the underlying protocol into a documented API.

`PRIVATE_API_DEPENDENCY_REMAINS`.

`NO_DOCUMENTED_EQUIVALENT_FOUND`: the project's recorded research did not identify a documented API offering the same continuous, reversible global system animations. This is a bounded research finding, not proof that no alternative could ever exist. See [API audit](api-audit.md) and [Bridge specification](system-gesture-bridge-spec.md).

## Product consequences

- macOS updates can change or remove these interfaces. Present compatibility is not a future guarantee.
- Replacing the current backend with one-shot keyboard actions would not preserve its existing continuous behavior.
- The current tested target is macOS 27 / Apple Silicon; broader compatibility remains unverified.
- Signing identifies code and supports integrity checks. Notarization is not a grant of private API authorization or a compatibility guarantee.
- Minimum local ABI declarations and protocol facts have their own provenance considerations. See [source provenance](system-gesture-provenance.md) and [third-party notices](../THIRD_PARTY_NOTICES.md).

## Owner decision outstanding

Choose whether the Preview will be source-only or include a binary using the present private interfaces, and separately choose the signing/notarization route. Review applicable terms for the selected route before publication. This document does not claim Apple approval, legal certainty, or absence of risk.

`APPLE_PRIVATE_API = OWNER_DECISION`. No signing enrollment, notarization, publication or API implementation change is performed by this record.
