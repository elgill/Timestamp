import SwiftUI

/// The current time to the tenth of a second. When the wrist is down the
/// screen only updates once a minute, so it drops to hours and minutes.
struct ClockView: View {
    let timeSource: TimeSource
    let format: TimeFormat

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        TimelineView(schedule) { _ in
            let parts = TimeFormatting.parts(timeSource.now().time, format)
            VStack(spacing: 0) {
                Text(isLuminanceReduced ? String(parts.time.dropLast(5)) : parts.time)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(parts.suffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var schedule: PeriodicTimelineSchedule {
        if isLuminanceReduced {
            let minute = (Date().timeIntervalSince1970 / 60).rounded(.down) * 60
            return .periodic(from: Date(timeIntervalSince1970: minute), by: 60)
        }
        return .periodic(from: .now, by: 0.1)
    }
}
