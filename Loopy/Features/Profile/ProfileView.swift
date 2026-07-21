import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var habits: [Habit]
    @Query private var checkIns: [HabitCheckIn]
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("appearance") private var appearanceRaw = AppearancePreference.system.rawValue
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var isPresentingArchive = false

    private var activeHabits: [Habit] {
        habits.filter { $0.archivedAt == nil }
    }

    private var currentStreak: Int {
        HabitAnalytics.currentStreak(asOf: .now, habits: habits, checkIns: checkIns)
    }

    private var totalDone: Int {
        let grouped = Dictionary(grouping: checkIns) { checkIn in
            "\(checkIn.habitID.uuidString)-\(checkIn.dayKey)"
        }
        return grouped.values.filter { entries in
            guard let first = entries.first,
                  let habit = habits.first(where: { $0.id == first.habitID }) else {
                return false
            }
            return entries.reduce(0) { $0 + $1.value } >= habit.safeTarget
        }.count
    }

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { colorScheme == .dark },
            set: { appearanceRaw = $0 ? AppearancePreference.dark.rawValue : AppearancePreference.light.rawValue }
        )
    }

    private var achievements: [AchievementProgress] {
        AchievementCatalog.progress(habits: habits, checkIns: checkIns)
    }

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private var iCloudStatusText: String {
        if !iCloudSyncEnabled { return "Off" }
        return LoopyPersistence.isICloudAccountAvailable ? "iCloud" : "Waiting for iCloud"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                profileHeader
                summaryGrid
                achievementsCard
                settingsCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(LoopyTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("Your name", isPresented: $isEditingName) {
            TextField("Name", text: $draftName)
                .textContentType(.name)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                displayName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } message: {
            Text("This stays on your device and is used only for your greeting.")
        }
        .sheet(isPresented: $isPresentingArchive) {
            ArchivedHabitsView()
        }
    }

    private var profileHeader: some View {
        Button {
            draftName = displayName
            isEditingName = true
        } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Text(initial)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 82, height: 82)
                        .background(LoopyTheme.coral, in: Circle())
                        .shadow(color: LoopyTheme.coral.opacity(0.34), radius: 14, y: 8)

                    Image(systemName: "pencil")
                        .font(.caption.bold())
                        .foregroundStyle(LoopyTheme.coral)
                        .frame(width: 27, height: 27)
                        .background(LoopyTheme.card, in: Circle())
                        .overlay { Circle().stroke(LoopyTheme.coral.opacity(0.2)) }
                }

                VStack(spacing: 3) {
                    Text(displayName.isEmpty ? "Loopy User" : displayName)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text(memberSinceText)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayName.isEmpty ? "Loopy User" : displayName)
        .accessibilityHint("Double tap to edit your name")
    }

    private var summaryGrid: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return layout {
            ProfileMetricCard(value: currentStreak, label: "Streak", color: LoopyTheme.coral)
            ProfileMetricCard(value: totalDone, label: "Done", color: LoopyTheme.green)
            ProfileMetricCard(value: activeHabits.count, label: "Habits", color: Color(hex: "#8659E6"))
        }
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(unlockedCount) / \(achievements.count)")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(LoopyTheme.secondaryText)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 2 : 4),
                spacing: 16
            ) {
                ForEach(achievements.prefix(8)) { item in
                    AchievementTile(progress: item)
                }
            }
        }
        .padding(18)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
        .accessibilityElement(children: .contain)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                RemindersSettingsView()
            } label: {
                ProfileSettingRow(
                    title: "Reminders",
                    systemImage: "bell.fill",
                    color: LoopyTheme.coral
                ) {
                    let count = activeHabits.filter(\.reminderEnabled).count
                    Text(count == 0 ? "Off" : "\(count) active")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LoopyTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            Button {
                isPresentingArchive = true
            } label: {
                ProfileSettingRow(
                    title: "Archived habits",
                    systemImage: "archivebox.fill",
                    color: Color(hex: "#8659E6")
                ) {
                    Text("\(habits.count - activeHabits.count)")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(LoopyTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 58)

            ProfileSettingRow(
                title: "Dark mode",
                systemImage: "moon.fill",
                color: Color(hex: "#4A9DFF")
            ) {
                HStack(spacing: 8) {
                    Text(appearance.title)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                    Toggle("Dark mode", isOn: darkModeBinding)
                        .labelsHidden()
                        .tint(LoopyTheme.coral)
                }
            }

            Divider().padding(.leading, 58)

            ProfileSettingRow(
                title: "Backup & sync",
                systemImage: "icloud.fill",
                color: LoopyTheme.green
            ) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(iCloudStatusText)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(LoopyTheme.secondaryText)
                    Toggle("iCloud sync", isOn: $iCloudSyncEnabled)
                        .labelsHidden()
                        .tint(LoopyTheme.coral)
                        .accessibilityLabel("iCloud sync")
                }
            }
        }
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
    }

    private var initial: String {
        String((displayName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "L")).uppercased()
    }

    private var memberSinceText: String {
        guard let firstDate = habits.map(\.createdAt).min() else {
            return "Ready to begin"
        }
        return "Member since \(firstDate.formatted(.dateTime.month(.abbreviated).year()))"
    }
}

private struct ProfileMetricCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value, format: .number)
                .font(.title.monospacedDigit().bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LoopyTheme.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.05))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AchievementTile: View {
    let progress: AchievementProgress

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: progress.definition.systemImage)
                .font(.title2)
                .foregroundStyle(Color(hex: progress.definition.colorHex).opacity(progress.isUnlocked ? 1 : 0.45))
                .frame(width: 52, height: 52)
                .background(
                    Color(hex: progress.definition.colorHex).opacity(progress.isUnlocked ? 0.16 : 0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    if !progress.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .offset(x: 18, y: 18)
                    }
                }
            Text(progress.definition.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(progress.isUnlocked ? .primary : LoopyTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.definition.title)
        .accessibilityValue(progress.isUnlocked ? "Unlocked, \(progress.progressLabel)" : "Locked, \(progress.progressLabel)")
        .accessibilityHint(progress.definition.detail)
    }
}

private struct ProfileSettingRow<Accessory: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    private let accessory: () -> Accessory

    init(
        title: String,
        systemImage: String,
        color: Color,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)
            accessory()
        }
        .padding(.horizontal, 17)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
    }
}
