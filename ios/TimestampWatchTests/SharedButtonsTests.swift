import Foundation
import Testing
@testable import TimestampWatch

/// The buttons the watch app shares with its controls extension.
struct SharedButtonsTests {
    let buttons = [
        RecordButtonConfig(name: "Start", color: .green),
        RecordButtonConfig(name: "Stop", color: .red),
    ]

    func suite() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    @Test func settingsShareTheButtonsWhenTheyChange() {
        let shared = suite()
        let settings = WatchSettings(defaults: suite(), shared: shared)
        settings.buttons = buttons
        #expect(SharedButtons.load(from: shared) == buttons)
    }

    /// Buttons saved before there was an extension to share them with.
    @Test func settingsShareTheButtonsTheyStartWith() {
        let defaults = suite()
        WatchSettings(defaults: defaults, shared: nil).buttons = buttons
        let shared = suite()
        _ = WatchSettings(defaults: defaults, shared: shared)
        #expect(SharedButtons.load(from: shared) == buttons)
    }

    @Test func aRenamedButtonStillResolves() async throws {
        let entities = try await RecordButtonQuery().entities(for: ["Gone"])
        #expect(entities.map(\.config) == [RecordButtonConfig(name: "Gone", color: .defaultColor)])
    }
}
