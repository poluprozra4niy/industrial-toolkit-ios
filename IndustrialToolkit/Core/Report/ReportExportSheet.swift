import PDFKit
import SwiftUI

/// Collects signer names, renders the protocol to a temporary PDF and offers preview and sharing.
struct ReportExportSheet: View {
    let filePrefix: String
    let objectName: String
    let makeDocument: (ReportSigners) -> ReportDocument

    @Environment(\.dismiss) private var dismiss
    @AppStorage("report.performer") private var performer = ""
    @AppStorage("report.organization") private var organization = ""
    @AppStorage("report.customer") private var customer = ""
    @State private var fileURL: URL?
    @State private var isRendering = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let fileURL {
                    PDFPreview(url: fileURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    form
                }
            }
            .navigationTitle(fileURL == nil ? "PDF-протокол" : fileURL?.lastPathComponent ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                if let fileURL {
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: fileURL) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("ФИО исполнителя", text: $performer)
                    .textContentType(.name)
                TextField("Организация", text: $organization)
                    .textContentType(.organizationName)
                TextField("Представитель заказчика (ФИО)", text: $customer)
            } header: {
                Text("Подписи")
            } footer: {
                Text("Имена печатаются под линиями подписи; пустые поля остаются для заполнения от руки. Значения запоминаются.")
            }
            Section {
                Button {
                    render()
                } label: {
                    HStack {
                        Spacer()
                        if isRendering {
                            ProgressView()
                        } else {
                            Label("Сформировать PDF", systemImage: "doc.richtext")
                        }
                        Spacer()
                    }
                }
                .disabled(isRendering)
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.fault)
                }
            }
        }
    }

    private func render() {
        isRendering = true
        errorMessage = nil
        let signers = ReportSigners(performer: performer, organization: organization, customer: customer)
        Task { @MainActor in
            // Let the progress indicator appear before the synchronous drawing starts.
            await Task.yield()
            let data = ReportPDFRenderer.render(makeDocument(signers))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(ReportFileName.make(prefix: filePrefix, object: objectName, date: .now))
            do {
                try data.write(to: url, options: .atomic)
                fileURL = url
            } catch {
                errorMessage = "Не удалось сохранить PDF: \(error.localizedDescription)"
            }
            isRendering = false
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
