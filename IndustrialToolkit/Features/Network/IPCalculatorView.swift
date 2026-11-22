import SwiftUI

struct IPCalculatorView: View {
    @State private var model = IPCalculatorViewModel()

    private let prefixColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let tileColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Режим", selection: $model.mode) {
                    ForEach(IPCalculatorViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch model.mode {
                case .subnet: subnetContent
                case .compare: compareContent
                case .reference: referenceContent
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("IP-калькулятор")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .resultActions(title: model.noteTitle, summary: model.summary, category: .design)
    }

    // MARK: Subnet

    @ViewBuilder
    private var subnetContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            NumericField(
                label: "IP-адрес (можно 192.168.0.10/24)",
                text: $model.addressText,
                isInvalid: model.isAddressInvalid
            )
            if !model.hasEmbeddedPrefix {
                NumericField(
                    label: "Маска или префикс",
                    text: $model.maskText,
                    isInvalid: model.isMaskInvalid
                )
            }
            LazyVGrid(columns: prefixColumns, spacing: 8) {
                ForEach(IPCalculatorViewModel.quickPrefixes, id: \.self) { prefix in
                    ChoiceChip(title: "/\(prefix)", isSelected: model.subnet?.mask.prefix == prefix) {
                        model.setPrefix(prefix)
                    }
                }
            }
            if model.isMaskInvalid {
                Label("Маска: префикс 0…32 или непрерывная маска вида 255.255.255.0", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()

        if let subnet = model.subnet {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Результат")
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    MetricTile(title: "Сеть", value: subnet.cidr, unit: subnet.mask.dotted)
                    MetricTile(title: "Узлов", value: String(subnet.hostCount), unit: "адресов для устройств")
                }
                ValueRow(label: "Адрес сети", value: subnet.network.description)
                ValueRow(label: "Широковещательный", value: subnet.broadcast.description)
                ValueRow(label: "Первый узел", value: subnet.firstHost.description)
                ValueRow(label: "Последний узел", value: subnet.lastHost.description)
                ValueRow(label: "Маска", value: subnet.mask.dotted)
                ValueRow(label: "Wildcard", value: subnet.mask.wildcardDotted)
                ValueRow(label: "Тип адреса", value: subnet.address.scope.title, copyable: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(subnet.address.binary)
                    Text(IPv4Address(value: subnet.mask.value).binary)
                        .foregroundStyle(.secondary)
                }
                .font(.monoCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .textSelection(.enabled)
                ForEach(model.subnetWarnings, id: \.self) { warning in
                    StatusBanner(title: "Внимание", detail: warning, symbol: "exclamationmark.triangle.fill", tint: Theme.warning)
                }
            }
            .industrialCard()

            splitCard(subnet)
        }
    }

    private func splitCard(_ subnet: IPv4Subnet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Разбить на подсети")
            NumericField(
                label: "Новый префикс (больше /\(subnet.mask.prefix))",
                text: $model.splitText,
                isInvalid: model.isSplitInvalid
            )
            if let total = model.splitTotal {
                let shown = model.splitSubnets
                Text("\(total) подсетей" + (total > shown.count ? ", показаны первые \(shown.count)" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(shown) { part in
                    HStack(alignment: .firstTextBaseline) {
                        Text(part.cidr)
                            .font(.monoBody.weight(.semibold))
                        Spacer(minLength: 8)
                        Text("\(part.firstHost) … \(part.lastHost)")
                            .font(.monoCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .industrialCard()
    }

    // MARK: Compare

    @ViewBuilder
    private var compareContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Два устройства, одна маска")
            NumericField(label: "Устройство A (напр. ПЛК)", text: $model.firstText, isInvalid: model.isFirstInvalid)
            NumericField(label: "Устройство B (напр. панель, ПК)", text: $model.secondText, isInvalid: model.isSecondInvalid)
            NumericField(label: "Маска или префикс", text: $model.compareMaskText, isInvalid: model.isCompareMaskInvalid)
            NumericField(label: "Шлюз (необязательно)", text: $model.gatewayText, isInvalid: model.isGatewayInvalid)
        }
        .industrialCard()

        if let comparison = model.comparison {
            VStack(alignment: .leading, spacing: 10) {
                StatusBanner(
                    title: comparison.isSameSubnet ? "Одна подсеть" : "Разные подсети",
                    detail: comparison.isSameSubnet
                        ? "Устройства видят друг друга напрямую, без маршрутизатора"
                        : "Нужен маршрутизатор или смена адреса/маски одного из устройств",
                    symbol: comparison.isSameSubnet ? "checkmark.circle.fill" : "xmark.octagon.fill",
                    tint: comparison.isSameSubnet ? Theme.ok : Theme.fault
                )
                ValueRow(label: "Сеть A", value: comparison.firstSubnet.cidr)
                ValueRow(label: "Сеть B", value: comparison.secondSubnet.cidr)
                if let inSubnet = comparison.isGatewayInSubnet {
                    ValueRow(
                        label: "Шлюз",
                        value: inSubnet ? "в подсети A" : "вне подсети A",
                        valueColor: inSubnet ? Theme.ok : Theme.fault,
                        copyable: false
                    )
                }
                ForEach(model.comparisonIssues, id: \.self) { issue in
                    StatusBanner(title: "Внимание", detail: issue, symbol: "exclamationmark.triangle.fill", tint: Theme.warning)
                }
            }
            .industrialCard()
        }
    }

    // MARK: Reference

    @ViewBuilder
    private var referenceContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Маски подсетей")
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Префикс")
                    Text("Маска")
                    Text("Узлов").gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(8...32, id: \.self) { prefix in
                    if let mask = SubnetMask(prefix: prefix) {
                        let hosts = IPv4Subnet(address: IPv4Address(value: 0), mask: mask).hostCount
                        GridRow {
                            Text("/\(prefix)")
                                .foregroundStyle(prefix == 24 ? Theme.accent : Color.primary)
                            Text(mask.dotted)
                            Text(String(hosts))
                        }
                        .font(.monoCaption)
                    }
                }
            }
        }
        .industrialCard()

        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Порты промышленных протоколов")
            ForEach(IndustrialPorts.all) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.protocolName)
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 8)
                        Text(item.port)
                            .font(.monoBody.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(item.note.isEmpty ? item.transport : "\(item.transport) · \(item.note)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if item.id != IndustrialPorts.all.last?.id {
                    Divider()
                }
            }
        }
        .industrialCard()
    }
}
