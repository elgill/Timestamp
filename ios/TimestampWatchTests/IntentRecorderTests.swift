import Foundation
import Testing
@testable import TimestampWatch

/// The time an event from Shortcuts, Siri or the Action button is recorded at.
@MainActor
struct IntentRecorderTests {
    let synced = Date(timeIntervalSince1970: 1_794_164_400)
    var accuracy: PhoneAccuracy { PhoneAccuracy(precision: 22, syncedAt: synced) }

    @Test func thePressIsRecordedWhenItHappened() {
        let pressed = synced.addingTimeInterval(60)
        let reading = IntentRecorder.reading(pressedAt: pressed, now: pressed.addingTimeInterval(0.8), accuracy: accuracy)
        #expect(reading.time == pressed)
        #expect(reading.precision == 22)
    }

    @Test func aPressAfterTheSyncGrewOldHasUnknownPrecision() {
        let pressed = synced.addingTimeInterval(WatchClock.maxAge + 1)
        let reading = IntentRecorder.reading(pressedAt: pressed, now: pressed, accuracy: accuracy)
        #expect(reading.precision == -1)
    }

    /// Without the system's timestamp, nothing says how long ago the press was.
    @Test func withoutTheTimestampItIsNowWithUnknownPrecision() {
        let now = synced.addingTimeInterval(60)
        let reading = IntentRecorder.reading(pressedAt: nil, now: now, accuracy: accuracy)
        #expect(reading.time == now)
        #expect(reading.precision == -1)
    }
}
