import AVFAudio
import Combine
import Foundation
import Speech

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var routeName = "Not listening"
    @Published private(set) var status = "Ready"
    @Published private(set) var usesOnDeviceRecognition = false

    var onTranscript: ((String, Bool) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var wantsListening = false
    private var tapInstalled = false
    private var restartTask: Task<Void, Never>?

    func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let microphoneAuthorized = await AVAudioApplication.requestRecordPermission()
        return speechAuthorized && microphoneAuthorized
    }

    func startListening() async {
        guard !wantsListening else { return }
        guard await requestPermissions() else {
            status = "Microphone or Speech permission denied"
            return
        }

        wantsListening = true
        await startRecognitionCycle()
    }

    func stopListening() {
        wantsListening = false
        restartTask?.cancel()
        restartTask = nil
        tearDownRecognition(deactivateAudio: true)
        isListening = false
        status = "Stopped"
        routeName = "Not listening"
    }

    func pauseForPlayback() {
        guard wantsListening else { return }
        tearDownRecognition(deactivateAudio: false)
        isListening = false
        status = "Speaking translation"
    }

    func resumeAfterPlayback() {
        guard wantsListening else { return }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.startRecognitionCycle()
        }
    }

    private func startRecognitionCycle() async {
        guard wantsListening else { return }
        tearDownRecognition(deactivateAudio: false)

        guard let recognizer, recognizer.isAvailable else {
            status = "Spanish speech recognition unavailable"
            scheduleRestart(after: 1.0)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            if let airPodsInput = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
                try? session.setPreferredInput(airPodsInput)
            }

            routeName = session.currentRoute.inputs.first?.portName ?? "iPhone microphone"

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            usesOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.requiresOnDeviceRecognition = usesOnDeviceRecognition
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            tapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            status = "Listening for Spanish"

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        let text = result.bestTranscription.formattedString
                        self.transcript = text
                        self.onTranscript?(text, result.isFinal)

                        if result.isFinal {
                            self.scheduleRestart(after: 0.20)
                        }
                    }

                    if error != nil, self.wantsListening {
                        self.scheduleRestart(after: 0.45)
                    }
                }
            }
        } catch {
            status = "Audio start failed: \(error.localizedDescription)"
            scheduleRestart(after: 1.0)
        }
    }

    private func scheduleRestart(after seconds: Double) {
        guard wantsListening else { return }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            let ns = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            await self?.startRecognitionCycle()
        }
    }

    private func tearDownRecognition(deactivateAudio: Bool) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        if deactivateAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
