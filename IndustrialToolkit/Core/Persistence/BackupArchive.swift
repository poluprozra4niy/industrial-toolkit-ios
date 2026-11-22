import Foundation

/// Portable JSON snapshot of the notebook, checklists (with photos) and I/O lists. Kept free of
/// SwiftData so the format and the merge rules are testable without a model container.
struct BackupArchive: Codable, Equatable {
    static let formatIdentifier = "industrial-toolkit-backup"
    /// v2 added checklist photos and I/O lists; v1 files still restore.
    static let currentVersion = 2

    struct Note: Codable, Equatable {
        var title: String
        var body: String
        var category: String
        var createdAt: Date
        var updatedAt: Date
    }

    struct Checklist: Codable, Equatable {
        var objectName: String
        var kind: String
        var createdAt: Date
        var entries: [Entry]
    }

    struct Entry: Codable, Equatable {
        var order: Int
        var section: String
        var text: String
        var hint: String
        var isDone: Bool
        var remark: String
        var checkedAt: Date?
        /// JPEG, base64 in JSON. Absent in v1 files.
        var photos: [Photo]?
    }

    struct Photo: Codable, Equatable {
        var data: Data
        var createdAt: Date
    }

    struct SignalList: Codable, Equatable {
        var name: String
        var createdAt: Date
        var points: [SignalPoint]
    }

    struct SignalPoint: Codable, Equatable {
        var order: Int
        var record: IOSignalRecord
        var status: IOPointStatus
        var remark: String
        var checkedAt: Date?
    }

    var format: String
    var version: Int
    var exportedAt: Date
    var notes: [Note]
    var checklists: [Checklist]
    /// Absent in v1 files.
    var ioLists: [SignalList]?

    init(exportedAt: Date, notes: [Note], checklists: [Checklist], ioLists: [SignalList] = []) {
        self.format = Self.formatIdentifier
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.notes = notes
        self.checklists = checklists
        self.ioLists = ioLists
    }

    var isEmpty: Bool { notes.isEmpty && checklists.isEmpty && (ioLists ?? []).isEmpty }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: BackupArchive
        do {
            archive = try decoder.decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.unreadable
        }
        guard archive.format == formatIdentifier else { throw BackupError.foreignFile }
        guard archive.version <= currentVersion else { throw BackupError.newerVersion(archive.version) }
        return archive
    }

    static func fileName(for date: Date) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        return "industrial-toolkit-backup-\(day).json"
    }
}

enum BackupError: LocalizedError, Equatable {
    case unreadable
    case foreignFile
    case newerVersion(Int)
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .unreadable: "Файл повреждён или это не JSON."
        case .foreignFile: "Это не резервная копия «Инженер АСУ ТП»."
        case .newerVersion(let version): "Копия создана более новой версией приложения (формат \(version)). Обновите приложение."
        case .accessDenied: "Нет доступа к файлу. Выберите его ещё раз в «Файлах»."
        }
    }
}

/// Restoring the same backup twice must not duplicate records. A record is identified by its
/// creation second plus its name: ISO 8601 drops sub-second precision on export.
enum BackupMerge {
    struct NoteKey: Hashable {
        let created: Int
        let title: String
    }

    struct ChecklistKey: Hashable {
        let created: Int
        let objectName: String
        let kind: String
    }

    struct SignalListKey: Hashable {
        let created: Int
        let name: String
    }

    struct Plan: Equatable {
        let notes: [BackupArchive.Note]
        let checklists: [BackupArchive.Checklist]
        let ioLists: [BackupArchive.SignalList]
        let skippedDuplicates: Int
    }

    static func second(_ date: Date) -> Int { Int(date.timeIntervalSince1970.rounded(.down)) }

    static func noteKey(title: String, createdAt: Date) -> NoteKey {
        NoteKey(created: second(createdAt), title: title)
    }

    static func checklistKey(objectName: String, kind: String, createdAt: Date) -> ChecklistKey {
        ChecklistKey(created: second(createdAt), objectName: objectName, kind: kind)
    }

    static func signalListKey(name: String, createdAt: Date) -> SignalListKey {
        SignalListKey(created: second(createdAt), name: name)
    }

    static func plan(
        _ archive: BackupArchive,
        existingNotes: Set<NoteKey>,
        existingChecklists: Set<ChecklistKey>,
        existingSignalLists: Set<SignalListKey> = []
    ) -> Plan {
        var seenNotes = existingNotes
        var seenChecklists = existingChecklists
        var seenSignalLists = existingSignalLists
        let sourceLists = archive.ioLists ?? []
        let ioLists = sourceLists.filter { seenSignalLists.insert(signalListKey(name: $0.name, createdAt: $0.createdAt)).inserted }
        let notes = archive.notes.filter { seenNotes.insert(noteKey(title: $0.title, createdAt: $0.createdAt)).inserted }
        let checklists = archive.checklists.filter {
            seenChecklists.insert(checklistKey(objectName: $0.objectName, kind: $0.kind, createdAt: $0.createdAt)).inserted
        }
        let skipped = archive.notes.count - notes.count
            + archive.checklists.count - checklists.count
            + sourceLists.count - ioLists.count
        return Plan(notes: notes, checklists: checklists, ioLists: ioLists, skippedDuplicates: skipped)
    }
}
