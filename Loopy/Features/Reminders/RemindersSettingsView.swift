import SwiftData
import SwiftUI
import UserNotifications

struct RemindersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private var activeHabits: [Habit] {
        habits.filter { $0.archivedAt == nil }
    }

    private var enabledCount: Int {
        activeHabits.filter(\.reminderEnabled).count
    }

    var body: some View {
        List {
            Section {
                statusRow
            } footer: {
                Text("Reminders fire at the time you set. Habits that are not due that weekday still appear in Today only on scheduled days.")
            }

            Section("Habits") {
                if activeHabits.isEmpty {
                    Text("No active habits")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeHabits) { habit in
                        ReminderHabitRow(habit: habit) {
                            Task { await persistAndReschedule() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .tint(LoopyTheme.coral)
        .task {
            authStatus = await HabitReminderScheduler.authorizationStatus()
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch authStatus {
        case .authorized, .provisional, .ephemeral:
            Label("\(enabledCount) active", systemImage: "bell.fill")
                .foregroundStyle(LoopyTheme.coral)
        case .denied:
            VStack(alignment: .leading, spacing: 10) {
                Text("Notifications are off")
                    .font(.body.weight(.semibold))
                Text("Enable them in Settings to get habit reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    HabitReminderScheduler.openSystemSettings()
                }
            }
            .padding(.vertical, 4)
        default:
            Button("Allow notifications") {
                Task {
                    _ = await HabitReminderScheduler.requestAuthorization()
                    authStatus = await HabitReminderScheduler.authorizationStatus()
                    await persistAndReschedule()
                }
            }
        }
    }

    private func persistAndReschedule() async {
        try? modelContext.save()
        await HabitReminderScheduler.reschedule(habits: activeHabits)
        authStatus = await HabitReminderScheduler.authorizationStatus()
    }
}

private struct ReminderHabitRow: View {
    @Bindable var habit: Habit
    let onChange: () -> Void

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: habit.reminderHour, minute: habit.reminderMinute)
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                habit.reminderHour = components.hour ?? 9
                habit.reminderMinute = components.minute ?? 0
                onChange()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(habit.name, isOn: Binding(
                get: { habit.reminderEnabled },
                set: { enabled in
                    habit.reminderEnabled = enabled
                    onChange()
                }
            ))

            if habit.reminderEnabled {
                DatePicker(
                    "Time",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
            }
        }
        .padding(.vertical, 4)
    }
}
