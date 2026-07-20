import Foundation

struct DailyCompletion: Identifiable, Equatable {
    let date: Date
    let completed: Int
    let due: Int

    var id: Date { date }
    var ratio: Double { due == 0 ? 0 : Double(completed) / Double(due) }
    var isPerfect: Bool { due > 0 && completed == due }
}

enum HabitAnalytics {
    static func value(
        for habit: Habit,
        on date: Date,
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> Double {
        let key = DayKey.make(for: date, calendar: calendar)
        return checkIns
            .filter { $0.habitID == habit.id && $0.dayKey == key }
            .reduce(0) { $0 + $1.value }
    }

    static func progress(
        for habit: Habit,
        on date: Date,
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> Double {
        min(value(for: habit, on: date, checkIns: checkIns, calendar: calendar) / habit.safeTarget, 1)
    }

    static func isComplete(
        _ habit: Habit,
        on date: Date,
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> Bool {
        progress(for: habit, on: date, checkIns: checkIns, calendar: calendar) >= 1
    }

    static func dailyCompletion(
        on date: Date,
        habits: [Habit],
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> DailyCompletion {
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        let dueHabits = habits.filter { habit in
            let existed = habit.createdAt <= endOfDay
            let wasNotArchived = habit.archivedAt.map { $0 > date } ?? true
            return existed && wasNotArchived && habit.isDue(on: date, calendar: calendar)
        }
        let completed = dueHabits.filter {
            isComplete($0, on: date, checkIns: checkIns, calendar: calendar)
        }.count
        return DailyCompletion(date: calendar.startOfDay(for: date), completed: completed, due: dueHabits.count)
    }

    static func dailyCompletions(
        endingOn endDate: Date,
        days: Int,
        habits: [Habit],
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> [DailyCompletion] {
        guard days > 0 else { return [] }
        let end = calendar.startOfDay(for: endDate)
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end)
        }.map {
            dailyCompletion(on: $0, habits: habits, checkIns: checkIns, calendar: calendar)
        }
    }

    static func currentStreak(
        asOf date: Date,
        habits: [Habit],
        checkIns: [HabitCheckIn],
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: date)
        var inspected = 0
        var isFirstDueDay = true

        while inspected < 3_650 {
            let day = dailyCompletion(on: cursor, habits: habits, checkIns: checkIns, calendar: calendar)
            if day.due == 0 {
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                inspected += 1
                continue
            }
            if day.isPerfect {
                streak += 1
                isFirstDueDay = false
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                inspected += 1
                continue
            }
            if isFirstDueDay && calendar.isDate(cursor, inSameDayAs: date) {
                isFirstDueDay = false
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                inspected += 1
                continue
            }
            break
        }
        return streak
    }
}
