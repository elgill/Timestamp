import SwiftUI
import WatchKit

/// Records and deletes events, telling the phone. Remembers the last
/// event recorded, which every record page confirms in its top bar.
@Observable
final class Recorder {
    private(set) var lastRecorded: WatchEvent?

    @ObservationIgnored private let store: EventStore
    @ObservationIgnored private let link: PhoneLink

    init(store: EventStore, link: PhoneLink) {
        self.store = store
        self.link = link
    }

    func record(_ config: RecordButtonConfig?, at reading: TimeReading) {
        let event = WatchEvent(
            time: reading.time,
            precision: reading.precision,
            label: config?.name ?? "",
            color: config?.color ?? .defaultColor)
        WKInterfaceDevice.current().play(.click)
        store.add(event)
        link.send(added: [event])
        lastRecorded = event
    }

    /// Deletes an event recorded on this watch. The phone's own events are
    /// deleted on the phone.
    func delete(_ ids: Set<String>) {
        link.send(deleted: store.delete(ids: ids))
    }
}

/// One page of record buttons, with the clock in the top bar.
struct RecordView: View {
    let page: ButtonPage
    let timeSource: TimeSource

    @Environment(WatchSettings.self) private var settings
    @Environment(Recorder.self) private var recorder

    private static let spacing: CGFloat = 4

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(Array(page.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Self.spacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, config in
                        RecordPad(
                            config: config,
                            timeSource: timeSource,
                            readsTimeOnTouchDown: settings.recordOnTouchDown
                        ) { reading in
                            recorder.record(config, at: reading)
                        }
                    }
                }
            }
        }
        // The buttons are the point of the screen; give them every bit.
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RecordHeader(timeSource: timeSource, recorder: recorder)
            }
        }
    }
}

/// The clock, or for a moment after recording, what was recorded. Tapping
/// the confirmation opens the event, which is how to undo it.
private struct RecordHeader: View {
    let timeSource: TimeSource
    let recorder: Recorder

    @Environment(WatchSettings.self) private var settings

    private static let confirmFor: TimeInterval = 2

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if let event = recorder.lastRecorded,
               context.date.timeIntervalSince(event.time) < Self.confirmFor {
                NavigationLink(value: event.id) { confirmation(event) }
                    .buttonStyle(.plain)
            } else {
                ClockView(timeSource: timeSource, format: settings.timeFormat)
            }
        }
    }

    private func confirmation(_ event: WatchEvent) -> some View {
        HStack(spacing: 4) {
            // A long label gives way; the time always shows.
            Text("✓ \(event.label.isEmpty ? "Recorded" : event.label)")
                .lineLimit(1)
                .truncationMode(.tail)
            Text(TimeFormatting.parts(event.time, settings.timeFormat).time)
                .monospacedDigit()
                .fixedSize()
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(.tint)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the event")
    }
}

/// One record button.
///
/// The event is saved when the finger lifts, so a touch that turns into a
/// swipe or a Crown turn changes page instead of recording. With
/// `readsTimeOnTouchDown` the event still gets the time the finger landed,
/// which is closer to the moment the user reacted to.
private struct RecordPad: View {
    let config: RecordButtonConfig?
    let timeSource: TimeSource
    let readsTimeOnTouchDown: Bool
    let record: (TimeReading) -> Void

    @State private var press = PressTime()

    var body: some View {
        Button {
            let reading = (readsTimeOnTouchDown ? press.reading() : nil) ?? timeSource.now()
            record(reading)
        } label: {
            face
        }
        .buttonStyle(RecordPadStyle(color: (config?.color ?? .defaultColor).color) { pressed in
            if pressed {
                // Read the time before doing anything else.
                press.down(timeSource.now())
            } else {
                press.up()
            }
        })
    }

    private var face: some View {
        Group {
            if let name = config?.name {
                Text(name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
            } else {
                Image(systemName: "arrow.down")
                    .font(.title2.weight(.semibold))
                    .accessibilityLabel("Record")
            }
        }
        .foregroundStyle(.white)
    }
}

/// When the finger landed on a button, for the button's action to use.
private final class PressTime {
    private var downReading: TimeReading?
    private var liftedAt: Date?

    /// How long after the finger lifts the action can still take the
    /// touch-down time. The action runs as the finger lifts; anything later
    /// (an accessibility action long after a cancelled press) gets its own.
    private static let window: TimeInterval = 0.5

    func down(_ reading: TimeReading) {
        downReading = reading
        liftedAt = nil
    }

    func up() {
        liftedAt = Date()
    }

    /// The touch-down time for the press that just ended, used once.
    func reading() -> TimeReading? {
        defer { downReading = nil }
        if let liftedAt, Date().timeIntervalSince(liftedAt) > Self.window { return nil }
        return downReading
    }
}

private struct RecordPadStyle: ButtonStyle {
    let color: Color
    let pressChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                color.opacity(configuration.isPressed ? 0.6 : 1),
                in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: configuration.isPressed) { _, pressed in
                pressChanged(pressed)
            }
    }
}
