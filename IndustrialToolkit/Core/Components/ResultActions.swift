import SwiftData
import SwiftUI

/// Toolbar "Share" + "Save to notebook" shared by every calculator screen.
struct ResultActions: ViewModifier {
    let noteTitle: String
    let summary: String?
    let category: NoteCategory

    @Environment(\.modelContext) private var modelContext
    @State private var toast: String?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let summary {
                        ShareLink(item: summary) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            save(summary)
                        } label: {
                            Label("В блокнот", systemImage: "tray.and.arrow.down")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.fieldCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: toast)
            .sensoryFeedback(.success, trigger: toast) { _, message in message != nil }
            .task(id: toast) {
                guard toast != nil, (try? await Task.sleep(for: .seconds(1.6))) != nil else { return }
                toast = nil
            }
    }

    private func save(_ summary: String) {
        modelContext.insert(EngineerNote(title: noteTitle, body: summary, category: category))
        do {
            try modelContext.save()
            toast = "Сохранено в блокнот"
        } catch {
            toast = "Не удалось сохранить: \(error.localizedDescription)"
        }
    }
}

extension View {
    func resultActions(title: String, summary: String?, category: NoteCategory) -> some View {
        modifier(ResultActions(noteTitle: title, summary: summary, category: category))
    }
}
