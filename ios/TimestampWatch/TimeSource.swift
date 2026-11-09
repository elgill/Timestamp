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

/// The watch's own clock. Apple keeps it synced, but the app can't measure
/// how closely, so precision is unknown. Correcting it against the phone's
/// time server offset comes later.
struct SystemClock: TimeSource {
    func now() -> TimeReading {
        TimeReading(time: Date(), precision: -1)
    }
}
