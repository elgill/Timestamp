import Foundation
import Testing
@testable import TimestampWatch

struct EventStoreTests {
    let fileURL = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
        .appending(path: "events.json")

    func event(_ seconds: TimeInterval, _ label: String = "") -> WatchEvent {
        WatchEvent(time: Date(timeIntervalSince1970: seconds), precision: 40, label: label)
    }

    @Test func keepsNewestFirst() {
        let store = EventStore(fileURL: fileURL)
        store.add(event(20))
        store.add(event(30))
        store.add(event(10))
        #expect(store.events.map(\.time.timeIntervalSince1970) == [30, 20, 10])
    }

    @Test func referenceIsTheOldest() {
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

    @Test func deleteRemovesOnlyThoseEvents() {
        let store = EventStore(fileURL: fileURL)
        let keep = event(10), drop = event(20)
        store.add(keep)
        store.add(drop)
        store.delete(ids: [drop.id])
        #expect(store.events == [keep])
        #expect(EventStore(fileURL: fileURL).events == [keep])
    }

    @Test func oneBadEntryDoesNotLoseTheRest() throws {
        let good = UUID()
        let json = """
        [
          {"id": "\(good)", "time": 10000, "precision": 40, "description": "Start", "color": 1},
          {"id": "not a uuid", "time": 20000, "precision": 40, "description": "", "color": 0},
          {"id": "\(UUID())", "time": 30000, "precision": 40, "description": "Later", "color": 99}
        ]
        """
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: fileURL)

        let store = EventStore(fileURL: fileURL)
        #expect(store.events.map(\.label) == ["Later", "Start"])
        #expect(store.events.last?.id == good)
        #expect(store.events.last?.color == .red)
        // A color this version doesn't know becomes the default.
        #expect(store.events.first?.color == .defaultColor)
    }

    @Test func noFileMeansNoEvents() {
        #expect(EventStore(fileURL: fileURL).events.isEmpty)
    }
}
