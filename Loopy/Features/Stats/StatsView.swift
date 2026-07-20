import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @State private var period = StatsPeriod.month

    private let calendar = Calendar.current

    private enum StatsPeriod: Int, CaseIterable, Identifiable {
        case month = 30
        case year = 365

        var id: Int { rawValue }
        var title: String { self == .month ? "30D" : "1Y" }
        var subtitle: String { self == .month ? "Last 30 days" : "Last 12 months" }
        var comparisonLabel: String { self == .month ? "vs previous 30 days" : "vs previous year" }
    }

    private var relevantHabits: [Habit] {
        habits.filter { $0.createdAt <= .now }
    }

    private var activeHabits: [Habit] {
        relevantHabits.filter { $0.archivedAt == nil }
    }

    private var days: [DailyCompletion] {
        HabitAnalytics.dailyCompletions(
            endingOn: .now,
            days: period.rawValue,
            habits: relevantHabits,
            checkIns: checkIns
        )
    }

    private var previousDays: [DailyCompletion] {
        guard let firstDay = days.first?.date,
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: firstDay) else {
            return []
        }
        return HabitAnalytics.dailyCompletions(
            endingOn: previousEnd,
            days: period.rawValue,
            habits: relevantHabits,
            checkIns: checkIns
        )
    }

    private var totalDue: Int { days.reduce(0) { $0 + $1.due } }
    private var totalCompleted: Int { days.reduce(0) { $0 + $1.completed } }
    private var completionRate: Double { rate(for: days) }
    private var previousCompletionRate: Double { rate(for: previousDays) }
    private var rateChange: Double { completionRate - previousCompletionRate }

    private var chartPoints: [StatsChartPoint] {
        if period == .month {
            return days.suffix(12).map {
                StatsChartPoint(date: $0.date, completed: $0.completed, due: $0.due)
            }
        }

        let grouped = Dictionary(grouping: days) { day in
            calendar.dateInterval(of: .month, for: day.date)?.start ?? day.date
        }
        return grouped.keys.sorted().map { month in
            let values = grouped[month] ?? []
            return StatsChartPoint(
                date: month,
                completed: values.reduce(0) { $0 + $1.completed },
                due: values.reduce(0) { $0 + $1.due }
            )
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                pageHeader
                completionCard
                summaryGrid
                chartCard
                byHabitCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(LoopyTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var pageHeader: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))

        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your stats")
                    .font(.title.bold())
                Text(period.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LoopyTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Picker("Period", selection: $period) {
                ForEach(StatsPeriod.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 150 : 118)
            .accessibilityLabel("Statistics period")
        }
    }

    private var completionCard: some View {
        let hasPreviousData = previousDays.contains { $0.due > 0 }
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))

        return layout {
            VStack(alignment: .leading, spacing: 4) {
                Text("OVERALL COMPLETION")
                    .font(.caption.bold())
                    .tracking(1.5)
                    .opacity(0.9)
                Text(completionRate, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                if hasPreviousData {
                    Label {
                        Text(abs(rateChange), format: .percent.precision(.fractionLength(0)))
                    } icon: {
                        Image(systemName: rateChange >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    }
                    .font(.title3.monospacedDigit().bold())
                } else {
                    Text("—")
                        .font(.title3.bold())
                }
                Text(hasPreviousData ? period.comparisonLabel : "No earlier data")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.trailing)
                    .opacity(0.9)
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: LoopyTheme.coral.opacity(0.32), radius: 16, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var summaryGrid: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            MetricCard(
                value: HabitAnalytics.currentStreak(asOf: .now, habits: relevantHabits, checkIns: checkIns),
                label: "Day streak",
                color: LoopyTheme.coral
            )
            MetricCard(
                value: days.filter(\.isPerfect).count,
                label: "Perfect days",
                color: LoopyTheme.green
            )
            MetricCard(
                value: totalCompleted,
                label: "Total done",
                color: Color(hex: "#8659E6")
            )
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Completions per day")
                    .font(.headline)
                Spacer()
                Text(period == .month
                     ? Date.now.formatted(.dateTime.month(.abbreviated))
                     : Date.now.formatted(.dateTime.year()))
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(LoopyTheme.secondaryText)
            }

            if totalDue == 0 {
                ContentUnavailableView("No data yet", systemImage: "chart.bar")
                    .frame(height: 180)
            } else {
                Chart(chartPoints) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Completion", point.ratio)
                    )
                    .foregroundStyle(point.isPerfect ? LoopyTheme.coral : LoopyTheme.coral.opacity(0.32))
                    .cornerRadius(5)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(period == .month
                                     ? date.formatted(.dateTime.day())
                                     : date.formatted(.dateTime.month(.narrow)))
                                    .font(.caption2.monospacedDigit().bold())
                                    .foregroundStyle(LoopyTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 190)
                .accessibilityLabel("Completion chart")
            }
        }
        .padding(18)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
    }

    private var byHabitCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("By habit")
                .font(.headline)

            if activeHabits.isEmpty {
                Text("Create a habit to see its completion rate.")
                    .font(.subheadline)
                    .foregroundStyle(LoopyTheme.secondaryText)
            } else {
                ForEach(activeHabits) { habit in
                    let completion = completionRate(for: habit)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: habit.colorHex))
                            .frame(width: 10, height: 10)
                        Text(habit.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .frame(width: 92, alignment: .leading)
                        ProgressView(value: completion)
                            .tint(Color(hex: habit.colorHex))
                        Text(completion, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(LoopyTheme.secondaryText)
                            .frame(width: 42, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(18)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
    }

    private func rate(for completions: [DailyCompletion]) -> Double {
        let due = completions.reduce(0) { $0 + $1.due }
        guard due > 0 else { return 0 }
        return Double(completions.reduce(0) { $0 + $1.completed }) / Double(due)
    }

    private func completionRate(for habit: Habit) -> Double {
        let eligible = days.filter { day in
            let existed = habit.createdAt <= day.date
            let wasNotArchived = habit.archivedAt.map { $0 > day.date } ?? true
            return existed && wasNotArchived && habit.isDue(on: day.date)
        }
        guard !eligible.isEmpty else { return 0 }
        let completed = eligible.filter {
            HabitAnalytics.isComplete(habit, on: $0.date, checkIns: checkIns)
        }.count
        return Double(completed) / Double(eligible.count)
    }
}

private struct StatsChartPoint: Identifiable {
    let date: Date
    let completed: Int
    let due: Int

    var id: Date { date }
    var ratio: Double { due == 0 ? 0 : Double(completed) / Double(due) }
    var isPerfect: Bool { due > 0 && completed == due }
}

struct MetricCard: View {
    let value: Int
    let label: String
    let color: Color
    var minimumHeight: CGFloat = 92

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value, format: .number)
                .font(.title.monospacedDigit().bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LoopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
        .accessibilityElement(children: .combine)
    }
}
