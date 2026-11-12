import SwiftUI
import WidgetKit

/// The time since the reference event, on the watch face.
struct ReferenceComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ComplicationSnapshot.kind, provider: Provider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Since Reference")
        .description("The time since your reference event. Tap to open Timestamp.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }

    struct Entry: TimelineEntry {
        var date: Date
        var snapshot: ComplicationSnapshot?
    }

    /// One entry, kept until the app reloads it with a new reference: the
    /// count up runs by itself.
    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry {
            Entry(date: .now, snapshot: ComplicationSnapshot(
                reference: WatchEvent(time: .now.addingTimeInterval(-312), precision: -1, label: "Start"),
                timeFormat: .local24Hour))
        }

        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
            // The gallery shows what it'll look like, even before any events.
            let saved = ComplicationSnapshot.load()
            completion(context.isPreview && saved?.reference == nil ? placeholder(in: context) : Entry(date: .now, snapshot: saved))
        }

        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [Entry(date: .now, snapshot: ComplicationSnapshot.load())], policy: .never))
        }
    }
}

private struct ComplicationEntryView: View {
    let entry: ReferenceComplication.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        ComplicationView(family: family, snapshot: entry.snapshot)
            .containerBackground(for: .widget) {}
    }
}
