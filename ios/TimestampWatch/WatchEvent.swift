import Foundation
import SwiftUI

/// One recorded moment. Mirrors the phone's `Event` (lib/models/event.dart),
/// including its `id`, which is how the phone and watch recognise an event
/// they've already seen.
struct WatchEvent: Codable, Identifiable, Equatable {
    /// Compared as text: the phone's ids are lowercase, the watch's uppercase.
    var id: String
    /// Already corrected by the best clock offset known when it was recorded.
    var time: Date
    /// How far `time` could be off, in milliseconds. -1 when unknown, as on
    /// the phone.
    var precision: Int
    var label: String
    var color: EventColor

    init(
        id: String = UUID().uuidString,
        time: Date,
        precision: Int,
        label: String = "",
        color: EventColor = .defaultColor
    ) {
        self.id = id
        self.time = time
        self.precision = precision
        self.label = label
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id, time, precision, color
        case label = "description"
    }
}

/// The phone's `PredefinedColor`, by the same index.
enum EventColor: Int, Codable, CaseIterable {
    case defaultColor = 0
    case red
    case green
    case orange
    case purple

    /// An index this version doesn't know becomes the default, as on the
    /// phone, so it can't cost the user the event it's attached to.
    init(from decoder: Decoder) throws {
        let index = try decoder.singleValueContainer().decode(Int.self)
        self = EventColor(rawValue: index) ?? .defaultColor
    }

    /// The Material colors the phone uses, so a button looks the same on both.
    var color: Color {
        switch self {
        case .defaultColor: return Color(hex: 0x009688) // Colors.teal
        case .red: return Color(hex: 0xF44336)
        case .green: return Color(hex: 0x4CAF50)
        case .orange: return Color(hex: 0xFF9800)
        case .purple: return Color(hex: 0x9C27B0)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// JSON as the phone and the event file use it: times in whole milliseconds
/// since 1970.
enum WatchJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            // Down, not to nearest, so the tenths never change. From 2038
            // on, some times read back from milliseconds come out just under
            // (...470 as ...469.9998); the 1µs nudge stops those losing a
            // millisecond on every save.
            try container.encode((date.timeIntervalSince1970 * 1000 + 0.001).rounded(.down))
        }
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}

/// Decodes to nil instead of failing, so one bad array element doesn't fail
/// the whole array.
struct Lossy<Value: Codable>: Codable {
    let value: Value?

    init(value: Value?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
