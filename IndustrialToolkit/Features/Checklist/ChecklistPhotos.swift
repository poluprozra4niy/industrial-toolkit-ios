import PhotosUI
import SwiftData
import SwiftUI
import UIKit

@Model
final class ChecklistPhoto {
    /// JPEG kept outside the SQLite file so the store stays small.
    @Attribute(.externalStorage) var imageData: Data
    var createdAt: Date
    var entry: ChecklistEntry?

    init(imageData: Data, createdAt: Date = .now) {
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

enum PhotoCompressor {
    /// Long side 1600 px, JPEG quality 0.7: ~200–400 KB, readable on an A4 protocol.
    static let maxDimension: CGFloat = 1_600
    static let quality: CGFloat = 0.7

    static func jpeg(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// Photos attached to one checklist item: camera, library, delete.
struct EntryPhotosSheet: View {
    let entry: ChecklistEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsCamera = false
    @State private var errorMessage: String?
    @State private var isImporting = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var photos: [ChecklistPhoto] { entry.photos.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showsCamera = true
                            } label: {
                                Label("Камера", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                            Label("Галерея", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    if isImporting {
                        ProgressView("Сжатие фото…")
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.fault)
                    }
                    if photos.isEmpty {
                        Text("Фото попадут в PDF-протокол под этим пунктом.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(photos) { photo in
                                PhotoThumbnail(data: photo.imageData)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(photo)
                                        } label: {
                                            Label("Удалить фото", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        Text("Удерживайте фото, чтобы удалить.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Фото к пункту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in
                    if let image { add(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                importItems(items)
            }
        }
    }

    private func add(_ image: UIImage) {
        guard let data = PhotoCompressor.jpeg(from: image) else {
            errorMessage = "Не удалось обработать фото."
            return
        }
        let photo = ChecklistPhoto(imageData: data)
        modelContext.insert(photo)
        photo.entry = entry
        save()
    }

    private func importItems(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task { @MainActor in
            var failures = 0
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data)
                    else {
                        failures += 1
                        continue
                    }
                    add(image)
                } catch {
                    failures += 1
                }
            }
            pickerItems = []
            isImporting = false
            if failures > 0 {
                errorMessage = "Не загружено фото: \(failures)."
            }
        }
    }

    private func delete(_ photo: ChecklistPhoto) {
        modelContext.delete(photo)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

private struct PhotoThumbnail: View {
    let data: Data

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 100)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.fieldCornerRadius).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// System camera; returns nil when the user cancels.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onFinish(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onFinish(nil)
            parent.dismiss()
        }
    }
}
