import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Lists

struct IOListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IOList.createdAt, order: .reverse) private var lists: [IOList]
    @State private var isImporting = false
    @State private var pendingImport: PendingImport?
    @State private var errorMessage: String?

    struct PendingImport: Identifiable {
        let id = UUID()
        let suggestedName: String
        let outcome: IOListImporter.Outcome
    }

    var body: some View {
        Group {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label("Нет списков сигналов", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Импортируйте спецификацию из CSV: колонки «Тег», «Описание», «Тип», «Сигнал», «НПИ», «ВПИ», «Ед. изм.», «Адрес». Из Excel — «Сохранить как → CSV».")
                } actions: {
                    Button("Импорт CSV") { isImporting = true }
                        .buttonStyle(.borderedProminent)
                    ShareLink(item: IOListImporter.templateCSV, preview: SharePreview("Шаблон списка сигналов")) {
                        Text("Шаблон CSV")
                    }
                }
            } else {
                List {
                    ForEach(lists) { list in
                        NavigationLink {
                            IOListDetailView(list: list)
                        } label: {
                            IOListRow(list: list)
                        }
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background)
        .navigationTitle("Списки сигналов")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: IOListImporter.templateCSV, preview: SharePreview("Шаблон списка сигналов")) {
                    Label("Шаблон CSV", systemImage: "doc.text")
                }
                Button {
                    isImporting = true
                } label: {
                    Label("Импорт CSV", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]
        ) { result in
            handleImport(result)
        }
        .sheet(item: $pendingImport) { pending in
            IOImportPreview(pending: pending)
        }
        .alert(
            "Импорт не выполнен",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped { url.stopAccessingSecurityScopedResource() }
            }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Нет доступа к файлу. Выберите его ещё раз."
                return
            }
            guard let text = CSVParser.decodeText(data) else {
                errorMessage = IOListImportError.unreadable.message
                return
            }
            switch IOListImporter.importCSV(text) {
            case .success(let outcome):
                pendingImport = PendingImport(suggestedName: url.deletingPathExtension().lastPathComponent, outcome: outcome)
            case .failure(let error):
                errorMessage = error.message
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for list in offsets.map({ lists[$0] }) {
            modelContext.delete(list)
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось удалить: \(error.localizedDescription)"
        }
    }
}

private struct IOListRow: View {
    let list: IOList

    var body: some View {
        let progress = list.progress
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(progress.done)/\(progress.total)")
                    .font(.monoCaption.weight(.semibold))
                    .foregroundStyle(progress.isComplete ? Theme.ok : Color.secondary)
            }
            ProgressView(value: progress.fraction)
                .tint(progress.isComplete ? Theme.ok : Theme.accent)
            Text(list.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Import preview

private struct IOImportPreview: View {
    let pending: IOListsView.PendingImport

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var saveError: String?

    init(pending: IOListsView.PendingImport) {
        self.pending = pending
        _name = State(initialValue: pending.suggestedName)
    }

    private var counts: String {
        IOSignalKind.allCases
            .map { kind in "\(kind.rawValue): \(pending.outcome.records.filter { $0.kind == kind }.count)" }
            .joined(separator: "  ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Объект или шкаф", text: $name)
                }
                Section {
                    LabeledContent("Сигналов", value: "\(pending.outcome.records.count)")
                    Text(counts).font(.monoCaption)
                    LabeledContent("Колонки", value: pending.outcome.columns.map(\.title).joined(separator: ", "))
                    if pending.outcome.skippedRows > 0 {
                        LabeledContent("Пропущено строк без тега", value: "\(pending.outcome.skippedRows)")
                    }
                } header: {
                    Text("Распознано")
                } footer: {
                    Text("Тип без колонки «Тип» определяется по наличию диапазона: есть — AI, нет — DI. Проверьте первые строки ниже.")
                }
                Section("Первые строки") {
                    ForEach(Array(pending.outcome.records.prefix(8).enumerated()), id: \.offset) { _, record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.tag) · \(record.kind.rawValue)").font(.monoBody)
                            if let range = record.rangeDescription {
                                Text(range).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.fault)
                    }
                }
            }
            .navigationTitle("Импорт списка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать", action: create)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        IOList.make(in: modelContext, name: name.trimmingCharacters(in: .whitespaces), records: pending.outcome.records)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

// MARK: - Detail

struct IOListDetailView: View {
    let list: IOList

    enum Filter: String, CaseIterable, Identifiable {
        case all
        case pending
        case failed
        case analog
        case discrete

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "Все"
            case .pending: "Не проверены"
            case .failed: "Замечания"
            case .analog: "AI/AO"
            case .discrete: "DI/DO"
            }
        }

