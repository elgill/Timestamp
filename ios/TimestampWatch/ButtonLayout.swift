import Foundation

/// One screen of record buttons, in rows. Every page fits on the screen
/// without scrolling, so the Digital Crown and swipes always move between
/// pages instead of scrolling the buttons.
struct ButtonPage: Equatable {
    /// One or two buttons per row. A nil button is the unnamed default.
    var rows: [[RecordButtonConfig?]]
}

/// Lays the record buttons out as Apple suggests for watchOS: full-width
/// buttons while there are three or fewer, then two per row (the most
/// text buttons a row should hold), and never more than fit on one screen.
enum ButtonLayout {
    static let perPage = 6

    /// The buttons in order, in pages of up to `perPage`. With no buttons
    /// set up there is one unnamed button, as on the phone.
    static func pages(_ buttons: [RecordButtonConfig]) -> [ButtonPage] {
        let configs: [RecordButtonConfig?] = buttons.isEmpty ? [nil] : buttons
        return stride(from: 0, to: configs.count, by: perPage).map { start in
            page(Array(configs[start..<min(start + perPage, configs.count)]))
        }
    }

    /// Each page lays out its own buttons, so a last page of three goes
    /// back to full width.
    private static func page(_ configs: [RecordButtonConfig?]) -> ButtonPage {
        if configs.count <= 3 {
            return ButtonPage(rows: configs.map { [$0] })
        }
        return ButtonPage(rows: stride(from: 0, to: configs.count, by: 2).map {
            Array(configs[$0..<min($0 + 2, configs.count)])
        })
    }
}
