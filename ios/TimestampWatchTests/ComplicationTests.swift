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

    /// Dimmed, the count is to the minute and short.
    @Test func theDimmedCountIsShort() {
        func age(_ seconds: TimeInterval) -> String {
            ComplicationView.shortAge(of: time, at: time.addingTimeInterval(seconds))
        }
        #expect(age(-5) == "0m")
        #expect(age(59) == "0m")
        #expect(age(60) == "1m")
        #expect(age(47 * 60 + 59) == "47m")
        #expect(age(3600 + 5 * 60) == "1h 05m")
        #expect(age(23 * 3600 + 59 * 60) == "23h 59m")
        #expect(age(2 * 86400 + 7 * 3600 + 30 * 60) == "2d 7h")
    }

    /// One entry each time the count reaches a whole minute, so the dimmed
    /// count steps when it should.
    @Test func entriesComeOnTheMinute() {
        let now = time.addingTimeInterval(125)
        let dates = ComplicationView.entryDates(from: time, now: now)
        #expect(dates.first == now)
        #expect(dates[1] == time.addingTimeInterval(180))
        #expect(dates[2] == time.addingTimeInterval(240))
        #expect(dates.last! < now.addingTimeInterval(ComplicationView.span))
        #expect(dates.count == 1 + Int(ComplicationView.span / 60))
        #expect(ComplicationView.entryDates(from: nil, now: now) == [now])
    }

    @Test func aSnapshotSurvivesSaving() {
        let defaults = suite()
        let snapshot = ComplicationSnapshot(
            reference: WatchEvent(time: time, precision: 22, label: "Start", color: .orange),
            latest: WatchEvent(time: time.addingTimeInterval(9), precision: -1, label: "Lap"),
            timeFormat: .local12Hour)
        snapshot.save(to: defaults)
        #expect(ComplicationSnapshot.load(from: defaults) == snapshot)
    }

    /// watchOS limits reloads, so one is only asked for when what it shows
    /// changes.
    @Test func onlyTheComplicationsThatChangeReload() {
        let defaults = suite()
        let start = WatchEvent(time: time, precision: -1, label: "Start")
        let lap = WatchEvent(time: time.addingTimeInterval(60), precision: -1, label: "Lap")
        let snapshot = ComplicationSnapshot(reference: start, latest: start, timeFormat: .local24Hour)
        #expect(snapshot.save(to: defaults) == [.reference, .latest])
        #expect(snapshot.save(to: defaults) == [])
        #expect(ComplicationSnapshot(reference: start, latest: lap, timeFormat: .local24Hour).save(to: defaults) == [.latest])
        #expect(ComplicationSnapshot(reference: start, latest: lap, timeFormat: .utc24Hour).save(to: defaults) == [.reference, .latest])
    }

    /// Saved by the build before there was a latest-event complication.
    @Test func anOlderSnapshotStillLoads() throws {
        let defaults = suite()
        let event = try WatchJSON.encoder.encode(WatchEvent(time: time, precision: -1, label: "Start"))
        let old = "{\"reference\":\(String(decoding: event, as: UTF8.self)),\"timeFormat\":1}"
        defaults.set(Data(old.utf8), forKey: "complicationSnapshot")
        let loaded = try #require(ComplicationSnapshot.load(from: defaults))
        #expect(loaded.reference?.label == "Start")
        #expect(loaded.latest == nil)
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
        #expect(ComplicationSnapshot.load(from: defaults)?.latest == lap)

        store.setReference(lap)
        Complications.update(store: store, settings: settings, defaults: defaults)
        #expect(ComplicationSnapshot.load(from: defaults)?.reference == lap)
    }
}
