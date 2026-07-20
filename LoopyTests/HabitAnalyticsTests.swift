import Foundation
import Testing
@testable import Loopy

@Suite("Habit schedule and analytics")
struct HabitAnalyticsTests {
    @Test("A selected weekday is due and an unselected weekday is not")
    @MainActor
    func selectedWeekdays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 19)))
        let monday = try #require(calendar.date(byAdding: .day, value: 1, to: sunday))
        let mondayOnly = HabitSchedule(mask: 1 << 1)

        #expect(!mondayOnly.contains(sunday, calendar: calendar))
        #expect(mondayOnly.contains(monday, calendar: calendar))
    }

    @Test("A count habit completes only when its target is reached")
    @MainActor
    func countProgress() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(name: "Water", trackingKind: .count, targetValue: 8, createdAt: date)
        let partial = HabitCheckIn(
            habitID: habit.id,
            timestamp: date,
            dayKey: DayKey.make(for: date, calendar: calendar),
            value: 5
        )

        #expect(HabitAnalytics.progress(for: habit, on: date, checkIns: [partial], calendar: calendar) == 0.625)
        #expect(!HabitAnalytics.isComplete(habit, on: date, checkIns: [partial], calendar: calendar))

        partial.value = 8
        #expect(HabitAnalytics.isComplete(habit, on: date, checkIns: [partial], calendar: calendar))
    }

    @Test("Perfect scheduled days contribute to the streak")
    @MainActor
    func perfectDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(name: "Read", createdAt: date)
        let log = HabitCheckIn(
            habitID: habit.id,
            timestamp: date,
            dayKey: DayKey.make(for: date, calendar: calendar),
            value: 1
        )

        let completion = HabitAnalytics.dailyCompletion(
            on: date,
            habits: [habit],
            checkIns: [log],
            calendar: calendar
        )

        #expect(completion.due == 1)
        #expect(completion.completed == 1)
        #expect(completion.isPerfect)
    }
}

