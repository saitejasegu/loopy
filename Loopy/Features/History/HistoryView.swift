import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let leading = calendar.component(.weekday, from: first) - 1
        return Array(repeating: nil, count: leading) + range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: first)
        }.map(Optional.some)
    }

    private var monthStats: [DailyCompletion] {
        monthDays.compactMap { $0 }.filter { $0 <= .now }.map {
            HabitAnalytics.dailyCompletion(on: $0, habits: habits, checkIns: checkIns)
        }
    }

    private var activeDays: Int {
        monthStats.filter { $0.completed > 0 }.count
    }

    private var perfectDays: Int {
        monthStats.filter(\.isPerfect).count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                pageHeader
                streakBanner
                calendarCard
                monthSummary
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(LoopyTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: Binding(
            get: { selectedDate != nil },
            set: { if !$0 { selectedDate = nil } }
        )) {
            if let selectedDate {
                DayDetailView(date: selectedDate, habits: habits, checkIns: checkIns)
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("History")
                .font(.title.bold())
            Text("Every day you showed up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LoopyTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var streakBanner: some View {
        let streak = HabitAnalytics.currentStreak(asOf: .now, habits: habits, checkIns: checkIns)
        let best = HabitAnalytics.personalBestStreak(asOf: .now, habits: habits, checkIns: checkIns)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))

        return layout {
            Text(streak, format: .number)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            VStack(alignment: .leading, spacing: 2) {
                Text("day streak")
                    .font(.headline)
                Label {
                    Text(streak == 0
                         ? "Complete every due habit to begin"
                         : "Keep it alive — best was \(best)")
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .font(.caption.weight(.semibold))
                .opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LoopyTheme.coral.opacity(0.3), radius: 14, y: 9)
        .accessibilityElement(children: .combine)
    }

    private var calendarCard: some View {
        VStack(spacing: 18) {
            HStack {
                monthButton(title: "Previous month", systemImage: "chevron.left") {
                    moveMonth(by: -1)
                }

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                monthButton(title: "Next month", systemImage: "chevron.right") {
                    moveMonth(by: 1)
                }
                .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            completion: HabitAnalytics.dailyCompletion(
                                on: date,
                                habits: habits,
                                checkIns: checkIns
                            ),
                            isFuture: calendar.startOfDay(for: date) > calendar.startOfDay(for: .now)
                        )
                        .onTapGesture {
                            if date <= .now { selectedDate = date }
                        }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Less")
                ForEach([0.08, 0.3, 0.6, 1.0], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LoopyTheme.coral.opacity(opacity))
                        .frame(width: 14, height: 14)
                }
                Text("More")
            }
            .font(.caption2.monospaced().bold())
            .foregroundStyle(LoopyTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Calendar completion scale from less to more")
        }
        .padding(18)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
    }

    private func monthButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.bold())
                .foregroundStyle(LoopyTheme.secondaryText)
                .frame(width: 44, height: 44)
                .background(LoopyTheme.chip, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .accessibilityLabel(title)
    }

    private var monthSummary: some View {
        let month = displayedMonth.formatted(.dateTime.month(.abbreviated))
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            MetricCard(
                value: activeDays,
                label: "Active days in \(month)",
                color: .primary,
                minimumHeight: 96
            )
            MetricCard(
                value: perfectDays,
                label: "Perfect days",
                color: .primary,
                minimumHeight: 96
            )
        }
    }

    private func moveMonth(by offset: Int) {
        withAnimation(.snappy) {
            displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
        }
    }
}

