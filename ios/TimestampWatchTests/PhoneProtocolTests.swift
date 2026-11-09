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
        #expect(context.importedIds == ["A1B2C3D4-0000-4000-8000-000000000001"])
    }

    @Test func writesWhatThePhoneReads() throws {
        let changes = WatchChanges(
            added: [WatchEvent(
                id: "A1B2C3D4-0000-4000-8000-000000000001",
                time: Date(timeIntervalSince1970: 1_794_164_602.47),
                precision: -1, label: "Lap", color: .orange)],
            deleted: ["A1B2C3D4-0000-4000-8000-000000000002"])

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
