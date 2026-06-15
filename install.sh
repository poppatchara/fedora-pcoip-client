#!/usr/bin/env bash
# HP Anyware PCoIP Client — Fedora 44 Install Script
# Repackages official Ubuntu .deb for Fedora.
#
# Usage:  sudo ./install.sh [--clipboard]
# Uninstall: sudo ./uninstall.sh
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PKGVER="26.05.2"
UBUNTUVER="22.04"
DEB_URL="https://dl.anyware.hp.com/pcoip-client/deb/ubuntu/pool/main/p/pcoip-client/pcoip-client_${PKGVER}-${UBUNTUVER}_amd64.deb"
PROTOBUF_URL="http://archive.ubuntu.com/ubuntu/pool/main/p/protobuf/libprotobuf23_3.12.4-1ubuntu7_amd64.deb"
DEB_SHA256="31afe83f6529b1e0af47069287b6c07efab111b1a7b1ff005366377d2b560232"
PROTOBUF_SHA256="8c9942e9130ab7c343438b1b81603bdd86509d7e2a9cc877ae35a998dbf5e0a8"

VENDOR_ROOT="/usr/lib64/pcoip-client"
WORKDIR="/tmp/pcoip-fedora-install"
CLIPBOARD=false

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --clipboard) CLIPBOARD=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "❌ Must run as root (sudo ./install.sh)"
    exit 1
fi

echo "==> HP Anyware PCoIP Client — Fedora 44 Installer =="
echo "    Version: ${PKGVER}  |  Ubuntu base: ${UBUNTUVER}"
echo "    Clipboard plugin: ${CLIPBOARD}"
echo ""

# ---------------------------------------------------------------------------
# 1. Install system dependencies via dnf5
# ---------------------------------------------------------------------------
echo "==> [1/7] Installing system dependencies..."

DNF_DEPS=(
    alsa-lib
    dbus
    expat
    fontconfig
    freetype
    glib2
    krb5-libs
    libarchive
    libcap
    libdrm
    libglvnd
    libpng
    pulseaudio-libs
    libva
    libX11
    libxcb
    libXext
    libXi
    libxkbcommon-x11
    mesa-libGL
    nspr
    nss
    pcsc-lite
    systemd
    xcb-util
    xcb-util-image
    xcb-util-keysyms
    xcb-util-renderutil
    xcb-util-wm
    zlib
)

if $CLIPBOARD; then
    DNF_DEPS+=( GraphicsMagick )
fi

# Detect GPU for optional VA-API driver suggestion
GPU_VENDOR=""
if lspci | grep -qi nvidia; then
    GPU_VENDOR="nvidia"
elif lspci | grep -qi "intel.*graphic\|intel.*display\|intel.*UHD\|intel.*Iris\|intel.*Arc"; then
    GPU_VENDOR="intel"
elif lspci | grep -qi "amd.*graphic\|amd.*radeon\|amd.*advanced"; then
    GPU_VENDOR="amd"
fi

if command -v dnf5 &>/dev/null; then
    DNF="dnf5"
else
    DNF="dnf"
fi

$DNF install -y "${DNF_DEPS[@]}"

# Enable RPM Fusion nonfree if NVIDIA detected
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    echo "    → NVIDIA GPU detected, enabling RPM Fusion nonfree for VA-API..."
    $DNF install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" 2>/dev/null || true
    $DNF install -y libva-nvidia-driver 2>/dev/null || \
        echo "    ⚠ libva-nvidia-driver not installed (install manually if needed)"
elif [[ "$GPU_VENDOR" == "intel" ]]; then
    $DNF install -y intel-media-driver libva-intel-driver 2>/dev/null || true
elif [[ "$GPU_VENDOR" == "amd" ]]; then
    $DNF install -y libva-mesa-driver 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 2. Download & verify
# ---------------------------------------------------------------------------
echo "==> [2/7] Downloading files..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

curl -fSL# -o pcoip-client.deb "$DEB_URL"
curl -fSL# -o libprotobuf23.deb "$PROTOBUF_URL"

echo "$DEB_SHA256  pcoip-client.deb" | sha256sum -c
echo "$PROTOBUF_SHA256  libprotobuf23.deb" | sha256sum -c

# ---------------------------------------------------------------------------
# 3. Extract
# ---------------------------------------------------------------------------
echo "==> [3/7] Extracting packages..."
mkdir -p pcoip-client libprotobuf
bsdtar -C pcoip-client -xf pcoip-client.deb
bsdtar -C libprotobuf -xf libprotobuf23.deb

# ---------------------------------------------------------------------------
# 4. Install files
# ---------------------------------------------------------------------------
echo "==> [4/7] Installing to system..."

# Extract data archives
tar -C / -xf pcoip-client/data.tar.gz 2>/dev/null || true

