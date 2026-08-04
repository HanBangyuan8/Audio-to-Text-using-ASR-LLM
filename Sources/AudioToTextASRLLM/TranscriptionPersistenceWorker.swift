import Foundation

actor TranscriptionPersistenceWorker {
    private var scheduledConfigurationSave: Task<Void, Never>?
    private var scheduledRecordsSave: Task<Void, Never>?

    func scheduleConfigurationSave(
        configuration: ProviderConfiguration,
        debounceNanoseconds: UInt64
    ) {
        scheduledConfigurationSave?.cancel()
        scheduledConfigurationSave = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled,
                  let data = try? JSONEncoder().encode(configuration)
            else { return }
            UserDefaults.standard.set(data, forKey: "ProviderConfiguration")
        }
    }

    func scheduleRecordsSave(
        records: [TranscriptionRecord],
        destination: URL,
        debounceNanoseconds: UInt64
    ) {
        scheduledRecordsSave?.cancel()
        scheduledRecordsSave = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let snapshot = records.map { record -> TranscriptionRecord in
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
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: destination, options: .atomic)
            } catch {
                // Persistence is best-effort so disk failures never block transcription work.
            }
        }
    }
}
