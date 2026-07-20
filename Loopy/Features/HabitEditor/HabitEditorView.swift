import SwiftData
import SwiftUI

struct HabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let habit: Habit?

    @State private var name: String
    @State private var kind: HabitTrackingKind
    @State private var target: Double
    @State private var unit: String
    @State private var colorHex: String
    @State private var schedule: HabitSchedule

    private let colors = ["#33A06C", "#2F7FE0", "#8659E6", "#E0512F", "#C78300"]

    init(habit: Habit? = nil) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _kind = State(initialValue: habit?.trackingKind ?? .binary)
        _target = State(initialValue: habit.map { $0.trackingKind == .duration ? $0.targetValue / 60 : $0.targetValue } ?? 1)
        _unit = State(initialValue: habit?.unit ?? "times")
        _colorHex = State(initialValue: habit?.colorHex ?? "#33A06C")
        _schedule = State(initialValue: HabitSchedule(mask: habit?.weekdaysMask ?? HabitSchedule.everyDayMask))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)

                    Picker("Tracking", selection: $kind) {
                        ForEach(HabitTrackingKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if kind != .binary {
                    Section(kind == .duration ? "Daily duration" : "Daily goal") {
                        HStack {
                            TextField("Target", value: $target, format: .number)
                                .keyboardType(.decimalPad)
                            Text(kind == .duration ? "minutes" : unit)
                                .foregroundStyle(.secondary)
                        }

                        if kind == .count {
                            TextField("Unit (glasses, pages…)", text: $unit)
                        }
                    }
                }

                Section("Schedule") {
                    HStack(spacing: 7) {
                        ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                            let selected = schedule.mask & (1 << index) != 0
                            Button {
                                schedule.toggle(weekdayIndex: index)
                            } label: {
                                Text(symbol)
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(selected ? LoopyTheme.coral : Color.secondary.opacity(0.12), in: Circle())
                                    .foregroundStyle(selected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Calendar.current.weekdaySymbols[index])
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                        }
                    }
                    Text(schedule.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Accent") {
                    HStack(spacing: 18) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex.caseInsensitiveCompare(hex) == .orderedSame {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Accent color")
                            .accessibilityValue(colorHex == hex ? "Selected" : "Not selected")
                        }
                    }
                }

                if habit != nil {
                    Section {
                        Button("Archive Habit", systemImage: "archivebox", role: .destructive) {
                            habit?.archivedAt = .now
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .tint(LoopyTheme.coral)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && schedule.mask != 0
            && (kind == .binary || target > 0)
    }

    private func save() {
        let persistedTarget = kind == .duration ? target * 60 : (kind == .binary ? 1 : target)
        let persistedUnit = kind == .duration ? "seconds" : unit.trimmingCharacters(in: .whitespacesAndNewlines)

        if let habit {
            habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.trackingKind = kind
            habit.targetValue = persistedTarget
            habit.unit = persistedUnit.isEmpty ? "times" : persistedUnit
            habit.colorHex = colorHex
            habit.weekdaysMask = schedule.mask
        } else {
            let descriptor = FetchDescriptor<Habit>()
            let nextOrder = ((try? modelContext.fetchCount(descriptor)) ?? 0)
            modelContext.insert(Habit(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                trackingKind: kind,
                targetValue: persistedTarget,
                unit: persistedUnit.isEmpty ? "times" : persistedUnit,
                colorHex: colorHex,
                weekdaysMask: schedule.mask,
                sortOrder: nextOrder
            ))
        }
        dismiss()
    }
}
