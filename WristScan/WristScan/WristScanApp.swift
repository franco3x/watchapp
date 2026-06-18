import SwiftUI
import SwiftData

@main
struct WristScanApp: App {
    let container: ModelContainer
    
    init() {
        do {
            // Only initialize the container here. No async Tasks.
            container = try ModelContainer(for: WatchCatalogItem.self, WatchTimepiece.self)
        } catch {
            fatalError("Failed to configure SwiftData Container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Attach the hydration task directly to the view hierarchy
                .task {
                    do {
                        try await HydrationManager.seedDatabaseIfNeeded(context: container.mainContext)
                    } catch {
                        print("[Database] Hydration failed: \(error)")
                    }
                }
        }
        .modelContainer(container)
    }
}
