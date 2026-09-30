# Build 16 identity migration

## Scope and identity

- Old: `local.macmousegesture.poc`.
- Permanent: `io.github.double-u-zw.macmousegesture` (owner decision).
- Version: `0.2.0-beta.1`; Build: `16`. Unlike Build 15, CFBundleShortVersionString now contains the exact beta version as requested; BetaVersion remains the same.
- Build 15 core gesture hardware acceptance was reported PASS by the user, including both buttons, all directions, Spaces/Mission Control/App Exposé and reconnect without app restart. Core gesture implementation is frozen.

## Preferences

`ProductIdentity.migrateSettings` executes under the existing instance lock, before lazy AppViewModel initialization or ConfigStore.load. It reads the legacy persistent domain and allowlists the eight actual fields in `gesture.configuration.v1`, plus `onboardingCompleted`. Only absent destination fields are filled; existing false values and malformed values are not overwritten. Marker `bundleIdentifierMigrationV1Completed` is written last. Repeated startup preserves later edits. The old domain is never deleted. There is no persistent onboarding step other than completion.

Real pre-upgrade settings: buttons 3/4, enabled, both axes enabled, horizontalInvert=true, sensitivity=777, deadZone=9, freezePointer=true, onboardingCompleted=true. New domain initially absent. Local evidence excludes unrelated preference keys.

## Login item

No login preference exists: the switch reflects `SMAppService.mainApp.status`. No helper or LaunchAgent exists. Build 15 is currently registered and enabled at `/Applications`. To preserve this user's enabled intent without duplicate active registration, use the existing Build 15 switch to unregister before replacing the bundle, then use Build 16's switch to register. Stop before replacement if unregister fails. Fresh installs are not automatically opted in. This is an installation procedure, not an invented UserDefaults setting or an automatic cleanup of system records. Future Build 15 upgrades must follow the same old-off/new-on sequence; macOS approval may still require the user.

## Single instance

Retain the legacy Application Support lock namespace deliberately. Builds 13–16 contend on the same inode regardless of installation path. Current and legacy IDs are searched when activating an already-running copy; the existing pre-Build-13 guard remains. No lock file is removed.

## Permissions and storage

`ACCESSIBILITY_REAUTH_MAY_BE_REQUIRED`. No TCC reset, permission transfer, database modification, or automated System Settings clicks. Exact behavior awaits the installed app. No user content/cache/log directory migration is needed; the sole app-managed Application Support content is the shared lock, diagnostics remain memory-based and redacted.

## Validation so far

- 74/74 Swift regression checks (67 existing + 7 identity tests) PASS.
- 15/15 native Bridge contracts PASS; total **89/89**.
- Package mutations expanded from six to eight: identity and exact marketing version added.
- Package, actual installation, single-instance, login restoration and permission results recorded below after execution.

## Manual acceptance remaining

About/version; permission grant if required; visible retained settings; login state across app restart and actual next login; two side buttons/four directions quick smoke, Spaces/Mission Control/App Exposé, one disconnect/reconnect. Automated tests do not substitute for physical mouse actions.

## API references

Apple [persistentDomain(forName:)](https://developer.apple.com/documentation/foundation/userdefaults/persistentdomain(forname:)) documents reading only the named persistent domain. Apple [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) identifies registration with the main application. These references do not imply TCC authorization inheritance.
