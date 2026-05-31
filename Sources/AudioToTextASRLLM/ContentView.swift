import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        NavigationSplitView {
            FileQueueView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } content: {
            ConfigurationView()
                .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 460)
        } detail: {
            TranscriptDetailView()
        }
        .overlay(alignment: .bottom) {
            StatusBar()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task { @MainActor in
                viewModel.addAudioFiles(await loadDroppedFileURLs(from: providers))
            }
            return true
        }
    }

    private func loadDroppedFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
               let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                urls.append(url)
            } else if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier),
                      let url = item as? URL {
                urls.append(url)
            }
        }
        return urls
    }
}

private struct FileQueueView: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.pickAudioFiles()
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    viewModel.removeSelectedRecord()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(viewModel.selectedRecord == nil || viewModel.isTranscribing)

                Menu {
                    Button("Reset Failed/Canceled") {
                        viewModel.resetFailedAndCanceled()
                    }
                    Button("Clear Completed") {
                        viewModel.clearCompleted()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .disabled(viewModel.records.isEmpty || viewModel.isTranscribing)

                Spacer()
            }
            .padding(12)

            List(selection: $viewModel.selectedRecordID) {
                ForEach(viewModel.records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(record.file.name)
                                .font(.headline)
                                .lineLimit(1)
                            Spacer()
                            StatusPill(status: record.status)
                        }

                        Text(record.file.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let errorMessage = record.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(record.id)
                }
            }
            .overlay {
                if viewModel.records.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("Drop audio files here")
                            .font(.headline)
                        Text("MP3, WAV, M4A, FLAC, OGG, WebM, AAC")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct ConfigurationView: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Preset", selection: Binding(
                    get: { "" },
                    set: { name in
                        guard let preset = ProviderPresets.all.first(where: { $0.name == name }) else { return }
                        viewModel.applyPreset(preset)
                    }
                )) {
                    Text("Custom").tag("")
                    ForEach(ProviderPresets.all) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }

                Picker("Backend", selection: $viewModel.configuration.backend) {
                    ForEach(ASRBackendMode.allCases) { backend in
                        Text(backend.label).tag(backend)
                    }
                }

                TextField("Base URL", text: $viewModel.configuration.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.configuration.backend == .localCommand)
                TextField("Endpoint Path", text: $viewModel.configuration.endpointPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.configuration.backend == .localCommand)
                SecureField("API Key", text: $viewModel.configuration.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.configuration.backend == .localCommand)
                TextField("ASR Model", text: $viewModel.configuration.model)
                    .textFieldStyle(.roundedBorder)

                if viewModel.configuration.backend == .apiChatAudio {
                    Picker("Audio Payload", selection: $viewModel.configuration.chatAudioPayload) {
                        ForEach(ChatAudioPayloadMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            }

            Section("Recognition") {
                TextField("Language hint, e.g. zh, en, ja", text: $viewModel.configuration.language)
                    .textFieldStyle(.roundedBorder)

                Picker("Response", selection: $viewModel.configuration.responseFormat) {
                    ForEach(ASRResponseFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Temperature: \(viewModel.configuration.temperature, specifier: "%.2f")")
                    Slider(value: $viewModel.configuration.temperature, in: 0...1, step: 0.05)
                }

                TextEditor(text: $viewModel.configuration.prompt)
                    .font(.body)
                    .frame(minHeight: 88)
                    .overlay(alignment: .topLeading) {
                        if viewModel.configuration.prompt.isEmpty {
                            Text("Prompt: glossary, speaker names, product names, formatting preferences")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section("Advanced") {
                if viewModel.configuration.backend == .apiCustomJSON {
                    TextField("Response text path, e.g. choices.0.message.content", text: $viewModel.configuration.responseTextPath)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $viewModel.configuration.customJSONTemplate)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 170)
                        .overlay(alignment: .topLeading) {
                            if viewModel.configuration.customJSONTemplate.isEmpty {
                                Text("Custom JSON body. Placeholders: {model}, {instruction}, {audioBase64}, {audioDataURL}, {mimeType}, {filename}, {language}, {prompt}, {temperature}")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                if viewModel.configuration.backend == .localCommand {
                    TextEditor(text: $viewModel.configuration.localCommandTemplate)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 96)
                        .overlay(alignment: .topLeading) {
                            if viewModel.configuration.localCommandTemplate.isEmpty {
                                Text("Local command, e.g. whisper-cli -m {model} -f {audio} -otxt -of {outputBase}")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }

                TextEditor(text: $viewModel.configuration.customHeaders)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 62)
                    .overlay(alignment: .topLeading) {
                        if viewModel.configuration.customHeaders.isEmpty {
                            Text("Extra HTTP headers, one per line: Header: value")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
                    .disabled(viewModel.configuration.backend == .localCommand)

                TextEditor(text: $viewModel.configuration.extraFields)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 84)
                    .overlay(alignment: .topLeading) {
                        if viewModel.configuration.extraFields.isEmpty {
                            Text("Extra multipart fields, one per line: key=value")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

            Section {
                Button {
                    Task { await viewModel.transcribeSelectedFiles() }
                } label: {
                    Label(viewModel.isTranscribing ? "Transcribing..." : "Transcribe Queue", systemImage: "waveform.and.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canTranscribe)

                Button {
                    viewModel.cancelTranscription()
                } label: {
                    Label("Cancel", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.isTranscribing)
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 28)
    }
}

private struct TranscriptDetailView: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedRecord?.file.name ?? "No transcript selected")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(viewModel.selectedRecord?.status.label ?? "Add an audio file to begin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Export", selection: $viewModel.exportFormat) {
                    ForEach(TextExportFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
                .frame(width: 150)

                Button {
                    viewModel.exportSelectedResult()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.selectedRecord?.result == nil)

                Button {
                    viewModel.exportAllCompletedResults()
                } label: {
                    Label("Export All", systemImage: "tray.and.arrow.down")
                }
                .disabled(viewModel.completedRecords.isEmpty)
            }
            .padding(16)

            Divider()

            if let record = viewModel.selectedRecord, let result = record.result {
                TranscriptPreview(result: result)
            } else {
                ContentUnavailableView(
                    "Transcript Preview",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Completed transcriptions will appear here.")
                )
            }
        }
        .padding(.bottom, 28)
    }
}

private struct TranscriptPreview: View {
    let result: TranscriptionResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(result.text)
                    .font(.system(.body, design: .serif))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !result.segments.isEmpty {
                    Divider()
                    Text("Segments")
                        .font(.headline)

                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(result.segments) { segment in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(timeRange(segment))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 150, alignment: .leading)

                                Text(segment.text)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    private func timeRange(_ segment: TranscriptSegment) -> String {
        "\(formatTime(segment.start)) - \(formatTime(segment.end))"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        let wholeSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", hours, minutes, wholeSeconds)
    }
}

private struct StatusPill: View {
    let status: TranscriptionStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch status {
        case .complete: .green
        case .failed: .red
        case .running: .blue
        case .canceled: .secondary
        case .queued: .orange
        }
    }

    private var background: Color {
        foreground.opacity(0.14)
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var viewModel: TranscriptionViewModel

    var body: some View {
        HStack {
            if viewModel.isTranscribing {
                ProgressView()
                    .controlSize(.small)
            }
            Text(viewModel.statusMessage)
                .lineLimit(1)
            Spacer()
            Text("\(viewModel.records.count) file(s)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.bar)
    }
}
