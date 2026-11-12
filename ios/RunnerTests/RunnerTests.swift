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

/// What the phone compares to decide whether the watch's complications need
/// the context sent the fast way, which is limited to 50 a day.
class ComplicationContextTests: XCTestCase {
  func context(reference: String = "a", timeFormat: Int = 1, extra: String = "") -> String {
    """
    {"buttons": [{"name": "Lap", "color": 2}], "timeFormat": \(timeFormat), "importedIds": ["x"\(extra)],
     "events": [{"id": "b", "time": 1794164600000, "precision": -1, "description": "", "color": 0},
                {"id": "a", "time": 1794164500000, "precision": -1, "description": "", "color": 0}],
     "reference": {"id": "\(reference)", "time": 1794164500000, "precision": -1, "description": "", "color": 0}}
    """
  }

  func testOnlyWhatTheComplicationsShowCounts() {
    let shown = WatchBridge.complicationsShow(context())
    XCTAssertNotNil(shown)
    // The same every time, or every context would look like a change.
    for _ in 0..<20 {
      XCTAssertEqual(WatchBridge.complicationsShow(context()), shown)
    }
    // Buttons and imported ids aren't shown.
    XCTAssertEqual(WatchBridge.complicationsShow(context(extra: ", \"y\"")), shown)
    XCTAssertNotEqual(WatchBridge.complicationsShow(context(reference: "b")), shown)
    XCTAssertNotEqual(WatchBridge.complicationsShow(context(timeFormat: 2)), shown)
  }

  func testTheLatestEventCounts() {
    let more = context().replacingOccurrences(
      of: "\"events\": [", with: "\"events\": [{\"id\": \"c\", \"time\": 1794164700000, \"precision\": -1, \"description\": \"\", \"color\": 0}, ")
    XCTAssertNotEqual(WatchBridge.complicationsShow(more), WatchBridge.complicationsShow(context()))
  }

  func testAnUnreadableContextIsNotSent() {
    XCTAssertNil(WatchBridge.complicationsShow("not json"))
  }
}
