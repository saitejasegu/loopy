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
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var isRequestingHealth = false

    private let colors = ["#33A06C", "#2F7FE0", "#8659E6", "#E0512F", "#C78300"]

    init(habit: Habit? = nil) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _kind = State(initialValue: habit?.trackingKind ?? .binary)
        _target = State(initialValue: habit.map {
            switch $0.trackingKind {
            case .duration: $0.targetValue / 60
            case .binary, .count, .healthSteps, .healthActiveEnergy: $0.targetValue
            }
        } ?? 1)
        _unit = State(initialValue: habit?.unit ?? "times")
        _colorHex = State(initialValue: habit?.colorHex ?? "#33A06C")
        _schedule = State(initialValue: HabitSchedule(mask: habit?.weekdaysMask ?? HabitSchedule.everyDayMask))
        _reminderEnabled = State(initialValue: habit?.reminderEnabled ?? false)
        let hour = habit?.reminderHour ?? 9
        let minute = habit?.reminderMinute ?? 0
        _reminderTime = State(
            initialValue: Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)

                    Picker("Tracking", selection: $kind) {
                        ForEach(HabitTrackingKind.manualCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                        ForEach(HabitTrackingKind.healthCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: kind) { _, newKind in
                        applyDefaults(for: newKind)
                    }

                    if kind.isHealthBacked {
                        Text("Progress syncs from Apple Health into dated check-ins. No manual check-in needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if kind != .binary {
                    Section(kind == .duration ? "Daily duration" : "Daily goal") {
                        HStack {
                            TextField("Target", value: $target, format: .number)
                                .keyboardType(.decimalPad)
                            Text(unitLabel)
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

                Section("Reminder") {
                    Toggle("Remind me", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
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
                            if let habit {
                                HabitReminderScheduler.clear(habit: habit)
                            }
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
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isRequestingHealth)
                }
            }
        }
        .tint(LoopyTheme.coral)
    }

    private var unitLabel: String {
        switch kind {
        case .duration: "minutes"
        case .healthSteps: "steps"
        case .healthActiveEnergy: "kcal"
        default: unit
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && schedule.mask != 0
            && (kind == .binary || target > 0)
    }

    private func applyDefaults(for kind: HabitTrackingKind) {
        switch kind {
        case .binary:
            target = 1
            unit = "times"
        case .count:
            if unit == "seconds" || unit == "steps" || unit == "kcal" { unit = "times" }
            if target <= 1 { target = 8 }
        case .duration:
            target = 10
            unit = "minutes"
        case .healthSteps:
            target = HealthKitMetric.steps.defaultTarget
            unit = HealthKitMetric.steps.defaultUnit
        case .healthActiveEnergy:
            target = HealthKitMetric.activeEnergy.defaultTarget
            unit = HealthKitMetric.activeEnergy.defaultUnit
        }
    }

    @MainActor
    private func save() async {
        if kind.isHealthBacked {
            isRequestingHealth = true
            _ = await HealthKitHabitSync.requestAuthorization()
            isRequestingHealth = false
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0

        let persistedTarget: Double
        let persistedUnit: String
        switch kind {
        case .duration:
            persistedTarget = target * 60
            persistedUnit = "seconds"
        case .binary:
            persistedTarget = 1
            persistedUnit = "times"
        case .healthSteps:
            persistedTarget = target
            persistedUnit = HealthKitMetric.steps.defaultUnit
        case .healthActiveEnergy:
            persistedTarget = target
            persistedUnit = HealthKitMetric.activeEnergy.defaultUnit
        case .count:
            persistedTarget = target
            let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            persistedUnit = trimmed.isEmpty ? "times" : trimmed
        }

        if let habit {
            habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            habit.trackingKind = kind
            habit.targetValue = persistedTarget
            habit.unit = persistedUnit
            habit.colorHex = colorHex
            habit.weekdaysMask = schedule.mask
            habit.reminderEnabled = reminderEnabled
            habit.reminderHour = hour
            habit.reminderMinute = minute
        } else {
            let descriptor = FetchDescriptor<Habit>()
            let nextOrder = ((try? modelContext.fetchCount(descriptor)) ?? 0)
            modelContext.insert(Habit(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                trackingKind: kind,
                targetValue: persistedTarget,
                unit: persistedUnit,
                colorHex: colorHex,
                weekdaysMask: schedule.mask,
                sortOrder: nextOrder,
                reminderEnabled: reminderEnabled,
                reminderHour: hour,
                reminderMinute: minute
            ))
        }

        try? modelContext.save()
        let active = ((try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []).filter { $0.archivedAt == nil }
        await HabitReminderScheduler.reschedule(habits: active)
        if kind.isHealthBacked {
            await HealthKitHabitSync.sync(habits: active, on: .now, in: modelContext)
            try? modelContext.save()
        }
        dismiss()
    }
}
