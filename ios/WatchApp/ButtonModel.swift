import Foundation
import SwiftUI

struct ButtonModel: Identifiable, Codable {
    let id: String
    let name: String
    let color: String

    var swiftUIColor: Color {
        switch color.lowercased() {
        case "red":
            return .red
        case "green":
            return .green
        case "orange":
            return .orange
        case "purple":
            return .purple
        default:
            return .blue
        }
    }

    static func from(dict: [String: Any]) -> ButtonModel? {
        guard let name = dict["name"] as? String,
              let color = dict["color"] as? String else {
            return nil
        }

        let id = dict["id"] as? String ?? UUID().uuidString
        return ButtonModel(id: id, name: name, color: color)
    }

    func toDict() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "color": color
        ]
    }
}
