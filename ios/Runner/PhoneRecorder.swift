import AppIntents
import Foundation

/// Where `RecordEventIntent` records on the phone: from Shortcuts, Siri,
/// Spotlight or the iPhone's Action button.
///
/// The event goes into the watch inbox, as if the watch had recorded it,
/// and Flutter saves it from there: straight away if it's running, else
/// when the app next opens. Flutter's own events are never written from
/// here (see `WatchBridge`).
enum PhoneRecorder {
    /// What lib/services/ntp_service.dart saves as the clock's offset from
    /// the time server, in milliseconds. shared_preferences keeps its keys
    /// in the standard defaults, prefixed "flutter.".
    private static let ntpOffsetKey = "flutter.ntpOffset"

    /// Records `config`, or the unnamed button, at `time` on the phone's
    /// clock, and returns the time recorded.
    @discardableResult
    static func record(_ config: RecordButtonConfig?, at time: Date, defaults: UserDefaults = .standard) -> Date {
        let event = event(config, at: time, offsetMillis: defaults.object(forKey: ntpOffsetKey) as? Int)
        do {
            WatchBridge.shared.deliver(json: try Changes(added: [event]).json())
        } catch {
            print("Encoding a recorded event failed: \(error)")
        }
        return event.time
    }

    static func event(_ config: RecordButtonConfig?, at time: Date, offsetMillis: Int?) -> WatchEvent {
        WatchEvent(
            id: UUID().uuidString.lowercased(),
            // Corrected like the phone's own events, by the last offset
            // measured.
            time: time.addingTimeInterval(Double(offsetMillis ?? 0) / 1000),
            // The time is when the intent ran, some unknown while after
            // whatever started it.
            precision: -1,
            label: config?.name ?? "",
            color: config?.color ?? .defaultColor)
    }

    /// The watch's `WatchChanges`, which is what the inbox holds.
    private struct Changes: Encodable {
        var added: [WatchEvent]
        var deleted: [String] = []

        func json() throws -> String {
            String(decoding: try WatchJSON.encoder.encode(self), as: UTF8.self)
        }
    }
}
