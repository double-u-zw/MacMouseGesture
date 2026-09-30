# GitHub first public Preview gate

Date: 2026-09-30. Current branch: `productization/github-beta`. This gate does not publish, push, create a tag, or rewrite history.

## Build 15 current gates

| Gate | Status | Scope |
|---|---|---|
| MMF_SOURCE_PROVENANCE | PASS — current tree engineering evidence | Both old constructors removed; specification and behavior-contract replacement. Historical attribution retained; not a legal guarantee or clearance of old Git history. |
| MMF_BINARY_LICENSE | CLOSED_FOR_BUILD15_CURRENT_SOURCE | New binary built solely from replacement source; no current MMF code derivative found. This does not clear old Build 14 binaries or assign a project-wide license. |
| APPLE_PRIVATE_API | OWNER_DECISION | PRIVATE_API_DEPENDENCY_REMAINS; NO_DOCUMENTED_EQUIVALENT_FOUND. |
| APPLE_PRIVATE_API_CONTRACT | LEGAL_REVIEW_REQUIRED | Applicable SDK/program/distribution terms remain separate. |
| APPLE_HEADER_PROVENANCE | LEGAL_REVIEW_REQUIRED | Minimal ABI/protocol facts remain; no complete headers included. |

See [provenance](system-gesture-provenance.md), [specification](system-gesture-bridge-spec.md), and [Build 15 validation](build15-validation.md). No publication is authorized by these engineering results.

## Historical publication audit facts (Build 14)

## PASS

- Current branch is `productization/github-beta`. The previous publication-audit pass started clean; this provenance pass preserved its existing README and document changes. `main` and `v0.1.6-build12` remain untouched.
- Current public-facing docs explain the product, tested target, installation flow, permissions, privacy, known issues, and Release download location.
- Release DMG and its recorded SHA256 agree. DMG is 2.2 MB; a separate dSYM is in the developer archive and is not a user release asset.
- Pattern scan found no private key, common token, or credential value in reachable Git objects. This is not a comprehensive guarantee.
- Third-party audit and notices identify the MMF and Apple OSS sources and distinguish protocol/API usage from vendored source. No complete Apple private header was found in `Sources`; the Build 15 replacement uses the minimal `MGNativeHID` declaration.
- No repository visibility change, push, Release creation, history rewrite, core gesture change, or stable tag movement was performed.
- App icon identity is consistent in README, app assets, ICNS, and the current app metadata; no replacement icon was introduced in this pass.

## MANUAL_CHECK

- On the actual intended release build: both side buttons; all four directions; pause/continue; reverse; release finish; fresh user first launch and permission flow.
- Physically disconnect and reconnect the mouse without restarting the app; Build 15 recovery remains unaccepted on hardware.
- Normal-user macOS execution now passes both cross-process persistence tests: all 67 original checks and 15 Bridge checks pass. The previous restricted-environment failures are closed for this candidate.
- Test downloading the final signed/notarized-or-explicitly-approved package in a clean user/browser context, Gatekeeper flow, installation, and launch. Current local package is not notarized and does not have Developer ID signing.
- Before finalizing the README/release description, verify the target macOS/device claims against the final build and chosen distribution route.

## OWNER_DECISION

- **Bundle ID:** choose the permanent reverse-DNS ID before producing the first public Preview binary. See [bundle ID audit](bundle-id-audit.md). `local.macmousegesture.poc` is the current development ID.
- **Git history:** accept the personal author/committer email and historical public certificate fingerprint, or authorize a reviewed clean public history plan. See [history privacy audit](git-history-privacy-audit.md).
- **Distribution:** decide whether a non-notarized, non-Developer-ID package is acceptable for a limited Preview. Do not present it as a normal trusted download.
- **MMF route:** independent implementation completed; inspect its evidence and retain historical obligations. No permission request was sent.
- **Apple route:** select Route 1, 2, or 3 in [the API decision](apple-private-api-decision.md); applicable contractual and declaration-source questions remain separate from engineering implementation.

## BLOCKER

- **Historical Build 14 binary:** its MMF license question remains unresolved; Build 15 closure cannot be applied retroactively. Build 15 manual acceptance and Apple decisions remain outstanding.

Apple private API dependency is a known product architecture fact, not a technical bug to fix by renaming symbols. Route selection and contract review retain their separate statuses above.

## First public Preview runbook (after blockers and owner decisions close)

1. Choose the MMF route and Apple product/distribution route. For a binary Preview, close MMF_BINARY_LICENSE and resolve the applicable Apple contract/declaration-source review; record the evidence. A source-only publication uses its own scope and does not imply binary approval.
2. Confirm permanent Bundle ID and publisher identity; migrate/build against that identity and recheck settings, login registration, permissions, and lock path.
3. Decide the Git history plan; if rewrite is authorized, preserve private refs/tags and review the proposed sanitized history before any force push.
4. Complete the manual Build 15 acceptance above. If code or identity changes, rebuild the release package.
5. Run `./scripts/test.sh`, the existing Beta package checks, and a fresh public-history scan against the exact release commit and assets.
6. Review README, privacy, security, install, troubleshooting, notices, issue templates, Release draft, and `git status`.
7. Create tag `v0.2.0-beta.1` on the final reviewed commit; verify the tag target. Do not move `v0.1.6-build12`.
8. Push the approved branch and tag only after explicit owner authorization.
9. Change the GitHub repository to Public only after the exact public commit/history and assets are approved.
10. Create GitHub Release `v0.2.0-beta.1`, mark it **Pre-release**, and upload only the matching DMG and `SHA256SUMS` (not dSYM).
11. Publish only after reviewing the final page and uploaded checksum.
12. From a logged-out browser/clean user, verify the public repository, Release page, asset download, SHA256, install, and first launch.
