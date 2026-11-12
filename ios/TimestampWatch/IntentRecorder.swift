import Foundation

/// Where `RecordEventIntent` records on the watch, once the app has
/// started: from Shortcuts, Siri, or the Action button's control. The
/// intent runs in the app, but App Intents creates it, so it can't be handed
/// the app's objects; the app hands them over here instead.
@MainActor
enum IntentRecorder {
    static var recorder: Recorder?
    static var settings: WatchSettings?

    /// Records `config`, or the unnamed button, and returns the time it was
    /// recorded at: `pressedAt` if the system said when the Action button
    /// was pressed, else `now`.
    @discardableResult
    static func record(_ config: RecordButtonConfig?, at now: Date, pressedAt: Date?) -> Date {
        let reading = reading(pressedAt: pressedAt, now: now, accuracy: settings?.phoneAccuracy)
        // The button as it is now, in case its color changed since the
        // shortcut or control was set up.
        let current = config.map { chosen in
            settings?.buttons.first { $0.name == chosen.name } ?? chosen
        }
        recorder?.record(current, at: reading)
        return reading.time
    }

    static func reading(pressedAt: Date?, now: Date, accuracy: PhoneAccuracy?) -> TimeReading {
        guard let pressedAt else {
            // Whatever started this came before the system opened the app
            // and ran the intent, by an amount nobody told us, so the
            // clock's precision doesn't hold for it.
            return TimeReading(time: now, precision: -1)
        }
        // The system read the press off the same clock, so it's as precise
        // as the clock is.
        return TimeReading(time: pressedAt, precision: WatchClock.precision(accuracy, at: pressedAt))
    }
}
