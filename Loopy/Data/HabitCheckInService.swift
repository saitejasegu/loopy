import Foundation
import SwiftData

/// Shared check-in mutations used by Today, History, App Intents, and widgets.
enum HabitCheckInService {
    static func value(
        for habit: Habit,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Double {
        let key = DayKey.make(for: date, calendar: calendar)
        let habitID = habit.id
        var descriptor = FetchDescriptor<HabitCheckIn>(
            predicate: #Predicate { $0.habitID == habitID && $0.dayKey == key }
        )
        descriptor.fetchLimit = 32
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.reduce(0) { $0 + $1.value }
    }

    static func setValue(
        _ value: Double,
        for habit: Habit,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let key = DayKey.make(for: date, calendar: calendar)
        let habitID = habit.id
        let descriptor = FetchDescriptor<HabitCheckIn>(
            predicate: #Predicate { $0.habitID == habitID && $0.dayKey == key }
        )
        let existing = (try? context.fetch(descriptor)) ?? []

        if value <= 0 {
            for row in existing {
                context.delete(row)
            }
            return
        }

        if let first = existing.first {
            first.value = value
            first.timestamp = date
            first.timeZoneIdentifier = TimeZone.current.identifier
            for extra in existing.dropFirst() {
                context.delete(extra)
            }
        } else {
            context.insert(
                HabitCheckIn(
                    habitID: habit.id,
                    timestamp: date,
                    dayKey: key,
                    value: value
                )
            )
        }
    }

    static func toggleBinary(
        for habit: Habit,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let current = value(for: habit, on: date, in: context, calendar: calendar)
        if current >= habit.safeTarget {
            setValue(0, for: habit, on: date, in: context, calendar: calendar)
        } else {
            setValue(habit.safeTarget, for: habit, on: date, in: context, calendar: calendar)
        }
    }

    static func adjustCount(
        for habit: Habit,
        by amount: Double,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let next = max(0, value(for: habit, on: date, in: context, calendar: calendar) + amount)
        setValue(next, for: habit, on: date, in: context, calendar: calendar)
    }
}
