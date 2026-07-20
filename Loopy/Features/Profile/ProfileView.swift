import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("appearance") private var appearanceRaw = AppearancePreference.system.rawValue

    private var activeHabits: [Habit] { habits.filter { $0.archivedAt == nil } }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Text(initial)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(LoopyTheme.coral, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName.isEmpty ? "Loopy User" : displayName)
                            .font(.title3.bold())
                        Text("Keep the loop going")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Profile") {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearanceRaw) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
            }

            Section("Summary") {
                LabeledContent("Current streak") {
                    Text(HabitAnalytics.currentStreak(asOf: .now, habits: activeHabits, checkIns: checkIns), format: .number)
                }
                LabeledContent("Active habits", value: activeHabits.count.formatted())
                LabeledContent("Days checked in", value: uniqueCheckInDays.formatted())
            }

            Section("About") {
                LabeledContent("App", value: "Loopy")
                LabeledContent("Version", value: "1.0")
            }
        }
        .navigationTitle("Profile")
    }

    private var initial: String {
        String((displayName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "L")).uppercased()
    }

    private var uniqueCheckInDays: Int {
        Set(checkIns.map(\.dayKey)).count
    }
}

