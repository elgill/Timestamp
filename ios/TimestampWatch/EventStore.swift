import Foundation
import Observation

/// The events on the watch, newest first, saved to a JSON file.
@Observable
final class EventStore {
    private(set) var events: [WatchEvent] = []

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = EventStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    /// What relative times count from. The oldest event, which is what the
    /// phone uses until the user picks another.
    var reference: WatchEvent? { events.last }

    func add(_ event: WatchEvent) {
        // Most events are the newest, so this is usually an insert at the front.
        let index = events.firstIndex { $0.time < event.time } ?? events.endIndex
        events.insert(event, at: index)
        save()
    }

    func delete(ids: Set<UUID>) {
        events.removeAll { ids.contains($0.id) }
        save()
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "events.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        // One unreadable entry must not cost the user the rest of the log.
        let entries = (try? Self.decoder.decode([Lossy<WatchEvent>].self, from: data)) ?? []
        events = entries.compactMap(\.value).sorted { $0.time > $1.time }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(events).write(to: fileURL, options: .atomic)
        } catch {
            // Keep going: the events are still in memory and the next save
            // tries again.
            print("Saving events failed: \(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

/// Decodes to nil instead of failing, so one bad array element doesn't fail
/// the whole array.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
