import Foundation
import SwiftData

@Model
final class IOList {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \IOPoint.list)
    var points: [IOPoint] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    var orderedPoints: [IOPoint] { points.sorted { $0.order < $1.order } }

    var snapshots: [IOPointSnapshot] { orderedPoints.map(\.snapshot) }

    var progress: ChecklistProgress { IOListReport.progress(of: snapshots) }

    func protocolDocument(signers: ReportSigners, issuedAt: Date = .now) -> ReportDocument {
        IOListReport.document(name: name, points: snapshots, signers: signers, issuedAt: issuedAt)
    }

    var textReport: String {
        var lines = ["Список сигналов: \(name)", "Проверено: \(progress.done) из \(progress.total)", ""]
        for point in orderedPoints {
            let remark = point.remark.isEmpty ? "" : " — \(point.remark)"
            lines.append("[\(point.status.reportStatus.mark)] \(point.tag) \(point.kindRaw) \(point.record.rangeDescription ?? "")\(remark)")
        }
        return lines.joined(separator: "\n")
    }

    /// Points are linked after the list is inserted: see ChecklistRun.make.
    @discardableResult
    static func make(in context: ModelContext, name: String, records: [IOSignalRecord]) -> IOList {
        let list = IOList(name: name)
        context.insert(list)
        for (order, record) in records.enumerated() {
            let point = IOPoint(order: order, record: record)
            context.insert(point)
            point.list = list
        }
        return list
    }
}

@Model
final class IOPoint {
    var order: Int
    var tag: String
    var details: String
    var kindRaw: String
    /// Empty for discrete signals.
    var signalRaw: String
    var low: Double?
    var high: Double?
    var unit: String
    var address: String
    var statusRaw: String
    var remark: String
    var checkedAt: Date?
    var list: IOList?

    init(order: Int, record: IOSignalRecord) {
        self.order = order
        self.tag = record.tag
        self.details = record.details
        self.kindRaw = record.kind.rawValue
        self.signalRaw = record.signal?.rawValue ?? ""
        self.low = record.low
        self.high = record.high
        self.unit = record.unit
        self.address = record.address
        self.statusRaw = IOPointStatus.pending.rawValue
        self.remark = ""
        self.checkedAt = nil
    }

    var kind: IOSignalKind { IOSignalKind(rawValue: kindRaw) ?? .di }

    var status: IOPointStatus {
        get { IOPointStatus(rawValue: statusRaw) ?? .pending }
        set {
            statusRaw = newValue.rawValue
            checkedAt = newValue == .pending ? nil : .now
        }
    }

    var record: IOSignalRecord {
        IOSignalRecord(
            tag: tag,
            details: details,
            kind: kind,
            signal: SignalRange(rawValue: signalRaw),
            low: low,
            high: high,
            unit: unit,
            address: address
        )
    }

    var snapshot: IOPointSnapshot {
        IOPointSnapshot(record: record, status: status, remark: remark, checkedAt: checkedAt)
    }
}
