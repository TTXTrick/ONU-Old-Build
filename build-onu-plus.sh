#!/usr/bin/env bash
# ===============================================================
#  ONU Linux 1.0 "Hydrogen+" Build Script
#  Oxygen is Not Unix — Lightweight Debian-based XFCE distro
#  Includes: Calamares Installer + Theming + Live User
# ===============================================================

set -e

# ---------- CONFIG ----------
DISTRO="bookworm"
BUILD_DIR="$HOME/onu-linux"
ISO_NAME="ONU-1.0-HydrogenPlus.iso"
LIVE_USER="onu"
LIVE_PASS="live"
WALLPAPER_URL="https://upload.wikimedia.org/wikipedia/commons/8/89/Xfce_wallpaper_blue.png"
# ----------------------------

echo "=============================="
echo "  Building ONU Linux 1.0+"
echo "  Oxygen is Not Unix"
echo "=============================="
sleep 2

# ---------- INSTALL DEPENDENCIES ----------
echo "[1/8] Installing required packages..."
sudo apt update -y
sudo apt install -y live-build debootstrap syslinux genisoimage squashfs-tools \
                    xorriso curl git vim qtbase5-dev qttools5-dev-tools cmake \
                    extra-cmake-modules libkf5coreaddons-dev libkf5i18n-dev \
                    libkf5config-dev libkf5widgetsaddons-dev libkf5xmlgui-dev \
                    libkf5iconthemes-dev libkf5parts-dev libyaml-cpp-dev \
                    calamares-settings-debian

# ---------- PREPARE BUILD DIR ----------
echo "[2/8] Setting up build directory..."
sudo rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

lb config --distribution "$DISTRO" \
           --debian-installer live \
           --archive-areas "main contrib non-free-firmware"

# ---------- ADD PACKAGES ----------
echo "[3/8] Adding package list..."
mkdir -p config/package-lists
cat <<'EOF' > config/package-lists/onu.list.chroot
# Core utilities
sudo
bash
zsh
vim
curl
wget
htop
neofetch
git
nano
parted
gparted

# Desktop environment
xfce4
lightdm
network-manager
network-manager-gnome
pulseaudio
alsa-utils

# Applications
firefox-esr
thunar
mousepad
gnome-disk-utility
gnome-terminal
vlc

# Appearance
xfce4-goodies
fonts-dejavu

# Installer
calamares
EOF

# ---------- BRANDING ----------
echo "[4/8] Adding ONU branding..."
mkdir -p config/includes.chroot/etc
echo "Welcome to ONU Linux (Oxygen is Not Unix)" | sudo tee config/includes.chroot/etc/issue

# Wallpaper
mkdir -p config/includes.chroot/usr/share/backgrounds/ONU
curl -L "$WALLPAPER_URL" -o config/includes.chroot/usr/share/backgrounds/ONU/onu-wallpaper.png

# XFCE theme defaults
mkdir -p config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
cat <<'EOF' > config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/backgrounds/ONU/onu-wallpaper.png"/>
        <property name="image-style" type="int" value="5"/>
        <property name="image-show" type="bool" value="true"/>
      </property>
    </property>
  </property>
</channel>
EOF

# ---------- LIVE USER ----------
echo "[5/8] Creating default live user..."
mkdir -p config/includes.chroot/lib/live/config
cat <<EOF | sudo tee config/includes.chroot/lib/live/config/0031-onu-user
#!/bin/sh
useradd -m -s /bin/bash $LIVE_USER
echo "$LIVE_USER:$LIVE_PASS" | chpasswd
adduser $LIVE_USER sudo
echo "Created live user: $LIVE_USER (password: $LIVE_PASS)"
EOF
chmod +x config/includes.chroot/lib/live/config/0031-onu-user

# ---------- BOOT MENU ----------
echo "[6/8] Creating boot menu..."
mkdir -p config/includes.binary/isolinux
cat <<'EOF' > config/includes.binary/isolinux/isolinux.cfg
UI menu.c32
PROMPT 0
MENU TITLE ONU Linux Boot Menu
TIMEOUT 50

LABEL live
  MENU LABEL Start ONU Linux Live
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live quiet splash
EOF

# ---------- BUILD ----------
echo "[7/8] Building the ONU+ ISO..."
sudo lb clean
sudo lb build

# ---------- FINALIZE ----------
echo "[8/8] Finalizing..."
ISO_FILE=$(ls live-image-amd64.hybrid.iso 2>/dev/null || echo "")
if [ -f "$ISO_FILE" ]; then
    mv "$ISO_FILE" "$ISO_NAME"
    echo "✅ Build complete: $BUILD_DIR/$ISO_NAME"
else
    echo "❌ Build failed. Check logs above."
    exit 1
fi

echo
echo "=============================================================="
echo " ONU Linux 1.0+ “Hydrogen+” built successfully!"
echo " ISO path: $BUILD_DIR/$ISO_NAME"
echo
echo " Default user: $LIVE_USER   Password: $LIVE_PASS"
echo
echo " Test with:  qemu-system-x86_64 -m 2048 -cdrom $BUILD_DIR/$ISO_NAME"
echo "=============================================================="