private struct DayCell: View {
    let date: Date
    let completion: DailyCompletion
    let isFuture: Bool

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Text(date, format: .dateTime.day())
            .font(.caption.monospacedDigit().bold())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(foreground)
            .contentShape(Rectangle())
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityValue(accessibilityValue)
            .accessibilityAddTraits(isToday ? .isSelected : [])
    }

    private var background: Color {
        if isToday { return .primary }
        if isFuture || completion.due == 0 { return LoopyTheme.progressTrack.opacity(0.55) }
        return LoopyTheme.coral.opacity(0.2 + completion.ratio * 0.8)
    }

    private var foreground: Color {
        if isToday { return LoopyTheme.background }
        if isFuture || completion.due == 0 { return LoopyTheme.secondaryText.opacity(0.6) }
        return completion.ratio >= 0.5 ? .white : .primary
    }

    private var accessibilityValue: String {
        if isToday {
            return "Today, \(completion.completed) of \(completion.due) habits completed"
        }
        if completion.due == 0 { return "No habits due" }
        return "\(completion.completed) of \(completion.due) habits completed"
    }
}

private struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let date: Date
    let habits: [Habit]
    let checkIns: [HabitCheckIn]

    private var dueHabits: [Habit] {
        habits.filter { habit in
            let existed = habit.createdAt <= date
            let wasNotArchived = habit.archivedAt.map { $0 > date } ?? true
            return existed && wasNotArchived && habit.isDue(on: date)
        }
    }

    var body: some View {
        NavigationStack {
            List(dueHabits) { habit in
                DayDetailHabitRow(habit: habit, date: date, checkIns: checkIns)
            }
            .overlay {
                if dueHabits.isEmpty {
                    ContentUnavailableView("No habits due", systemImage: "calendar")
                }
            }
            .navigationTitle(date.formatted(date: .long, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(LoopyTheme.coral)
    }
}

private struct DayDetailHabitRow: View {
    @Environment(\.modelContext) private var modelContext
    let habit: Habit
    let date: Date
    let checkIns: [HabitCheckIn]

    private var value: Double {
        HabitAnalytics.value(for: habit, on: date, checkIns: checkIns)
    }

    private var isComplete: Bool {
        HabitAnalytics.isComplete(habit, on: date, checkIns: checkIns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(habit.name, systemImage: habit.trackingKind.systemImage)
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isComplete ? LoopyTheme.green : .secondary)
                    .accessibilityLabel(isComplete ? "Complete" : "Incomplete")
            }

            switch habit.trackingKind {
            case .binary:
                Button(isComplete ? "Mark incomplete" : "Mark complete") {
                    HabitCheckInService.toggleBinary(for: habit, on: date, in: modelContext)
                    try? modelContext.save()
                }
            case .count:
                HStack {
                    Text("\(Int(value)) / \(Int(habit.targetValue)) \(habit.unit)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        HabitCheckInService.adjustCount(for: habit, by: -1, on: date, in: modelContext)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(value <= 0)
                    .accessibilityLabel("Decrease")

                    Button {
                        HabitCheckInService.adjustCount(for: habit, by: 1, on: date, in: modelContext)
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Increase")
                }
                .buttonStyle(.plain)
                .foregroundStyle(LoopyTheme.coral)
            case .duration:
                HStack {
                    Text(durationLabel)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set complete") {
                        HabitCheckInService.setValue(habit.safeTarget, for: habit, on: date, in: modelContext)
                        try? modelContext.save()
                    }
                    Button("Clear", role: .destructive) {
                        HabitCheckInService.setValue(0, for: habit, on: date, in: modelContext)
                        try? modelContext.save()
                    }
                }
            case .healthSteps, .healthActiveEnergy:
                Text("Synced from Apple Health · \(Int(value)) / \(Int(habit.targetValue)) \(habit.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Refresh from Health") {
                    Task {
                        await HealthKitHabitSync.sync(habits: [habit], on: date, in: modelContext)
                        try? modelContext.save()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var durationLabel: String {
        let total = max(0, Int(value.rounded(.down)))
        let target = max(0, Int(habit.targetValue.rounded(.down)))
        return String(format: "%d:%02d / %d:%02d", total / 60, total % 60, target / 60, target % 60)
    }
}
