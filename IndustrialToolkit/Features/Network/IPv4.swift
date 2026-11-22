import Foundation

struct IPv4Address: Hashable, Comparable, CustomStringConvertible {
    let value: UInt32

    init(value: UInt32) {
        self.value = value
    }

    /// Dotted-quad only: four decimal octets 0…255.
    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard (1...3).contains(part.count),
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let octet = UInt32(part), octet <= 255
            else { return nil }
            result = (result << 8) | octet
        }
        self.value = result
    }

    var octets: [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> UInt32($0)) } }

    var description: String { octets.map { String($0) }.joined(separator: ".") }

    var binary: String { octets.map { $0.binaryString(digits: 8) }.joined(separator: ".") }

    var scope: IPv4Scope { IPv4Scope(self) }

    static func < (lhs: IPv4Address, rhs: IPv4Address) -> Bool { lhs.value < rhs.value }
}

enum IPv4Scope: Equatable {
    case unspecified
    case loopback
    case privateNetwork
    case linkLocal
    case multicast
    case limitedBroadcast
    case publicNetwork

    init(_ address: IPv4Address) {
        let value = address.value
        func inBlock(_ base: UInt32, _ prefix: UInt32) -> Bool {
            value >> (32 - prefix) == base >> (32 - prefix)
        }
        if value == 0 {
            self = .unspecified
        } else if value == .max {
            self = .limitedBroadcast
        } else if inBlock(0x7F00_0000, 8) {
            self = .loopback
        } else if inBlock(0x0A00_0000, 8) || inBlock(0xAC10_0000, 12) || inBlock(0xC0A8_0000, 16) {
            self = .privateNetwork
        } else if inBlock(0xA9FE_0000, 16) {
            self = .linkLocal
        } else if inBlock(0xE000_0000, 4) {
            self = .multicast
        } else {
            self = .publicNetwork
        }
    }

    var title: String {
        switch self {
        case .unspecified: "Не задан (0.0.0.0)"
        case .loopback: "Loopback (127/8)"
        case .privateNetwork: "Частный (RFC 1918)"
        case .linkLocal: "Link-local (169.254/16): DHCP не ответил"
        case .multicast: "Multicast (224/4)"
        case .limitedBroadcast: "Широковещательный 255.255.255.255"
        case .publicNetwork: "Публичный"
        }
    }

    /// Only private and public unicast addresses can be assigned to a PLC or HMI port.
    var isAssignable: Bool { self == .privateNetwork || self == .publicNetwork }
}

struct SubnetMask: Hashable {
    let prefix: Int

    init?(prefix: Int) {
        guard (0...32).contains(prefix) else { return nil }
        self.prefix = prefix
    }

    /// Accepts "24", "/24" or a contiguous dotted mask such as "255.255.255.192".
    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(".") {
            guard let address = IPv4Address(trimmed) else { return nil }
            let ones = address.value.nonzeroBitCount
            guard address.value == Self.bits(forPrefix: ones) else { return nil }
            self.prefix = ones
        } else {
            let digits = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
            guard let prefix = Int(digits), (0...32).contains(prefix) else { return nil }
            self.prefix = prefix
        }
    }

    var value: UInt32 { Self.bits(forPrefix: prefix) }

    var wildcard: UInt32 { ~value }

    var dotted: String { IPv4Address(value: value).description }

    var wildcardDotted: String { IPv4Address(value: wildcard).description }

    private static func bits(forPrefix prefix: Int) -> UInt32 {
        prefix == 0 ? 0 : UInt32.max << UInt32(32 - prefix)
    }
}

enum AddressRole: Equatable {
    case host
    case networkAddress
    case broadcastAddress
}

struct IPv4Subnet: Hashable, Identifiable {
    let address: IPv4Address
    let mask: SubnetMask

    var id: UInt32 { network.value }

    var network: IPv4Address { IPv4Address(value: address.value & mask.value) }

    var broadcast: IPv4Address { IPv4Address(value: network.value | mask.wildcard) }

    var cidr: String { "\(network)/\(mask.prefix)" }

