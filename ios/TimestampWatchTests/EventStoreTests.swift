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
        _ events: [WatchEvent], reference: WatchEvent? = nil, imported: [String] = [],
        referenceSetAt: TimeInterval? = nil
    ) throws -> PhoneContext {
        var json: [String: Any] = [
            "buttons": [],
            "timeFormat": 1,
            "events": try events.map { try JSONSerialization.jsonObject(with: WatchJSON.encoder.encode($0)) },
            "reference": try reference.map { try JSONSerialization.jsonObject(with: WatchJSON.encoder.encode($0)) } ?? NSNull(),
            "importedIds": imported,
        ]
        if let referenceSetAt { json["referenceSetAt"] = referenceSetAt * 1000 }
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

    @Test func eventsAreUnconfirmedUntilThePhoneHasThem() throws {
        let store = EventStore(fileURL: fileURL)
        let first = event(10, "first"), second = event(20, "second"), third = event(30, "third")
        store.add(second)
        store.add(first)
        store.add(third)
        #expect(store.unconfirmed == [first, second, third])

        store.apply(try context([second], imported: [first.id]))
        #expect(store.unconfirmed == [third])

        store.delete(ids: [third.id])
        #expect(store.unconfirmed.isEmpty)
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

    // MARK: Choosing the reference

    func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    @Test func aChosenReferenceShowsAtOnce() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a, referenceSetAt: 100))
        let choice = store.setReference(b, at: at(200))
        #expect(choice == ReferenceChoice(id: b.id, setAt: at(200)))
        #expect(store.reference == b)
    }

    @Test func aContextSentBeforeThePhoneHeardDoesNotUndoIt() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a, referenceSetAt: 100))
        store.setReference(b, at: at(200))
        store.apply(try context([b, a], reference: a, referenceSetAt: 100))
        #expect(store.reference == b)
    }

    @Test func onceThePhoneHasItThePhonesWordIsUsedAgain() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        store.setReference(b, at: at(200))
        store.apply(try context([b, a], reference: b, referenceSetAt: 200))
        #expect(store.reference == b)

        // Later, the phone falls back to the oldest when b is deleted there.
        store.apply(try context([a], reference: a, referenceSetAt: 200))
        #expect(store.reference == a)
    }

    @Test func aLaterChoiceOnThePhoneWins() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        store.setReference(b, at: at(200))
        store.apply(try context([b, a], reference: a, referenceSetAt: 300))
        #expect(store.reference == a)
    }

    @Test func aChoiceOfAnEventDeletedOnThePhoneIsDropped() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        store.setReference(b, at: at(200))
        store.apply(try context([a], reference: a))
        #expect(store.reference == a)
    }

    @Test func itsOwnEventCanBeChosenBeforeThePhoneHasIt() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap")
        store.apply(try context([a], reference: a))
        store.add(lap)
        store.setReference(lap, at: at(200))
        // Sent before the phone got the event.
        store.apply(try context([a], reference: a))
        #expect(store.reference == lap)
    }

    @Test func deletingTheChosenEventFallsBack() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap")
        store.apply(try context([a], reference: a))
        store.add(lap)
        store.setReference(lap, at: at(200))
        store.delete(ids: [lap.id])
        #expect(store.reference == a)
    }

    // MARK: Choosing the reference while events are deleted

    @Test func aChoiceEchoedToTheMillisecondSettles() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        let choice = store.setReference(b, at: at(200.123_456))
        // What the phone sends back: whole milliseconds.
        store.apply(try context([b, a], reference: b, referenceSetAt: 200.123))
        #expect(choice.setAt == at(200.123))
        // Settled, so the phone's word counts again: it falls back to a.
        store.apply(try context([a], reference: a, referenceSetAt: 200.123))
        #expect(store.reference == a)
    }

    @Test func thePhoneDeletingEverythingDropsTheChoice() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        store.setReference(b, at: at(200))
        store.apply(try context([]))
        #expect(store.reference == nil)
        #expect(store.events.isEmpty)
    }

    @Test func itsOwnChosenEventTakenInAndDeletedOnThePhoneIsDropped() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap")
        store.apply(try context([a], reference: a))
        store.add(lap)
        store.setReference(lap, at: at(200))
        // The phone took the event in, then deleted it, before the choice came.
        store.apply(try context([a], reference: a, imported: [lap.id]))
        #expect(store.reference == a)
        #expect(!store.events.contains(lap))
    }

    @Test func deletingAnotherEventKeepsTheChoice() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap"), b = event(30)
        store.apply(try context([b, a], reference: a))
        store.add(lap)
        store.setReference(b, at: at(200))
        store.delete(ids: [lap.id])
        #expect(store.reference == b)
    }

    @Test func deletingThePhonesReferenceHereKeepsAChoiceMadeHere() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap"), b = event(30)
        store.add(lap)
        store.apply(try context([b, lap, a], reference: lap))
        store.setReference(b, at: at(200))
        store.delete(ids: [lap.id])
        #expect(store.reference == b)
    }

    @Test func choosingAgainAfterTheChosenEventIsDeletedWorks() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), lap = event(20, "Lap"), b = event(30)
        store.apply(try context([b, a], reference: a))
        store.add(lap)
        store.setReference(lap, at: at(200))
        store.delete(ids: [lap.id])
        store.setReference(b, at: at(300))
        store.apply(try context([b, a], reference: a, referenceSetAt: 100))
        #expect(store.reference == b)
    }

    @Test func aChoiceSurvivesARelaunch() throws {
        let store = EventStore(fileURL: fileURL)
        let a = event(10), b = event(20)
        store.apply(try context([b, a], reference: a))
        store.setReference(b, at: at(200))

        let reloaded = EventStore(fileURL: fileURL)
        #expect(reloaded.reference == b)
        // And is still held over an old context.
        reloaded.apply(try context([b, a], reference: a))
        #expect(reloaded.reference == b)
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
