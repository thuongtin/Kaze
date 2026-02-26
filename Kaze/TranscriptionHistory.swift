import Foundation
import Combine

// MARK: - TranscriptionRecord

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let engine: String       // "dictation" or "whisper"
    let wasEnhanced: Bool

    init(text: String, engine: TranscriptionEngine, wasEnhanced: Bool) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.engine = engine.rawValue
        self.wasEnhanced = wasEnhanced
    }
}

// MARK: - TranscriptionHistoryManager

/// Manages a persistent history of the last 50 transcriptions.
/// Stored as a JSON file in Application Support.
@MainActor
class TranscriptionHistoryManager: ObservableObject {
    @Published private(set) var records: [TranscriptionRecord] = []

    private static let maxRecords = 50

    private static var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.fayazahmed.Kaze", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    init() {
        loadFromDisk()
    }

    /// Adds a new transcription record. Keeps only the most recent 50.
    func addRecord(_ record: TranscriptionRecord) {
        guard !record.text.isEmpty else { return }
        records.insert(record, at: 0)
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }
        saveToDisk()
    }

    /// Deletes a single record by ID.
    func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        saveToDisk()
    }

    /// Clears all history.
    func clearHistory() {
        records.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: Self.historyFileURL, options: .atomic)
        } catch {
            print("TranscriptionHistory: Failed to save: \(error)")
        }
    }

    private func loadFromDisk() {
        let url = Self.historyFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
        } catch {
            print("TranscriptionHistory: Failed to load: \(error)")
            records = []
        }
    }
}
