import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var isDropTargeted = false

    private let ink = Color(red: 20 / 255, green: 58 / 255, blue: 67 / 255)
    private let mint = Color(red: 103 / 255, green: 221 / 255, blue: 208 / 255)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), mint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    if !model.isModelInstalled { modelCard }
                    sourceCard
                    if let message = model.errorMessage { errorCard(message) }
                    if model.isBusy { progressCard }
                    if model.transcript != nil { transcriptCard }
                    privacyNote
                }
                .frame(maxWidth: 880)
                .padding(32)
            }
        }
        .tint(ink)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("BrandIcon")
                .resizable()
                .frame(width: 66, height: 66)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("WhisperBridge")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Text("Audio into words for LM Studio")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(model.phase.label, systemImage: statusSymbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(model.phase == .failed ? .red : ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .accessibilityLabel("Status: \(model.phase.label)")
        }
    }

    private var modelCard: some View {
        Card {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(ink)
                    .frame(width: 44, height: 44)
                    .background(mint.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text("One-time speech model download")
                        .font(.headline)
                    Text("\(ModelManifest.recommended.displayName) is \(ModelManifest.recommended.formattedSize). It stays on this Mac and handles multiple languages.")
                        .foregroundStyle(.secondary)
                    Text("Internet is used only for this download. Audio and transcripts are processed locally.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Download Model") { model.downloadModel() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isBusy)
            }
        }
    }

    private var sourceCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio file")
                            .font(.headline)
                        if let selection = model.selection {
                            Text(selection.displayName)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                            Text(selection.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Drop one recording here or choose a file")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(model.selection == nil ? "Choose Audio…" : "Choose Another…") {
                        model.chooseAudio()
                    }
                    .keyboardShortcut("o")
                    .disabled(model.isBusy)
                }

                Divider()

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Spoken language")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Spoken language", selection: $model.language) {
                            ForEach(LanguageOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }
                    Spacer()
                    if model.isBusy {
                        Button("Cancel") { model.cancelWork() }
                            .keyboardShortcut(.cancelAction)
                    } else {
                        Button("Transcribe") { model.transcribe() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(!model.canTranscribe)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isDropTargeted ? mint : .clear, lineWidth: 3)
                    .padding(-20)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.receiveDrop(urls)
            return !urls.isEmpty
        } isTargeted: { isDropTargeted = $0 }
    }

    private var progressCard: some View {
        Card {
            HStack(spacing: 14) {
                ProgressView(value: progressIsDeterminate ? model.progress : nil)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.phase.label)
                        .font(.headline)
                    Text(model.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if progressIsDeterminate {
                    Text(model.progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.phase.label). \(model.statusMessage)")
    }

    private func errorCard(_ message: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn’t complete that step")
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Dismiss") { model.dismissError() }
            }
        }
    }

    private var transcriptCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Review transcript")
                            .font(.headline)
                        Text("Correct names or numbers before adding this text to your prompt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(model.characterCount)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $model.editedText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 210)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                    .accessibilityLabel("Editable transcript")

                HStack {
                    Button("Reset Edits") { model.resetTranscript() }
                        .disabled(!model.transcriptIsDirty)
                    Button("Clear") { model.clearTranscript() }
                    Spacer()
                    Button("Save Text…") { model.saveTranscript() }
                        .disabled(!model.hasTranscript)
                    Button {
                        model.copyTranscript()
                    } label: {
                        Label("Copy for LM Studio", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.hasTranscript)
                }
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Status: \(model.statusMessage)")
            }
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(ink)
            Text("Local by default. Your recording and transcript are not uploaded. Copying places text on the macOS clipboard, which may sync through your system settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var progressIsDeterminate: Bool {
        model.phase == .decoding || model.phase == .transcribing
    }

    private var statusSymbol: String {
        switch model.phase {
        case .needsModel: "arrow.down.circle"
        case .downloadingModel, .checkingModel, .inspectingAudio, .decoding, .transcribing: "hourglass"
        case .review: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .ready: "checkmark.circle"
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.22)))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }
}
