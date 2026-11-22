import Foundation
import Observation

@MainActor
@Observable
final class IPCalculatorViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case subnet
        case compare
        case reference

        var id: String { rawValue }

        var title: String {
            switch self {
            case .subnet: "Подсеть"
            case .compare: "Проверка"
            case .reference: "Справка"
            }
        }
    }

    static let quickPrefixes = [8, 16, 24, 25, 26, 27, 28, 30]
    static let splitLimit = 64

    var mode: Mode = .subnet

    var addressText = "192.168.0.10"
    var maskText = "24"
    var splitText = ""

    var firstText = "192.168.0.1"
    var secondText = "192.168.1.20"
    var compareMaskText = "255.255.255.0"
    var gatewayText = ""

    // MARK: Subnet

    /// "192.168.0.10/24" in the address field overrides the separate mask field.
    private var addressParts: (address: String, prefix: String?) {
        let parts = addressText.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : nil)
    }

    var hasEmbeddedPrefix: Bool { addressParts.prefix != nil }

    private var parsedAddress: IPv4Address? { IPv4Address(addressParts.address) }

    private var parsedMask: SubnetMask? { SubnetMask(addressParts.prefix ?? maskText) }

    var isAddressInvalid: Bool { !Self.isBlank(addressText) && parsedAddress == nil }

    var isMaskInvalid: Bool { parsedMask == nil }

    var subnet: IPv4Subnet? {
        guard let parsedAddress, let parsedMask else { return nil }
        return IPv4Subnet(address: parsedAddress, mask: parsedMask)
    }

    var subnetWarnings: [String] {
        guard let subnet else { return [] }
        var warnings: [String] = []
        switch subnet.addressRole {
        case .networkAddress: warnings.append("\(subnet.address) — адрес сети, устройству его назначать нельзя")
        case .broadcastAddress: warnings.append("\(subnet.address) — широковещательный адрес, устройству его назначать нельзя")
        case .host: break
        }
        if !subnet.address.scope.isAssignable {
            warnings.append(subnet.address.scope.title)
        }
        return warnings
    }

    func setPrefix(_ prefix: Int) {
        if hasEmbeddedPrefix {
            addressText = "\(addressParts.address)/\(prefix)"
        } else {
            maskText = String(prefix)
        }
    }

    private var splitPrefix: Int? { SubnetMask(splitText)?.prefix }

    var isSplitInvalid: Bool {
        guard !Self.isBlank(splitText) else { return false }
        guard let subnet, let splitPrefix else { return true }
        return subnet.subnetCount(newPrefix: splitPrefix) == nil
    }

    var splitTotal: Int? {
        guard let subnet, let splitPrefix else { return nil }
        return subnet.subnetCount(newPrefix: splitPrefix)
    }

    var splitSubnets: [IPv4Subnet] {
        guard let subnet, let splitPrefix else { return [] }
        return subnet.split(newPrefix: splitPrefix, limit: Self.splitLimit)
    }

    // MARK: Compare

    private var firstAddress: IPv4Address? { IPv4Address(firstText) }
    private var secondAddress: IPv4Address? { IPv4Address(secondText) }
    private var compareMask: SubnetMask? { SubnetMask(compareMaskText) }
    private var gateway: IPv4Address? { IPv4Address(gatewayText) }

    var isFirstInvalid: Bool { firstAddress == nil }
    var isSecondInvalid: Bool { secondAddress == nil }
    var isCompareMaskInvalid: Bool { compareMask == nil }
    var isGatewayInvalid: Bool { !Self.isBlank(gatewayText) && gateway == nil }

    var comparison: SubnetComparison? {
        guard let firstAddress, let secondAddress, let compareMask, !isGatewayInvalid else { return nil }
        return SubnetComparison(first: firstAddress, second: secondAddress, mask: compareMask, gateway: gateway)
    }

    var comparisonIssues: [String] {
        guard let comparison else { return [] }
        var issues: [String] = []
        if comparison.isDuplicate {
            issues.append("Одинаковые адреса — конфликт IP в сети")
        }
        for (name, subnet) in [("A", comparison.firstSubnet), ("B", comparison.secondSubnet)] {
            switch subnet.addressRole {
            case .networkAddress: issues.append("\(name): \(subnet.address) — адрес сети")
            case .broadcastAddress: issues.append("\(name): \(subnet.address) — широковещательный адрес")
            case .host: break
            }
            if !subnet.address.scope.isAssignable {
                issues.append("\(name): \(subnet.address.scope.title)")
            }
        }
        if let gateway = comparison.gateway, gateway == comparison.first || gateway == comparison.second {
            issues.append("Шлюз совпадает с адресом одного из устройств")
        }
        return issues
    }

    // MARK: Export

    var noteTitle: String {
        switch mode {
        case .subnet: "Подсеть \(subnet?.cidr ?? addressText)"
        case .compare: "Проверка IP: \(firstText) ↔ \(secondText)"
        case .reference: "Сетевая справка"
        }
    }

    var summary: String? {
        switch mode {
        case .subnet: subnetSummary
        case .compare: compareSummary
        case .reference: nil
        }
    }

    private var subnetSummary: String? {
        guard let subnet else { return nil }
        var lines = [
            "Подсеть \(subnet.cidr)",
            "Адрес: \(subnet.address) (\(subnet.address.scope.title))",
            "Маска: \(subnet.mask.dotted) (/\(subnet.mask.prefix)), wildcard \(subnet.mask.wildcardDotted)",
            "Сеть: \(subnet.network), широковещательный: \(subnet.broadcast)",
            "Узлы: \(subnet.firstHost) … \(subnet.lastHost) (\(subnet.hostCount))",
        ]
        lines += subnetWarnings.map { "! \($0)" }
        if let splitTotal, let splitPrefix {
            lines.append("")
            lines.append("Разбиение на /\(splitPrefix): \(splitTotal) подсетей")
            lines += splitSubnets.map { "  \($0.cidr): \($0.firstHost) … \($0.lastHost)" }
        }
        return lines.joined(separator: "\n")
    }

    private var compareSummary: String? {
        guard let comparison else { return nil }
        var lines = [
            "A: \(comparison.first) → сеть \(comparison.firstSubnet.cidr)",
            "B: \(comparison.second) → сеть \(comparison.secondSubnet.cidr)",
            comparison.isSameSubnet ? "Одна подсеть: связь напрямую возможна" : "Разные подсети: нужен маршрутизатор или смена адреса",
        ]
        if let gateway = comparison.gateway, let inSubnet = comparison.isGatewayInSubnet {
            lines.append("Шлюз \(gateway): \(inSubnet ? "в подсети A" : "вне подсети A")")
        }
        lines += comparisonIssues.map { "! \($0)" }
        return lines.joined(separator: "\n")
    }

    private static func isBlank(_ text: String) -> Bool { text.allSatisfy(\.isWhitespace) }
}
