import SwiftData
import SwiftUI

@main
struct LoopyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let container: ModelContainer

    init() {
        container = LoopyPersistence.makeContainer(cloudKitEnabled: true)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .fullScreenCover(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { if !$0 { hasCompletedOnboarding = true } }
                )) {
                    OnboardingView()
                }
        }
        .modelContainer(container)
    }
}

private enum AppTab: Hashable {
    case today
    case stats
    case history
    case profile
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var selection: AppTab = .today
    @AppStorage("appearance") private var appearanceRaw = AppearancePreference.system.rawValue

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("Today", systemImage: "checkmark.circle.fill") }
            .tag(AppTab.today)

            NavigationStack {
                StatsView()
            }
            .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            .tag(AppTab.stats)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "calendar") }
            .tag(AppTab.history)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Me", systemImage: "person.fill") }
            .tag(AppTab.profile)
        }
        .tint(LoopyTheme.coral)
        .preferredColorScheme(appearance.colorScheme)
        .task {
            await HabitReminderScheduler.reschedule(habits: habits.filter { $0.archivedAt == nil })
            await HealthKitHabitSync.sync(habits: habits, on: .now, in: modelContext)
            try? modelContext.save()
        }
    }
}
