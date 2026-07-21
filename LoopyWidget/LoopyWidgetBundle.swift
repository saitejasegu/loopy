import WidgetKit
import SwiftUI

@main
struct LoopyWidgetEntry: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
        StreakAccessoryWidget()
    }
}
