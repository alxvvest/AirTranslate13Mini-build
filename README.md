# AirTranslate13Mini

Native iPhone MVP for **Spanish speech -> English subtitles**, designed for an iPhone 13 mini with AirPods.

## What it does

- Uses the AirPods Bluetooth HFP microphone when iOS exposes it as an input.
- Falls back to the iPhone microphone if no Bluetooth HFP input is available.
- Continuously transcribes Spanish (`es-MX`) with Apple's Speech framework.
- Uses on-device speech recognition when that recognizer reports support; otherwise iOS may use Apple's network speech service.
- Translates Spanish text to English with Apple's Translation framework.
- Shows large live English subtitles plus transcript history.
- Optional English speech playback through the active audio route. Listening pauses while playback occurs to reduce feedback/re-transcription.
- No OpenAI key, Google key, subscription, or paid API is required by this project.

## Requirements

- iPhone 13 mini running **iOS 18 or newer**.
- AirPods (recommended) or the iPhone microphone.
- **Linux-only path supported for this project:** GitHub Actions compiles the unsigned IPA on a hosted macOS/Xcode runner; iloader on Linux signs/installs the IPA over USB with a free Apple account. SideStore and LocalDevVPN are not required for direct USB installation.
- A paid Apple Developer membership is **not required** for personal sideloading. Free-account signatures expire after 7 days and must be refreshed.
- See `LINUX_TO_IPHONE.md`. For the shortest path, run `./scripts/PUSH_BUILD_DOWNLOAD.sh`, then import the resulting IPA with iloader.

## Build

### Fast path with XcodeGen

```bash
brew install xcodegen
cd AirTranslate13Mini
xcodegen generate
open AirTranslate13Mini.xcodeproj
```

In Xcode:

1. Select the **AirTranslate13Mini** target.
2. Signing & Capabilities -> choose your Apple ID / Personal Team.
3. Change the bundle identifier if Xcode says it is already taken.
4. Connect the iPhone 13 mini by USB (or use wireless debugging once trusted).
5. Select the iPhone as the run destination.
6. Press Run.
7. On first launch, grant Microphone and Speech Recognition permissions.
8. Connect AirPods, open AirTranslate, then tap **Start Listening**.

The first Spanish -> English translation may ask to download the language pair. Accept it.

## AirPods behavior

The app configures `AVAudioSession` for `playAndRecord` and enables Bluetooth HFP. If an HFP Bluetooth input is available, it requests that input. iOS owns the final route decision. The status card shows the actual input route currently in use.

For the cleanest results, leave **Speak English into AirPods** off. That gives you live translated subtitles without the app's own English audio competing with the microphone. If you turn speech playback on, the app pauses recognition during playback and resumes afterward.

## MVP limitations

- This is not simultaneous full-duplex interpreter audio. It prioritizes reliable subtitles.
- Speech recognition quality depends on noise, accent, iOS language support, and whether on-device recognition is available.
- Apple's Translation framework manages its own downloadable language models and availability.
- Background/locked-screen continuous recognition is intentionally not enabled in v0.1.
- This package has not been compiled inside this Linux environment because Apple iOS SDKs are only available through Xcode on macOS.

## Next upgrades

1. Language picker (Spanish dialects + more target languages).
2. Voice activity detection and smarter phrase chunking.
3. Conversation mode (English reply -> Spanish speech).
4. Lock-screen/Live Activity controls where platform rules allow.
5. Export/share transcript.
6. Offline readiness checker for Speech + Translation models.
7. Optional local Whisper/Core ML speech engine for devices where Apple's on-device Spanish recognizer is unavailable.
