import Foundation
import SwiftData

enum NoteCategory: String, CaseIterable, Identifiable {
    case electrical
    case automation
    case design
    case field
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .electrical: "Электрика"
        case .automation: "АСУ ТП"
        case .design: "Проектирование"
        case .field: "Объект / ПНР"
        case .general: "Общее"
        }
    }
}

@Model
final class EngineerNote {
    var title: String
    var body: String
    /// Stored as raw string: SwiftData predicates on custom enums are unreliable across iOS 17.x.
    var categoryRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, body: String, category: NoteCategory = .general, createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var category: NoteCategory {
        get { NoteCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    var exportText: String {
        let date = createdAt.formatted(date: .numeric, time: .shortened)
        return "\(title)\n[\(category.title) · \(date)]\n\n\(body)"
    }
}
