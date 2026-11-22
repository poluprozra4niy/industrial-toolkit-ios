import SwiftData
import SwiftUI

@main
struct IndustrialToolkitApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [EngineerNote.self, ChecklistRun.self, ChecklistEntry.self, ChecklistPhoto.self, IOList.self, IOPoint.self])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Инструменты", systemImage: "square.grid.2x2") }
            NavigationStack { NotebookView() }
                .tabItem { Label("Блокнот", systemImage: "note.text") }
        }
    }
}
