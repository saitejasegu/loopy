import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @State private var period = StatsPeriod.month

    private enum StatsPeriod: Int, CaseIterable, Identifiable {
        case month = 30
        case year = 365

        var id: Int { rawValue }
        var title: String { self == .month ? "30D" : "1Y" }
    }

    private var relevantHabits: [Habit] {
        habits.filter { $0.createdAt <= .now }
    }

    private var days: [DailyCompletion] {
        HabitAnalytics.dailyCompletions(
            endingOn: .now,
            days: period.rawValue,
            habits: relevantHabits,
            checkIns: checkIns
        )
    }

    private var totalDue: Int { days.reduce(0) { $0 + $1.due } }
    private var totalCompleted: Int { days.reduce(0) { $0 + $1.completed } }
    private var completionRate: Double { totalDue == 0 ? 0 : Double(totalCompleted) / Double(totalDue) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Statistics period")

                completionCard
                summaryGrid
                chartCard
                byHabitCard
            }
            .padding()
        }
        .background(LoopyTheme.background)
        .navigationTitle("Stats")
    }

    private var completionCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("OVERALL COMPLETION")
                    .font(.caption.bold())
                    .tracking(1.4)
                Text(completionRate, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
            }
            Spacer()
            Image(systemName: completionRate >= 0.8 ? "arrow.up.right" : "arrow.right")
                .font(.largeTitle.bold())
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(LoopyTheme.coral, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
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
            Text("Completions by day")
                .font(.headline)

            if totalDue == 0 {
                ContentUnavailableView("No data yet", systemImage: "chart.bar")
                    .frame(height: 180)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: period == .month ? .day : .month),
                        y: .value("Completion", day.ratio)
                    )
                    .foregroundStyle(day.isPerfect ? LoopyTheme.coral : LoopyTheme.coral.opacity(0.35))
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let ratio = value.as(Double.self) {
                                Text(ratio, format: .percent)
                            }
                        }
                    }
                }
                .frame(height: 190)
            }
        }
        .padding(17)
        .loopyCard()
    }

    private var byHabitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By habit")
                .font(.headline)

            if relevantHabits.isEmpty {
                Text("Create a habit to see its completion rate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relevantHabits.filter { $0.archivedAt == nil }) { habit in
                    let completion = completionRate(for: habit)
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: habit.colorHex))
                            .frame(width: 9, height: 9)
                        Text(habit.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .frame(width: 88, alignment: .leading)
                        ProgressView(value: completion)
                            .tint(Color(hex: habit.colorHex))
                        Text(completion, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
        }
        .padding(17)
        .loopyCard()
    }

    private func completionRate(for habit: Habit) -> Double {
        let eligible = days.filter { day in
            habit.createdAt <= day.date && habit.isDue(on: day.date)
        }
        guard !eligible.isEmpty else { return 0 }
        let completed = eligible.filter {
            HabitAnalytics.isComplete(habit, on: $0.date, checkIns: checkIns)
        }.count
        return Double(completed) / Double(eligible.count)
    }
}

struct MetricCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(LoopyTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .loopyCard()
    }
}
