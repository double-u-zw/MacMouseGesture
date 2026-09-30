# Pre-publication Git history privacy audit

## Scope and result

2026-09-30. **GIT_PRIVACY_CLEANUP_PASS applies to `productization/github-beta` and its reachable ancestry only.** The original `main`, stable tag, other development branch and `backup/pre-public-history` deliberately retain private historical metadata. They are local/private preservation refs, not part of the approved public ref set. An unrestricted `--all` scan will still find those retained values. Never push `--all`, `--mirror`, all tags, or the backup to publish this cleaned history.

The proposed public history contains the same 23 original development commits, followed by normal documentation/hygiene commits. Rewriting changes commit identities throughout the ancestry; it is not represented as a new ordinary cleanup commit. Author/committer names, timestamps, commit messages, ordering, file sets and all runtime/build/test/icon content were verified unchanged across every old/new commit pair. No historical file was deleted.

## Findings and disposition

| Item | Current HEAD before cleanup | Git history before cleanup | Action |
|---|---|---|---|
| Personal author/committer email | Private developer email | All 23 commits | PRIVACY_SENSITIVE: replace only identified owner email with owner-confirmed GitHub noreply |
| Actual local project/home paths | Build 15/16 and UI validation docs | Same historical documents | PRIVACY_SENSITIVE: project-root placeholder or home shorthand; retain artifact record suffixes |
| Local public certificate fingerprint | Already placeholder | One older distribution audit | PRIVACY_SENSITIVE correlation metadata: replace with placeholder; not a leaked private key |
| Signing identity labels | Generic product-local names, TeamIdentifier not set | Same | PUBLIC_OK: not a personal name, Apple ID or real Team ID; retain build behavior |
| File-content emails | No owner email | Regex hit was an icon `@2x.png` asset path, not email | PUBLIC_OK: keep assets; third-party attribution untouched |
| Secrets / credentials | No actual credential found | No actual credential found in text or binary scan | NO_SECRET_FOUND / NO_CREDENTIAL_FOUND; password-reading script syntax and scanner patterns are not credential values |
| Device identifiers | No actual serial/MAC/hardware UUID found | No positive real-device finding | Keep generic API/property names and synthetic fixtures |
| User-path tests | Synthetic names and privacy test fixtures | Same | PUBLIC_OK: preserve privacy regression coverage |
| Build archives | No tracked app/DMG/dSYM/private diagnostic archives | None in all reachable trees | Nothing removed; keep reviewed small baseline text records |
| Binary blobs | Product icons/design assets | Eight distinct binary blobs | Keep; byte scan found no identified owner path/email/credential; no embedded diagnostic archive found |
| Third-party names/notices | Historical MMF acknowledgement and Apple ABI provenance | Same | PUBLIC_OK: preserve notices, attribution and historical research facts |
| Release/code hashes | Useful evidence | Same | Preserve commit mentions and Release checksums; historical hashes refer to pre-rewrite source snapshots and are not rewritten artifact claims |

Initial complete inventory: 23 commits, 97 trees, 185 blobs, one annotated tag object. All reachable commit/tree/blob objects were enumerated, including deleted-path history checks. No historical file deletions were found. Text keyword matches were context-reviewed; binary contents were also checked for identified private values. This is an engineering scan, not an absolute security guarantee.

## Rewrite method and backup

- Official tool: [newren/git-filter-repo](https://github.com/newren/git-filter-repo), source revision `d7b75aca907380f608892cc289e616f195427b99`, reported version `31ebad4c8fb3`. Installed in a Git-ignored local tool directory after owner authorization.
- Local backup: `backup/pre-public-history -> 3ec9922b40318f1986b409e1ad21ad44ccbc9331`.
- Rewritten branch tip before documentation commits: `0a89e489d4bfbbd7907729a31f2eafb9638fa668`.
- Filtering ran first in an isolated bare single-branch clone. Full per-commit verification passed before updating the working repository branch. Uncommitted documents were saved and verified unchanged during ref/tree transfer.
- Rewritten blobs were limited to `docs/build15-validation.md`, `docs/build16-identity-migration.md`, `docs/distribution-audit.md`, `docs/ui-productization-audit.md`.
- Runtime files, tests, build scripts, icons and third-party notices were byte-identical for each commit pair. There was no reset, main/tag movement, push, visibility change or remote publication.
- Private before/after evidence, commit map and original uncommitted-document copies remain under ignored `build/public-history-private-backup/`. Do not publish this directory or the original refs.

## Public identity

Name retained: `wzw`.
Email: `171811796+double-u-zw@users.noreply.github.com` (explicitly provided by the owner).
Only this repository's future commit email was updated; no third-party identity was rewritten.

## Pending-file decisions

| File | Decision | Rationale |
|---|---|---|
| README.md | COMMIT_PUBLIC | User-facing features, target, installation, permissions, feedback, privacy and truthful licence status |
| docs/apple-private-api-decision.md | COMMIT_PUBLIC / PUBLIC_DOC | Concise technical dependency and owner decision record; no legal/Apple approval claim |
| docs/git-history-privacy-audit.md | COMMIT_PUBLIC | Redacted scope, results and preservation boundaries |
| docs/github-release-v0.2.0-beta.1.md | COMMIT_PUBLIC | Build 16 draft; FINAL_ARTIFACT_PENDING, no invented final checksum |
| docs/mmf-permission-request.md | KEEP_LOCAL_ONLY | Obsolete as a current release prerequisite; moved to ignored internal-only evidence, original preserved; never sent |

DELETE_OBSOLETE: none. Public source no longer links to the private request draft. No licence notice was deleted.

## Public-ref scan conclusions

- NO_PRIVATE_EMAIL_FOUND (owner-confirmed public noreply retained).
- NO_REAL_USER_PATH_FOUND (synthetic privacy fixtures retained).
- NO_SECRET_FOUND.
- NO_CREDENTIAL_FOUND.
- No real device privacy value identified.

These statements exclude intentionally retained original refs. Before any later push, recheck the exact public branch and selected tags. An existing remote's private history is not cleaned by this local operation; inspect/decide its publication separately before changing visibility. No new final distribution package was built after the rewrite: **FINAL_ARTIFACT_PENDING**.
