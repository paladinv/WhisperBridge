import SwiftUI
import WhisperBridgeCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showAdvanced = false
    @State private var showSpeakers = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 8) {
                HStack {
                    Image("BrandIcon").resizable().frame(width: 34, height: 34)
                    Text("Transcript Studio").font(.headline)
                }.padding(.top, 10)
                TextField("Search text or speakers", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.searchLibrary() }
                    .padding(.horizontal)
                List(selection: Binding(get: { model.currentDocument?.id }, set: { if let id = $0 { model.selectTranscript(id) } })) {
                    if model.searchText.isEmpty {
                        ForEach(model.library) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).lineLimit(1)
                                Text(item.speakerNames.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                            }.tag(item.id)
                        }
                    } else {
                        ForEach(model.searchResults) { result in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title).font(.headline)
                                Text(result.speakerName ?? "Transcript").font(.caption)
                                Text(result.snippet).lineLimit(3).foregroundStyle(.secondary)
                            }.tag(result.transcriptID)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 280)
        } detail: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if let document = model.currentDocument { editor(document) }
                else { welcome }
                status
            }
        }
        .frame(minWidth: 980, minHeight: 650)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button("Import Audio…") { model.chooseAudio() }
            Button("Import Transcript…") { model.importTranscriptFile() }
            Button("Play/Pause", systemImage: "playpause") { model.playPause() }.disabled(model.selection == nil)
            Divider().frame(height: 20)
            Button("Transcribe All") { model.transcribe() }.disabled(!model.canTranscribe)
            Button("Transcribe Selection") { model.transcribeSelection() }.disabled(!model.canTranscribe || model.rangeEnd <= model.rangeStart)
            if model.isBusy { Button("Cancel") { model.cancelWork() } }
            Spacer()
            Toggle("Compact", isOn: $model.compactMode).toggleStyle(.button)
            Toggle("Hide fillers", isOn: Binding(get: { model.hideFillers }, set: { model.setFillersHidden($0) })).toggleStyle(.button)
            Button("Export…") { model.exportDocument() }.disabled(model.currentDocument == nil)
            Button("Copy for LM Studio") { model.copyDocumentForLMStudio() }.buttonStyle(.borderedProminent).disabled(model.currentDocument == nil)
        }.padding(12)
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Image("BrandIcon").resizable().frame(width: 88, height: 88)
            Text("WhisperBridge Transcript Studio").font(.largeTitle.bold())
            Text("Import a recording to create a searchable, editable local transcript.").foregroundStyle(.secondary)
            if !model.isModelInstalled {
                Button("Download Whisper Base") { model.downloadModel() }.buttonStyle(.borderedProminent)
            } else {
                Button("Choose Audio…") { model.chooseAudio() }.buttonStyle(.borderedProminent)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func editor(_ document: TranscriptDocument) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(document.title).font(.title2.bold())
                    Text("\(document.sourceFilename) · \(Int(document.duration / 60)):\(String(format: "%02d", Int(document.duration) % 60))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Preset", selection: Binding(get: { model.decodingPreset }, set: { model.applyPreset($0) })) {
                    ForEach(DecodingPreset.allCases, id: \.self) { Text($0.title).tag($0) }
                }.frame(width: 170)
                Picker("Timestamps", selection: $model.timestampGranularity) {
                    ForEach(TimestampGranularity.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }.frame(width: 160)
                Toggle("Diarize", isOn: $model.diarizationEnabled)
                    .help("Requires macOS 15 and verified FluidAudio assets")
                Button("Speakers…") { showSpeakers.toggle() }
                    .popover(isPresented: $showSpeakers) { speakerEditor(document).padding().frame(width: 380) }
                Button("Advanced…") { showAdvanced.toggle() }.popover(isPresented: $showAdvanced) { advanced.padding().frame(width: 360) }
            }.padding()

            VStack(spacing: 5) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.12))
                        ForEach(0..<80, id: \.self) { index in
                            let height = 5 + CGFloat((index * 37) % 25)
                            Capsule().fill(.teal.opacity(0.6)).frame(width: 2, height: height)
                                .offset(x: CGFloat(index) / 80 * proxy.size.width, y: (proxy.size.height - height) / 2)
                        }
                    }
                }.frame(height: 42).accessibilityLabel("Audio waveform overview")
                HStack {
                    Text("Start"); Slider(value: $model.rangeStart, in: 0...max(document.duration, 0.01))
                    Text(TranscriptFormatting.timestamp(model.rangeStart))
                    Text("End"); Slider(value: $model.rangeEnd, in: 0...max(document.duration, 0.01))
                    Text(TranscriptFormatting.timestamp(model.rangeEnd))
                }.font(.caption.monospacedDigit())
            }.padding(.horizontal)

            HStack {
                Menu("Assign Speaker") {
                    Button("Unassigned") { model.assignSpeaker(nil) }
                    ForEach(document.speakers) { speaker in Button(speaker.name) { model.assignSpeaker(speaker.id) } }
                    Divider(); Button("Add Speaker") { model.addSpeaker() }
                }.disabled(model.selectedSegmentIDs.isEmpty)
                Button("Merge") { model.mergeSelectedSegments() }.disabled(model.selectedSegmentIDs.count < 2)
                Button("Split at midpoint") { model.splitSelectedSegment() }.disabled(model.selectedSegmentIDs.count != 1)
                Button("Delete") { model.deleteSelectedSegments() }.disabled(model.selectedSegmentIDs.isEmpty)
                Button("Restore") { model.restoreSelectedSegments() }.disabled(model.selectedSegmentIDs.isEmpty)
                Spacer()
                Text("\(document.segments.filter { !$0.isDeleted }.count) segments").foregroundStyle(.secondary)
            }.padding(10)

            List(selection: $model.selectedSegmentIDs) {
                ForEach(document.segments) { segment in
                    HStack(alignment: .top, spacing: 12) {
                        if !model.compactMode {
                            Text(TranscriptFormatting.timestamp(segment.start)).font(.caption.monospacedDigit()).frame(width: 86, alignment: .leading)
                        }
                        Text(document.speakers.first(where: { $0.id == segment.speakerID })?.name ?? "—")
                            .frame(width: 100, alignment: .leading).foregroundStyle(.secondary)
                        TextField("Transcript segment", text: Binding(get: { segment.editedText }, set: { model.updateSegment(id: segment.id, text: $0) }), axis: .vertical)
                            .textFieldStyle(.plain)
                        if segment.hasOverlappingSpeech { Image(systemName: "person.2.wave.2").help("Overlapping speech") }
                        if segment.isDeleted { Text("Deleted").foregroundStyle(.red).font(.caption) }
                    }.tag(segment.id).opacity(segment.isDeleted ? 0.5 : 1)
                }
            }
        }
    }

    private var advanced: some View {
        Form {
            Picker("Strategy", selection: $model.decodingOptions.strategy) {
                Text("Greedy").tag(DecodingStrategy.greedy); Text("Beam search").tag(DecodingStrategy.beam)
            }
            Stepper("Beam size: \(model.decodingOptions.beamSize)", value: $model.decodingOptions.beamSize, in: 1...10)
            Stepper("Greedy best-of: \(model.decodingOptions.greedyBestOf)", value: $model.decodingOptions.greedyBestOf, in: 1...10)
            LabeledContent("Temperature") { TextField("", value: $model.decodingOptions.temperature, format: .number).frame(width: 80) }
            LabeledContent("No-speech threshold") { TextField("", value: $model.decodingOptions.noSpeechThreshold, format: .number).frame(width: 80) }
            TextField("Initial prompt", text: Binding(get: { model.decodingOptions.initialPrompt ?? "" }, set: { model.decodingOptions.initialPrompt = $0.isEmpty ? nil : $0 }))
        }
    }

    private func speakerEditor(_ document: TranscriptDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Speakers").font(.headline)
                Spacer()
                Button("Add") { model.addSpeaker() }
            }
            if document.speakers.isEmpty {
                Text("Add a speaker, then assign selected transcript segments.").foregroundStyle(.secondary)
            }
            ForEach(document.speakers) { speaker in
                SpeakerEditorRow(
                    speaker: speaker,
                    destinations: document.speakers.filter { $0.id != speaker.id },
                    rename: { model.renameSpeaker(speaker.id, name: $0) },
                    merge: { model.mergeSpeaker(speaker.id, into: $0) }
                )
            }
        }
    }

    private var status: some View {
        HStack {
            if model.isBusy { ProgressView(value: model.progress).frame(width: 140) }
            Text(model.errorMessage ?? model.statusMessage).foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.red)
            Spacer()
        }.font(.caption).padding(10).background(.bar)
    }
}

private struct SpeakerEditorRow: View {
    let speaker: TranscriptSpeaker
    let destinations: [TranscriptSpeaker]
    let rename: (String) -> Void
    let merge: (UUID) -> Void
    @State private var draft: String

    init(speaker: TranscriptSpeaker, destinations: [TranscriptSpeaker], rename: @escaping (String) -> Void, merge: @escaping (UUID) -> Void) {
        self.speaker = speaker
        self.destinations = destinations
        self.rename = rename
        self.merge = merge
        _draft = State(initialValue: speaker.name)
    }

    var body: some View {
        HStack {
            TextField("Speaker name", text: $draft)
                .onSubmit { if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { rename(draft) } }
            Menu("Merge into") {
                ForEach(destinations) { destination in
                    Button(destination.name) { merge(destination.id) }
                }
            }.disabled(destinations.isEmpty)
        }
    }
}
