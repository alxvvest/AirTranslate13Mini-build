import Combine
import Foundation

@MainActor
final class TranslatorViewModel: ObservableObject {
    @Published var latestSpanish = ""
    @Published var latestEnglish = ""
    @Published var translationSource = ""
    @Published var lines: [ConversationLine] = []
    @Published var speakEnglish = false
    @Published var translationError: String?

    let speech = SpeechRecognizer()
    private let output = SpeechOutput()

    private var trailingTranslationTask: Task<Void, Never>?
    private var lastTranslationDispatch = Date.distantPast
    private let partialTranslationInterval: TimeInterval = 0.25

    private var lastCommittedSpanish = ""
    private var latestFinalSpanish = ""
    private var latestTranslatedSource = ""
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward nested SpeechRecognizer UI changes to this view model.
        speech.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        speech.onTranscript = { [weak self] text, isFinal in
            guard let self else { return }
            self.handleTranscript(text, isFinal: isFinal)
        }

        output.onFinished = { [weak self] in
            self?.speech.resumeAfterPlayback()
        }
    }

    func start() async {
        translationError = nil
        await speech.startListening()
    }

    func stop() {
        trailingTranslationTask?.cancel()
        trailingTranslationTask = nil
        output.stop()
        speech.stopListening()
    }

    func clear() {
        trailingTranslationTask?.cancel()
        trailingTranslationTask = nil
        latestSpanish = ""
        latestEnglish = ""
        translationSource = ""
        lines.removeAll()
        lastCommittedSpanish = ""
        latestFinalSpanish = ""
        latestTranslatedSource = ""
        lastTranslationDispatch = .distantPast
        translationError = nil
    }

    func receiveTranslation(source: String, english: String) {
        guard source == translationSource else { return }

        latestEnglish = english
        latestTranslatedSource = source
        translationError = nil

        // Live partial translations update the big subtitle only.
        // History is committed only when Speech marks the phrase final.
        if source == latestFinalSpanish {
            commitLineIfNeeded(source: source, english: english)
        }
    }

    func setTranslationError(_ message: String) {
        translationError = message
    }

    private func handleTranscript(_ text: String, isFinal: Bool) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        latestSpanish = cleaned

        if isFinal {
            trailingTranslationTask?.cancel()
            trailingTranslationTask = nil
            latestFinalSpanish = cleaned

            if translationSource != cleaned {
                dispatchTranslation(cleaned)
            } else if latestTranslatedSource == cleaned, !latestEnglish.isEmpty {
                commitLineIfNeeded(source: cleaned, english: latestEnglish)
            }
            return
        }

        // Throttle rather than debounce:
        // while a person keeps talking, emit a new translation about 4x/sec
        // instead of waiting for a 700ms silence gap.
        let elapsed = Date().timeIntervalSince(lastTranslationDispatch)

        if elapsed >= partialTranslationInterval {
            dispatchTranslation(cleaned)
            return
        }

        trailingTranslationTask?.cancel()
        let remaining = max(0.03, partialTranslationInterval - elapsed)

        trailingTranslationTask = Task { [weak self] in
            let ns = UInt64(remaining * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled, let self else { return }

            let newest = self.latestSpanish.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newest.isEmpty else { return }
            self.dispatchTranslation(newest)
        }
    }

    private func dispatchTranslation(_ source: String) {
        guard !source.isEmpty, source != translationSource else { return }
        translationSource = source
        lastTranslationDispatch = Date()
    }

    private func commitLineIfNeeded(source: String, english: String) {
        guard source != lastCommittedSpanish, !english.isEmpty else { return }

        lines.append(
            ConversationLine(
                spanish: source,
                english: english,
                createdAt: Date()
            )
        )
        lastCommittedSpanish = source

        if speakEnglish {
            speech.pauseForPlayback()
            output.speak(english)
        }
    }
}
