import Foundation
import Testing
@testable import TimestampWatch

/// What the complications are given to show.
struct ComplicationTests {
    let time = Date(timeIntervalSince1970: 1_794_164_400.47) // 2026-11-07 19:00:00.4 UTC
    let newYork = TimeZone(identifier: "America/New_York")!

    func suite() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    @Test func theClockTimeSaysWhichClock() {
        #expect(ComplicationView.clockTime(time, .local12Hour, timeZone: newYork) == "2:00:00.4 PM")
        #expect(ComplicationView.clockTime(time, .local24Hour, timeZone: newYork) == "14:00:00.4")
        #expect(ComplicationView.clockTime(time, .utc24Hour, timeZone: newYork) == "19:00:00.4 UTC")
    }

    @Test func aSnapshotSurvivesSaving() {
        let defaults = suite()
        let snapshot = ComplicationSnapshot(
            reference: WatchEvent(time: time, precision: 22, label: "Lap", color: .orange), timeFormat: .local12Hour)
        snapshot.save(to: defaults)
        #expect(ComplicationSnapshot.load(from: defaults) == snapshot)
    }

    /// watchOS limits reloads, so one is only asked for when something shows.
    @Test func savingTheSameAgainChangesNothing() {
        let defaults = suite()
        let snapshot = ComplicationSnapshot(reference: nil, timeFormat: .local24Hour)
        #expect(snapshot.save(to: defaults))
        #expect(!snapshot.save(to: defaults))
        #expect(ComplicationSnapshot(reference: nil, timeFormat: .utc24Hour).save(to: defaults))
    }

    /// Without a reference chosen it's the oldest event, as in the app.
    @MainActor
    @Test func itCountsFromTheReference() {
        let defaults = suite()
        let store = EventStore(fileURL: URL.temporaryDirectory.appending(path: "\(UUID()).json"))
        let settings = WatchSettings(defaults: suite(), shared: nil)
        let start = WatchEvent(time: time, precision: -1, label: "Start")
        let lap = WatchEvent(time: time.addingTimeInterval(60), precision: -1, label: "Lap")
        store.add(start)
        store.add(lap)
        Complications.update(store: store, settings: settings, defaults: defaults)
        #expect(ComplicationSnapshot.load(from: defaults)?.reference == start)

        store.setReference(lap)
        Complications.update(store: store, settings: settings, defaults: defaults)
        #expect(ComplicationSnapshot.load(from: defaults)?.reference == lap)
    }
}
