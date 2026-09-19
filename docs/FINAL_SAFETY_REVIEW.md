# Final safety review — 2026-09-19

This fork is **not a stable Siri AI enablement release**. Recognition of iOS 27 RC `24A435` / release `24A437` is separate from permission to access system data. Both builds are now blocked before the private API, including when write flags are explicitly changed. No device installation or system modification is part of this review.

## Compatibility evidence and limits

- The build recognition list is in `GestaltEdit/GestaltAccess.m`, `isRunningSupportedOS`.
- The independent access allowlist, `isSystemAccessAllowed`, contains only the six original beta build identifiers. Unknown builds fail closed.
- [The upstream access primitive](https://github.com/forcequitOS/bad_query) claims iOS support only through 27 beta 4. [The GestaltEdit author states that beta 5 fixed the vulnerability](https://github.com/frs0n/GestaltEdit/issues/2#issuecomment-5252980224). Adding an OS identifier cannot repair that access path.
- No paired, verified MobileGestalt dumps from beta and release were obtained. Structure equivalence or differences are **NOT VERIFIED**. Checking root/CacheExtra dictionaries validates only basic shape, not key meanings or Siri compatibility.
- The original MobileGestalt write algorithm is unchanged (normalized save-body SHA-256 `633438f74c651d8fe9361df90a1dd8d055da1d225345b15b890b62699a1c4268`). It is excluded from read-only compilation, not claimed to be transactional or safe.

## Corrections made in this review

| Risk | Correction |
| --- | --- |
| Whitelist interpreted as working support | Block RC/release before API access and explain the block on screen |
| Automatic first-launch access | Manual start on original beta builds only; no read-only startup/pull-to-refresh acquisition |
| Unlimited retries and live re-reads for export | One cached, immutable snapshot or cached failure per process; backup cannot start the first read |
| Lease persisted across UI lifetime | Invalidate after success/failure in `@finally`; direct connection is blocked in probe mode |
| Mapped reads and unchecked data | Bounded non-mapped O_RDONLY read, same descriptor checks, regular file, no final-path symlink, root/CacheExtra validation |
| Hidden write/automation paths | Early refusal before backup/access; compile out writer; test invalid flags and deny writes on RC/release |
| Existing app replaced by probe install | Separate probe Bundle ID and display name; signed package must preserve isolation |
| Backup collision/partial file/privacy | UUID names, protected staged file, byte verification, rename refusing overwrite, exclude probe backup directory from system backup |
| Legacy tag workflow could publish unsafe artifact | Release job cannot run in this fork; manual reviewed workflow has read-only repository permission |
| Source greps treated as execution tests | Add host behavior tests with stub bridge, negative compilation tests, binary symbol and identity checks |

There was no refactor of MobileGestalt mutation logic, presets, spoofing fields or the private API bridge. UI, read-only access, backup handling and CI changes are safety corrections, not a claim of production support.

## What verification does and does not establish

Run `node tests/verify-source.mjs` for source regression assertions. On a Mac, run `bash tests/run-safety-tests.sh` for synthetic-file behavior and compiler rejection tests. These tests deliberately do **not** link `BadQueryBridge.m`; they cannot validate a real exploit or phone compatibility. The CI workflow also builds an unsigned iOS archive, rejects write syscalls/WebKit linkage, checks the separate bundle ID and emits file hashes.

CI evidence must refer to the exact reviewed commit and successful run. A previous run for `207978a` is superseded. A successful archive or static scan does not prove the absence of every bug, network behavior or private-API side effect.

## Rollback boundaries

**Source rollback:** upstream baseline `bca57fdd8858f5906952f4fe20b22486f3b87bf1`; pre-final-review baseline `207978a17c9f27f2684c089264e959781999b879`. A full Git bundle and both source ZIPs were created locally before edits. The bundle was verified and cloned into an isolated directory; both baselines were checked out with clean diffs. Restore by cloning the bundle to a NEW directory and selecting the desired baseline. Do not overwrite a dirty working tree or force-push the fork.

**Device rollback:** NOT ESTABLISHED. There has been no install, signing, MobileGestalt read/write, Apple ID handling or restart in this review. Thus no phone-side change from this review needs undoing. This is not a fresh audit of changes made independently by the user or other software.

A MobileGestalt plist is not a full device snapshot. Even an encrypted local device backup does not establish that this protected system cache or an exact RC OS build can be restored. [Apple's factory restore erases information/settings and installs the latest software](https://support.apple.com/en-us/118107). Do not use a phone restore as an automatic rollback test. Do not disable Find My, erase, update, install profiles or use Restore in this app as part of this review.

If a probe was independently installed, first export any wanted app-private data privately; deleting that isolated app deletes its private files, not necessarily any system changes previously made by another version. If a system write ever occurred, uninstalling does not roll it back. There is no verified automatic system recovery routine here.

## Signing and residual risks

- Signing normally changes an executable's embedded signature; comparing the entire signed binary's hash to the unsigned binary is not a valid equality requirement. [Apple's code-signature documentation](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes) describes embedded signatures. Preserve separate before/after hashes and audit signature validity, team/app identifiers, entitlements, provisioning profile, executable payload/resources and added plugins/frameworks. No signed package has been reviewed here.
- A sandbox lease may grant broader rights even though our file descriptor is O_RDONLY. Releasing it is best effort because the unchanged bridge does not report release errors. Force-quitting terminates the process but is not a demonstrated reversal of private API side effects.
- File metadata consistency checks are not an atomic system snapshot and cannot prove semantic compatibility. Invalid or changing files are rejected; unknown key meanings remain unverified.
- The single-attempt latch is per process. Relaunching starts another process; after failure, do not repeatedly relaunch to retry. RC/release remains blocked on every launch.
- Existing upstream write error recovery is best effort and may itself fail; post-write verification does not implement a guaranteed rollback. It is preserved but excluded, never relied upon on the target phone.
- Account status, app signing trust, third-party tool behavior and actual device backup restorability remain outside what a source audit can guarantee. No claim of zero risk or Apple ID immunity is made.

## Execution gate

`BLOCKED — NO DEVICE EXECUTION ON RC / RELEASE`.

Do not use older artifacts as recovery installers. The historical copies exist only for source recovery/audit. Do not switch write flags, spoof OS versions, replace the original installed app, upload phone backups to GitHub, or treat repository rollback as a phone rollback. Reopening device work requires independent evidence of a supported access path and a separately reviewed recovery plan; neither is supplied by this patch.

Original LICENSE and author notices are retained. This remains a noncommercial safety-review derivative, not an upstream release or an endorsement by the author.
