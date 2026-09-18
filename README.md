<div align="center">

<img src="docs/icon.png" alt="GestaltEdit app icon" width="128" height="128">

# GestaltEdit

**A MobileGestalt utility that runs directly on iPhone and iPad**

<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/daily?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>
<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/weekly?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>

<p>
  <a href="https://github.com/frs0n/GestaltEdit/releases/latest"><img src="https://img.shields.io/github/v/release/frs0n/GestaltEdit?style=flat-square&label=release&color=6E56CF" alt="Latest release"></a>
  <a href="https://github.com/frs0n/GestaltEdit/releases"><img src="https://img.shields.io/github/downloads/frs0n/GestaltEdit/total?style=flat-square&label=downloads&color=6E56CF" alt="Downloads"></a>
  <a href="https://github.com/frs0n/GestaltEdit/stargazers"><img src="https://img.shields.io/github/stars/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="Stars"></a>
  <img src="https://img.shields.io/badge/iOS%20%7C%20iPadOS-27-000000?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Noncommercial-6E56CF?style=flat-square" alt="PolyForm Noncommercial License"></a>
</p>

<a href="https://github.com/frs0n/GestaltEdit/releases/latest"><b>Download IPA</b></a> ·
<a href="#requirements">Requirements</a> ·
<a href="#install">Install</a> ·
<a href="README.zh-CN.md">简体中文</a>

</div>

Edit `com.apple.MobileGestalt.plist` on-device. Capability presets, a full field editor, and backup/restore.

> [!WARNING]
> This app uses private APIs and modifies system cache data. Bad MobileGestalt values can break system features and may require restoring the device. Use only on devices you own.

> [!IMPORTANT]
> GestaltEdit is free and its source is public. Without authorization, you may not sell it.

## Features

**Presets** — Dynamic Island, device model name, boot chime, charge limit, tap to wake, Camera Control, Apple Pencil, Action Button, Collision SOS, Always-On Display, wallpaper parallax, Stage Manager, iPad app compatibility, Siri AI US region, and more. Tick what you want, tap Apply.

**Field editor** — Search and edit any MobileGestalt key by hand when a preset doesn't cover it.

**Backups** — Every write is backed up automatically. Back up, import, export, and restore at any time.

## Requirements

- iOS / iPadOS 27 beta 1–4
- iOS / iPadOS 27.0 RC (24A435) passes the version gate; the `bad_query` access path is not verified on this build
- iOS / iPadOS 27.0 release (24A437) passes the version gate; the `bad_query` access path is not verified on this build
- Developer Mode enabled
- A signing tool such as [iLoader](https://github.com/nab138/iloader)

The source defaults to a read-only compatibility probe (`GESTALT_READ_ONLY_PROBE=1`, `GESTALT_ENABLE_WRITES=0`). The probe checks access with `O_RDONLY`, can export backups, and fails the build if probe and write modes are enabled together. Every MobileGestalt save path still fails closed before opening the file for writing.

## Install

1. Download `GestaltEdit.ipa` from [Releases](https://github.com/frs0n/GestaltEdit/releases/latest).
2. Use a trusted local signing method. Do not provide a primary Apple ID password or 2FA code to an unverified third-party signing service.
3. Import the IPA to sign and install it, then trust the certificate under Settings → General → VPN & Device Management.

## Credits

- [Nugget](https://github.com/leminlimez/Nugget) — presets and iPadOS support
- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop), [bad_query](https://github.com/forcequitOS/bad_query), [0xJohnny](https://x.com/0xjohnny) — file access research
- [neospring](https://github.com/rooootdev/neospring) — respring implementation

Not affiliated with Apple or the projects above.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free for noncommercial use; commercial use is not permitted.
