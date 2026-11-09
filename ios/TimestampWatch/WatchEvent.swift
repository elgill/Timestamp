import Foundation
import SwiftUI

/// One recorded moment. Mirrors the phone's `Event` (lib/models/event.dart),
/// plus an `id` so an event that reaches the phone twice is only added once.
struct WatchEvent: Codable, Identifiable, Equatable {
    var id: UUID
    /// Already corrected by the best clock offset known when it was recorded.
    var time: Date
    /// How far `time` could be off, in milliseconds. -1 when unknown, as on
    /// the phone.
    var precision: Int
    var label: String
    var color: EventColor

    init(
        id: UUID = UUID(),
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
