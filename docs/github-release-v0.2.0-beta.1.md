# MacMouseGesture 0.2.0-beta.1 — release draft

**DRAFT · Beta Preview · FINAL_ARTIFACT_PENDING**

Current local UI candidate: **0.2.0-beta.1 / Build 16**.
Bundle ID: `io.github.double-u-zw.macmousegesture`.
The identity-migration DMG predates the final UI polish and is not the final release asset. No final public DMG or checksum is assigned here. Historical build checksums must not be reused for a newly packaged release.

## Highlights

- Hold either enabled mouse side button and drag left/right for continuous Spaces navigation, up for Mission Control, or down for App Exposé.
- Pause, continue, reverse and release gestures; configure side buttons, horizontal direction and feel.
- Local settings, optional launch at login and single-instance protection.
- Compact Chinese settings/help/about interface and four-step setup guide.
- Bounded recovery after mouse removal. Reconnect behavior passed the user's Build 15 core acceptance; the implementation remains frozen.

## Installation and permissions

When this draft is approved and published, download the DMG and matching `SHA256SUMS` from the official Release, verify the checksum, drag the App to Applications and launch that installed copy. Follow the setup guide to grant Accessibility and test your mouse. Optional Input Monitoring supports additional diagnostics.

The current local candidate is not Developer ID signed or notarized. Final signing/distribution policy remains an owner decision. Do not describe it as a normally trusted download. See [installation](INSTALL.md), [troubleshooting](TROUBLESHOOTING.md) and [privacy](../PRIVACY.md).

## Compatibility and limitations

- macOS 27 / Apple Silicon (arm64); other environments are untested.
- Continuous gestures rely on undocumented/private interfaces and may break after macOS updates.
- Mouse models, connections and vendor drivers may affect behavior.
- App Exposé can have a slight finishing delay in some external-display/full-screen cases.
- No automatic updater. Identity/signing changes may require renewed permission.

## Feedback

Use [GitHub Issues](https://github.com/double-u-zw/MacMouseGesture/issues). Include system version, mouse model, connection type, steps and observed behavior; omit serial numbers and unreviewed diagnostics. No account, telemetry or automatic diagnostic upload is used.

## Assets and approval

`FINAL_ARTIFACT_PENDING`: final DMG filename, size and SHA256 will be recorded only after final packaging and verification. The developer dSYM is not a user download asset.

This draft authorizes no publication. Private API Preview route, signing/notarization route and project-wide license remain separate owner decisions. Current implementation provenance and historical acknowledgement are in [THIRD_PARTY_NOTICES](../THIRD_PARTY_NOTICES.md). No tag, upload or Release was created.
