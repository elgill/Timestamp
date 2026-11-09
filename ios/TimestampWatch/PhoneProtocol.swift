import Foundation

/// What the phone sends: the buttons and settings the watch shares with it,
/// and its newest events. Written by `WatchProtocol.context` in
/// lib/services/watch_protocol.dart; test/fixtures/watch/context.json is an
/// example both sides are tested against.
struct PhoneContext: Decodable {
    var buttons: [RecordButtonConfig]
    var timeFormat: TimeFormat
    var events: [WatchEvent]
    var reference: WatchEvent?
    /// The watch's events the phone has taken in.
    var importedIds: [String]
    /// How accurate the phone's time is, if it has synced with a time server.
    var accuracy: PhoneAccuracy?

    enum CodingKeys: String, CodingKey {
        case buttons, timeFormat, events, reference, importedIds, accuracy
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        buttons = (try? c.decode([Lossy<RecordButtonConfig>].self, forKey: .buttons))?
            .compactMap(\.value) ?? []
        timeFormat = (try? c.decode(Int.self, forKey: .timeFormat))
            .flatMap(TimeFormat.init(rawValue:)) ?? .local24Hour
        events = (try? c.decode([Lossy<WatchEvent>].self, forKey: .events))?
            .compactMap(\.value) ?? []
        reference = try? c.decode(WatchEvent.self, forKey: .reference)
        importedIds = (try? c.decode([String].self, forKey: .importedIds)) ?? []
        accuracy = try? c.decode(PhoneAccuracy.self, forKey: .accuracy)
    }

    static func decode(json: String) throws -> PhoneContext {
        try WatchJSON.decoder.decode(PhoneContext.self, from: Data(json.utf8))
    }
}

/// The phone's last sync with a time server: the precision its own events
/// get, and when it was measured.
struct PhoneAccuracy: Codable, Equatable {
    /// Milliseconds.
    var precision: Int
    var syncedAt: Date
}

/// What the watch sends: events it recorded and events it deleted. Read by
/// `WatchChanges.parse` in lib/services/watch_protocol.dart;
/// test/fixtures/watch/changes.json is an example.
struct WatchChanges: Encodable {
    var added: [WatchEvent] = []
    var deleted: [String] = []

    func json() throws -> String {
        String(decoding: try WatchJSON.encoder.encode(self), as: UTF8.self)
    }
}
