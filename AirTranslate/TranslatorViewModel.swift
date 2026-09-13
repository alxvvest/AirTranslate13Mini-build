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
    private var debounceTask: Task<Void, Never>?
    private var lastCommittedSpanish = ""

    init() {
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
        debounceTask?.cancel()
        debounceTask = nil
        output.stop()
        speech.stopListening()
    }

    func clear() {
        latestSpanish = ""
        latestEnglish = ""
        translationSource = ""
        lines.removeAll()
        lastCommittedSpanish = ""
        translationError = nil
    }

    func receiveTranslation(source: String, english: String) {
        guard source == translationSource else { return }
        latestEnglish = english
        translationError = nil

        if source != lastCommittedSpanish, !english.isEmpty {
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

    func setTranslationError(_ message: String) {
        translationError = message
    }

    private func handleTranscript(_ text: String, isFinal: Bool) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        latestSpanish = cleaned

        debounceTask?.cancel()

        if isFinal {
            translationSource = cleaned
            return
        }

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.translationSource = cleaned
        }
    }
}