    /// /31 is a point-to-point link (RFC 3021) with two usable addresses, /32 a single host.
    var hostCount: Int {
        switch mask.prefix {
        case 32: 1
        case 31: 2
        default: (1 << (32 - mask.prefix)) - 2
        }
    }

    var firstHost: IPv4Address {
        mask.prefix >= 31 ? network : IPv4Address(value: network.value + 1)
    }

    var lastHost: IPv4Address {
        mask.prefix >= 31 ? broadcast : IPv4Address(value: broadcast.value - 1)
    }

    var addressRole: AddressRole {
        guard mask.prefix <= 30 else { return .host }
        if address == network { return .networkAddress }
        if address == broadcast { return .broadcastAddress }
        return .host
    }

    func contains(_ other: IPv4Address) -> Bool {
        other.value & mask.value == network.value
    }

    func subnetCount(newPrefix: Int) -> Int? {
        guard newPrefix >= mask.prefix, newPrefix <= 32 else { return nil }
        return 1 << (newPrefix - mask.prefix)
    }

    /// Consecutive subnets of `newPrefix` inside this network, capped at `limit` entries.
    func split(newPrefix: Int, limit: Int) -> [IPv4Subnet] {
        guard let count = subnetCount(newPrefix: newPrefix), let newMask = SubnetMask(prefix: newPrefix) else { return [] }
        let blockSize = UInt64(1) << UInt64(32 - newPrefix)
        return (0..<min(count, limit)).map { index in
            let start = UInt64(network.value) + UInt64(index) * blockSize
            return IPv4Subnet(address: IPv4Address(value: UInt32(truncatingIfNeeded: start)), mask: newMask)
        }
    }
}

/// Two devices sharing one mask: the classic commissioning question "can the HMI see the PLC?".
struct SubnetComparison: Equatable {
    let first: IPv4Address
    let second: IPv4Address
    let mask: SubnetMask
    let gateway: IPv4Address?

    var firstSubnet: IPv4Subnet { IPv4Subnet(address: first, mask: mask) }
    var secondSubnet: IPv4Subnet { IPv4Subnet(address: second, mask: mask) }

    var isSameSubnet: Bool { firstSubnet.network == secondSubnet.network }

    var isDuplicate: Bool { first == second }

    /// nil when no gateway is given.
    var isGatewayInSubnet: Bool? { gateway.map { firstSubnet.contains($0) } }
}

struct IndustrialPort: Identifiable {
    let protocolName: String
    let port: String
    let transport: String
    let note: String

    var id: String { protocolName }
}

enum IndustrialPorts {
    static let all: [IndustrialPort] = [
        IndustrialPort(protocolName: "Modbus TCP", port: "502", transport: "TCP", note: ""),
        IndustrialPort(protocolName: "Modbus TCP Security", port: "802", transport: "TCP", note: "TLS"),
        IndustrialPort(protocolName: "S7comm (Siemens)", port: "102", transport: "TCP", note: "ISO-TSAP"),
        IndustrialPort(protocolName: "PROFINET", port: "34962–34964", transport: "UDP", note: "Циклика RT идёт на уровне Ethernet, без IP"),
        IndustrialPort(protocolName: "EtherNet/IP", port: "44818 / 2222", transport: "TCP+UDP / UDP", note: "Явный обмен / I/O"),
        IndustrialPort(protocolName: "OPC UA", port: "4840", transport: "TCP", note: ""),
        IndustrialPort(protocolName: "МЭК 60870-5-104", port: "2404", transport: "TCP", note: ""),
        IndustrialPort(protocolName: "DNP3", port: "20000", transport: "TCP / UDP", note: ""),
        IndustrialPort(protocolName: "BACnet/IP", port: "47808", transport: "UDP", note: ""),
        IndustrialPort(protocolName: "MQTT", port: "1883 / 8883", transport: "TCP", note: "8883 — TLS"),
        IndustrialPort(protocolName: "SNMP", port: "161 / 162", transport: "UDP", note: "162 — trap"),
        IndustrialPort(protocolName: "NTP", port: "123", transport: "UDP", note: ""),
    ]
}
