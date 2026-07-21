import SwiftUI
import WidgetKit
import SwiftData

struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let completed: Int
    let due: Int
    let streak: Int
    let habitNames: [String]
}

enum TodayProgressLoader {
    static func loadEntry() -> TodayProgressEntry {
        do {
            let schema = Schema([Habit.self, HabitCheckIn.self])
            let configuration = ModelConfiguration(
                "Loopy",
                schema: schema,
                url: LoopyPersistence.storeURL(),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let habits = try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
            let checkIns = try context.fetch(FetchDescriptor<HabitCheckIn>())
            let active = habits.filter { $0.archivedAt == nil }
            let due = active.filter { $0.isDue(on: .now) }
            let completed = due.filter { HabitAnalytics.isComplete($0, on: .now, checkIns: checkIns) }.count
            let streak = HabitAnalytics.currentStreak(asOf: .now, habits: active, checkIns: checkIns)
            return TodayProgressEntry(
                date: .now,
                completed: completed,
                due: due.count,
                streak: streak,
                habitNames: Array(due.prefix(3).map(\.name))
            )
        } catch {
            return TodayProgressEntry(date: .now, completed: 0, due: 0, streak: 0, habitNames: [])
        }
    }
}

struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: .now, completed: 2, due: 4, streak: 5, habitNames: ["Stretch", "Water"])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> Void) {
        completion(TodayProgressLoader.loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> Void) {
        let entry = TodayProgressLoader.loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayProgressWidget: Widget {
    let kind = "TodayProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LoopyTheme.background
                }
        }
        .configurationDisplayName("Today")
        .description("See today's habit progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(LoopyTheme.secondaryText)
            Text("\(entry.completed)/\(entry.due)")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(LoopyTheme.coral)
            Text(entry.due == 0 ? "Nothing due" : "habits complete")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LoopyTheme.secondaryText)
            if family == .systemMedium, !entry.habitNames.isEmpty {
                Text(entry.habitNames.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack {
                Text("Streak \(entry.streak)")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(LoopyTheme.coral)
                Spacer()
                Button(intent: OpenTodayIntent()) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Loopy")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct StreakAccessoryWidget: Widget {
    let kind = "StreakAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            Text("\(entry.streak)")
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(LoopyTheme.coral)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Streak")
        .description("Current perfect-day streak.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