        func includes(_ point: IOPoint) -> Bool {
            switch self {
            case .all: true
            case .pending: point.status == .pending
            case .failed: point.status == .failed
            case .analog: point.kind.isAnalog
            case .discrete: !point.kind.isAnalog
            }
        }
    }

    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var showsProtocol = false

    private var visiblePoints: [IOPoint] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return list.orderedPoints.filter { point in
            filter.includes(point)
                && (needle.isEmpty || point.tag.localizedCaseInsensitiveContains(needle)
                    || point.details.localizedCaseInsensitiveContains(needle)
                    || point.address.localizedCaseInsensitiveContains(needle))
        }
    }

    var body: some View {
        let progress = list.progress
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Проверено")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(progress.done) / \(progress.total)")
                            .font(.monoBody.weight(.semibold))
                    }
                    ProgressView(value: progress.fraction)
                        .tint(progress.isComplete ? Theme.ok : Theme.accent)
                    Picker("Фильтр", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(visiblePoints) { point in
                    NavigationLink {
                        IOPointView(point: point)
                    } label: {
                        IOPointRow(point: point)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .searchable(text: $query, prompt: "Тег, описание, адрес")
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsProtocol = true
                } label: {
                    Label("PDF-протокол", systemImage: "doc.richtext")
                }
            }
        }
        .resultActions(title: "Список сигналов: \(list.name)", summary: list.textReport, category: .field)
        .sheet(isPresented: $showsProtocol) {
            ReportExportSheet(filePrefix: "Loop_check", objectName: list.name) { signers in
                list.protocolDocument(signers: signers)
            }
        }
    }
}

private struct IOPointRow: View {
    let point: IOPoint

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(point.tag).font(.monoBody.weight(.semibold))
                    Text(point.kind.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.border, lineWidth: 1))
                }
                if !point.details.isEmpty {
                    Text(point.details).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if let range = point.record.rangeDescription {
                    Text(range).font(.monoCaption).foregroundStyle(.secondary)
                }
                if !point.remark.isEmpty {
                    Label(point.remark, systemImage: "text.bubble").font(.caption).foregroundStyle(Theme.fault)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(point.status.title)
    }

    private var symbol: String {
        switch point.status {
        case .pending: "circle"
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch point.status {
        case .pending: .secondary
        case .passed: Theme.ok
        case .failed: Theme.fault
        }
    }
}

// MARK: - Point

struct IOPointView: View {
    @Bindable var point: IOPoint
    @Environment(\.modelContext) private var modelContext
    @State private var saveError: String?

    var body: some View {
        let record = point.record
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("\(record.kind.sectionTitle)")
                    if !record.details.isEmpty {
                        Text(record.details).font(.subheadline)
                    }
                    if let range = record.rangeDescription {
                        ValueRow(label: "Диапазон", value: range, copyable: false)
                    }
                    if !record.address.isEmpty {
                        ValueRow(label: "Адрес", value: record.address)
                    }
                }
                .industrialCard()

                if let scale = record.scale {
                    loopCheckCard(scale: scale, record: record)
                } else {
                    discreteCard(record)
                }
                statusCard
            }
            .padding(16)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(point.tag)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .onDisappear(perform: save)
    }

    private func loopCheckCard(scale: SignalScale, record: IOSignalRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(record.kind == .ai ? "Подать сигнал → проверить в SCADA" : "Задать в SCADA → измерить сигнал")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("%")
                    Text(scale.signal.unit)
                    Text(record.unit.isEmpty ? "PV" : record.unit)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                ForEach(Array(scale.loopCheckTable.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        Text(Fmt.number(row.signalFraction * 100, fractionDigits: 0))
                        Text(Fmt.number(row.signal, fractionDigits: 2))
                        Text(Fmt.number(row.processValue, fractionDigits: 3)).foregroundStyle(Theme.accent)
                    }
                    .font(.monoBody)
                }
            }
            NavigationLink {
                SignalConverterView(preset: converterPreset(record))
            } label: {
                Label("Открыть в конвертере сигналов", systemImage: "gauge.with.dots.needle.50percent")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .industrialCard()
    }

    private func discreteCard(_ record: IOSignalRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Проверка")
            Text(record.kind == .di
                 ? "Замкнуть/разомкнуть контакт на объекте — проверить состояние входа в ПЛК и SCADA, сообщение и квитирование."
                 : "Подать команду из SCADA — проверить срабатывание реле/пускателя и обратную связь.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .industrialCard()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Результат")
            HStack(spacing: 8) {
                statusButton(.passed, symbol: "checkmark.circle.fill", tint: Theme.ok)
                statusButton(.failed, symbol: "xmark.octagon.fill", tint: Theme.fault)
                statusButton(.pending, symbol: "arrow.uturn.backward", tint: .secondary)
            }
            TextField("Замечание: что не так, что сделано", text: $point.remark, axis: .vertical)
                .lineLimit(2...5)
                .fieldChrome()
            if let checkedAt = point.checkedAt {
                Text("Отмечено: \(checkedAt.formatted(date: .numeric, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.fault)
            }
        }
        .industrialCard()
    }

    private func statusButton(_ status: IOPointStatus, symbol: String, tint: Color) -> some View {
        Button {
            point.status = status
            save()
        } label: {
            Label(status.title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(point.status == status ? tint : Color.primary)
                .background(
                    point.status == status ? tint.opacity(0.14) : Theme.surfaceSunken,
                    in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                        .strokeBorder(point.status == status ? tint : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(point.status == status ? .isSelected : [])
    }

    private func converterPreset(_ record: IOSignalRecord) -> SignalConverterViewModel {
        let model = SignalConverterViewModel()
        if let signal = record.signal { model.signalRange = signal }
        if let low = record.low { model.lowText = Fmt.number(low, fractionDigits: 6) }
        if let high = record.high { model.highText = Fmt.number(high, fractionDigits: 6) }
        model.unit = record.unit
        return model
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}
