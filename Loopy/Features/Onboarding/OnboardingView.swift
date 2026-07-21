import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var draftName = ""
    @State private var habitName = "Stretch"
    @State private var selectedKind: HabitTrackingKind = .binary

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProgressView(value: Double(step + 1), total: 3)
                    .tint(LoopyTheme.coral)

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: nameStep
                    default: firstHabitStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Button(primaryTitle) {
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(LoopyTheme.coral)
                .disabled(!canAdvance)
                .frame(maxWidth: .infinity)
                .controlSize(.large)

                if step > 0 {
                    Button("Back") {
                        withAnimation(.snappy) { step -= 1 }
                    }
                    .foregroundStyle(LoopyTheme.secondaryText)
                }
            }
            .padding(24)
            .background(LoopyTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Loopy")
                .font(.largeTitle.bold())
            Text("Build small daily loops. Track yes/no, counts, and timed habits — all on your device.")
                .font(.body)
                .foregroundStyle(LoopyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should we call you?")
                .font(.title.bold())
            Text("Used only for your Today greeting. Stays on this device.")
                .font(.subheadline)
                .foregroundStyle(LoopyTheme.secondaryText)
            TextField("Your name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .submitLabel(.continue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var firstHabitStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your first habit")
                .font(.title.bold())
            Text("You can add more anytime from Today.")
                .font(.subheadline)
                .foregroundStyle(LoopyTheme.secondaryText)

            TextField("Habit name", text: $habitName)
                .textFieldStyle(.roundedBorder)

            Picker("Tracking", selection: $selectedKind) {
                ForEach(HabitTrackingKind.manualCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var primaryTitle: String {
        switch step {
        case 0: "Get started"
        case 1: "Continue"
        default: "Start looping"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: true
        case 1: !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: !habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func advance() {
        switch step {
        case 0:
            withAnimation(.snappy) { step = 1 }
        case 1:
            displayName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            withAnimation(.snappy) { step = 2 }
        default:
            finish()
        }
    }

    private func finish() {
        let name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Double
        let unit: String
        switch selectedKind {
        case .duration:
            target = 600
            unit = "seconds"
        case .count:
            target = 8
            unit = "times"
        case .healthSteps:
            target = HealthKitMetric.steps.defaultTarget
            unit = HealthKitMetric.steps.defaultUnit
        case .healthActiveEnergy:
            target = HealthKitMetric.activeEnergy.defaultTarget
            unit = HealthKitMetric.activeEnergy.defaultUnit
        case .binary:
            target = 1
            unit = "times"
        }

        modelContext.insert(
            Habit(
                name: name,
                trackingKind: selectedKind,
                targetValue: target,
                unit: unit,
                sortOrder: 0
            )
        )
        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