# Fedora: /usr/sbin is a real directory (not a symlink). Keep sbin files there.
# Fix permissions on vendor libs
install -d "$VENDOR_ROOT"

# Bundle Ubuntu libprotobuf for ABI compatibility
tar -C / -xf libprotobuf/data.tar.zst \
    ./usr/lib/x86_64-linux-gnu/libprotobuf.so.23.0.4 2>/dev/null || true

# Move vendor .so files from the .deb multiarch path to our vendor root
# The .deb places libs under /usr/lib/x86_64-linux-gnu/
if ls /usr/lib/x86_64-linux-gnu/lib*.so* &>/dev/null 2>&1; then
    mv /usr/lib/x86_64-linux-gnu/lib*.so* "$VENDOR_ROOT"/ 2>/dev/null || true
fi

# Move protobuf into vendor root
if [[ -f /usr/lib/x86_64-linux-gnu/libprotobuf.so.23.0.4 ]]; then
    mv /usr/lib/x86_64-linux-gnu/libprotobuf.so.23.0.4 "$VENDOR_ROOT"/
fi
ln -sf libprotobuf.so.23.0.4 "$VENDOR_ROOT"/libprotobuf.so.23

# Qt looks for a sibling lib/ directory
ln -sf . "$VENDOR_ROOT"/lib

chmod +x "$VENDOR_ROOT"/lib*so* 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. Wrapper script (force X11/XCB)
# ---------------------------------------------------------------------------
echo "==> [5/7] Creating wrapper script..."

# Drop Wayland Qt platform plugins that fail with system libQt6WaylandClient
rm -f /usr/lib/x86_64-linux-gnu/pcoip-client/plugins/platforms/libqwayland-*.so 2>/dev/null || true

# Create wrapper that forces XCB
cat <<'EOF' > /usr/bin/pcoip-client
#!/bin/sh
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
exec /usr/libexec/pcoip-client/pcoip-client "$@"
EOF
chmod +x /usr/bin/pcoip-client

# ---------------------------------------------------------------------------
# 6. Desktop integration
# ---------------------------------------------------------------------------
echo "==> [6/7] Setting up desktop integration..."

# Remove URL handler to avoid collisions
if [[ -f /usr/share/applications/pcoip-client.desktop ]]; then
    sed -i -e 's!MimeType=x-scheme-handler/pcoip;!!' /usr/share/applications/pcoip-client.desktop
fi

# Cleanup unused directories
rm -rf \
    /usr/lib/x86_64-linux-gnu/org.hp.pcoip-client \
    /var/opt/pcoip-client 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Capabilities (USB redirection)
# ---------------------------------------------------------------------------
echo "==> [7/7] Setting capabilities..."
setcap cap_setgid+p /usr/libexec/pcoip-client/pcoip-client 2>/dev/null || \
    echo "    ⚠ Failed to set cap on pcoip-client (USB may not work)"
setcap cap_setgid+i /usr/libexec/pcoip-client/usb-helper 2>/dev/null || \
    echo "    ⚠ Failed to set cap on usb-helper (USB may not work)"

# ---------------------------------------------------------------------------
# Clipboard plugin (optional)
# ---------------------------------------------------------------------------
if $CLIPBOARD; then
    echo ""
    echo "==> [Extra] Installing clipboard plugin..."

    tar -C / -xf pcoip-client/data.tar.gz \
        ./usr/lib/x86_64-linux-gnu/org.hp.pcoip-client/vchan_plugins/libvchan-plugin-clipboard.so \
        2>/dev/null || true

    CLIPBOARD_PLUGIN="/usr/lib/x86_64-linux-gnu/org.hp.pcoip-client/vchan_plugins/libvchan-plugin-clipboard.so"
    if [[ -f "$CLIPBOARD_PLUGIN" ]]; then
        chmod +x "$CLIPBOARD_PLUGIN"
        # Patch to use Arch/Fedora GraphicsMagick SONAME
        patchelf --replace-needed libGraphicsMagick++-Q16.so.12 libGraphicsMagick++.so.12 \
            "$CLIPBOARD_PLUGIN"
        echo "    ✓ Clipboard plugin installed and patched"
    else
        echo "    ⚠ Clipboard plugin not found in .deb (may have moved)"
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "══════════════════════════════════════════════"
echo "  ✓ HP Anyware PCoIP Client ${PKGVER} installed"
echo "══════════════════════════════════════════════"
echo ""
echo "  Launch:  pcoip-client"
echo "  Or find it in your application menu under 'HP Anyware'"
echo ""
echo "  ⚠  Reboot to ensure NVIDIA driver or VA-API modules load properly."
echo ""

# Cleanup
rm -rf "$WORKDIR"
