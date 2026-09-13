# Linux -> iPhone 13 mini (no paid Apple developer account)

This route does **not** require a Mac, SideStore, LocalDevVPN, or the App Store.

Flow:

`Linux source -> GitHub Actions macOS/Xcode build -> unsigned IPA -> iloader on Linux -> free Apple-account signing -> iPhone`

## 1. Get the corrected source into your GitHub repo

On Linux:

```bash
sudo apt update
sudo apt install -y git gh rsync
gh auth login
cd ~/Downloads
gh repo clone alxvvest/AirTranslate13Mini AirTranslate13Mini
```

Copy the corrected project files into that clone if you downloaded this package separately.

## 2. Push, build, and download the IPA

From the cloned repo:

```bash
cd ~/Downloads/AirTranslate13Mini
./scripts/PUSH_BUILD_DOWNLOAD.sh
```

When the GitHub Actions build passes, the script downloads:

```text
build-output/AirTranslate13Mini-unsigned.ipa
```

A paid Apple Developer membership is not needed for this personal sideloading route.

## 3. Install iloader on Linux

```bash
./scripts/SETUP_ILOADER_LINUX.sh
```

Plug the iPhone 13 mini into USB, unlock it, tap **Trust**, then verify:

```bash
idevice_id -l
```

You should see a device identifier.

## 4. Sign/install AirTranslate

Open **iloader** on Linux:

1. Sign in with your Apple Account.
2. Select the iPhone 13 mini.
3. Choose **Import IPA**.
4. Pick `build-output/AirTranslate13Mini-unsigned.ipa`.
5. Let iloader sign/install it using the free Apple development provisioning path.

On the iPhone, if requested:

- Settings -> General -> VPN & Device Management -> trust your Developer App profile.
- Settings -> Privacy & Security -> Developer Mode -> enable it and restart.

Then launch AirTranslate and grant Microphone + Speech Recognition permission.

## Free-account limitation

Apple's free development provisioning is temporary (commonly 7 days). When it expires, reconnect the iPhone to Linux and import/sign the IPA with iloader again.

## Notes

- The project targets iOS 18+.
- Apple's Translation framework may need to download Spanish/English language assets the first time it is used. That is separate from downloading an App Store app.
- AirPods HFP input is requested through AVAudioSession; iOS owns the final route decision.
