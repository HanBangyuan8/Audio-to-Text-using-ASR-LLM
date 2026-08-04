import Foundation

struct TranscriptionQueueSummary: Equatable, Sendable {
    var total = 0
    var queued = 0
    var running = 0
    var completed = 0
    var failed = 0
    var canceled = 0

    func count(for status: TranscriptionStatus) -> Int {
        switch status {
        case .queued: queued
        case .running: running
        case .complete: completed
        case .failed: failed
        case .canceled: canceled
        }
    }
}

struct TranscriptionRecordIndex {
    private var recordsByID: [UUID: TranscriptionRecord] = [:]
    private(set) var summary = TranscriptionQueueSummary()

    init(records: [TranscriptionRecord]) {
        replace(with: records)
    }

    mutating func replace(with records: [TranscriptionRecord]) {
        recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var nextSummary = TranscriptionQueueSummary(total: records.count)

        for record in records {
            increment(record.status, in: &nextSummary)
        }

        summary = nextSummary
    }

    mutating func update(from oldRecord: TranscriptionRecord, to newRecord: TranscriptionRecord) {
        recordsByID[newRecord.id] = newRecord
        guard oldRecord.status != newRecord.status else { return }
        decrement(oldRecord.status, in: &summary)
        increment(newRecord.status, in: &summary)
    }

    func record(id: UUID?) -> TranscriptionRecord? {
        guard let id else { return nil }
        return recordsByID[id]
    }

    private func increment(_ status: TranscriptionStatus, in summary: inout TranscriptionQueueSummary) {
        switch status {
        case .queued: summary.queued += 1
        case .running: summary.running += 1
        case .complete: summary.completed += 1
        case .failed: summary.failed += 1
        case .canceled: summary.canceled += 1
        }
    }

    private func decrement(_ status: TranscriptionStatus, in summary: inout TranscriptionQueueSummary) {
        switch status {
        case .queued: summary.queued -= 1
        case .running: summary.running -= 1
        case .complete: summary.completed -= 1
        case .failed: summary.failed -= 1
        case .canceled: summary.canceled -= 1
        }
    }
}
