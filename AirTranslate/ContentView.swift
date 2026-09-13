import SwiftUI
import Translation

struct ContentView: View {
    @StateObject private var model = TranslatorViewModel()
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var pendingSpanish = ""

    private let sourceLanguage = Locale.Language(identifier: "es-MX")
    private let targetLanguage = Locale.Language(identifier: "en-US")

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusCard
                liveTranslationCard
                controls
                history
            }
            .padding()
            .navigationTitle("AirTranslate")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: model.translationSource) { _, newValue in
                guard !newValue.isEmpty else { return }
                pendingSpanish = newValue
                if translationConfiguration == nil {
                    translationConfiguration = .init(source: sourceLanguage, target: targetLanguage)
                } else {
                    translationConfiguration?.invalidate()
                }
            }
            .translationTask(translationConfiguration) { session in
                do {
                    let source = pendingSpanish
                    guard !source.isEmpty else { return }
                    let response = try await session.translate(source)
                    await MainActor.run {
                        model.receiveTranslation(source: source, english: response.targetText)
                    }
                } catch {
                    await MainActor.run {
                        model.setTranslationError(error.localizedDescription)
                    }
                }
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(model.speech.isListening ? Color.green : Color.secondary)
                Text(model.speech.status)
                    .font(.headline)
                Spacer()
            }

            Text("Mic: \(model.speech.routeName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(model.speech.usesOnDeviceRecognition ? "Spanish speech: on-device" : "Spanish speech: network may be used")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var liveTranslationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPANISH")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(model.latestSpanish.isEmpty ? "Waiting for Spanish…" : model.latestSpanish)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text("ENGLISH")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(model.latestEnglish.isEmpty ? "Translation appears here" : model.latestEnglish)
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let error = model.translationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if model.speech.isListening {
                        model.stop()
                    } else {
                        Task { await model.start() }
                    }
                } label: {
                    Label(model.speech.isListening ? "Stop" : "Start Listening", systemImage: model.speech.isListening ? "stop.fill" : "airpods")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Clear") {
                    model.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Toggle("Speak English into AirPods", isOn: $model.speakEnglish)
                .font(.subheadline)
        }
    }

    private var history: some View {
        List(model.lines.reversed()) { line in
            VStack(alignment: .leading, spacing: 4) {
                Text(line.spanish)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(line.english)
                    .font(.body.weight(.semibold))
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
}

#Preview {
    ContentView()
}
