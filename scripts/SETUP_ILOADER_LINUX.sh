#!/usr/bin/env bash
set -euo pipefail

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    ASSET="iloader-linux-amd64.deb"
    ;;
  aarch64|arm64)
    ASSET="iloader-linux-aarch64.deb"
    ;;
  *)
    echo "Unsupported Linux architecture: $ARCH"
    exit 1
    ;;
esac

sudo apt update
sudo apt install -y usbmuxd libimobiledevice-utils curl
sudo systemctl enable --now usbmuxd || sudo systemctl restart usbmuxd

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

echo "Downloading official iloader release: $ASSET"
curl -fL --retry 3 \
  "https://github.com/nab138/iloader/releases/latest/download/$ASSET" \
  -o "$ASSET"

sudo apt install -y "./$ASSET"

echo
echo "iloader installed."
echo "1. Plug the iPhone into USB and unlock it."
echo "2. Tap Trust on the iPhone if prompted."
echo "3. Verify Linux sees it with: idevice_id -l"
echo "4. Open iloader and use Import IPA once the AirTranslate IPA is built."
