import AppIntents

struct OpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Today"
    static let description = IntentDescription("Opens the Today tab in Loopy.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
