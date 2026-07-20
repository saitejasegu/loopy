import SwiftData
import SwiftUI

@main
struct LoopyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Habit.self, HabitCheckIn.self])
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
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(AppTab.profile)
        }
        .tint(LoopyTheme.coral)
        .preferredColorScheme(appearance.colorScheme)
    }
}

