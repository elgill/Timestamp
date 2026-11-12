import AppIntents
import SwiftUI
import WidgetKit

@main
struct TimestampWatchControls: WidgetBundle {
    var body: some Widget {
        RecordControl()
    }
}

/// A control that records an event, for the Action button on Apple Watch
/// Ultra (and Control Center and the Smart Stack). Which event is chosen
/// when the control is set up.
struct RecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: "dev.gillin.timestamp.watchkitapp.record",
            intent: RecordEventIntent.self
        ) { intent in
            ControlWidgetButton(action: intent) {
                Label(intent.button?.id ?? "Record", systemImage: "stopwatch")
            }
            .tint((intent.button?.color ?? .defaultColor).color)
        }
        .displayName("Record Event")
        .description("Records the time, as tapping one of your buttons does. It’s timed when the app opens, a moment after the press, so it’s less precise than a tap.")
        .promptsForUserConfiguration()
    }
}
