# Build 16 permanent identity dependency audit

2026-09-30. Owner fixed `CURRENT_PRODUCT_ID = io.github.double-u-zw.macmousegesture`.
`LEGACY_PRODUCT_ID = local.macmousegesture.poc`; Build 15 records remain historical.
This inventory was written before implementation, following code/metadata/script scans. Implementation and real installation now PASS; see [Build 16 results](build16-identity-migration.md). The old login registration is disabled and the new registration enabled; one active entry.

| Dependency | Old ID used? | Migration impact | Required action |
|---|---|---|---|
| Xcode project / PRODUCT_BUNDLE_IDENTIFIER | No Xcode project exists | None | Swift CLI build only |
| Info.plist / CFBundleIdentifier | Yes | Main product identity | Permanent ID; Build 16; short version 0.2.0-beta.1 as requested |
| Signing requirement and identifier | Yes | New code identity, same local certificate | Update signing/build scripts together; strict verification |
| UserDefaults.standard | Implicit | New preferences domain | One-time allowlisted import before model initialization, absent destination values only |
| gesture.configuration.v1 | Dictionary in legacy domain | All actual gesture settings | Preserve dictionary, including enable, buttons, axes, invert, sensitivity, dead zone, pointer freeze |
| onboardingCompleted | Boolean in legacy domain | Welcome may repeat | Migrate persisted completion; welcome/permission/test intermediate steps are memory-only |
| SMAppService.mainApp | Implicit main app identity | Old/new login registrations | No preferences key/helper. On actual upgrade unregister through running Build 15 before replacement, then restore enabled intent through Build 16; verify. Do not infer login choice from preferences or auto-register fresh users |
| helper / LaunchAgent | None | None | No target/plist to migrate |
| SingleInstance lock | Explicit legacy Application Support path | Changing path permits concurrent Build 15/16 | Retain legacy path as compatibility namespace; never unlink lock |
| Running-app activation | Explicit legacy ID | Duplicate launch should activate correct app | Search current and legacy IDs; retain older-build guard |
| Application Support | Lock only | No user content migration | Keep shared lock path |
| Cache / Logs / diagnostics | No app-managed ID-based persistence | No migration needed | Logs are bounded memory; explicit exports stay in chosen location; redaction unchanged |
| Packaging / verifier | Explicit ID and Build 15 | Incorrect package acceptance | Permanent ID, exact requested short version, Build 16; add identity mutation rejection |
| Regression suite | Random isolated suites, no product ID binding | Add migration coverage | Fresh, legacy, new wins, idempotency, onboarding, key isolation, partial values |
| README | No literal temporary ID found | None | Preserve prior uncommitted content |
| Docs / historical metadata | Yes | Historic facts must remain | Update only audit/gate/new migration record; old records are HISTORICAL_REFERENCE |

Accessibility: `ACCESSIBILITY_REAUTH_MAY_BE_REQUIRED`; never reset TCC or transfer permission records.
Login automation must use the app's existing switch, not write ServiceManagement databases. Failed unregister is a stop condition before replacement; registration requiring approval is a manual check.

---

## Historical pre-migration audit (preserved)

# Bundle ID audit

Date: 2026-09-30. This records the current identity and migration surface; it does not choose the product's permanent identifier.

## Current identifiers

- App bundle identifier: `local.macmousegesture.poc` (`Resources/Info.plist`, enforced by `scripts/build.sh` and `scripts/verify-beta.py`).
- No separate login-item/helper bundle is present. Login at Login uses `SMAppService.mainApp` for the main app.
- No LaunchAgent plist, helper target, or custom `UserDefaults` suite is present. App settings use the standard defaults domain derived from the main bundle identifier.
- Accessibility identity follows the signed app identity/designated requirement; it is not a separately configured identifier. Changing the bundle ID and/or signing identity can cause macOS to treat the app as a different TCC client and prompt for Accessibility again.
- The single-instance lock is under `~/Library/Application Support/local.macmousegesture.poc/` (see `Sources/MouseGesturePOC/SingleInstance.swift`); the directory is explicitly keyed by the current ID and would need a deliberate migration/compatibility decision. The login item is `SMAppService.mainApp`, not a separately named helper.

## If changed

Changing the ID can create a new UserDefaults domain, lose the user's current settings from the new app's point of view, require a migration if preserving settings is desired, change login-item registration identity, move the single-instance lock directory, and require renewed Accessibility authorization. Existing Preview users may see the old app and new app as separate apps. A signing Team ID / designated-requirement change adds a separate identity migration risk. Do not change only the plist: build guards, packaging verification, test fixtures, uninstall guidance, signing requirements, and identity documentation also contain the current ID.

## Decision

Fix the permanent reverse-DNS identifier before the first public Preview binary and keep it stable through subsequent signed updates. Possible forms, only if controlled by the owner, include `com.<owner-or-organization>.MacMouseGesture` or `io.<owner-or-organization>.MacMouseGesture`. These are examples, not availability checks or a recommendation of ownership.

**OWNER_DECISION_REQUIRED:** choose and confirm the permanent Bundle ID and publisher namespace. No identifier was changed in this audit.
