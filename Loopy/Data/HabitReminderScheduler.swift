import Foundation
import UIKit
import UserNotifications

/// Schedules and clears local notifications for habit reminders.
enum HabitReminderScheduler {
    static let categoryIdentifier = "loopy.habit.reminder"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = habits.map(requestIdentifier(for:))
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        for habit in habits where habit.archivedAt == nil && habit.reminderEnabled {
            await schedule(habit: habit, center: center)
        }
    }

    static func clear(habit: Habit) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestIdentifier(for: habit)])
    }

    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func requestIdentifier(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)"
    }

    private static func schedule(habit: Habit, center: UNUserNotificationCenter) async {
        var dateComponents = DateComponents()
        dateComponents.hour = habit.reminderHour
        dateComponents.minute = habit.reminderMinute

        let content = UNMutableNotificationContent()
        content.title = "Loopy"
        content.body = "Time for \(habit.name)"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = ["habitID": habit.id.uuidString]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: requestIdentifier(for: habit),
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}
