import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var configuration: ProviderConfiguration {
        didSet { saveConfiguration() }
    }
    @Published var records: [TranscriptionRecord] = [] {
        didSet { saveRecords() }
    }
    @Published var selectedRecordID: TranscriptionRecord.ID?
    @Published var exportFormat: TextExportFormat = .markdown
    @Published var statusMessage = "Ready"
    @Published var isTranscribing = false

    private let client = ASRClient()
    private var transcriptionTask: Task<Void, Never>?

    var selectedRecord: TranscriptionRecord? {
        guard let selectedRecordID else { return records.first }
        return records.first { $0.id == selectedRecordID } ?? records.first
    }

    var canTranscribe: Bool {
        guard !records.isEmpty && !isTranscribing else { return false }
        switch configuration.backend {
        case .localCommand:
            return !configuration.localCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .apiTranscriptions, .apiChatAudio, .apiCustomJSON:
            return !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var completedRecords: [TranscriptionRecord] {
        records.filter { $0.result != nil }
    }

    init() {
        configuration = Self.loadConfiguration()
        records = Self.loadRecords()
        selectedRecordID = records.first?.id
    }

    func pickAudioFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose audio files"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.supportedAudioTypes

        guard panel.runModal() == .OK else { return }
        addAudioFiles(panel.urls)
    }

    func addAudioFiles(_ urls: [URL]) {
        let existing = Set(records.map { $0.file.url })
        let additions = urls
            .filter { !existing.contains($0) }
            .map { TranscriptionRecord(file: AudioFile(url: $0)) }

        guard !additions.isEmpty else { return }
        records.append(contentsOf: additions)
        selectedRecordID = additions.first?.id
        statusMessage = "Added \(additions.count) audio file(s)"
    }

    func removeSelectedRecord() {
        guard let selectedRecordID else { return }
        records.removeAll { $0.id == selectedRecordID }
        self.selectedRecordID = records.first?.id
    }

    func revealSelectedAudioFile() {
        guard let record = selectedRecord else { return }
        NSWorkspace.shared.activateFileViewerSelecting([record.file.url])
    }

    func clearCompleted() {
        records.removeAll { $0.status == .complete }
        selectedRecordID = records.first?.id
    }

    func resetFailedAndCanceled() {
        for index in records.indices where records[index].status == .failed || records[index].status == .canceled {
            records[index].status = .queued
            records[index].errorMessage = nil
        }
        statusMessage = "Reset failed and canceled items"
    }

    func applyPreset(_ preset: ProviderPreset) {
        let existingKey = configuration.apiKey
        configuration = preset.configuration
        configuration.apiKey = existingKey
        if configuration.endpointPath.isEmpty {
            configuration.endpointPath = configuration.backend.recommendedEndpointPath
        }
        statusMessage = "Applied preset: \(preset.name)"
    }

    func importConfiguration() {
        let panel = NSOpenPanel()
        panel.title = "Import provider configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            configuration = try JSONDecoder().decode(ProviderConfiguration.self, from: data)
            statusMessage = "Imported configuration"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "Export provider configuration"
        panel.nameFieldStringValue = "asr-llm-provider.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
            statusMessage = "Exported configuration"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func copySelectedTranscript() {
        guard let text = selectedRecord?.result?.text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Copied transcript"
    }

    func transcribeSelectedFiles() async {
        guard canTranscribe else { return }
        transcriptionTask?.cancel()

        isTranscribing = true
        statusMessage = "Starting transcription..."

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            await self.runQueue()
        }

        await transcriptionTask?.value
    }

    func cancelTranscription() {
        transcriptionTask?.cancel()
        isTranscribing = false
        statusMessage = "Canceled"

        for index in records.indices where records[index].status == .running || records[index].status == .queued {
            records[index].status = .canceled
        }
    }

    func exportSelectedResult() {
        guard let record = selectedRecord, let result = record.result else { return }

        let panel = NSSavePanel()
        panel.title = "Export transcript"
        panel.nameFieldStringValue = "\(record.file.url.deletingPathExtension().lastPathComponent).\(exportFormat.fileExtension)"
        panel.allowedContentTypes = [Self.contentType(for: exportFormat)]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let rendered = try TranscriptExporter.render(result, as: exportFormat)
            try rendered.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Exported \(url.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportAllCompletedResults() {
        let completed = completedRecords
        guard !completed.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose export folder"
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            for record in completed {
                guard let result = record.result else { continue }
                let rendered = try TranscriptExporter.render(result, as: exportFormat)
                let baseName = record.file.url.deletingPathExtension().lastPathComponent
                let url = uniqueURL(
                    in: folder,
                    baseName: baseName,
                    extension: exportFormat.fileExtension
                )
                try rendered.write(to: url, atomically: true, encoding: .utf8)
            }
            statusMessage = "Exported \(completed.count) transcript(s)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runQueue() async {
        defer {
            isTranscribing = false
            transcriptionTask = nil
        }

        for index in records.indices where records[index].status == .queued || records[index].status == .failed {
            if Task.isCancelled {
                records[index].status = .canceled
                continue
            }

            records[index].status = .running
            records[index].errorMessage = nil
            selectedRecordID = records[index].id
            statusMessage = "Transcribing \(records[index].file.name)..."

            do {
                let result = try await client.transcribe(fileURL: records[index].file.url, configuration: configuration)
                records[index].result = result
                records[index].status = .complete
                statusMessage = "Finished \(records[index].file.name)"
            } catch is CancellationError {
                records[index].status = .canceled
                statusMessage = "Canceled"
            } catch {
                records[index].status = .failed
                records[index].errorMessage = error.localizedDescription
                statusMessage = error.localizedDescription
            }
        }
    }

    private func saveConfiguration() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: "ProviderConfiguration")
    }

    private static func loadConfiguration() -> ProviderConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "ProviderConfiguration"),
              let configuration = try? JSONDecoder().decode(ProviderConfiguration.self, from: data) else {
            return ProviderConfiguration()
        }

        return configuration
    }

    private func saveRecords() {
        let snapshot = records.map { record in
            var copy = record
            if copy.status == .running {
                copy.status = .queued
            }
            return copy
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: Self.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: Self.recordsURL, options: .atomic)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private static func loadRecords() -> [TranscriptionRecord] {
        guard let data = try? Data(contentsOf: recordsURL) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TranscriptionRecord].self, from: data).map { record in
                var copy = record
                if copy.status == .running {
                    copy.status = .queued
                }
                return copy
            }
        } catch {
            return []
        }
    }

    private static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AudioToTextASRLLM", isDirectory: true)
    }

    private static var recordsURL: URL {
        applicationSupportDirectory.appendingPathComponent("records.json")
    }

    private static var supportedAudioTypes: [UTType] {
        [
            .audio,
            UTType(filenameExtension: "mp3"),
            UTType(filenameExtension: "m4a"),
            UTType(filenameExtension: "wav"),
            UTType(filenameExtension: "flac"),
            UTType(filenameExtension: "ogg"),
            UTType(filenameExtension: "oga"),
            UTType(filenameExtension: "webm"),
            UTType(filenameExtension: "aac")
        ].compactMap { $0 }
    }

    private static func contentType(for format: TextExportFormat) -> UTType {
        switch format {
        case .txt: .plainText
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .srt: UTType(filenameExtension: "srt") ?? .plainText
        case .vtt: UTType(filenameExtension: "vtt") ?? .plainText
        case .json: .json
        case .csv: .commaSeparatedText
        case .tsv: UTType(filenameExtension: "tsv") ?? .tabSeparatedText
        case .html: .html
        }
    }

    private func uniqueURL(in folder: URL, baseName: String, extension fileExtension: String) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = folder
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}
