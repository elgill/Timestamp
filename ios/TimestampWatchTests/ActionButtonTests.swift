import Foundation
import Testing
@testable import TimestampWatch

/// The time an Action button press is recorded at.
@MainActor
struct ActionButtonTests {
    let synced = Date(timeIntervalSince1970: 1_794_164_400)
    var accuracy: PhoneAccuracy { PhoneAccuracy(precision: 22, syncedAt: synced) }

    @Test func thePressIsRecordedWhenItHappened() {
        let pressed = synced.addingTimeInterval(60)
        let now = TimeReading(time: pressed.addingTimeInterval(0.8), precision: 22)
        let reading = ActionButton.reading(pressedAt: pressed, now: now, accuracy: accuracy)
        #expect(reading.time == pressed)
        #expect(reading.precision == 22)
    }

    @Test func aPressAfterTheSyncGrewOldHasUnknownPrecision() {
        let pressed = synced.addingTimeInterval(WatchClock.maxAge + 1)
        let reading = ActionButton.reading(pressedAt: pressed, now: TimeReading(time: pressed, precision: 22), accuracy: accuracy)
        #expect(reading.precision == -1)
    }

    /// Without the system's timestamp, nothing says how long ago the press was.
    @Test func withoutTheTimestampItIsNowWithUnknownPrecision() {
        let now = TimeReading(time: synced.addingTimeInterval(60), precision: 22)
        let reading = ActionButton.reading(pressedAt: nil, now: now, accuracy: accuracy)
        #expect(reading.time == now.time)
        #expect(reading.precision == -1)
    }
}
