import Testing
@testable import IndustrialToolkit

@Suite("IP-калькулятор IPv4")
struct IPv4Tests {
    private func subnet(_ address: String, _ prefix: Int) throws -> IPv4Subnet {
        let parsed = try #require(IPv4Address(address))
        let mask = try #require(SubnetMask(prefix: prefix))
        return IPv4Subnet(address: parsed, mask: mask)
    }

    @Test("Разбор адресов")
    func parsing() {
        #expect(IPv4Address("192.168.0.10")?.value == 0xC0A8_000A)
        #expect(IPv4Address(" 10.0.0.1 ")?.description == "10.0.0.1")
        #expect(IPv4Address("192.168.000.001")?.description == "192.168.0.1")
        #expect(IPv4Address("256.1.1.1") == nil)
        #expect(IPv4Address("1.2.3") == nil)
        #expect(IPv4Address("1.2.3.4.5") == nil)
        #expect(IPv4Address("1..3.4") == nil)
        #expect(IPv4Address("1.2.3.-4") == nil)
        #expect(IPv4Address("1.2.3.4a") == nil)
    }

    @Test("Маска: префикс, /префикс, точечная запись")
    func masks() {
        #expect(SubnetMask("24")?.dotted == "255.255.255.0")
        #expect(SubnetMask("/26")?.dotted == "255.255.255.192")
        #expect(SubnetMask("255.255.255.192")?.prefix == 26)
        #expect(SubnetMask("0.0.0.0")?.prefix == 0)
        #expect(SubnetMask("255.255.255.255")?.prefix == 32)
        #expect(SubnetMask("255.0.255.0") == nil)
        #expect(SubnetMask("33") == nil)
        #expect(SubnetMask("24")?.wildcardDotted == "0.0.0.255")
    }

    @Test("192.168.0.10/24")
    func classicSubnet() throws {
        let classic = try subnet("192.168.0.10", 24)
        #expect(classic.cidr == "192.168.0.0/24")
        #expect(classic.broadcast.description == "192.168.0.255")
        #expect(classic.firstHost.description == "192.168.0.1")
        #expect(classic.lastHost.description == "192.168.0.254")
        #expect(classic.hostCount == 254)
        #expect(classic.addressRole == .host)
        #expect(classic.address.scope == .privateNetwork)
    }

    @Test("Нестандартные маски /27, /31, /32")
    func edgePrefixes() throws {
        let p27 = try subnet("10.1.2.77", 27)
        #expect(p27.cidr == "10.1.2.64/27")
        #expect(p27.lastHost.description == "10.1.2.94")
        #expect(p27.hostCount == 30)

        let p31 = try subnet("10.1.2.77", 31)
        #expect(p31.hostCount == 2)
        #expect(p31.firstHost.description == "10.1.2.76")
        #expect(p31.lastHost.description == "10.1.2.77")

        let p32 = try subnet("10.1.2.77", 32)
        #expect(p32.hostCount == 1)
        #expect(p32.firstHost == p32.address)
    }

    @Test("Адрес сети и широковещательный нельзя назначить")
    func addressRoles() throws {
        #expect(try subnet("192.168.1.0", 24).addressRole == .networkAddress)
        #expect(try subnet("192.168.1.255", 24).addressRole == .broadcastAddress)
    }

    @Test("Типы адресов")
    func scopes() {
        #expect(IPv4Address("172.16.5.4")?.scope == .privateNetwork)
        #expect(IPv4Address("172.32.0.1")?.scope == .publicNetwork)
        #expect(IPv4Address("169.254.10.20")?.scope == .linkLocal)
        #expect(IPv4Address("127.0.0.1")?.scope == .loopback)
        #expect(IPv4Address("239.1.1.1")?.scope == .multicast)
        #expect(IPv4Address("0.0.0.0")?.scope == .unspecified)
        #expect(IPv4Address("255.255.255.255")?.scope == .limitedBroadcast)
    }

    @Test("Разбиение 192.168.0.0/24 на /26")
    func splitting() throws {
        let network = try subnet("192.168.0.0", 24)
        #expect(network.subnetCount(newPrefix: 26) == 4)
        let parts = network.split(newPrefix: 26, limit: 64).map(\.cidr)
        #expect(parts == ["192.168.0.0/26", "192.168.0.64/26", "192.168.0.128/26", "192.168.0.192/26"])
        #expect(network.subnetCount(newPrefix: 20) == nil)
        #expect(network.split(newPrefix: 32, limit: 3).count == 3)
    }

    @Test("ПЛК и панель: одна подсеть или нет")
    func comparison() throws {
        let plc = try #require(IPv4Address("192.168.0.1"))
        let hmi = try #require(IPv4Address("192.168.1.20"))
        let gateway = try #require(IPv4Address("192.168.0.254"))
        let mask24 = try #require(SubnetMask(prefix: 24))
        let mask16 = try #require(SubnetMask(prefix: 16))

        let narrow = SubnetComparison(first: plc, second: hmi, mask: mask24, gateway: gateway)
        #expect(!narrow.isSameSubnet)
        #expect(narrow.isGatewayInSubnet == true)

        let wide = SubnetComparison(first: plc, second: hmi, mask: mask16, gateway: nil)
        #expect(wide.isSameSubnet)
        #expect(wide.isGatewayInSubnet == nil)
        #expect(!wide.isDuplicate)
    }
}
