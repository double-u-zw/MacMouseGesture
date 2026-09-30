# Build 15 candidate validation

Version: 0.2.0-beta.1 / Build 15. Source replacement only; no installation or running-app replacement performed.

## Automated evidence

- Original regression checks: **67/67 PASS** in normal macOS user context.
- New non-posting native Bridge contracts: **15/15 PASS**; total **82/82**.
- Pre-replacement C API baseline: **12/12 PASS** (behavior properties, not binary golden).
- Isolated arm64 app compilation and full dSYM generation: **PASS**.
- Evidence logs: ignored local `build/bridge15-evidence/`; packaged final evidence recorded below after packaging.
- All Swift source hashes match the pre-change snapshot, including bounded automatic recovery after mouse removal. No state-machine or input behavior code changed.

## User hardware acceptance — NOT RUN

| Item | Status |
|---|---|
| Side Button A: left, right, up, down | PENDING_USER_VALIDATION |
| Side Button B: left, right, up, down | PENDING_USER_VALIDATION |
| Pause, reverse, release, cancel | PENDING_USER_VALIDATION |
| Rapid repeated gestures; continuous Spaces animation | PENDING_USER_VALIDATION |
| Mission Control and App Exposé | PENDING_USER_VALIDATION |
| Connect → gesture → unplug → wait → reconnect → gesture without app restart | PENDING_USER_VALIDATION |

No physical mouse action was performed by automation; therefore no hardware PASS/FAIL is claimed. After user testing, record actual PASS or FAIL for each row. Payload creation/readback does not prove Dock response.

## Final candidate evidence

- Source commit: `759377a965e41f069807f1949d2bf7a59c1c4a56`; exported with `git archive`. Unrelated uncommitted publishing documents were not build inputs. `SourceTreeDirty=false` describes that exact committed archive, not the root checkout.
- Runtime commit: `37b3e5e`; provenance commit: `759377a`. Subsequent commits only update audit/validation documents.
- Final archive rerun: **67/67 original + 15/15 Bridge = 82/82 PASS**.
- Package mutation rejection: **6/6 PASS** (version, commit, dirty, notices, icon, binary).
- Bundle checks before packaging and from mounted readonly DMG: **PASS**.
- DMG checksum verification, Applications symlink and executable/dSYM UUID pairing: **PASS**.
- Non-posting horizontal/vertical probes: **PASS**; no events posted, Dock response unverified.
- Version: **0.2.0-beta.1 / Build 15**, arm64.
- App: `<project-root>/build/beta-preview/0.2.0-beta.1-build15-759377a965e41f069807f1949d2bf7a59c1c4a56/MacMouseGesture.app`
- DMG: `<project-root>/build/beta-preview/0.2.0-beta.1-build15-759377a965e41f069807f1949d2bf7a59c1c4a56/MacMouseGesture-0.2.0-beta.1-build15.dmg`
- DMG SHA256: `495260ff9da0edce75cdbbb7925994ed0264be49d962632127b1e9f7890130a2`
- Signing: **MacMouseGesture Local Development**, local self-signed, hardened runtime enabled, strict verification PASS; not Developer ID, no secure timestamp.
- Notarization: **NOT_SUBMITTED / NOT_NOTARIZED**.
- Evidence: candidate `developer/` contains tests, compile, package-checks, probe, verify, signature, DMG verification, source metadata and matching full dSYM.
- Build 14 DMG remains unchanged: `bcac6ae45f1fb8a2f90ec5aca3c28196112ab6ddc5f94d94c3c7a48563745c17`.
- `main` and `v0.1.6-build12` refs unchanged. No push, tag, release, visibility change, upload, install or running-app replacement.
