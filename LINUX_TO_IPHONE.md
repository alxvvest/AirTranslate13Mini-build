# Linux -> iPhone 13 mini, no paid Apple Developer account

You do **not** need the $99/year Apple Developer Program for this MVP.

The practical path is:

1. Linux installs **SideStore** on the iPhone with `iloader`.
2. GitHub Actions uses a hosted macOS/Xcode runner to compile AirTranslate into an **unsigned IPA**.
3. Download the IPA to the iPhone.
4. SideStore signs it using your free Apple Account and installs it.
5. With a free Apple Account, refresh the app before the 7-day signature expires.

## A. Install SideStore from Linux

On the iPhone first, install **LocalDevVPN** from Apple's App Store.

Then on Linux:

```bash
cd AirTranslate13Mini
./scripts/SETUP_SIDESTORE_LINUX.sh
```

Connect the iPhone by USB, unlock it, press **Trust** when asked, then launch the iloader AppImage printed by the script.

Inside iloader:

1. Sign in with your Apple Account.
2. Select the iPhone 13 mini.
3. Choose **Install SideStore (Stable)**.

On the iPhone after installation:

1. Settings -> General -> VPN & Device Management.
2. Trust the Developer App associated with your Apple Account.
3. Settings -> Privacy & Security -> Developer Mode -> turn it on and restart when prompted.
4. Open **LocalDevVPN** and connect it.
5. Open **SideStore**, sign in to the same Apple Account, then refresh SideStore by tapping its `7 DAYS` indicator.

## B. Build the AirTranslate IPA without owning a Mac

Install GitHub CLI if needed:

```bash
sudo apt update
sudo apt install -y gh git
```

Authenticate once:

```bash
gh auth login
```

From this project folder:

```bash
./scripts/PUBLISH_TO_GITHUB.sh
```

The included `.github/workflows/build-ipa.yml` runs Xcode on GitHub's macOS runner and uploads:

`AirTranslate13Mini-unsigned.ipa`

Download that Actions artifact when the run completes.

## C. Put the IPA on the phone

Easiest options:

- Open GitHub on the iPhone and download the Actions artifact, then unzip it in Files; or
- download the artifact on Linux and transfer the `.ipa` to the iPhone with any normal file-transfer method/cloud drive.

In **SideStore**:

1. Make sure LocalDevVPN is connected.
2. Tap `+` / Add App.
3. Select `AirTranslate13Mini-unsigned.ipa` from Files.
4. Let SideStore sign and install it.
5. Launch **AirTranslate** and approve Microphone + Speech Recognition permissions.
6. Connect AirPods and tap **Start Listening**.

## Free Apple Account limits

SideStore documents the free Apple Account limits as 3 simultaneously sideloaded apps (SideStore counts as one), up to 10 App IDs per week, and a 7-day signing lifetime. Refresh before expiry.

This project does not require a paid Apple developer membership or paid translation API.
