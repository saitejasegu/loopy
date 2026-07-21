import Foundation

struct AchievementDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let colorHex: String
    let detail: String
}

struct AchievementProgress: Identifiable, Hashable, Sendable {
    let definition: AchievementDefinition
    let isUnlocked: Bool
    let progressLabel: String

    var id: String { definition.id }
}

enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        AchievementDefinition(
            id: "first_habit",
            title: "First loop",
            systemImage: "plus.circle.fill",
            colorHex: "#FF6B4A",
            detail: "Create your first habit"
        ),
        AchievementDefinition(
            id: "streak_3",
            title: "Warm up",
            systemImage: "flame.fill",
            colorHex: "#FFB020",
            detail: "Reach a 3-day streak"
        ),
        AchievementDefinition(
            id: "streak_7",
            title: "Week strong",
            systemImage: "flame.fill",
            colorHex: "#E0512F",
            detail: "Reach a 7-day streak"
        ),
        AchievementDefinition(
            id: "streak_30",
            title: "Monthly groove",
            systemImage: "flame.circle.fill",
            colorHex: "#C78300",
            detail: "Reach a 30-day streak"
        ),
        AchievementDefinition(
            id: "perfect_1",
            title: "Perfect day",
            systemImage: "checkmark.seal.fill",
            colorHex: "#33A06C",
            detail: "Complete every habit due in a day"
        ),
        AchievementDefinition(
            id: "perfect_10",
            title: "Ten perfect",
            systemImage: "star.fill",
            colorHex: "#2F7FE0",
            detail: "Log 10 perfect days"
        ),
        AchievementDefinition(
            id: "timer_session",
            title: "On the clock",
            systemImage: "timer",
            colorHex: "#8659E6",
            detail: "Log any timed habit progress"
        ),
        AchievementDefinition(
            id: "habits_5",
            title: "Full plate",
            systemImage: "square.stack.3d.up.fill",
            colorHex: "#4A9DFF",
            detail: "Keep 5 active habits"
        )
    ]

    static func progress(
        habits: [Habit],
        checkIns: [HabitCheckIn],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> [AchievementProgress] {
        let activeCount = habits.filter { $0.archivedAt == nil }.count
        let bestStreak = HabitAnalytics.personalBestStreak(
            asOf: date,
            habits: habits,
            checkIns: checkIns,
            calendar: calendar
        )
        let perfectDays = HabitAnalytics.dailyCompletions(
            endingOn: date,
            days: 365,
            habits: habits,
            checkIns: checkIns,
            calendar: calendar
        ).filter(\.isPerfect).count
        let hasTimerProgress = checkIns.contains { entry in
            guard let habit = habits.first(where: { $0.id == entry.habitID }) else { return false }
            return habit.trackingKind == .duration && entry.value > 0
        }

        return all.map { definition in
            switch definition.id {
            case "first_habit":
                return AchievementProgress(
                    definition: definition,
                    isUnlocked: !habits.isEmpty,
                    progressLabel: habits.isEmpty ? "0 / 1" : "1 / 1"
                )
            case "streak_3":
                return streakProgress(definition, best: bestStreak, target: 3)
            case "streak_7":
                return streakProgress(definition, best: bestStreak, target: 7)
            case "streak_30":
                return streakProgress(definition, best: bestStreak, target: 30)
            case "perfect_1":
                return AchievementProgress(
                    definition: definition,
                    isUnlocked: perfectDays >= 1,
                    progressLabel: "\(min(perfectDays, 1)) / 1"
                )
            case "perfect_10":
                return AchievementProgress(
                    definition: definition,
                    isUnlocked: perfectDays >= 10,
                    progressLabel: "\(min(perfectDays, 10)) / 10"
                )
            case "timer_session":
                return AchievementProgress(
                    definition: definition,
                    isUnlocked: hasTimerProgress,
                    progressLabel: hasTimerProgress ? "1 / 1" : "0 / 1"
                )
            case "habits_5":
                return AchievementProgress(
                    definition: definition,
                    isUnlocked: activeCount >= 5,
                    progressLabel: "\(min(activeCount, 5)) / 5"
                )
            default:
                return AchievementProgress(definition: definition, isUnlocked: false, progressLabel: "0 / 1")
            }
        }
    }

    private static func streakProgress(
        _ definition: AchievementDefinition,
        best: Int,
        target: Int
    ) -> AchievementProgress {
        AchievementProgress(
            definition: definition,
            isUnlocked: best >= target,
            progressLabel: "\(min(best, target)) / \(target)"
        )
    }
}
