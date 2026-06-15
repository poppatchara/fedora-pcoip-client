# Fedora 44 — HP Anyware PCoIP Client Installer

Unofficial install script for the **HP Anyware Client** (formerly *Teradici PCoIP Client*) on Fedora 44, repackaged from the official Ubuntu `.deb`.

- This is **not** an official HP/Teradici project.
- The client is **proprietary**; you must comply with the upstream license/EULA.
- `x86_64` only.

## What It Does

- Downloads the official HP Anyware `.deb` (Ubuntu 22.04 build)
- Extracts and installs to Fedora-native paths (`/usr/lib64/pcoip-client`)
- Forces X11/XCB (drops broken Wayland Qt plugin)
- Bundles Ubuntu `libprotobuf23` for ABI compatibility
- Applies `setcap` for USB redirection
- Optional: clipboard sync plugin (`--clipboard`)

## Quick Install

```bash
git clone https://github.com/poppatchara/fedora-pcoip-client.git
cd fedora-pcoip-client
sudo ./install.sh
```

### With Clipboard Plugin

```bash
sudo ./install.sh --clipboard
```

## Dependencies (Auto-Installed)

The script installs required packages via `dnf5`. RPM Fusion (nonfree) is enabled automatically if an NVIDIA GPU is detected.

## Uninstall

```bash
sudo ./uninstall.sh
```

## Notes

- The wrapper script forces `QT_QPA_PLATFORM=xcb` because the upstream Wayland build is broken against system Qt on Fedora.
- Capabilities (`cap_setgid`) are applied during install; re-apply manually if they get lost.
- Fedora 44 uses Plasma Login Manager (not SDDM) — no login screen conflicts.

## Credits

- Original Arch PKGBUILD by [Patrik Pira](https://github.com/ppira)
- Fedora adaptation by [Patchara T](https://github.com/poppatchara)
