import SwiftUI
import WidgetKit

/// The time since the reference event, on the watch face.
struct ReferenceComplication: EventComplication {
    static let source = ComplicationSource.reference
}

/// The time since the latest event, on the watch face.
struct LatestComplication: EventComplication {
    static let source = ComplicationSource.latest
}

/// The time since an event, on the watch face. A widget can't be given
/// which, so each event has its own.
protocol EventComplication: Widget {
    static var source: ComplicationSource { get }
}

extension EventComplication {
    private var source: ComplicationSource { Self.source }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: source.kind, provider: ComplicationProvider(source: source)) { entry in
            ComplicationEntryView(entry: entry, source: source)
        }
        .configurationDisplayName(displayName)
        .description(description)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }

    private var displayName: LocalizedStringKey {
        switch source {
        case .reference: "Since Reference"
        case .latest: "Since Last Event"
        }
    }

    private var description: LocalizedStringKey {
        switch source {
        case .reference: "The time since your reference event. Tap to open Timestamp."
        case .latest: "The time since your latest event. Tap to open Timestamp."
        }
    }

}

struct ComplicationEntry: TimelineEntry {
    var date: Date
    var snapshot: ComplicationSnapshot?
}

/// Bright, the count up runs by itself and one entry would do until the app
/// reloads with a new event. Dimmed, it's drawn from the entry's date, so
/// there's one each minute.
struct ComplicationProvider: TimelineProvider {
    typealias Entry = ComplicationEntry
    let source: ComplicationSource

    func placeholder(in context: Context) -> Entry {
        let start = WatchEvent(time: .now.addingTimeInterval(-312), precision: -1, label: "Start")
        let lap = WatchEvent(time: .now.addingTimeInterval(-47), precision: -1, label: "Lap")
        return Entry(date: .now, snapshot: ComplicationSnapshot(reference: start, latest: lap, timeFormat: .local24Hour))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // The gallery shows what it'll look like, even before any events.
        let saved = ComplicationSnapshot.load()
        let empty = source.event(in: saved) == nil
        completion(context.isPreview && empty ? placeholder(in: context) : Entry(date: .now, snapshot: saved))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let snapshot = ComplicationSnapshot.load()
        let dates = ComplicationView.entryDates(from: source.event(in: snapshot)?.time, now: .now)
        let entries = dates.map { Entry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: dates.count > 1 ? .atEnd : .never))
    }
}

private struct ComplicationEntryView: View {
    let entry: ComplicationEntry
    let source: ComplicationSource

    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        ComplicationView(
            family: family, snapshot: entry.snapshot, source: source,
            luminanceReduced: luminanceReduced, date: entry.date)
            .containerBackground(for: .widget) {}
    }
}
