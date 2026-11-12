import Foundation
import Observation

/// The phone's `TimeFormat`, by the same index.
enum TimeFormat: Int, Codable {
    case local12Hour = 0
    case local24Hour
    case utc24Hour
}

/// Settings the watch shares with the phone. Saved so the watch keeps them
/// when the phone isn't around.
@Observable
final class WatchSettings {
    /// Empty means a single unnamed button, as on the phone.
    var buttons: [RecordButtonConfig] { didSet { save() } }
    var timeFormat: TimeFormat { didSet { save() } }
    /// Record when the finger lands instead of when it lifts, which is
    /// earlier and so closer to the moment the user reacted to.
    var recordOnTouchDown: Bool { didSet { save() } }
    /// What the watch's events give as their precision. See `WatchClock`.
    var phoneAccuracy: PhoneAccuracy? { didSet { save() } }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let shared: UserDefaults?

    private enum Key {
        static let buttons = "buttons"
        static let timeFormat = "timeFormat"
        static let recordOnTouchDown = "recordOnTouchDown"
        static let phoneAccuracy = "phoneAccuracy"
    }

    init(defaults: UserDefaults = .standard, shared: UserDefaults? = SharedButtons.defaults) {
        self.defaults = defaults
        self.shared = shared
        buttons = defaults.data(forKey: Key.buttons)
            .flatMap { try? JSONDecoder().decode([RecordButtonConfig].self, from: $0) } ?? []
        timeFormat = (defaults.object(forKey: Key.timeFormat) as? Int)
            .flatMap(TimeFormat.init(rawValue:)) ?? .local24Hour
        recordOnTouchDown = defaults.object(forKey: Key.recordOnTouchDown) as? Bool ?? true
        phoneAccuracy = defaults.data(forKey: Key.phoneAccuracy)
            .flatMap { try? JSONDecoder().decode(PhoneAccuracy.self, from: $0) }
        // Buttons saved before the controls extension existed.
        SharedButtons.save(buttons, to: shared)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(buttons), forKey: Key.buttons)
        SharedButtons.save(buttons, to: shared)
        defaults.set(timeFormat.rawValue, forKey: Key.timeFormat)
        defaults.set(recordOnTouchDown, forKey: Key.recordOnTouchDown)
        defaults.set(try? JSONEncoder().encode(phoneAccuracy), forKey: Key.phoneAccuracy)
    }
}
