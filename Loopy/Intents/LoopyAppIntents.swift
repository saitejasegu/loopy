import AppIntents
import SwiftData
import WidgetKit

struct LoopyHabitEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = LoopyHabitEntityQuery()

    var id: UUID
    var name: String
    var trackingKindRaw: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct LoopyHabitEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LoopyHabitEntity] {
        let habits = try await loadHabits()
        return habits.filter { identifiers.contains($0.id) }.map(Self.entity(from:))
    }

    func suggestedEntities() async throws -> [LoopyHabitEntity] {
        try await loadHabits()
            .filter { $0.archivedAt == nil }
            .map(Self.entity(from:))
    }

    private func loadHabits() async throws -> [Habit] {
        let container = await MainActor.run {
            LoopyPersistence.makeContainer(cloudKitEnabled: false)
        }
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    private static func entity(from habit: Habit) -> LoopyHabitEntity {
        LoopyHabitEntity(
            id: habit.id,
            name: habit.name,
            trackingKindRaw: habit.trackingKindRaw
        )
    }
}

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Marks a yes/no habit complete for today, or adds one to a count habit.")

    @Parameter(title: "Habit")
    var habit: LoopyHabitEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$habit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = LoopyPersistence.makeContainer(cloudKitEnabled: false)
        let context = ModelContext(container)
        let habitID = habit.id
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let model = try context.fetch(descriptor).first, model.archivedAt == nil else {
            return .result(dialog: "That habit was not found.")
        }

        switch model.trackingKind {
        case .binary:
            HabitCheckInService.setValue(model.safeTarget, for: model, on: .now, in: context)
        case .count:
            HabitCheckInService.adjustCount(for: model, by: 1, on: .now, in: context)
        case .duration:
            return .result(dialog: "Open Loopy to run the timer for \(model.name).")
        case .healthSteps, .healthActiveEnergy:
            await HealthKitHabitSync.sync(habits: [model], on: .now, in: context)
        }

        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Updated \(model.name).")
    }
}

struct LoopyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Complete a habit in \(.applicationName)",
                "Check in with \(.applicationName)"
            ],
            shortTitle: "Complete Habit",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "Open today in \(.applicationName)"
            ],
            shortTitle: "Open Today",
            systemImageName: "sun.max.fill"
        )
    }
}
