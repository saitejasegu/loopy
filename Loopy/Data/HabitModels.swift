import Foundation
import SwiftData

enum HabitTrackingKind: String, Codable, CaseIterable, Identifiable {
    case binary
    case count
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .binary: "Yes / No"
        case .count: "Count"
        case .duration: "Timed"
        }
    }

    var systemImage: String {
        switch self {
        case .binary: "checkmark.circle"
        case .count: "number.circle"
        case .duration: "timer"
        }
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var trackingKindRaw: String
    var targetValue: Double
    var unit: String
    var colorHex: String
    var weekdaysMask: Int
    var sortOrder: Int
    var createdAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        trackingKind: HabitTrackingKind = .binary,
        targetValue: Double = 1,
        unit: String = "times",
        colorHex: String = "#FF6B4A",
        weekdaysMask: Int = HabitSchedule.everyDayMask,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.trackingKindRaw = trackingKind.rawValue
        self.targetValue = targetValue
        self.unit = unit
        self.colorHex = colorHex
        self.weekdaysMask = weekdaysMask
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    var trackingKind: HabitTrackingKind {
        get { HabitTrackingKind(rawValue: trackingKindRaw) ?? .binary }
        set { trackingKindRaw = newValue.rawValue }
    }

    var safeTarget: Double { max(targetValue, 1) }

    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        HabitSchedule(mask: weekdaysMask).contains(date, calendar: calendar)
    }
}

@Model
final class HabitCheckIn {
    var id: UUID
    var habitID: UUID
    var timestamp: Date
    var dayKey: String
    var timeZoneIdentifier: String
    var value: Double

    init(
        id: UUID = UUID(),
        habitID: UUID,
        timestamp: Date = .now,
        dayKey: String? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        value: Double
    ) {
        self.id = id
        self.habitID = habitID
        self.timestamp = timestamp
        self.dayKey = dayKey ?? DayKey.make(for: timestamp)
        self.timeZoneIdentifier = timeZoneIdentifier
        self.value = value
    }
}

struct HabitSchedule: Equatable, Sendable {
    static let everyDayMask = 0b1111111

    var mask: Int

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        return mask & (1 << weekdayIndex) != 0
    }

    mutating func toggle(weekdayIndex: Int) {
        mask ^= 1 << weekdayIndex
    }

    var isEveryDay: Bool { mask == Self.everyDayMask }

    var summary: String {
        if isEveryDay { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return symbols.indices
            .filter { mask & (1 << $0) != 0 }
            .map { symbols[$0] }
            .joined(separator: " · ")
    }
}

enum DayKey {
    static func make(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

