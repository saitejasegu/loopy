import AppIntents

struct OpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today"
    static var description = IntentDescription("Opens the Today tab in Loopy.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
