import Foundation

/// Layout-free description of a printable protocol. Checklists and I/O lists build it;
/// `ReportPDFRenderer` turns it into A4 pages.
struct ReportDocument: Equatable {
    var title: String
    var headerLines: [String]
    var sections: [ReportSection]
    var summaryLines: [String]
    var signatures: [ReportSignature]
}

struct ReportSection: Equatable {
    var title: String
    var rows: [ReportRow]
}

enum ReportStatus: Equatable {
    case passed
    case failed
    case pending

    var mark: String {
        switch self {
        case .passed: "✓"
        case .failed: "✗"
        case .pending: "—"
        }
    }

    var title: String {
        switch self {
        case .passed: "выполнено"
        case .failed: "замечание"
        case .pending: "не проверено"
        }
    }
}

struct ReportRow: Equatable {
    var status: ReportStatus
    var text: String
    var details: [String]
    var images: [Data]
}

struct ReportSignature: Equatable {
    var role: String
    var name: String
}

/// Who signs the protocol; remembered between exports.
struct ReportSigners: Equatable {
    var performer: String
    var organization: String
    var customer: String

    var signatures: [ReportSignature] {
        [
            ReportSignature(role: "Выполнил", name: performer),
            ReportSignature(role: "Представитель заказчика", name: customer),
        ]
    }

    var organizationLine: String? {
        let trimmed = organization.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "Организация: \(trimmed)"
    }
}

enum ReportFileName {
    /// File-system-safe name: «Протокол_PT-101_2026-11-22.pdf».
    static func make(prefix: String, object: String, date: Date) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines)
        let cleaned = object
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        let day = date.formatted(.iso8601.year().month().day())
        let body = cleaned.isEmpty ? prefix : "\(prefix)_\(cleaned.prefix(60))"
        return "\(body)_\(day).pdf"
    }
}
