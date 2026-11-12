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

    @Test func aCurrentButtonIsAsItIsNow() {
        let shared = suite()
        SharedButtons.save(buttons, to: shared)
        SharedButtons.save([RecordButtonConfig(name: "Start", color: .purple)], to: shared)
        #expect(SharedButtons.config(named: "Start", from: shared).color == .purple)
    }

    /// A shortcut or control set up with a button deleted since still
    /// records, as it looked.
    @Test func aDeletedButtonKeepsItsColor() {
        let shared = suite()
        SharedButtons.save(buttons, to: shared)
        SharedButtons.save([], to: shared)
        #expect(SharedButtons.config(named: "Stop", from: shared) == RecordButtonConfig(name: "Stop", color: .red))
    }

    @Test func aButtonNeverSeenGetsTheDefaultColor() {
        #expect(SharedButtons.config(named: "Gone", from: suite()) == RecordButtonConfig(name: "Gone", color: .defaultColor))
    }

    @Test func onlyTheLatestButtonsAreRemembered() {
        let shared = suite()
        for index in 0...SharedButtons.seenKept {
            SharedButtons.save([RecordButtonConfig(name: "B\(index)", color: .green)], to: shared)
        }
        #expect(SharedButtons.config(named: "B0", from: shared).color == .defaultColor)
        #expect(SharedButtons.config(named: "B1", from: shared).color == .green)
    }

    /// From what the control or shortcut stored, the button's name, to the
    /// event in the watch's list.
    @MainActor
    @Test func aDeletedButtonIsRecordedInItsColor() throws {
        let shared = suite()
        SharedButtons.save(buttons, to: shared)
        let settings = WatchSettings(defaults: suite(), shared: shared)
        settings.buttons = []
        let store = EventStore(fileURL: URL.temporaryDirectory.appending(path: "\(UUID()).json"))
        IntentRecorder.recorder = Recorder(store: store, settings: settings, link: PhoneLink(store: store, settings: settings))
        IntentRecorder.settings = settings
        defer {
            IntentRecorder.recorder = nil
            IntentRecorder.settings = nil
        }

        IntentRecorder.record(SharedButtons.config(named: "Stop", from: shared), at: Date(), pressedAt: nil)

        let event = try #require(store.events.first)
        #expect(event.label == "Stop")
        #expect(event.color == .red)
    }
}
