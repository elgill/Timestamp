import Foundation
import Testing
@testable import TimestampWatch

/// Checks the watch reads and writes the same messages as the phone, using
/// the examples in test/fixtures/watch that the Dart tests also use.
struct PhoneProtocolTests {
    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../test/fixtures/watch")

    func fixture(_ name: String) throws -> String {
        try String(contentsOf: Self.fixtures.appending(path: name), encoding: .utf8)
    }

    @Test func readsWhatThePhoneSends() throws {
        let context = try PhoneContext.decode(json: fixture("context.json"))

        #expect(context.buttons == [
            RecordButtonConfig(name: "Start", color: .green),
            RecordButtonConfig(name: "Lap", color: .orange),
        ])
        #expect(context.timeFormat == .local12Hour)
        #expect(context.events == [
            WatchEvent(
                id: "6f1c1a0e-3b55-4c9e-9f5a-0b8e5d2b1a01",
                time: Date(timeIntervalSince1970: 1_794_164_602.47),
                precision: 40, label: "Lap", color: .orange),
            WatchEvent(
                id: "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d",
                time: Date(timeIntervalSince1970: 1_794_164_500),
                precision: -1),
        ])
        #expect(context.reference == context.events.last)
        #expect(context.referenceSetAt == Date(timeIntervalSince1970: 1_794_164_550))
        #expect(context.importedIds == ["A1B2C3D4-0000-4000-8000-000000000001"])
        #expect(context.accuracy == PhoneAccuracy(
            precision: 22, syncedAt: Date(timeIntervalSince1970: 1_794_164_400)))
    }

    @Test func writesWhatThePhoneReads() throws {
        let changes = WatchChanges(
            added: [WatchEvent(
                id: "A1B2C3D4-0000-4000-8000-000000000001",
                time: Date(timeIntervalSince1970: 1_794_164_602.47),
                precision: -1, label: "Lap", color: .orange)],
            deleted: ["A1B2C3D4-0000-4000-8000-000000000002"],
            reference: ReferenceChoice(
                id: "A1B2C3D4-0000-4000-8000-000000000001",
                setAt: Date(timeIntervalSince1970: 1_794_164_610.25)))

        let written = try JSONSerialization.jsonObject(with: Data(changes.json().utf8)) as? NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Data(fixture("changes.json").utf8)) as? NSDictionary
        #expect(written == expected)
    }

    @Test func aContextWithoutAReferenceOrButtonsIsRead() throws {
        let context = try PhoneContext.decode(json: """
            {"buttons": [], "timeFormat": 2, "events": [], "reference": null, "importedIds": []}
            """)
        #expect(context.buttons.isEmpty)
        #expect(context.timeFormat == .utc24Hour)
        #expect(context.reference == nil)
        #expect(context.referenceSetAt == nil)
        // From a phone that hasn't synced with a time server, or an older app.
        #expect(context.accuracy == nil)
    }

    @Test func changesWithoutAReferenceLeaveItOut() throws {
        let json = try WatchChanges(deleted: ["a"]).json()
        let written = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        #expect(written?["reference"] == nil)
    }

    @Test func oneUnreadableEventDoesNotLoseTheRest() throws {
        let context = try PhoneContext.decode(json: """
            {"buttons": [], "timeFormat": 1, "importedIds": [],
             "events": [{"id": "a", "time": "bad"},
                        {"id": "b", "time": 1000, "precision": 5, "description": "ok", "color": 0}]}
            """)
        #expect(context.events.map(\.id) == ["b"])
    }

    @Test func anUnknownTimeFormatFallsBackTo24Hour() throws {
        let context = try PhoneContext.decode(json: """
            {"buttons": [], "timeFormat": 7, "events": [], "importedIds": []}
            """)
        #expect(context.timeFormat == .local24Hour)
    }
}

/// The phone's context can come twice, once for the complications, and the
/// copies can arrive in either order.
@MainActor
struct PhoneContextOrderTests {
    func context(reference: String) -> String {
        """
        {"buttons": [], "timeFormat": 1, "importedIds": [],
         "events": [{"id": "a", "time": 1794164500000, "precision": -1, "description": "", "color": 0},
                    {"id": "b", "time": 1794164600000, "precision": -1, "description": "", "color": 0}],
         "reference": {"id": "\(reference)", "time": \(reference == "a" ? 1794164500000 : 1794164600000), "precision": -1, "description": "", "color": 0}}
        """
    }

    @Test func anOlderCopyArrivingLateIsPassedOver() {
        let store = EventStore(fileURL: URL.temporaryDirectory.appending(path: "\(UUID()).json"))
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let link = PhoneLink(store: store, settings: WatchSettings(defaults: suite, shared: nil), defaults: suite)

        link.apply(["json": context(reference: "b"), "sentAt": 200.0])
        link.apply(["json": context(reference: "a"), "sentAt": 100.0])
        #expect(store.reference?.id == "b")

        // The other copy of the same send.
        link.apply(["json": context(reference: "b"), "sentAt": 200.0])
        #expect(store.reference?.id == "b")

        link.apply(["json": context(reference: "a"), "sentAt": 300.0])
        #expect(store.reference?.id == "a")
    }

    /// From a phone app from before contexts said when they were sent.
    @Test func aContextWithoutASendTimeIsApplied() {
        let store = EventStore(fileURL: URL.temporaryDirectory.appending(path: "\(UUID()).json"))
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let link = PhoneLink(store: store, settings: WatchSettings(defaults: suite, shared: nil), defaults: suite)
        link.apply(["json": context(reference: "b"), "sentAt": 200.0])
        link.apply(["json": context(reference: "a")])
        #expect(store.reference?.id == "a")
    }
}
