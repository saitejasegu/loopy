import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @AppStorage("displayName") private var displayName = ""

    @State private var isPresentingNewHabit = false
    @State private var editingHabit: Habit?
    @State private var timerHabit: Habit?

    private var activeHabits: [Habit] {
        habits.filter { $0.archivedAt == nil }
    }

    private var dueHabits: [Habit] {
        activeHabits.filter { $0.isDue(on: .now) }
    }

    private var completedCount: Int {
        dueHabits.filter { HabitAnalytics.isComplete($0, on: .now, checkIns: checkIns) }.count
    }

    private var greetingName: String {
        let firstName = displayName.split(separator: " ").first.map(String.init) ?? ""
        return firstName.isEmpty ? "there" : firstName
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                greeting
                streakCard

                if dueHabits.isEmpty {
                    ContentUnavailableView {
                        Label("No habits due", systemImage: "checkmark.seal")
                    } description: {
                        Text(activeHabits.isEmpty
                             ? "Create your first habit to start a loop."
                             : "Nothing is scheduled for today.")
                    } actions: {
                        Button("Add Habit") { isPresentingNewHabit = true }
                            .buttonStyle(.borderedProminent)
                            .tint(LoopyTheme.coral)
                    }
                    .frame(minHeight: 260)
                } else {
                    ForEach(dueHabits) { habit in
                        HabitRow(
                            habit: habit,
                            value: HabitAnalytics.value(for: habit, on: .now, checkIns: checkIns),
                            onPrimaryAction: { performPrimaryAction(for: habit) },
                            onDecrement: { adjust(habit, by: -1) }
                        )
                        .contextMenu {
                            if habit.trackingKind == .count,
                               HabitAnalytics.value(for: habit, on: .now, checkIns: checkIns) > 0 {
                                Button("Decrease", systemImage: "minus.circle") {
                                    adjust(habit, by: -1)
                                }
                            }
                            Button("Edit", systemImage: "pencil") {
                                editingHabit = habit
                            }
                            Button("Archive", systemImage: "archivebox", role: .destructive) {
                                habit.archivedAt = .now
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(LoopyTheme.background)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add habit", systemImage: "plus") {
                    isPresentingNewHabit = true
                }
            }
        }
        .sheet(isPresented: $isPresentingNewHabit) {
            HabitEditorView()
        }
        .sheet(item: $editingHabit) { habit in
            HabitEditorView(habit: habit)
        }
        .sheet(item: $timerHabit) { habit in
            TimerSessionView(habit: habit)
        }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline)
                    .foregroundStyle(LoopyTheme.secondaryText)
                Text("Hey, \(greetingName)")
                    .font(.title2.bold())
            }
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(LoopyTheme.coral)
                .accessibilityHidden(true)
        }
    }

    private var streakCard: some View {
        let streak = HabitAnalytics.currentStreak(asOf: .now, habits: activeHabits, checkIns: checkIns)
        let progress = dueHabits.isEmpty ? 0 : Double(completedCount) / Double(dueHabits.count)

        return HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CURRENT STREAK")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(streak, format: .number)
                        .font(.system(size: 52, weight: .bold, design: .monospaced))
                    Text(streak == 1 ? "day" : "days")
                        .font(.headline)
                }
                Text(streak == 0 ? "A perfect day starts your streak" : "Keep your loop alive")
                    .font(.caption)
                    .opacity(0.9)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(.white.opacity(0.28), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(completedCount)/\(dueHabits.count)")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
            }
            .frame(width: 72, height: 72)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's progress")
            .accessibilityValue("\(completedCount) of \(dueHabits.count) habits complete")
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: LoopyTheme.coral.opacity(0.3), radius: 14, y: 8)
    }

    private func performPrimaryAction(for habit: Habit) {
        switch habit.trackingKind {
        case .binary:
            toggleCompletion(for: habit)
        case .count:
            adjust(habit, by: 1)
        case .duration:
            timerHabit = habit
        }
    }

    private func todayCheckIn(for habit: Habit) -> HabitCheckIn? {
        let key = DayKey.make(for: .now)
        return checkIns.first { $0.habitID == habit.id && $0.dayKey == key }
    }

    private func toggleCompletion(for habit: Habit) {
        if let existing = todayCheckIn(for: habit) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(HabitCheckIn(habitID: habit.id, value: habit.safeTarget))
        }
    }

    private func adjust(_ habit: Habit, by amount: Double) {
        if let existing = todayCheckIn(for: habit) {
            existing.value = max(0, existing.value + amount)
            existing.timestamp = .now
            if existing.value == 0 { modelContext.delete(existing) }
        } else if amount > 0 {
            modelContext.insert(HabitCheckIn(habitID: habit.id, value: amount))
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let value: Double
    let onPrimaryAction: () -> Void
    let onDecrement: () -> Void

    private var progress: Double { min(value / habit.safeTarget, 1) }
    private var isComplete: Bool { progress >= 1 }

    var body: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: 13) {
                Text(String(habit.name.prefix(2)).capitalized)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: habit.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(LoopyTheme.secondaryText)
                }

                Spacer()

                trailingControl
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .loopyCard()
        .accessibilityLabel(habit.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction(named: "Decrease") { onDecrement() }
    }

    private var subtitle: String {
        switch habit.trackingKind {
        case .binary:
            HabitSchedule(mask: habit.weekdaysMask).summary
        case .count:
            "\(value.formatted(.number.precision(.fractionLength(0)))) of \(habit.targetValue.formatted(.number.precision(.fractionLength(0)))) \(habit.unit)"
        case .duration:
            "\((habit.targetValue / 60).formatted(.number.precision(.fractionLength(0)))) min · timed"
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if habit.trackingKind == .count {
            VStack(alignment: .trailing, spacing: 6) {
                ProgressView(value: progress)
                    .tint(Color(hex: habit.colorHex))
                    .frame(width: 82)
                Text("\(Int(value))/\(Int(habit.targetValue))")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(Color(hex: habit.colorHex))
            }
        } else {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 31))
                .foregroundStyle(isComplete ? LoopyTheme.green : Color.secondary.opacity(0.35))
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var accessibilityValue: String {
        if habit.trackingKind == .count {
            return "\(Int(value)) of \(Int(habit.targetValue)) \(habit.unit)"
        }
        return isComplete ? "Complete" : "Incomplete"
    }

    private var accessibilityHint: String {
        switch habit.trackingKind {
        case .binary: "Double tap to toggle completion"
        case .count: "Double tap to add one"
        case .duration: "Double tap to open the timer"
        }
    }
}

private struct TimerSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var checkIns: [HabitCheckIn]
    @AppStorage("activeTimerHabitID") private var activeHabitID = ""
    @AppStorage("activeTimerStartedAt") private var activeStartedAt = 0.0

    let habit: Habit

    private var isRunning: Bool {
        activeHabitID == habit.id.uuidString && activeStartedAt > 0
    }

    private var recordedSeconds: Double {
        HabitAnalytics.value(for: habit, on: .now, checkIns: checkIns)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let elapsed = elapsedSeconds(at: timeline.date)
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.14), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: min((recordedSeconds + elapsed) / habit.safeTarget, 1))
                            .stroke(Color(hex: habit.colorHex), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 5) {
                            Text(durationString(recordedSeconds + elapsed))
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                            Text("of \(durationString(habit.targetValue))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 230, height: 230)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Timer progress")
                    .accessibilityValue("\(durationString(recordedSeconds + elapsed)) of \(durationString(habit.targetValue))")
                }

                Button {
                    isRunning ? stopTimer() : startTimer()
                } label: {
                    Label(isRunning ? "Stop Timer" : "Start Timer", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : Color(hex: habit.colorHex))

                if !isRunning && recordedSeconds < habit.targetValue {
                    Button("Mark target complete") {
                        setTodayValue(habit.targetValue)
                        dismiss()
                    }
                }

                if recordedSeconds > 0 && !isRunning {
                    Button("Reset today", role: .destructive) {
                        setTodayValue(0)
                    }
                }

                Spacer()
            }
            .padding(28)
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(LoopyTheme.coral)
        .presentationDetents([.medium, .large])
    }

    private func elapsedSeconds(at date: Date) -> Double {
        guard isRunning else { return 0 }
        return max(0, date.timeIntervalSince1970 - activeStartedAt)
    }

    private func startTimer() {
        activeHabitID = habit.id.uuidString
        activeStartedAt = Date.now.timeIntervalSince1970
    }

    private func stopTimer() {
        let elapsed = elapsedSeconds(at: .now)
        setTodayValue(recordedSeconds + elapsed)
        activeHabitID = ""
        activeStartedAt = 0
    }

    private func setTodayValue(_ value: Double) {
        let key = DayKey.make(for: .now)
        if let existing = checkIns.first(where: { $0.habitID == habit.id && $0.dayKey == key }) {
            if value <= 0 {
                modelContext.delete(existing)
            } else {
                existing.value = value
                existing.timestamp = .now
            }
        } else if value > 0 {
            modelContext.insert(HabitCheckIn(habitID: habit.id, value: value))
        }
    }

    private func durationString(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
