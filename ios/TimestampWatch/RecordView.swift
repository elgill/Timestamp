import SwiftUI
import WatchKit

/// The clock and the record buttons.
struct RecordView: View {
    let timeSource: TimeSource
    let link: PhoneLink

    @Environment(EventStore.self) private var store
    @Environment(WatchSettings.self) private var settings
    @State private var lastRecorded: WatchEvent?

    private static let spacing: CGFloat = 4
    /// Below this the buttons scroll instead of shrinking further.
    private static let minButtonHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: Self.spacing) {
            ClockView(timeSource: timeSource, format: settings.timeFormat)
            GeometryReader { geometry in
                buttons(height: geometry.size.height)
            }
            // The buttons are the point of the screen; give them every bit.
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .bottom) {
            if let lastRecorded {
                ConfirmationBanner(event: lastRecorded, format: settings.timeFormat)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: lastRecorded?.id) {
            guard lastRecorded != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { lastRecorded = nil }
        }
    }

    /// With no buttons set up there is one unnamed button, as on the phone.
    private var configs: [RecordButtonConfig?] {
        settings.buttons.isEmpty ? [nil] : settings.buttons
    }

    @ViewBuilder
    private func buttons(height: CGFloat) -> some View {
        let count = CGFloat(configs.count)
        let fitted = (height - Self.spacing * (count - 1)) / count
        if fitted >= Self.minButtonHeight {
            VStack(spacing: Self.spacing) {
                ForEach(Array(configs.enumerated()), id: \.offset) { _, config in
                    pad(config, onTouchDown: settings.recordOnTouchDown)
                }
            }
        } else {
            ScrollView {
                VStack(spacing: Self.spacing) {
                    ForEach(Array(configs.enumerated()), id: \.offset) { _, config in
                        // A drag that starts on a button has to scroll, not
                        // record, so these record when the finger lifts.
                        pad(config, onTouchDown: false)
                            .frame(height: Self.minButtonHeight + 4)
                    }
                }
            }
        }
    }

    private func pad(_ config: RecordButtonConfig?, onTouchDown: Bool) -> some View {
        RecordPad(
            label: config?.name,
            color: (config?.color ?? .defaultColor).color,
            recordsOnTouchDown: onTouchDown
        ) {
            record(config)
        }
    }

    private func record(_ config: RecordButtonConfig?) {
        // Read the time before doing anything else.
        let reading = timeSource.now()
        let event = WatchEvent(
            time: reading.time,
            precision: reading.precision,
            label: config?.name ?? "",
            color: config?.color ?? .defaultColor)
        WKInterfaceDevice.current().play(.click)
        store.add(event)
        link.send(added: [event])
        withAnimation { lastRecorded = event }
    }
}

/// One record button.
private struct RecordPad: View {
    let label: String?
    let color: Color
    let recordsOnTouchDown: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        if recordsOnTouchDown {
            face
                .contentShape(shape)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressed else { return }
                            isPressed = true
                            action()
                        }
                        .onEnded { _ in isPressed = false }
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { action() }
        } else {
            Button(action: action) { face }
                .buttonStyle(.plain)
        }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12) }

    private var face: some View {
        Group {
            if let label {
                Text(label)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(isPressed ? 0.6 : 1), in: shape)
    }
}

/// Briefly confirms what was just recorded.
private struct ConfirmationBanner: View {
    let event: WatchEvent
    let format: TimeFormat

    var body: some View {
        let time = TimeFormatting.parts(event.time, format).time
        Text(event.label.isEmpty ? time : "\(event.label) · \(time)")
            .font(.footnote.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .padding(.bottom, 4)
            .allowsHitTesting(false)
    }
}
