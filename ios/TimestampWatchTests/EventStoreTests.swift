import Foundation
import Testing
@testable import TimestampWatch

struct EventStoreTests {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "events.json")

    func event(_ seconds: TimeInterval, _ label: String = "", id: String = UUID().uuidString) -> WatchEvent {
        WatchEvent(id: id, time: Date(timeIntervalSince1970: seconds), precision: 40, label: label)
    }

    func context(
        _ events: [WatchEvent], reference: WatchEvent? = nil, imported: [String] = []
    ) throws -> PhoneContext {
        let json: [String: Any] = [
            "buttons": [],
            "timeFormat": 1,
            "events": try events.map { try JSONSerialization.jsonObject(with: WatchJSON.encoder.encode($0)) },
            "reference": try reference.map { try JSONSerialization.jsonObject(with: WatchJSON.encoder.encode($0)) } ?? NSNull(),
            "importedIds": imported,
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try PhoneContext.decode(json: String(decoding: data, as: UTF8.self))
    }

    func times(_ store: EventStore) -> [TimeInterval] {
        store.events.map(\.time.timeIntervalSince1970)
    }

    // MARK: On its own

    @Test func keepsNewestFirst() {
        let store = EventStore(fileURL: fileURL)
        store.add(event(20))
        store.add(event(30))
        store.add(event(10))
        #expect(times(store) == [30, 20, 10])
    }

    @Test func withoutThePhoneTheReferenceIsTheOldest() {
        let store = EventStore(fileURL: fileURL)
        store.add(event(20))
        store.add(event(10))
        store.add(event(30))
        #expect(store.reference?.time.timeIntervalSince1970 == 10)
    }

    @Test func eventsSurviveARelaunch() {
        let store = EventStore(fileURL: fileURL)
        let lap = WatchEvent(
            time: Date(timeIntervalSince1970: 1_794_164_602.47),
            precision: 40, label: "Lap", color: .orange)
        store.add(lap)
        store.add(event(10))

        let reloaded = EventStore(fileURL: fileURL)
        #expect(reloaded.events == store.events)
        #expect(reloaded.events.first == lap)
    }

    @Test func timesDoNotDriftOverManySaves() {
        // From 2038 on, some times read back from milliseconds come out just
        // under, like this one, and would lose a millisecond per save.
        let time = Date(timeIntervalSince1970: 2_193_603_828.47)
        EventStore(fileURL: fileURL).add(WatchEvent(time: time, precision: 40))
        var store = EventStore(fileURL: fileURL)
        for _ in 0..<20 {
            store.add(event(1))
            store = EventStore(fileURL: fileURL)
        }
        #expect(store.events.first?.time == time)
    }

    @Test func noFileMeansNoEvents() {
        #expect(EventStore(fileURL: fileURL).events.isEmpty)
    }

    // MARK: With the phone

    @Test func showsThePhonesEventsWithItsOwn() throws {
        let store = EventStore(fileURL: fileURL)
        store.add(event(25, "watch"))
        store.apply(try context([event(30, "phone"), event(20, "phone")]))
        #expect(store.events.map(\.label) == ["phone", "watch", "phone"])
    }

    @Test func anEventThePhoneHasIsShownOnce() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        store.apply(try context([lap]))
        #expect(store.events == [lap])
    }

    @Test func letsGoOfAnEventThePhoneTookInAndDeleted() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        store.apply(try context([], imported: [lap.id]))
        #expect(store.events.isEmpty)
    }

    @Test func keepsItsEventsUntilThePhoneHasThem() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        // Sent before the phone got the event.
        store.apply(try context([event(10, "phone")]))
        #expect(store.events.map(\.label) == ["Lap", "phone"])
    }

    @Test func thePhonesReferenceIsUsed() throws {
        let store = EventStore(fileURL: fileURL)
        let reference = event(20, "ref")
        store.apply(try context([event(30), reference, event(10)], reference: reference))
        #expect(store.reference == reference)
    }

    @Test func aReferenceOlderThanTheEventsSentIsStillUsed() throws {
        let store = EventStore(fileURL: fileURL)
        let reference = event(1, "ref")
        store.apply(try context([event(30)], reference: reference))
        #expect(store.reference == reference)
    }

    @Test func phoneEventsCannotBeDeletedHere() throws {
        let store = EventStore(fileURL: fileURL)
        let phone = event(30, "phone")
        store.apply(try context([phone]))
        #expect(!store.canDelete(phone))
        #expect(store.delete(ids: [phone.id]).isEmpty)
        #expect(store.events == [phone])
    }

    @Test func itsOwnEventsCanBeDeletedAfterThePhoneHasThem() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        store.apply(try context([lap]))
        #expect(store.canDelete(lap))
        #expect(store.delete(ids: [lap.id]) == [lap.id])
        #expect(store.events.isEmpty)
    }

    @Test func aDeletedEventStaysHiddenUntilThePhoneDeletesIt() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        store.apply(try context([lap]))
        store.delete(ids: [lap.id])

        // The phone hasn't processed the delete yet.
        store.apply(try context([lap, event(30)]))
        #expect(!store.events.contains(lap))

        store.apply(try context([event(30)]))
        #expect(store.events.count == 1)
    }

    @Test func deletingTheReferenceFallsBackToTheOldest() throws {
        let store = EventStore(fileURL: fileURL)
        let lap = event(20, "Lap")
        store.add(lap)
        store.apply(try context([event(30), lap, event(25)], reference: lap))
        store.delete(ids: [lap.id])
        #expect(store.reference?.time.timeIntervalSince1970 == 25)
    }

    @Test func everythingSurvivesARelaunch() throws {
        let store = EventStore(fileURL: fileURL)
        let phone = event(30, "phone"), mine = event(20, "mine"), pending = event(40, "pending")
        store.add(mine)
        store.apply(try context([phone, mine], reference: phone))
        store.add(pending)

        let reloaded = EventStore(fileURL: fileURL)
        #expect(reloaded.events == store.events)
        #expect(reloaded.reference == phone)
        #expect(reloaded.canDelete(mine))
        #expect(reloaded.canDelete(pending))
        #expect(!reloaded.canDelete(phone))
    }

    @Test func oneBadEntryDoesNotLoseTheRest() throws {
        let json = """
        {
          "recorded": [
            {"id": "a", "time": 10000, "precision": 40, "description": "Start", "color": 1},
            {"id": "b", "time": "not a time", "precision": 40, "description": "", "color": 0},
            {"id": "c", "time": 30000, "precision": 40, "description": "Later", "color": 99}
          ],
          "phoneEvents": [],
          "ownIds": ["a", "b", "c"],
          "hiddenIds": []
        }
        """
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: fileURL)

        let store = EventStore(fileURL: fileURL)
        #expect(store.events.map(\.label) == ["Later", "Start"])
        #expect(store.events.last?.color == .red)
        // A color this version doesn't know becomes the default.
        #expect(store.events.first?.color == .defaultColor)
    }
}
