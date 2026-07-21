import SwiftData
import SwiftUI

struct ArchivedHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    private var archivedHabits: [Habit] {
        habits
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if archivedHabits.isEmpty {
                    ContentUnavailableView(
                        "No archived habits",
                        systemImage: "archivebox",
                        description: Text("Archive a habit from Today when you want to pause it without losing history.")
                    )
                } else {
                    List {
                        ForEach(archivedHabits) { habit in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.name)
                                        .font(.body.weight(.semibold))
                                    Text(archiveSubtitle(for: habit))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Restore") {
                                    restore(habit)
                                }
                                .buttonStyle(.bordered)
                                .tint(LoopyTheme.coral)
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(LoopyTheme.coral)
    }

    private func archiveSubtitle(for habit: Habit) -> String {
        let kind = habit.trackingKind.title
        if let archivedAt = habit.archivedAt {
            return "\(kind) · Archived \(archivedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return kind
    }

    private func restore(_ habit: Habit) {
        habit.archivedAt = nil
        HabitReminderScheduler.clear(habit: habit)
        Task {
            let active = habits.filter { $0.archivedAt == nil }
            await HabitReminderScheduler.reschedule(habits: active + [habit])
        }
        try? modelContext.save()
    }
}
