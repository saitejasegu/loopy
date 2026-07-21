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
    @State private var typePick: TypePick

    private let colors = ["#33A06C", "#2F7FE0", "#8659E6", "#E0512F", "#C78300"]

    private enum TypePick: Equatable {
        case yesNo
        case countable
        case timed
        case scheduled
        case health

        static func from(kind: HabitTrackingKind, schedule: HabitSchedule) -> TypePick {
            switch kind {
            case .count: .countable
            case .duration: .timed
            case .healthSteps, .healthActiveEnergy: .health
            case .binary: schedule.isEveryDay ? .yesNo : .scheduled
            }
        }
    }

    /// Sun-based mask for Mon · Wed · Fri (matches design prototype).
    private static let scheduledPresetMask = 0b0101010

    init(habit: Habit? = nil) {
        self.habit = habit
        let initialKind = habit?.trackingKind ?? .binary
        let initialSchedule = HabitSchedule(mask: habit?.weekdaysMask ?? HabitSchedule.everyDayMask)
        _name = State(initialValue: habit?.name ?? "")
        _kind = State(initialValue: initialKind)
        _target = State(initialValue: habit.map {
            switch $0.trackingKind {
            case .duration: $0.targetValue / 60
            case .binary, .count, .healthSteps, .healthActiveEnergy: $0.targetValue
            }
        } ?? 1)
        _unit = State(initialValue: habit?.unit ?? "times")
        _colorHex = State(initialValue: habit?.colorHex ?? "#33A06C")
        _schedule = State(initialValue: initialSchedule)
        _reminderEnabled = State(initialValue: habit?.reminderEnabled ?? false)
        let hour = habit?.reminderHour ?? 9
        let minute = habit?.reminderMinute ?? 0
        _reminderTime = State(
            initialValue: Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        )
        _typePick = State(initialValue: TypePick.from(kind: initialKind, schedule: initialSchedule))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                section(title: "Name") {
                    TextField("e.g. Stretch", text: $name)
                        .font(.body.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.primary.opacity(0.06), lineWidth: 1)
                        }
                        .accessibilityLabel("Name")
                }

                section(title: "Type") {
                    typeGrid
                }

                if kind != .binary {
                    section(title: targetSectionTitle) {
                        VStack(alignment: .leading, spacing: 10) {
                            if kind.isHealthBacked {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color(red: 1, green: 45 / 255, blue: 85 / 255))
                                    Text("APPLE HEALTH")
                                        .font(.caption2.weight(.bold).monospaced())
                                        .tracking(0.5)
                                        .foregroundStyle(Color(red: 1, green: 45 / 255, blue: 85 / 255))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Color(red: 1, green: 45 / 255, blue: 85 / 255).opacity(0.1),
                                    in: Capsule()
                                )
                            }

                            HStack {
                                TextField("Target", value: $target, format: .number)
                                    .font(.body.weight(.semibold))
                                    .keyboardType(.decimalPad)
                                Text(unitLabel)
                                    .foregroundStyle(LoopyTheme.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.primary.opacity(0.06), lineWidth: 1)
                            }

                            if kind == .count {
                                TextField("Unit (glasses, pages…)", text: $unit)
                                    .font(.body.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 15)
                                    .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(.primary.opacity(0.06), lineWidth: 1)
                                    }
                            }

                            if kind.isHealthBacked {
                                Text("Progress syncs automatically — no check-in needed.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(LoopyTheme.secondaryText)
                            }
                        }
                    }
                }

                section(title: "Schedule") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 7) {
                            ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                                let selected = schedule.mask & (1 << index) != 0
                                Button {
                                    schedule.toggle(weekdayIndex: index)
                                } label: {
                                    Text(symbol)
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(selected ? LoopyTheme.coral : LoopyTheme.chip, in: Circle())
                                        .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[index])
                                .accessibilityValue(selected ? "Selected" : "Not selected")
                            }
                        }
                        Text(schedule.summary)
                            .font(.caption)
                            .foregroundStyle(LoopyTheme.secondaryText)
                    }
                }

                section(title: "Reminder") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Remind me", isOn: $reminderEnabled)
                            .tint(LoopyTheme.coral)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.primary.opacity(0.06), lineWidth: 1)
                            }

                        if reminderEnabled {
                            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                                }
                        }
                    }
                }

                section(title: "Accent") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            let selected = colorHex.caseInsensitiveCompare(hex) == .orderedSame
                            Button {
                                colorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 38, height: 38)
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(3)
                                .overlay {
                                    if selected {
                                        Circle()
                                            .stroke(Color(hex: hex), lineWidth: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Accent color")
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                        }
                    }
                }

                Button {
                    Task { await save() }
                } label: {
                    Text(habit == nil ? "Create habit" : "Save changes")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(
                            canSave ? LoopyTheme.coral : Color(hex: "#D8B3A6"),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .shadow(
                            color: canSave ? LoopyTheme.coral.opacity(0.45) : .clear,
                            radius: 14,
                            y: 8
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isRequestingHealth)
                .accessibilityLabel(habit == nil ? "Create habit" : "Save changes")
                .padding(.top, 4)

                if habit != nil {
                    Button("Archive Habit", systemImage: "archivebox", role: .destructive) {
                        habit?.archivedAt = .now
                        if let habit {
                            HabitReminderScheduler.clear(habit: habit)
                        }
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(LoopyTheme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .tint(LoopyTheme.coral)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(habit == nil ? "New habit" : "Edit habit")
                .font(.title2.bold())
                .tracking(-0.3)
            Spacer(minLength: 12)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(LoopyTheme.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(LoopyTheme.chip, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
        }
    }

    private var typeGrid: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                typeTile(pick: .yesNo, title: "Yes / No", systemImage: "checkmark")
                typeTile(pick: .countable, title: "Countable", systemImage: "number")
                typeTile(pick: .timed, title: "Timed", systemImage: "stopwatch")
                typeTile(pick: .scheduled, title: "Scheduled", systemImage: "calendar")
            }

            healthTile

            if typePick == .health {
                HStack(spacing: 8) {
                    healthSubTile(kind: .healthSteps, title: "Steps", systemImage: "figure.walk")
                    healthSubTile(kind: .healthActiveEnergy, title: "Active energy", systemImage: "flame.fill")
                }
            }
        }
    }

    private var healthTile: some View {
        let selected = typePick == .health
        return Button {
            selectType(.health)
        } label: {
            typeTileLabel(
                title: "Apple Health",
                systemImage: "heart.fill",
                selected: selected
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple Health")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func typeTile(pick: TypePick, title: String, systemImage: String) -> some View {
        let selected = typePick == pick
        return Button {
            selectType(pick)
        } label: {
            typeTileLabel(title: title, systemImage: systemImage, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func typeTileLabel(title: String, systemImage: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(selected ? LoopyTheme.coral : .primary)
                .frame(width: 22)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color(hex: "#E0512F") : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(
            selected ? LoopyTheme.coral.opacity(0.1) : LoopyTheme.card,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? LoopyTheme.coral : .primary.opacity(0.06), lineWidth: selected ? 1.5 : 1)
        }
    }

    private func healthSubTile(kind tileKind: HabitTrackingKind, title: String, systemImage: String) -> some View {
        let selected = kind == tileKind
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                typePick = .health
                kind = tileKind
                applyDefaults(for: tileKind)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color(hex: "#E0512F") : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                selected ? LoopyTheme.coral.opacity(0.1) : LoopyTheme.card,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? LoopyTheme.coral : .primary.opacity(0.06), lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func selectType(_ pick: TypePick) {
        withAnimation(.snappy(duration: 0.2)) {
            typePick = pick
            switch pick {
            case .yesNo:
                kind = .binary
                schedule.mask = HabitSchedule.everyDayMask
                applyDefaults(for: .binary)
            case .scheduled:
                kind = .binary
                if schedule.isEveryDay {
                    schedule.mask = Self.scheduledPresetMask
                }
                applyDefaults(for: .binary)
            case .countable:
                kind = .count
                applyDefaults(for: .count)
            case .timed:
                kind = .duration
                applyDefaults(for: .duration)
            case .health:
                if !kind.isHealthBacked {
                    kind = .healthSteps
                    applyDefaults(for: .healthSteps)
                }
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold).monospaced())
                .tracking(1)
                .foregroundStyle(LoopyTheme.secondaryText)
            content()
        }
    }

    private var targetSectionTitle: String {
        switch kind {
        case .duration: "Duration"
        case .healthSteps, .healthActiveEnergy: "Daily target"
        default: "Daily goal"
        }
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
