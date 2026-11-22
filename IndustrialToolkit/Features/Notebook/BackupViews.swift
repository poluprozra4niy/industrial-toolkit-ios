import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.unreadable }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@MainActor
@Observable
final class BackupController {
    struct Message {
        let title: String
        let text: String
    }

    var isExporting = false
    var isImporting = false
    var message: Message?
    private(set) var document: BackupDocument?
    private(set) var defaultFileName = BackupArchive.fileName(for: .now)

    func prepareExport(from context: ModelContext) {
        do {
            let archive = try BackupStore.makeArchive(from: context)
            guard !archive.isEmpty else {
                message = Message(title: "Нечего сохранять", text: "В блокноте, чек-листах и списках сигналов пока нет записей.")
                return
            }
            document = BackupDocument(data: try archive.encoded())
            defaultFileName = BackupArchive.fileName(for: archive.exportedAt)
            isExporting = true
        } catch {
            message = Message(title: "Не удалось создать копию", text: error.localizedDescription)
        }
    }

    func finishExport(_ result: Result<URL, Error>) {
        document = nil
        switch result {
        case .success(let url):
            message = Message(
                title: "Копия сохранена",
                text: "\(url.lastPathComponent)\nДля восстановления: Блокнот → Резервная копия → Восстановить."
            )
        case .failure(let error):
            guard !Self.isCancellation(error) else { return }
            message = Message(title: "Не удалось сохранить", text: error.localizedDescription)
        }
    }

    func finishImport(_ result: Result<URL, Error>, into context: ModelContext) {
        switch result {
        case .success(let url):
            do {
                let summary = try BackupStore.restore(try Self.readArchive(at: url), into: context)
                message = Message(title: "Копия восстановлена", text: summary.message)
            } catch {
                context.rollback()
                message = Message(title: "Не удалось восстановить", text: error.localizedDescription)
            }
        case .failure(let error):
            guard !Self.isCancellation(error) else { return }
            message = Message(title: "Не удалось открыть файл", text: error.localizedDescription)
        }
    }

    /// Files picked outside the app sandbox (iCloud Drive, «На iPhone») are security-scoped.
    private static func readArchive(at url: URL) throws -> BackupArchive {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.accessDenied
        }
        return try BackupArchive.decode(data)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }
}

struct BackupMenu: View {
    let controller: BackupController
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Menu {
            Section("Блокнот, чек-листы с фото, списки сигналов") {
                Button {
                    controller.prepareExport(from: modelContext)
                } label: {
                    Label("Сохранить копию в файл", systemImage: "square.and.arrow.down")
                }
                Button {
                    controller.isImporting = true
                } label: {
                    Label("Восстановить из файла", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label("Резервная копия", systemImage: "externaldrive")
        }
    }
}

private struct BackupPresentation: ViewModifier {
    @Bindable var controller: BackupController
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $controller.isExporting,
                document: controller.document,
                contentType: .json,
                defaultFilename: controller.defaultFileName
            ) { result in
                controller.finishExport(result)
            }
            // A separate host view: two file panels attached to one view conflict on iOS 17.
            .background {
                Color.clear
                    .fileImporter(isPresented: $controller.isImporting, allowedContentTypes: [.json]) { result in
                        controller.finishImport(result, into: modelContext)
                    }
            }
            .alert(
                controller.message?.title ?? "",
                isPresented: Binding(
                    get: { controller.message != nil },
                    set: { if !$0 { controller.message = nil } }
                ),
                presenting: controller.message
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message.text)
            }
    }
}

extension View {
    func backupPresentation(_ controller: BackupController) -> some View {
        modifier(BackupPresentation(controller: controller))
    }
}
