import Foundation

/// Where `RecordEventIntent` records, once the app has started. The
/// intent runs in the app, but App Intents creates it, so it can't be
/// handed the app's objects; the app hands them over here instead.
@MainActor
enum ActionButton {
    static var recorder: Recorder?
    static var settings: WatchSettings?
    static var timeSource: TimeSource?

    /// Records `config`, or the unnamed button, at `pressedAt` if the
    /// system said when the button was pressed, else now.
    static func record(_ config: RecordButtonConfig?, pressedAt: Date?) {
        guard let recorder, let timeSource else { return }
        // The button as it is now, in case its color changed since the
        // control was set up.
        let current = config.map { chosen in
            settings?.buttons.first { $0.name == chosen.name } ?? chosen
        }
        recorder.record(current, at: reading(pressedAt: pressedAt, now: timeSource.now(), accuracy: settings?.phoneAccuracy))
    }

    static func reading(pressedAt: Date?, now: TimeReading, accuracy: PhoneAccuracy?) -> TimeReading {
        guard let pressedAt else {
            // The press came before the system opened the app and ran the
            // intent, by an amount nobody told us, so the clock's precision
            // doesn't hold for it.
            return TimeReading(time: now.time, precision: -1)
        }
        // The system read the press off the same clock, so it's as precise
        // as the clock is.
        return TimeReading(time: pressedAt, precision: WatchClock.precision(accuracy, at: pressedAt))
    }
}
