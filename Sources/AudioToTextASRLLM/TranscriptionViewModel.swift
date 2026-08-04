import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TranscriptionViewModel: ObservableObject {
    @Published var configuration: ProviderConfiguration {
        didSet { persistConfiguration() }
    }
    @Published private(set) var records: [TranscriptionRecord] = []
    @Published var selectedRecordID: TranscriptionRecord.ID?
    @Published var exportFormat: TextExportFormat = .markdown
    @Published var statusMessage = "Ready"
    @Published var isTranscribing = false

    private let client = ASRClient()
    private let persistenceWorker = TranscriptionPersistenceWorker()
    private let exportWorker = TranscriptionExportWorker()
    private let runtimePlan = RuntimeFeaturePlan.current
    private var recordIndex = TranscriptionRecordIndex(records: [])
    private var transcriptionTask: Task<Void, Never>?

    var selectedRecord: TranscriptionRecord? {
        recordIndex.record(id: selectedRecordID) ?? records.first
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

    var queueSummary: TranscriptionQueueSummary {
        recordIndex.summary
    }

    var visibleRecords: ArraySlice<TranscriptionRecord> {
        records.prefix(runtimePlan.visibleTaskBudget)
    }

    var transcriptSegmentRenderBudget: Int {
        runtimePlan.transcriptSegmentRenderBudget
    }

    init() {
        configuration = Self.loadConfiguration()
        records = Self.loadRecords()
        recordIndex = TranscriptionRecordIndex(records: records)
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
        recordsDidChange()
        selectedRecordID = additions.first?.id
        statusMessage = "Added \(additions.count) audio file(s)"
    }

    func removeSelectedRecord() {
        guard let selectedRecordID else { return }
        records.removeAll { $0.id == selectedRecordID }
        recordsDidChange()
        self.selectedRecordID = records.first?.id
    }

    func revealSelectedAudioFile() {
        guard let record = selectedRecord else { return }
        NSWorkspace.shared.activateFileViewerSelecting([record.file.url])
    }

    func clearCompleted() {
        records.removeAll { $0.status == .complete }
        recordsDidChange()
        selectedRecordID = records.first?.id
    }

    func resetFailedAndCanceled() {
        var updatedRecords = records
        for index in updatedRecords.indices where updatedRecords[index].status == .failed || updatedRecords[index].status == .canceled {
            updatedRecords[index].status = .queued
            updatedRecords[index].errorMessage = nil
        }
        records = updatedRecords
        recordsDidChange()
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

        Task {
            do {
                configuration = try await exportWorker.importConfiguration(from: url)
                statusMessage = "Imported configuration"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "Export provider configuration"
        panel.nameFieldStringValue = "asr-llm-provider.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let configuration = configuration
        Task {
            do {
                try await exportWorker.exportConfiguration(configuration, to: url)
                statusMessage = "Exported configuration"
            } catch {
                statusMessage = error.localizedDescription
            }
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

        var updatedRecords = records
        for index in updatedRecords.indices where updatedRecords[index].status == .running || updatedRecords[index].status == .queued {
            updatedRecords[index].status = .canceled
        }
        records = updatedRecords
        recordsDidChange()
    }

    func exportSelectedResult() {
        guard let record = selectedRecord, let result = record.result else { return }

        let panel = NSSavePanel()
        panel.title = "Export transcript"
        panel.nameFieldStringValue = "\(record.file.url.deletingPathExtension().lastPathComponent).\(exportFormat.fileExtension)"
        panel.allowedContentTypes = [Self.contentType(for: exportFormat)]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let format = exportFormat
        Task {
            do {
                try await exportWorker.exportResult(result, format: format, to: url)
                statusMessage = "Exported \(url.lastPathComponent)"
            } catch {
                statusMessage = error.localizedDescription
            }
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

        let format = exportFormat
        Task {
            do {
                let count = try await exportWorker.exportAll(completed, format: format, to: folder)
                statusMessage = "Exported \(count) transcript(s)"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func runQueue() async {
        defer {
            isTranscribing = false
            transcriptionTask = nil
        }

        for index in records.indices where records[index].status == .queued || records[index].status == .failed {
            if Task.isCancelled {
                updateRecord(at: index) { record in
                    record.status = .canceled
                }
                continue
            }

            updateRecord(at: index) { record in
                record.status = .running
                record.errorMessage = nil
            }
            selectedRecordID = records[index].id
            statusMessage = "Transcribing \(records[index].file.name)..."

            do {
                let result = try await client.transcribe(fileURL: records[index].file.url, configuration: configuration)
                updateRecord(at: index) { record in
                    record.result = result
                    record.status = .complete
                }
                statusMessage = "Finished \(records[index].file.name)"
            } catch is CancellationError {
                updateRecord(at: index) { record in
                    record.status = .canceled
                }
                statusMessage = "Canceled"
            } catch {
                updateRecord(at: index) { record in
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                }
                statusMessage = error.localizedDescription
            }
        }
    }

    private func persistConfiguration() {
        let snapshot = configuration
        let debounceNanoseconds = runtimePlan.configurationDebounceNanoseconds
        Task {
            await persistenceWorker.scheduleConfigurationSave(
                configuration: snapshot,
                debounceNanoseconds: debounceNanoseconds
            )
        }
    }

    private static func loadConfiguration() -> ProviderConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "ProviderConfiguration"),
              let configuration = try? JSONDecoder().decode(ProviderConfiguration.self, from: data) else {
            return ProviderConfiguration()
        }

        return configuration
    }

    private func persistRecords() {
        let snapshot = records
        let destination = Self.recordsURL
        let debounceNanoseconds = runtimePlan.persistenceDebounceNanoseconds
        Task {
            await persistenceWorker.scheduleRecordsSave(
                records: snapshot,
                destination: destination,
                debounceNanoseconds: debounceNanoseconds
            )
        }
    }

    private func recordsDidChange() {
        recordIndex.replace(with: records)
        persistRecords()
    }

    private func updateRecord(
        at index: Int,
        mutation: (inout TranscriptionRecord) -> Void
    ) {
        guard records.indices.contains(index) else { return }
        let oldRecord = records[index]
        var newRecord = oldRecord
        mutation(&newRecord)
        records[index] = newRecord
        recordIndex.update(from: oldRecord, to: newRecord)
        persistRecords()
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

}
