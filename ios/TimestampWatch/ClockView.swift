import SwiftUI

/// The current time to the tenth of a second, sized for the top bar, or
/// with a `reference` the time since it, running like a stopwatch. When the
/// wrist is down the screen only updates once a minute, so it drops to
/// hours and minutes.
struct ClockView: View {
    let timeSource: TimeSource
    let format: TimeFormat
    /// Shows the time since this instead of the time of day.
    var reference: Date? = nil

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(schedule) { _ in
            let (time, label) = text(timeSource.now().time)
            // Both end in ":ss.t", which a once-a-minute screen can't keep up.
            Text(isLuminanceReduced ? String(time.dropLast(5)) : time)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel(label)
        }
    }

    private func text(_ now: Date) -> (time: String, label: String) {
        if let reference {
            let time = TimeFormatting.relative(now, to: reference)
            return (time, "\(time) since the reference event")
        }
        let parts = TimeFormatting.parts(now, format)
        return (parts.time, "\(parts.time) \(parts.suffix)")
    }

    private var schedule: PeriodicTimelineSchedule {
        if isLuminanceReduced {
            // On the minute: of the clock, or of the time since the reference.
            let start = reference ?? Date(timeIntervalSince1970: 0)
            let elapsed = Date().timeIntervalSince(start)
            let minute = (elapsed / 60).rounded(.down) * 60
            return .periodic(from: start.addingTimeInterval(minute), by: 60)
        }
        return .periodic(from: .now, by: 0.1)
    }
}
