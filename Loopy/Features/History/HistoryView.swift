import SwiftData
import SwiftUI

struct HistoryView: View {
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
        monthDays.compactMap { $0 }.map {
            HabitAnalytics.dailyCompletion(on: $0, habits: habits, checkIns: checkIns)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                streakBanner
                calendarCard
                monthSummary
            }
            .padding()
        }
        .background(LoopyTheme.background)
        .navigationTitle("History")
        .sheet(isPresented: Binding(
            get: { selectedDate != nil },
            set: { if !$0 { selectedDate = nil } }
        )) {
            if let selectedDate {
                DayDetailView(date: selectedDate, habits: habits, checkIns: checkIns)
            }
        }
    }

    private var streakBanner: some View {
        let streak = HabitAnalytics.currentStreak(asOf: .now, habits: habits, checkIns: checkIns)
        return HStack(spacing: 14) {
            Text(streak, format: .number)
                .font(.system(size: 42, weight: .bold, design: .monospaced))
            VStack(alignment: .leading) {
                Text("day streak")
                    .font(.headline)
                Text(streak == 0 ? "Complete every due habit to begin" : "Keep your loop alive")
                    .font(.caption)
                    .opacity(0.9)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.title)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Previous month", systemImage: "chevron.left") {
                    moveMonth(by: -1)
                }
                .labelStyle(.iconOnly)
                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button("Next month", systemImage: "chevron.right") {
                    moveMonth(by: 1)
                }
                .labelStyle(.iconOnly)
                .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        DayCell(
                            date: date,
                            completion: HabitAnalytics.dailyCompletion(on: date, habits: habits, checkIns: checkIns),
                            isFuture: date > .now
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Less")
                ForEach([0.08, 0.3, 0.6, 1.0], id: \.self) { opacity in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LoopyTheme.coral.opacity(opacity))
                        .frame(width: 13, height: 13)
                }
                Text("More")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .loopyCard()
    }

    private var monthSummary: some View {
        HStack(spacing: 10) {
            MetricCard(
                value: monthStats.filter { $0.completed > 0 }.count,
                label: "Active days",
                color: LoopyTheme.coral
            )
            MetricCard(
                value: monthStats.filter(\.isPerfect).count,
                label: "Perfect days",
                color: LoopyTheme.green
            )
        }
    }

    private func moveMonth(by offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }
}

private struct DayCell: View {
    let date: Date
    let completion: DailyCompletion
    let isFuture: Bool

    var body: some View {
        Text(date, format: .dateTime.day())
            .font(.caption.monospacedDigit().bold())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .foregroundStyle(foreground)
            .overlay {
                if Calendar.current.isDateInToday(date) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.primary, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityValue(accessibilityValue)
    }

    private var background: Color {
        if isFuture || completion.due == 0 { return Color.secondary.opacity(0.08) }
        return LoopyTheme.coral.opacity(0.18 + completion.ratio * 0.82)
    }

    private var foreground: Color {
        completion.ratio >= 0.55 ? .white : .primary
    }

    private var accessibilityValue: String {
        if completion.due == 0 { return "No habits due" }
        return "\(completion.completed) of \(completion.due) habits completed"
    }
}

private struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let habits: [Habit]
    let checkIns: [HabitCheckIn]

    private var dueHabits: [Habit] {
        habits.filter { $0.createdAt <= date && $0.isDue(on: date) }
    }

    var body: some View {
        NavigationStack {
            List(dueHabits) { habit in
                HStack {
                    Label(habit.name, systemImage: habit.trackingKind.systemImage)
                    Spacer()
                    if HabitAnalytics.isComplete(habit, on: date, checkIns: checkIns) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(LoopyTheme.green)
                            .accessibilityLabel("Complete")
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Incomplete")
                    }
                }
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
    }
}
