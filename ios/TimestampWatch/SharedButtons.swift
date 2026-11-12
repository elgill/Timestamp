import Foundation

/// A named, colored record button, like the phone's `ButtonModel`.
struct RecordButtonConfig: Codable, Equatable, Identifiable {
    var name: String
    var color: EventColor

    var id: String { name }
}

/// The record buttons, for `RecordEventIntent` to offer. Each app writes
/// them whenever they change. On the watch they're kept where the controls
/// extension can read them too, and `WatchSettings` stays the app's own copy.
enum SharedButtons {
    static let appGroup = "group.dev.gillin.timestamp"

    private static let key = "buttons"

    /// Nil only if the app group isn't set up, as in a build without the
    /// entitlement.
    static var defaults: UserDefaults? {
        #if os(watchOS)
        UserDefaults(suiteName: appGroup)
        #else
        // Only the phone app reads them there.
        UserDefaults.standard
        #endif
    }

    /// Every button seen, current or since deleted, most recent last.
    private static let seenKey = "seenButtons"

    /// Enough for every button anyone keeps around, without growing forever.
    static let seenKept = 200

    static func load(from defaults: UserDefaults? = defaults) -> [RecordButtonConfig] {
        decode(defaults?.data(forKey: key))
    }

    static func save(_ buttons: [RecordButtonConfig], to defaults: UserDefaults? = defaults) {
        defaults?.set(try? JSONEncoder().encode(buttons), forKey: key)
        // Remembered as last seen, the current ones winning.
        let names = Set(buttons.map(\.name))
        let seen = decode(defaults?.data(forKey: seenKey)).filter { !names.contains($0.name) } + buttons
        defaults?.set(try? JSONEncoder().encode(Array(seen.suffix(seenKept))), forKey: seenKey)
    }

    /// The button called `name`. One since deleted or renamed still records,
    /// in the color it had; one never seen gets the default color.
    static func config(named name: String, from defaults: UserDefaults? = defaults) -> RecordButtonConfig {
        load(from: defaults).first { $0.name == name }
            ?? decode(defaults?.data(forKey: seenKey)).last { $0.name == name }
            ?? RecordButtonConfig(name: name, color: .defaultColor)
    }

    private static func decode(_ data: Data?) -> [RecordButtonConfig] {
        data.flatMap { try? JSONDecoder().decode([RecordButtonConfig].self, from: $0) } ?? []
    }
}
