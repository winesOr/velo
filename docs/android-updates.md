# Android GitHub updates

Velo self-update is enabled only when an Android build explicitly sets `ENABLE_UPDATE_CHECK=true`; GitHub distribution workflows also set `VELO_ANDROID_GITHUB_UPDATE_BUILD=true`, which is the only path that adds the `REQUEST_INSTALL_PACKAGES` permission. Store builds leave both disabled and do not advertise an installer they cannot use with their signing key. Velo checks the latest public, stable GitHub Release and, after an explicit download action or an enabled preference, downloads the matching APK. Automatic download defaults off. The installer remains an Android system screen: the user must allow Velo to install apps when requested, then confirm the update. A Git push or a tag without a published Release does not deliver an update.

## Publish a version

1. Configure repository Actions secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_SIGNING_CERT_SHA256` with the same long-lived release signing key used by the installed app. Both Android GitHub build workflows use this shared configuration and verify every release APK against the certificate fingerprint. The certificate secret is the SHA-256 fingerprint printed by `apksigner --print-certs`. Keep the keystore, password, and fingerprint configuration out of Git. The workflow fails closed if any secret is missing, invalid, or does not match the built APK.
2. Increase the build number in `pubspec.yaml`; for example, `2.23.23+4204` becomes `2.23.23+4205`. The build number must increase even when the visible version changes.
3. Commit the intended version and changes to the protected `main` branch. In GitHub Actions, run **Android Release** from `main`, using the unique tag `v2.23.23+4205`. `v2.23.23` is also accepted when it matches the visible version and has not already been released; use the full version/build tag for subsequent builds.
4. Leave **publish** enabled for a public stable Release. Disable it to create a draft for inspection; draft and prerelease entries are ignored by the updater. Existing Releases and their assets are never overwritten, and an existing tag must point to the workflow's exact commit.
5. The workflow serializes all Android release runs, verifies that the candidate build is greater than every published stable Android release, confirms the workflow commit is still `origin/main`, and verifies the built package, version, and signing before attaching `velo-android-universal.apk` and `velo-update.json`. Both files must remain in the same Release.

The first version containing this updater must be installed manually. A phone with a differently signed build cannot accept an in-place update from the release key; use the existing signing key to preserve in-place upgrade compatibility. Do not remove the old app merely to test updates, because uninstalling can erase app data.

## Asset contract

`velo-update.json` uses schema version 1 and contains `version` (visible version), `buildNumber` (Android version code), `packageName` (`com.wines.velo`), and `assets`. The universal asset entry contains its exact Release filename, `abi: "universal"`, the lowercase SHA-256 hash, and byte size. Downloads are resolved from the Release's assets rather than a URL supplied in this manifest. Android independently rejects wrong-package, incompatible-signature, and non-increasing-version APKs before opening the installer.

## Release acceptance

- Install an older build signed with the release key, then publish a higher build number using that same key. Confirm opening Velo detects and downloads it, the installer opens, and existing settings survive the upgrade.
- Test permission denial, granting installation permission and returning to Velo, cancelling installation, download interruption, a checksum mismatch, and a same-version higher-build update.
- Repeat once with automatic download disabled and use the settings page's manual check/download controls. Verify a draft Release is ignored.

Automated checks do not replace the signed-device upgrade test. The new workflow alone does not configure signing secrets, publish a Release, or update an already installed version that lacks this updater.
