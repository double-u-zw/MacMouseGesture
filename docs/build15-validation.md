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
