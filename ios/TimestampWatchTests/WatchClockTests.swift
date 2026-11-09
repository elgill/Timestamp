import Foundation
import Testing
@testable import TimestampWatch

/// The precision the watch's events get: the phone's, while it's recent.
struct WatchClockTests {
    let synced = Date(timeIntervalSince1970: 1_794_164_400)

    func accuracy(_ precision: Int = 22) -> PhoneAccuracy {
        PhoneAccuracy(precision: precision, syncedAt: synced)
    }

    @Test func withoutThePhonesAccuracyItIsUnknown() {
        #expect(WatchClock.precision(nil, at: synced) == -1)
    }

    @Test func itIsThePhonesWhileRecent() {
        #expect(WatchClock.precision(accuracy(), at: synced.addingTimeInterval(60)) == 22)
        #expect(WatchClock.precision(accuracy(), at: synced.addingTimeInterval(WatchClock.maxAge)) == 22)
    }

    @Test func anOldSyncNoLongerCounts() {
        #expect(WatchClock.precision(accuracy(), at: synced.addingTimeInterval(WatchClock.maxAge + 1)) == -1)
    }

    @Test func aSyncFromTheFutureDoesNotCount() {
        #expect(WatchClock.precision(accuracy(), at: synced.addingTimeInterval(-3600)) == -1)
    }

    @Test func theClockIsTheWatchsOwn() {
        let settings = WatchSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        settings.phoneAccuracy = PhoneAccuracy(precision: 30, syncedAt: Date())
        let before = Date()
        let reading = WatchClock(settings: settings).now()
        #expect(reading.time >= before && reading.time <= Date())
        #expect(reading.precision == 30)
    }

    @Test func theAccuracyIsKeptAcrossALaunch() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        WatchSettings(defaults: defaults).phoneAccuracy = accuracy(40)
        #expect(WatchSettings(defaults: defaults).phoneAccuracy == accuracy(40))
    }
}
