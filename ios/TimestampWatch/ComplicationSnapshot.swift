import Foundation

/// What the complications show, written by the watch app where the widget
/// extension can read it: the reference event, which the complications
/// count from, and how to show its time.
struct ComplicationSnapshot: Codable, Equatable {
    /// As the app has it: the one chosen, else the phone's, else the oldest.
    var reference: WatchEvent?
    var timeFormat: TimeFormat

    static let kind = "dev.gillin.timestamp.watchkitapp.reference"

    private static let key = "complicationSnapshot"

    static func load(from defaults: UserDefaults? = SharedButtons.defaults) -> ComplicationSnapshot? {
        defaults?.data(forKey: key).flatMap { try? WatchJSON.decoder.decode(ComplicationSnapshot.self, from: $0) }
    }

    /// Saves this if it differs from what's saved, and says whether it did,
    /// so the complications are only reloaded when they'd change. watchOS
    /// limits how often they can be.
    @discardableResult
    func save(to defaults: UserDefaults? = SharedButtons.defaults) -> Bool {
        guard let defaults, Self.load(from: defaults) != self,
              let data = try? WatchJSON.encoder.encode(self)
        else { return false }
        defaults.set(data, forKey: Self.key)
        return true
    }
}
