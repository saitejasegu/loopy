import Foundation
import SwiftData

#if canImport(HealthKit)
import HealthKit
#endif

enum HealthKitMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case steps
    case activeEnergy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: "Steps"
        case .activeEnergy: "Active energy"
        }
    }

    var defaultUnit: String {
        switch self {
        case .steps: "steps"
        case .activeEnergy: "kcal"
        }
    }

    var defaultTarget: Double {
        switch self {
        case .steps: 10_000
        case .activeEnergy: 400
        }
    }
}

/// Reads daily HealthKit totals and writes dated check-ins so streaks stay offline-consistent.
@MainActor
enum HealthKitHabitSync {
    static var isDataAvailable: Bool {
        #if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable()
        #else
        false
        #endif
    }

    static func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard isDataAvailable else { return false }
        let store = HKHealthStore()
        var read: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            read.insert(steps)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            read.insert(energy)
        }
        do {
            try await store.requestAuthorization(toShare: [], read: read)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    static func sync(
        habits: [Habit],
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) async {
        #if canImport(HealthKit)
        guard isDataAvailable else { return }
        let healthHabits = habits.filter {
            $0.archivedAt == nil && $0.trackingKind.isHealthBacked
        }
        guard !healthHabits.isEmpty else { return }

        let store = HKHealthStore()
        for habit in healthHabits {
            let metric: HealthKitMetric = habit.trackingKind == .healthSteps ? .steps : .activeEnergy
            if let total = await quantity(for: metric, on: date, store: store, calendar: calendar) {
                HabitCheckInService.setValue(total, for: habit, on: date, in: context, calendar: calendar)
            }
        }
        #endif
    }

    #if canImport(HealthKit)
    private static func quantity(
        for metric: HealthKitMetric,
        on date: Date,
        store: HKHealthStore,
        calendar: Calendar
    ) async -> Double? {
        let quantityType: HKQuantityType?
        let unit: HKUnit
        switch metric {
        case .steps:
            quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)
            unit = .count()
        case .activeEnergy:
            quantityType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
            unit = .kilocalorie()
        }
        guard let quantityType else { return nil }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
    #endif
}
