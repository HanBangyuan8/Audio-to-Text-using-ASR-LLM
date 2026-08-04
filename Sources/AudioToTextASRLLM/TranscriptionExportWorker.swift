import Foundation

actor TranscriptionExportWorker {
    func importConfiguration(from url: URL) throws -> ProviderConfiguration {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProviderConfiguration.self, from: data)
    }

    func exportConfiguration(_ configuration: ProviderConfiguration, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: url, options: .atomic)
    }

    func exportResult(_ result: TranscriptionResult, format: TextExportFormat, to url: URL) throws {
        let rendered = try TranscriptExporter.render(result, as: format)
        try rendered.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportAll(
        _ records: [TranscriptionRecord],
        format: TextExportFormat,
        to folder: URL
    ) throws -> Int {
        var exportedCount = 0
        for record in records {
            guard let result = record.result else { continue }
            let rendered = try TranscriptExporter.render(result, as: format)
            let baseName = record.file.url.deletingPathExtension().lastPathComponent
            let url = uniqueURL(in: folder, baseName: baseName, extension: format.fileExtension)
            try rendered.write(to: url, atomically: true, encoding: .utf8)
            exportedCount += 1
        }
        return exportedCount
    }

    private func uniqueURL(in folder: URL, baseName: String, extension fileExtension: String) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder
                .appendingPathComponent("\(baseName)-\(counter)")
                .appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}
