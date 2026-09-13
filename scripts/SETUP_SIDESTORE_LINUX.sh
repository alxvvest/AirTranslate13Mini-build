#!/usr/bin/env bash
set -euo pipefail

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ILOADER_ARCH="amd64" ;;
  aarch64|arm64) ILOADER_ARCH="aarch64" ;;
  *) echo "Unsupported CPU architecture: $ARCH"; exit 1 ;;
esac

printf '\nAirTranslate // Linux SideStore bootstrap\n'
printf 'This installs Linux USB support and downloads the official iloader AppImage.\n\n'

sudo apt update
sudo apt install -y usbmuxd libimobiledevice-utils curl
sudo systemctl enable --now usbmuxd || true
sudo systemctl restart usbmuxd || true

DEST="$HOME/Downloads/iloader-linux-${ILOADER_ARCH}.AppImage"
curl -fL "https://github.com/nab138/iloader/releases/latest/download/iloader-linux-${ILOADER_ARCH}.AppImage" -o "$DEST"
chmod +x "$DEST"

echo
echo "Downloaded: $DEST"
echo "Now connect the iPhone by USB, unlock it, tap Trust, then run:"
echo "  \"$DEST\""
echo
echo "If AppImage/FUSE refuses to launch, run:"
echo "  \"$DEST\" --appimage-extract-and-run"
echo
echo "In iloader: sign in with your Apple Account -> select iPhone -> Install SideStore (Stable)."
