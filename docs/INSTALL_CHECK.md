# Installation check, not a compatibility release

The user clarified on 2026-09-25 that testing means signing, installing and launching an app, **not flashing or reinstalling iOS**. The stated version is iOS 27.0 release; its exact current build has not been independently verified.

The `build-install-check.yml` manual workflow creates a separate unsigned test artifact with Bundle ID `me.ssus.gestaltedit.installcheck`. It defines `GESTALT_INSTALL_SMOKE_TEST=1`, `GESTALT_READ_ONLY_PROBE=1`, `GESTALT_ENABLE_WRITES=0` and the Swift read-only condition. Only this separately audited artifact is a candidate for installation/launch testing. The ordinary read-only artifact remains blocked on RC/release and must not be substituted.

In installation-check mode, `GestaltAccess` is a refusal-only implementation: connect, both reads and save return an error. The original access implementation and `BadQueryBridge.m` body are excluded at preprocessing, including on beta/unknown builds. The app shows an installation-check screen and the public OS build, without Tools/Fields/Restore controls. It does not read MobileGestalt, acquire a sandbox lease, change Siri or run respring. Normal installation still creates an app/container and signing trust may change; this is not zero phone-side change.

Original mutation code and the bridge body are retained without algorithm changes. This mode is deliberately **not functionally equivalent** to GestaltEdit and cannot count as stable Siri AI support. Upstream still specifies beta 1–4, and the author says beta 5 fixed the access vulnerability. Removing a safety gate cannot repair it.

## Verification

Existing source assertions and isolated safety tests remain required. `tests/run-install-smoke-tests.sh` links the actual source files with the installation flag, not a mock bridge; it asserts that `BadQueryLease` is absent and every access method refuses, and rejects unsafe flags. The iOS archive must have the isolated Bundle ID, no embedded profile/signature/plugins/frameworks, no private bridge/write/dynamic-loader symbols or target sandbox strings, and no direct WebKit/network framework dependencies. CI emits complete file hashes, binary/IPA hashes, symbols and dependencies. These checks do not approve a subsequently signed package.

## Required gates before installation

1. Record current iOS/build without collecting device identifiers or account secrets.
2. Choose trusted local signing; the user handles credentials/2FA. No unknown profiles, MDM or root certificates.
3. Preserve/verify a recent encrypted backup as a precaution. First enabling encryption can replace previous backups: preserve history first. Backup presence or a lock icon does not prove all data can be restored.
4. Audit the signed app: team/application identifiers, entitlements/profile, expiration, isolated Bundle ID, resources/executable payload and added components. Signing legitimately changes signature bytes; whole-file hashes need not match. No signed sample is available yet.
5. Check for app-ID collision and record existing developer-mode/trust state. Developer Mode may require a restart, a separately disclosed device action.
6. Confirm this exact signed artifact and scope before installing. Launch once, observe the installation-check banner, then exit. No protected-cache access or Siri test is included.

## Emergency boundaries

An app-only failure does not call for a firmware restore. Stop testing, preserve a redacted error, remove only the newly installed isolated app if needed. Deleting the app removes its container but may not undo trust/developer settings; do not indiscriminately delete shared profiles. For an unresponsive phone outside an active update, follow model-specific Apple restart guidance. Recovery-mode Update/Restore are not authorized by this install-only task; they require a separate decision and Restore erases data. Never use an unverified MobileGestalt backup as a repair.

References: [upstream](https://github.com/frs0n/GestaltEdit), [author on beta 5](https://github.com/frs0n/GestaltEdit/issues/2#issuecomment-5252980224), [encrypted backups](https://support.apple.com/en-us/108353), [unresponsive iPhone](https://support.apple.com/en-us/116940), [restore screen and Update](https://support.apple.com/en-us/108969), [factory restore data loss](https://support.apple.com/en-us/118107).
