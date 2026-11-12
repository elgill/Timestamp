import Foundation

/// A named, colored record button, like the phone's `ButtonModel`.
struct RecordButtonConfig: Codable, Equatable, Identifiable {
    var name: String
    var color: EventColor

    var id: String { name }
}

/// The record buttons, where the controls extension can read them too, so
/// the Action button's control can offer them. The watch app writes them
/// whenever they change; `WatchSettings` stays the app's own copy.
enum SharedButtons {
    static let appGroup = "group.dev.gillin.timestamp"

    private static let key = "buttons"

    /// Nil only if the app group isn't set up, as in a build without the
    /// entitlement.
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults? = defaults) -> [RecordButtonConfig] {
        defaults?.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([RecordButtonConfig].self, from: $0) } ?? []
    }

    static func save(_ buttons: [RecordButtonConfig], to defaults: UserDefaults? = defaults) {
        defaults?.set(try? JSONEncoder().encode(buttons), forKey: key)
    }
}
