import Flutter
import UIKit
import XCTest
@testable import Runner

/// Events recorded on the phone by the Record Event intent.
class PhoneRecorderTests: XCTestCase {
  let time = Date(timeIntervalSince1970: 1_794_164_400.5)

  func testCorrectsByTheTimeServerOffset() {
    let event = PhoneRecorder.event(nil, at: time, offsetMillis: -250)
    XCTAssertEqual(event.time, time.addingTimeInterval(-0.25))
  }

  func testWithoutAnOffsetKeepsTheClockTime() {
    XCTAssertEqual(PhoneRecorder.event(nil, at: time, offsetMillis: nil).time, time)
  }

  /// The delay before the intent ran is unknown.
  func testPrecisionIsUnknown() {
    XCTAssertEqual(PhoneRecorder.event(nil, at: time, offsetMillis: 0).precision, -1)
  }

  func testTakesTheButtonsNameAndColor() {
    let event = PhoneRecorder.event(RecordButtonConfig(name: "Lap", color: .orange), at: time, offsetMillis: 0)
    XCTAssertEqual(event.label, "Lap")
    XCTAssertEqual(event.color, .orange)
  }

  func testUnnamedIsTheDefaultButton() {
    let event = PhoneRecorder.event(nil, at: time, offsetMillis: 0)
    XCTAssertEqual(event.label, "")
    XCTAssertEqual(event.color, .defaultColor)
  }

  /// In the phone's style, as lib/models/event.dart makes them.
  func testIdsAreLowercase() {
    let id = PhoneRecorder.event(nil, at: time, offsetMillis: 0).id
    XCTAssertEqual(id, id.lowercased())
  }
}
