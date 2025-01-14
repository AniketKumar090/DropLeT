import SwiftUI
import SwiftData

@main
struct WaterTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DrinkRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Challenge(viewModel: DrinkViewModel())
        }
        .modelContainer(sharedModelContainer)
    }
}
