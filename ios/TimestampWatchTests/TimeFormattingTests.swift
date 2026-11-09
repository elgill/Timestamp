import Foundation
import Testing
@testable import TimestampWatch

/// Expected strings are what lib/utils/time_utils.dart gives for the same
/// time, so the watch and phone agree.
struct TimeFormattingTests {
    let newYork = TimeZone(identifier: "America/New_York")!

    /// Sun Nov 08 2026, 14:03:22.47 in New York (19:03:22.47 UTC).
    let afternoon = Date(timeIntervalSince1970: 1_794_164_602.47)

    @Test func local24Hour() {
        #expect(TimeFormatting.parts(afternoon, .local24Hour, timeZone: newYork)
            == .init(time: "14:03:22.4", suffix: "EST"))
        #expect(TimeFormatting.absolute(afternoon, .local24Hour, timeZone: newYork)
            == "14:03:22.4 EST")
    }

    @Test func local12Hour() {
        #expect(TimeFormatting.absolute(afternoon, .local12Hour, timeZone: newYork)
            == "2:03:22.4 PM EST")
    }

    @Test func midnightIsTwelveAM() {
        let midnight = Date(timeIntervalSince1970: 1_794_114_000) // 00:00 EST
        #expect(TimeFormatting.absolute(midnight, .local12Hour, timeZone: newYork)
            == "12:00:00.0 AM EST")
    }

    @Test func utcIgnoresTheLocalZone() {
        #expect(TimeFormatting.absolute(afternoon, .utc24Hour, timeZone: newYork)
            == "19:03:22.4 UTC")
    }

    @Test func tenthsAreTruncatedNotRounded() {
        let almost = Date(timeIntervalSince1970: 1_794_164_602.999)
        #expect(TimeFormatting.parts(almost, .local24Hour, timeZone: newYork).time
            == "14:03:22.9")
    }

    @Test func timesBeforeNineteenSeventy() {
        let before = Date(timeIntervalSince1970: -0.25)
        #expect(TimeFormatting.absolute(before, .utc24Hour) == "23:59:59.7 UTC")
    }

    @Test func relativeAfter() {
        let later = afternoon.addingTimeInterval(65.36)
        #expect(TimeFormatting.relative(later, to: afternoon) == "+00:01:05.3")
    }

    @Test func relativeBefore() {
        let earlier = afternoon.addingTimeInterval(-3.05)
        #expect(TimeFormatting.relative(earlier, to: afternoon) == "-00:00:03.0")
    }

    @Test func relativeSameTimeHasNoSign() {
        #expect(TimeFormatting.relative(afternoon, to: afternoon) == "00:00:00.0")
    }

    @Test func relativeDaysAndYears() {
        let later = afternoon.addingTimeInterval(367 * 86_400 + 3 * 3600)
        #expect(TimeFormatting.relative(later, to: afternoon) == "+1y 2d 03:00:00.0")
    }

    @Test func dayHeading() {
        #expect(TimeFormatting.day(afternoon, .local24Hour, timeZone: newYork)
            == "Sun Nov 08, 2026")
    }

    @Test func dayHeadingInUTC() {
        let lateEvening = Date(timeIntervalSince1970: 1_794_193_200) // 22:00 EST
        #expect(TimeFormatting.day(lateEvening, .local24Hour, timeZone: newYork)
            == "Sun Nov 08, 2026")
        #expect(TimeFormatting.day(lateEvening, .utc24Hour, timeZone: newYork)
            == "Mon Nov 09, 2026")
    }
}
