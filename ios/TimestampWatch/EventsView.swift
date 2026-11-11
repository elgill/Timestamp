import SwiftUI

/// Recorded events, newest first and grouped by day, as on the phone.
struct EventsView: View {
    @Environment(EventStore.self) private var store
    @Environment(WatchSettings.self) private var settings
    @Environment(Recorder.self) private var recorder
    @AppStorage("showRelative") private var showRelative = false

    var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRelative.toggle()
                } label: {
                    Image(systemName: showRelative ? "plusminus" : "clock")
                }
                .accessibilityLabel(showRelative ? "Show clock times" : "Show relative times")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.title) { day in
                Section(day.title) {
                    ForEach(day.events) { event in
                        NavigationLink(value: event.id) {
                            EventRow(
                                event: event,
                                format: settings.timeFormat,
                                reference: showRelative ? store.reference : nil)
                        }
                        // Events from the phone are deleted on the phone.
                        .deleteDisabled(!store.canDelete(event))
                    }
                    .onDelete { offsets in
                        recorder.delete(Set(offsets.map { day.events[$0].id }))
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

/// One event in full, and deleting it when it was recorded here.
struct EventDetailView: View {
    let eventId: String

    @Environment(EventStore.self) private var store
    @Environment(WatchSettings.self) private var settings
    @Environment(Recorder.self) private var recorder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Looked up each time, so a delete from the phone shows here too.
        if let event = store.events.first(where: { $0.id == eventId }) {
            details(event)
        } else {
            ContentUnavailableView("Deleted", systemImage: "trash")
        }
    }

    private func details(_ event: WatchEvent) -> some View {
        let parts = TimeFormatting.parts(event.time, settings.timeFormat)
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(event.color.color)
                        .frame(width: 10, height: 10)
                    Text(event.label.isEmpty ? "Event" : event.label)
                        .font(.headline)
                        .lineLimit(2)
                }
                Text(parts.time)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(parts.suffix) · \(TimeFormatting.day(event.time, settings.timeFormat))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(details(of: event))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if store.canDelete(event) {
                    Button(role: .destructive) {
                        recorder.delete([event.id])
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .padding(.top, 6)
                } else {
                    Text("Delete it on the iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func details(of event: WatchEvent) -> String {
        let precision = event.precision >= 0 ? "±\(event.precision) ms" : "Precision unknown"
        let source = store.canDelete(event) ? "recorded on this watch" : "from iPhone"
        return "\(precision) · \(source)"
    }
}
