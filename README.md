<div align="center">

# VN Editor AppImage 🎬🍷🐧

[![GitHub Downloads](https://img.shields.io/github/downloads/pkgforge-dev/vn-editor/total?logo=github&label=GitHub%20Downloads)](https://github.com/pkgforge-dev/vn-editor/releases/latest)
[![CI Build Status](https://github.com/pkgforge-dev/vn-editor/actions/workflows/appimage.yml/badge.svg)](https://github.com/pkgforge-dev/vn-editor/actions)
[![Latest Stable Release](https://img.shields.io/github/v/release/pkgforge-dev/vn-editor)](https://github.com/pkgforge-dev/vn-editor/releases/latest)

<p align="center">
  <img src="AppDir/vn-editor.svg" width="128" />
</p>


| Latest Stable Release | Upstream URL |
| :---: | :---: |
| [Click here](https://github.com/pkgforge-dev/vn-editor/releases/latest) | [Ubiquiti VN Editor](https://www.ui.com/) |

</div>

---

AppImage made using [quick-sharun](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh), which makes it extremely easy to turn any binary into a portable package reliably without using containers or similar tricks.

**This AppImage bundles everything and it should work on any Linux distro, including old and musl-based ones.**

This AppImage doesn't require FUSE to run at all, thanks to the [uruntime](https://github.com/VHSgunzo/uruntime).

This AppImage is also supplied with a self-updater by default, so any updates to this application won't be missed, you will be prompted for permission to check for updates and if agreed you will then be notified when a new update is available.

Self-updater is disabled by default if AppImage managers like [am](https://github.com/ivan-hc/AM), [soar](https://github.com/pkgforge/soar) or [dbin](https://github.com/xplshn/dbin) exist, which manage AppImage updates.

<details>
  <summary><b><i>raison d'être</i></b></summary>
    <img src="https://github.com/user-attachments/assets/d40067a6-37d2-4784-927c-2c7f7cc6104b" alt="Inspiration Image">
  </a>
</details>

---

**VN Editor** is the Ubiquiti video editor application, packaged as a portable AppImage using Wine.

More at: [AnyLinux-AppImages](https://pkgforge-dev.github.io/Anylinux-AppImages/)

---

## How it's built

The Windows payload is extracted from the official installer **at build time**, so the AppImage ships the app itself (~805 MB compressed) and needs no network on first launch:

1. `wget` the installer `.exe` from Ubiquiti
2. `7z x -tzip` — the installer is a PE that embeds a ZIP archive
3. `msiextract` (msitools) — the app lives inside the embedded `VN.msi`, whose cab media uses obfuscated `filXXX` names; the MSI File table restores the real names
4. The resulting `VN/` tree is flattened into `AppDir/share/vn-editor`

Wine itself is not bundled — on first launch the AppImage downloads [pkgforge-dev/wine-AppImage](https://github.com/pkgforge-dev/wine-AppImage) (one-time), creates a prefix in `~/.local/share/wine-appimage/apps/vn-editor/` and syncs the payload into it.

The final DWARFS compression uses reduced memory settings (`DWARFS_COMP="zstd:level=19 -N 3 -W 4"`) because mkdwarfs' defaults OOM on machines with ~5 GB free RAM — see `make-appimage.sh`.
