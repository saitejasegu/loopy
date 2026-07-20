import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @AppStorage("displayName") private var displayName = ""

    @State private var isPresentingNewHabit = false
    @State private var isEditing = false
    @State private var editingHabit: Habit?
    @State private var timerHabit: Habit?

    @ScaledMetric(relativeTo: .largeTitle) private var streakNumberSize = 58

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

    private var initial: String {
        String((displayName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "L")).uppercased()
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning,"
        case 12..<17: "Good afternoon,"
        default: "Good evening,"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    pageHeader
                    streakCard
                    habitsHeader

                    if dueHabits.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(dueHabits) { habit in
                                habitRow(for: habit)
                            }
                            addHabitRow
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 92)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Button {
                    isPresentingNewHabit = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(LoopyTheme.coral, in: Circle())
                        .shadow(color: LoopyTheme.coral.opacity(0.46), radius: 14, y: 8)
                }
                .accessibilityLabel("Add habit")
                .padding(.trailing, 22)
                .padding(.bottom, 18)
            }
        }
        .background(LoopyTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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

    private var pageHeader: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(greeting)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LoopyTheme.secondaryText)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        avatar
                    }
                    greetingTitle
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LoopyTheme.secondaryText)
                        greetingTitle
                    }

                    Spacer(minLength: 8)
                    avatar
                }
            }
        }
    }

    private var greetingTitle: some View {
        Text("Hey \(greetingName)")
            .font(.title.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.76)
    }

    private var avatar: some View {
        Text(initial)
            .font(.headline.bold())
            .foregroundStyle(LoopyTheme.secondaryText)
            .frame(width: 44, height: 44)
            .background(LoopyTheme.chip, in: Circle())
            .accessibilityLabel(displayName.isEmpty ? "Loopy profile" : "Profile for \(displayName)")
    }

    private var streakCard: some View {
        let streak = HabitAnalytics.currentStreak(asOf: .now, habits: activeHabits, checkIns: checkIns)
        let personalBest = HabitAnalytics.personalBestStreak(asOf: .now, habits: habits, checkIns: checkIns)
        let progress = dueHabits.isEmpty ? 0 : Double(completedCount) / Double(dueHabits.count)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(spacing: 18))

        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT STREAK")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .opacity(0.9)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(streak, format: .number)
                        .font(.system(size: min(streakNumberSize, 76), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text(streak == 1 ? "day" : "days")
                        .font(.headline.weight(.semibold))
                        .opacity(0.9)
                }

                Text("Personal best · \(personalBest) \(personalBest == 1 ? "day" : "days")")
                    .font(.subheadline.weight(.medium))
                    .opacity(0.86)
            }

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                ProgressRing(
                    progress: progress,
                    lineWidth: 9,
                    trackColor: .white.opacity(0.28),
                    progressColor: .white
                ) {
                    Text("\(completedCount)/\(dueHabits.count)")
                        .font(.headline.monospacedDigit().bold())
                }
                .frame(width: 78, height: 78)

                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .opacity(0.9)
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's progress")
            .accessibilityValue("\(completedCount) of \(dueHabits.count) habits complete")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: LoopyTheme.coral.opacity(0.36), radius: 16, y: 10)
    }

    private var habitsHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())

        return layout {
            Text("Today’s habits")
                .font(.title3.bold())

            Spacer(minLength: 0)

            if !dueHabits.isEmpty {
                Button(isEditing ? "Done" : "Edit") {
                    withAnimation(.snappy) {
                        isEditing.toggle()
                    }
                }
                .font(.caption.monospaced().bold())
                .foregroundStyle(isEditing ? LoopyTheme.coral : LoopyTheme.secondaryText)
                .padding(.horizontal, 13)
                .frame(minHeight: 34)
                .background(LoopyTheme.chip, in: Capsule())
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No habits due", systemImage: "checkmark.seal")
        } description: {
            Text(activeHabits.isEmpty
                 ? "Create your first habit to start a loop."
                 : "Nothing is scheduled for today.")
        } actions: {
            Button("Add Habit") {
                isPresentingNewHabit = true
            }
            .buttonStyle(.borderedProminent)
            .tint(LoopyTheme.coral)
        }
        .frame(minHeight: 250)
    }

    private func habitRow(for habit: Habit) -> some View {
        HabitRow(
            habit: habit,
            value: HabitAnalytics.value(for: habit, on: .now, checkIns: checkIns),
            isEditing: isEditing,
            onPrimaryAction: {
                if isEditing {
                    editingHabit = habit
                } else {
                    performPrimaryAction(for: habit)
                }
            },
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

    private var addHabitRow: some View {
        Button {
            isPresentingNewHabit = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(LoopyTheme.coral)
                    .frame(width: 44, height: 44)
                    .background(
                        LoopyTheme.coral.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )

                Text("Add a habit")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LoopyTheme.secondaryText)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LoopyTheme.secondaryText.opacity(0.42),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                )
        }
        .accessibilityHint("Opens the new habit form")
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
    let isEditing: Bool
    let onPrimaryAction: () -> Void
    let onDecrement: () -> Void

    private var progress: Double { min(value / habit.safeTarget, 1) }
    private var isComplete: Bool { progress >= 1 }

    var body: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: 13) {
                Text(String(habit.name.prefix(2)).capitalized)
                    .font(.headline.bold())
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 46, height: 46)
                    .background(
                        Color(hex: habit.colorHex).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LoopyTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                if isEditing {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(LoopyTheme.coral)
                        .frame(width: 36, height: 36)
                        .background(LoopyTheme.coral.opacity(0.12), in: Circle())
                } else {
                    trailingControl
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .loopyCard(background: isComplete ? LoopyTheme.completedCard : LoopyTheme.card)
        .accessibilityLabel(habit.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isEditing ? "Double tap to edit" : accessibilityHint)
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
        switch habit.trackingKind {
        case .count:
            VStack(alignment: .trailing, spacing: 6) {
                SegmentedProgress(
                    progress: progress,
                    target: habit.safeTarget,
                    color: Color(hex: habit.colorHex)
                )
                .frame(width: 94)
                Text("\(Int(value))/\(Int(habit.targetValue))")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(Color(hex: habit.colorHex))
            }
        case .duration:
            if isComplete {
                ZStack {
                    Circle().fill(LoopyTheme.green)
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
            } else {
                ProgressRing(
                    progress: progress,
                    lineWidth: 7,
                    trackColor: LoopyTheme.progressTrack,
                    progressColor: Color(hex: habit.colorHex)
                ) {
                    Text(durationString(value))
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(Color(hex: habit.colorHex))
                }
                .frame(width: 48, height: 48)
            }
        case .binary:
            ZStack {
                Circle()
                    .fill(isComplete ? LoopyTheme.green : .clear)
                Circle()
                    .stroke(isComplete ? .clear : LoopyTheme.progressTrack, lineWidth: 2)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 34, height: 34)
            .contentTransition(.symbolEffect(.replace))
        }
    }

    private var accessibilityValue: String {
        if habit.trackingKind == .count {
            return "\(Int(value)) of \(Int(habit.targetValue)) \(habit.unit)"
        }
        if habit.trackingKind == .duration {
            return "\(durationString(value)) recorded; \(isComplete ? "complete" : "incomplete")"
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

    private func durationString(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct ProgressRing<Content: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let trackColor: Color
    let progressColor: Color
    private let content: () -> Content

    init(
        progress: Double,
        lineWidth: CGFloat,
        trackColor: Color,
        progressColor: Color,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.trackColor = trackColor
        self.progressColor = progressColor
        self.content = content
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            content()
        }
    }
}

private struct SegmentedProgress: View {
    let progress: Double
    let target: Double
    let color: Color

    private var segmentCount: Int {
        min(max(Int(target.rounded()), 1), 8)
    }

    private var filledSegments: Int {
        min(Int((progress * Double(segmentCount)).rounded(.up)), segmentCount)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Capsule()
                    .fill(index < filledSegments ? color : LoopyTheme.progressTrack)
                    .frame(height: 5)
            }
        }
        .animation(.snappy, value: filledSegments)
        .accessibilityHidden(true)
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
