import SwiftUI

/// Recorded events, newest first and grouped by day, as on the phone.
struct EventsView: View {
    @Environment(EventStore.self) private var store
    @Environment(WatchSettings.self) private var settings
    @AppStorage("showRelative") private var showRelative = false

    var body: some View {
        NavigationStack {
            Group {
                if store.events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "clock",
                        description: Text("Tap a button to record the time."))
                } else {
                    list
                }
            }
            .navigationTitle("Events")
        }
    }

    private var list: some View {
        List {
            Button {
                showRelative.toggle()
            } label: {
                Label(
                    showRelative ? "Relative" : "Absolute",
                    systemImage: showRelative ? "plusminus" : "clock")
            }

            ForEach(days, id: \.title) { day in
                Section(day.title) {
                    ForEach(day.events) { event in
                        EventRow(
                            event: event,
                            format: settings.timeFormat,
                            reference: showRelative ? store.reference : nil)
                    }
                    .onDelete { offsets in
                        store.delete(ids: Set(offsets.map { day.events[$0].id }))
                    }
                }
            }
        }
    }

    private var days: [(title: String, events: [WatchEvent])] {
        var days: [(title: String, events: [WatchEvent])] = []
        for event in store.events {
            let title = TimeFormatting.day(event.time, settings.timeFormat)
            if days.last?.title == title {
                days[days.count - 1].events.append(event)
            } else {
                days.append((title, [event]))
            }
        }
        return days
    }
}

private struct EventRow: View {
    let event: WatchEvent
    let format: TimeFormat
    /// Shows the time relative to this when set.
    let reference: WatchEvent?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.color.color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                if !event.label.isEmpty {
                    Text(event.label)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(time)
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var time: String {
        if let reference {
            return TimeFormatting.relative(event.time, to: reference.time)
        }
        return TimeFormatting.absolute(event.time, format)
    }
}
