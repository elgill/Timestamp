import Foundation

/// What the complications show, written by the watch app where the widget
/// extension can read it: the events they count from, and how to show
/// their times.
struct ComplicationSnapshot: Codable, Equatable {
    /// As the app has it: the one chosen, else the phone's, else the oldest.
    var reference: WatchEvent?
    /// The newest event. Missing from snapshots saved before there was a
    /// complication for it, so optional in what's saved too.
    var latest: WatchEvent?
    var timeFormat: TimeFormat

    private static let key = "complicationSnapshot"

    static func load(from defaults: UserDefaults? = SharedButtons.defaults) -> ComplicationSnapshot? {
        defaults?.data(forKey: key).flatMap { try? WatchJSON.decoder.decode(ComplicationSnapshot.self, from: $0) }
    }

    /// Saves this and returns the complications it changes, so only those
    /// are reloaded. watchOS limits how often they can be.
    @discardableResult
    func save(to defaults: UserDefaults? = SharedButtons.defaults) -> [ComplicationSource] {
        guard let defaults else { return [] }
        let saved = Self.load(from: defaults)
        let changed = ComplicationSource.allCases.filter { source in
            saved.map { source.shows($0) != source.shows(self) } ?? true
        }
        guard !changed.isEmpty, let data = try? WatchJSON.encoder.encode(self) else { return [] }
        defaults.set(data, forKey: Self.key)
        return changed
    }
}

/// Which event a complication counts from.
enum ComplicationSource: CaseIterable {
    case reference
    case latest

    var kind: String {
        switch self {
        case .reference: "dev.gillin.timestamp.watchkitapp.reference"
        case .latest: "dev.gillin.timestamp.watchkitapp.latest"
        }
    }

    func event(in snapshot: ComplicationSnapshot?) -> WatchEvent? {
        switch self {
        case .reference: snapshot?.reference
        case .latest: snapshot?.latest
        }
    }

    /// What of the snapshot this complication shows.
    fileprivate struct Shown: Equatable {
        var event: WatchEvent?
        var timeFormat: TimeFormat
    }

    fileprivate func shows(_ snapshot: ComplicationSnapshot) -> Shown {
        Shown(event: event(in: snapshot), timeFormat: snapshot.timeFormat)
    }
}
