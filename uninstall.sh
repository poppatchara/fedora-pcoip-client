#!/usr/bin/env bash
# HP Anyware PCoIP Client — Fedora 44 Uninstall Script
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "❌ Must run as root (sudo ./uninstall.sh)"
    exit 1
fi

echo "==> Removing HP Anyware PCoIP Client..."

# Remove installed files
rm -f /usr/bin/pcoip-client
rm -rf /usr/libexec/pcoip-client
rm -rf /usr/lib64/pcoip-client
rm -rf /usr/lib/x86_64-linux-gnu/pcoip-client
rm -rf /usr/lib/x86_64-linux-gnu/org.hp.pcoip-client
rm -f /usr/share/applications/pcoip-client.desktop
rm -rf /usr/share/icons/hicolor/*/apps/pcoip-client.png
rm -f /usr/sbin/pcoip-configure-kernel-networking
rm -f /usr/lib/x86_64-linux-gnu/libprotobuf.so* 2>/dev/null || true

echo ""
echo "  ✓ HP Anyware PCoIP Client removed."
echo ""
echo "  Dependencies (libva, pulseaudio-libs, etc.) were NOT removed —"
echo "  they may be used by other packages. To clean them:"
echo "    sudo dnf5 autoremove"
echo ""
