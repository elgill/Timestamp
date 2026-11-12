import SwiftUI
import WidgetKit

/// The complication faces, one per family: an event (the reference, or the
/// latest) and a count up from it, like a stopwatch since the Start. The
/// count runs on its own, so the complication only reloads when the event
/// changes. Tapping any of them opens the app.
///
/// Built in the watch app too, so tests can draw them.
struct ComplicationView: View {
    let family: WidgetFamily
    let snapshot: ComplicationSnapshot?
    var source: ComplicationSource = .reference
    /// Dimmed, for Always On, where the face updates about once a minute.
    var luminanceReduced = false
    /// When this is shown, for the dimmed count.
    var date = Date()

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner: corner
        default: circular
        }
    }

    private var reference: WatchEvent? { source.event(in: snapshot) }

    private var icon: String {
        switch source {
        case .reference: "stopwatch"
        case .latest: "clock.arrow.circlepath"
        }
    }

    /// Counts up from `time`. Dimmed, it's to the minute and set from the
    /// timeline, since the face then updates about once a minute and the
    /// seconds would stand still.
    private func count(_ time: Date) -> Text {
        luminanceReduced ? Text(Self.shortAge(of: time, at: date)) : Text(time, style: .timer)
    }

    /// How long since `time`, to the minute and short enough for any face:
    /// "0m", "47m", "1h 05m", "2d 7h".
    static func shortAge(of time: Date, at now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(time) / 60))
        let (days, hours, mins) = (minutes / 1440, minutes / 60 % 24, minutes % 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h " + String(format: "%02d", mins) + "m" }
        return "\(mins)m"
    }

    private var name: String {
        guard let reference else { return "Timestamp" }
        return reference.label.isEmpty ? "Event" : reference.label
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let reference {
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .widgetAccentable()
                    count(reference.time)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        // Room for "10:00:00" once it's been hours.
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 3)
                }
            } else {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(name, systemImage: icon)
                .font(.headline)
                .lineLimit(1)
                .widgetAccentable()
            // The two lines below the name share what height is left, so on
            // the smallest faces they shrink alike to fit.
            Group {
                if let reference {
                    Text(ComplicationView.clockTime(reference.time, snapshot?.timeFormat ?? .local24Hour))
                    // "+5:12", counting up.
                    Text("+\(count(reference.time))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No events yet")
                        .foregroundStyle(.secondary)
                    Text("Tap to record")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var inline: some View {
        Group {
            if let reference {
                // The count first, so a long name is what's cut short.
                Text("\(Image(systemName: icon)) +\(count(reference.time)) \(name)")
            } else {
                Text("\(Image(systemName: icon)) Timestamp")
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var corner: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .widgetAccentable()
            .widgetLabel {
                if let reference {
                    Text("+\(count(reference.time))")
                } else {
                    Text("Timestamp")
                }
            }
            .accessibilityLabel(accessibilityLabel)
    }

    /// The event's time of day, with what says which clock it's on but not
    /// the time zone, which wouldn't fit: "5:32:15.1 PM", "17:32:15.1 UTC".
    static func clockTime(_ time: Date, _ format: TimeFormat, timeZone: TimeZone = .current) -> String {
        let parts = TimeFormatting.parts(time, format, timeZone: timeZone)
        switch format {
        case .local12Hour: return "\(parts.time) \(parts.suffix.prefix(2))"
        case .utc24Hour: return "\(parts.time) UTC"
        case .local24Hour: return parts.time
        }
    }

    /// How far ahead the entries go before the timeline is asked for again.
    static let span: TimeInterval = 4 * 60 * 60

    /// Now, then each time the count reaches another whole minute, for the
    /// next `span`, for the dimmed count. Just now without an event.
    static func entryDates(from time: Date?, now: Date) -> [Date] {
        guard let time else { return [now] }
        let next = time.addingTimeInterval(((now.timeIntervalSince(time) / 60).rounded(.down) + 1) * 60)
        return [now] + stride(from: max(next, time), to: now.addingTimeInterval(span), by: 60)
    }

    private var accessibilityLabel: Text {
        guard let reference else { return Text("Timestamp, no events yet") }
        return Text("\(name), \(reference.time, style: .relative) ago")
    }
}
