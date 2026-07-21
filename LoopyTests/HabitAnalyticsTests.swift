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

    @Test("Personal best keeps the longest completed run")
    @MainActor
    func personalBestStreak() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        let habit = Habit(name: "Read", createdAt: firstDay)
        let completedOffsets = [0, 1, 3, 4, 5]
        let logs = try completedOffsets.map { offset in
            let date = try #require(calendar.date(byAdding: .day, value: offset, to: firstDay))
            return HabitCheckIn(
                habitID: habit.id,
                timestamp: date,
                dayKey: DayKey.make(for: date, calendar: calendar),
                value: 1
            )
        }
        let lastDay = try #require(calendar.date(byAdding: .day, value: 6, to: firstDay))

        #expect(HabitAnalytics.personalBestStreak(
            asOf: lastDay,
            habits: [habit],
            checkIns: logs,
            calendar: calendar
        ) == 3)
    }

    @Test("Incomplete current day does not break the preceding streak")
    @MainActor
    func incompleteTodayDoesNotBreakStreak() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(
            name: "Read",
            createdAt: try #require(calendar.date(byAdding: .day, value: -3, to: today))
        )
        let logs = try [1, 2, 3].map { offset -> HabitCheckIn in
            let date = try #require(calendar.date(byAdding: .day, value: -offset, to: today))
            return HabitCheckIn(
                habitID: habit.id,
                timestamp: date,
                dayKey: DayKey.make(for: date, calendar: calendar),
                value: 1
            )
        }

        #expect(HabitAnalytics.currentStreak(
            asOf: today,
            habits: [habit],
            checkIns: logs,
            calendar: calendar
        ) == 3)
    }

    @Test("Days with no due habits are skipped for streaks")
    @MainActor
    func emptyDueDaysSkipStreak() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        // Sunday July 19 and Sunday July 26 2026; Monday-only habit.
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 26)))
        let mondayEarlier = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(
            name: "Gym",
            weekdaysMask: 1 << 1,
            createdAt: mondayEarlier
        )
        let log = HabitCheckIn(
            habitID: habit.id,
            timestamp: mondayEarlier,
            dayKey: DayKey.make(for: mondayEarlier, calendar: calendar),
            value: 1
        )

        #expect(HabitAnalytics.currentStreak(
            asOf: sunday,
            habits: [habit],
            checkIns: [log],
            calendar: calendar
        ) == 1)
    }

    @Test("Archived habits stop counting as due after archive day")
    @MainActor
    func archiveWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let created = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10)))
        let archiveDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let after = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 16)))
        let habit = Habit(name: "Meditate", createdAt: created, archivedAt: archiveDay)

        let onArchiveDay = HabitAnalytics.dailyCompletion(
            on: archiveDay,
            habits: [habit],
            checkIns: [],
            calendar: calendar
        )
        let afterArchive = HabitAnalytics.dailyCompletion(
            on: after,
            habits: [habit],
            checkIns: [],
            calendar: calendar
        )

        #expect(onArchiveDay.due == 0)
        #expect(afterArchive.due == 0)

        let before = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 14)))
        let beforeCompletion = HabitAnalytics.dailyCompletion(
            on: before,
            habits: [habit],
            checkIns: [],
            calendar: calendar
        )
        #expect(beforeCompletion.due == 1)
    }

    @Test("DayKey uses the provided calendar day boundary")
    @MainActor
    func dayKeyRespectsCalendar() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var denver = Calendar(identifier: .gregorian)
        denver.timeZone = try #require(TimeZone(identifier: "America/Denver"))

        let tokyoMorning = try #require(
            tokyo.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 1))
        )
        let denverEvening = try #require(
            denver.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 20))
        )

        #expect(DayKey.make(for: tokyoMorning, calendar: tokyo) == "2026-07-21")
        #expect(DayKey.make(for: denverEvening, calendar: denver) == "2026-07-20")
    }

    @Test("Duration progress uses seconds toward the target")
    @MainActor
    func durationProgress() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(
            name: "Meditate",
            trackingKind: .duration,
            targetValue: 600,
            unit: "seconds",
            createdAt: date
        )
        let log = HabitCheckIn(
            habitID: habit.id,
            timestamp: date,
            dayKey: DayKey.make(for: date, calendar: calendar),
            value: 300
        )

        #expect(HabitAnalytics.progress(for: habit, on: date, checkIns: [log], calendar: calendar) == 0.5)
        #expect(!HabitAnalytics.isComplete(habit, on: date, checkIns: [log], calendar: calendar))
    }

    @Test("Achievement catalog unlocks from real progress")
    @MainActor
    func achievementsFromProgress() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))
        let habit = Habit(name: "Read", createdAt: day)
        let log = HabitCheckIn(
            habitID: habit.id,
            timestamp: day,
            dayKey: DayKey.make(for: day, calendar: calendar),
            value: 1
        )

        let progress = AchievementCatalog.progress(
            habits: [habit],
            checkIns: [log],
            asOf: day,
            calendar: calendar
        )
        let first = try #require(progress.first { $0.id == "first_habit" })
        let perfect = try #require(progress.first { $0.id == "perfect_1" })
        #expect(first.isUnlocked)
        #expect(perfect.isUnlocked)
    }
}
