import SwiftUI

struct DashboardView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var query = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if query.isEmpty {
                    offlineStrip
                    categoriesSection
                    quickAccessSection
                } else {
                    searchResults
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Инженер АСУ ТП")
        .searchable(text: $query, prompt: "Поиск: 4-20, float, кабель…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Тема", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }
                } label: {
                    Label("Тема", systemImage: appearance.symbol)
                }
            }
        }
        .navigationDestination(for: Route.self) { route in
            RouteDestination(route: route)
        }
    }

    private var offlineStrip: some View {
        Label("Офлайн · все расчёты выполняются на устройстве", systemImage: "wifi.slash")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Разделы")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ToolCategory.allCases) { category in
                    NavigationLink(value: Route.category(category)) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Быстрый доступ")
            VStack(spacing: 8) {
                ForEach(Tool.quickAccess) { tool in
                    ToolLink(tool: tool)
                }
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let found = Tool.allCases.filter { $0.matches(query) }
        if found.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Найдено: \(found.count)")
                ForEach(found) { tool in
                    ToolLink(tool: tool)
                }
            }
        }
    }
}

struct CategoryView: View {
    let category: ToolCategory

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(category.tools) { tool in
                    ToolLink(tool: tool)
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .category(let category): CategoryView(category: category)
        case .tool(let tool): ToolDestination(tool: tool)
        }
    }
}

struct ToolDestination: View {
    let tool: Tool

    var body: some View {
        switch tool {
        case .cableSizing:
            CableSizingView()
        case .voltageDrop:
            VoltageDropView()
        case .ohmsLaw:
            OhmsLawView()
        case .wireColors:
            ConductorColorsView()
        case .breakers:
            BreakersView()
        case .signalScaling:
            SignalConverterView()
        case .ieee754:
            IEEE754View()
        case .modbusRegisters:
            ModbusRegistersView()
        case .rtd:
            RTDView()
        case .thermocouples:
            ThermocoupleView()
        case .pidTuning:
            PIDTuningView()
        case .ipRating:
            IPRatingView()
        case .networkCalc:
            IPCalculatorView()
        case .commissioningChecklist:
            ChecklistListView()
        case .notebook:
            NotebookView()
        }
    }
}

// MARK: - Cards

private struct CategoryCard: View {
    let category: ToolCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: category.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
            Text(category.title)
                .font(.headline)
                .multilineTextAlignment(.leading)
                .lineLimit(2, reservesSpace: true)
            Text(category.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            Text("Инструментов: \(category.tools.count)")
                .font(.monoCaption)
                .foregroundStyle(Theme.accent)
        }
        .industrialCard()
        .contentShape(Rectangle())
    }
}

private struct ToolLink: View {
    let tool: Tool

    var body: some View {
        NavigationLink(value: Route.tool(tool)) {
            ToolRow(tool: tool)
        }
        .buttonStyle(.plain)
    }
}

private struct ToolRow: View {
    let tool: Tool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tool.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).font(.body.weight(.medium))
                Text(tool.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
