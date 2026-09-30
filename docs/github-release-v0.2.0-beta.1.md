# MacMouseGesture 0.2.0-beta.1 — release notes

**Beta Preview · Build 17 · Pre-release**

Final release candidate: **0.2.0-beta.1 / Build 17**.
Bundle ID: `io.github.double-u-zw.macmousegesture`.
The published DMG and matching `SHA256SUMS` are the authoritative release assets. Historical Build 16 artifacts are not release assets.

## Highlights

- Hold either enabled mouse side button and drag left/right for continuous Spaces navigation, up for Mission Control, or down for App Exposé.
- Pause, continue, reverse and release gestures; configure side buttons, horizontal direction and feel.
- Local settings, optional launch at login and single-instance protection.
- Compact Chinese settings/help/about interface and four-step setup guide.
- Bounded recovery after mouse removal. Reconnect behavior passed the user's Build 15 core acceptance; the implementation remains frozen.

## Installation and permissions

Download the DMG and matching `SHA256SUMS` from this Release, verify the checksum, drag the App to Applications and launch that installed copy. Follow the setup guide to grant Accessibility and test your mouse. Optional Input Monitoring supports additional diagnostics.

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

The developer dSYM is retained for engineering diagnostics and is not a user download asset. The project source is licensed under MIT; third-party notices remain in [THIRD_PARTY_NOTICES](../THIRD_PARTY_NOTICES.md). This Preview is not notarized.
