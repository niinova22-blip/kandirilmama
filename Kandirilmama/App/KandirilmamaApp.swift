import SwiftData
import SwiftUI

@main
struct KandirilmamaApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            fatalError("Yerel veri deposu açılamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}
