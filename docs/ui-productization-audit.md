# Beta UI productization audit

2026-09-30. Based on the current SwiftUI/AppKit views and live Build 15 settings. Core gestures and Build 16 identity migration remain frozen.

| Current surface | What users need | Development information / action |
|---|---|---|
| General tab | Purpose, enable, login, permission, simple status | Merge gesture controls into one primary settings page; avoid repeated permission explanations |
| Gestures tab | Side buttons, shared four-direction map, axes, direction, feel | Keep every actual control; place less frequent feel controls in collapsed disclosure |
| Diagnostics tab | Retry, permission/help, copy/export | Hide event/sequence/restart/failure counts and raw report behind explicit collapsed diagnostics |
| About | Icon, name, version/build, purpose, acknowledgements | Remove Git commit, OS build string and engineering context; show bundled notices via explicit entry |
| Welcome | What app does, four-direction mapping, start | Remove private interface/validation-environment lecture |
| Permissions | Why Accessibility is needed, current state, open settings | Optional input monitoring moves to collapsed help; no HID terminology |
| Side-button test | Waiting/detected, gesture confirmation, continue/later | Remove raw last-button string, engine terminology and input-count explanation; retain existing completion conditions |
| Completion | Ready, lives in menu bar, finish | Retain state machine and persistence exactly |
| Menu bar | Status, enable, settings, about, quit | Remove diagnostic/restart/login duplicates from menu only; functions remain in settings/help |
| Login/direction | Clear native toggles | Keep existing bindings and backend behavior |

No existing ordinary page contains 67/82 test-suite counts; no need to invent removals. Actual leaks are About GitCommit, diagnostics counters, raw button label, engine terminology and technical onboarding copy. Do not label a mouse “connected” from an enabled event tap; show functional availability instead.

Implementation: native three-tab window (settings, help, about), compact main page with product, gesture controls, general controls and status. Use existing icon, native Form/Section/Toggle/DisclosureGroup. No new UI framework or developer mode. No state machine, permission, login or identity behavior change.

Validation will distinguish automatic tests/compilation from real visual/hardware acceptance. Build 16 identity artifact is preserved; UI candidate uses an isolated output directory and the same version metadata unless instructed otherwise.

## Implementation and automated results

- Combined general and gesture controls into Settings; Help contains troubleshooting and explicitly collapsed diagnostics; About contains icon/name/version, existing project URL and bundled acknowledgements.
- Removed normal presentation of commit SHA, system build string, gesture counters/restart/failure/sequence metrics, raw last-button label, HID/private-interface explanations and engine terminology. Detailed redacted reports and export remain unchanged.
- Every existing gesture setting remains bound to its original action; sensitivity/dead-zone mapping and debounce untouched. Optional input-monitoring entry remains in Help and permission disclosure.
- Welcome → permissions → side-button test → completion retains the exact transitions and completion predicate. Skipping does not mark completion. No physical input or completion success is fabricated.
- Menu reduced to app/status, enable, settings, about, quit; login/retry/diagnostics are available within settings/help.
- 77/77 Swift checks + 15/15 Bridge contracts = **92/92 PASS** (89 prior + 3 UI wording tests).
- Isolated SwiftUI/AppKit compile and dSYM generation PASS. Only existing Swift legacy-driver deprecation warnings appeared.
- GUI and physical mouse smoke results will be recorded separately. The appearance is subject to user visual acceptance, not an automated aesthetic verdict.


## Installed UI candidate and user confirmation

- UI code commit `6bb9bcb`; built source `290b12bea3fb57951cf1f1b35303c8e86d779ba0`.
- App artifact: `<project-root>/build/ui-preview/0.2.0-beta.1-build16-290b12bea3fb57951cf1f1b35303c8e86d779ba0/MacMouseGesture.app` (separate from the immutable Build 16 identity candidate/DMG).
- Installed `/Applications/MacMouseGesture.app`: permanent ID, version 0.2.0-beta.1, Build 16, GitCommit matches source; strict signature/bundle verifier PASS. Running executable confirmed at the installed path (PID 51248 when checked).
- User explicitly confirmed: “正常显示，主要开关完整可见” for the new three-entry settings/help/about window. No claim of automated aesthetic approval.
- Actual persisted settings and onboarding values unchanged after replacement. System registration readback after app restart: one enabled permanent-ID login item; legacy entry remains disabled. User had confirmed enabling new login registration succeeded.
- Native UI automation retained stale legacy identity / timed out for the new identity. Therefore no automated claim is made that all onboarding/About/menu/permission refresh screens were exercised. Their source compiles and existing state/persistence tests pass; full visual review remains manual.
- Protected implementation files compared to identity completion commit `98bb456`: Bridge, GestureCore, mouse input, HID observation, engine/recovery, single-instance, ProductIdentity migration, LoginItemController, ConfigStore and OnboardingState all unchanged. main.swift UI diff is limited to menu construction/status wording and window size.
- Hardware smoke (both buttons, Spaces/Mission Control/App Exposé and reconnect) was not performed during this UI pass. Build 15 user acceptance remains the historical core baseline.
- Manual pages: main settings; welcome; permissions; side-button test; completion; About/acknowledgements; menu bar. Also inspect expanded feel controls and help/diagnostic disclosure. Completion requires actual side-button detection and user gesture confirmation; do not bypass it just to obtain a screenshot.
