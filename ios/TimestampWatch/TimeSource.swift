import Foundation

/// A time and how far it could be off.
struct TimeReading {
    var time: Date
    /// Milliseconds; -1 when unknown.
    var precision: Int
}

/// Where the watch gets the time for the clock and for new events.
protocol TimeSource {
    func now() -> TimeReading
}

/// The watch's own clock, which Apple keeps synced. Its events are given
/// the phone's precision, as the phone's own events have it, while the
/// phone's last time server sync is recent. Otherwise precision is unknown.
struct WatchClock: TimeSource {
    let settings: WatchSettings

    /// How old the phone's sync may be before its precision no longer
    /// stands for the watch's events.
    static let maxAge: TimeInterval = 6 * 60 * 60

    func now() -> TimeReading {
        let time = Date()
        return TimeReading(time: time, precision: Self.precision(settings.phoneAccuracy, at: time))
    }

    static func precision(_ accuracy: PhoneAccuracy?, at time: Date) -> Int {
        guard let accuracy else { return -1 }
        let age = time.timeIntervalSince(accuracy.syncedAt)
        // A sync from the future means a clock is far off.
        guard age >= -60, age <= maxAge else { return -1 }
        return accuracy.precision
    }
}
