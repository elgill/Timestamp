import Foundation

/// The phone's time formats (lib/utils/time_utils.dart), so a time reads the
/// same on both. Tenths are truncated, never rounded, as on the phone.
enum TimeFormatting {
    /// A time split into the digits and what follows them, so the watch can
    /// show the digits large: "2:03:22.4" and "PM EST".
    struct Parts: Equatable {
        var time: String
        var suffix: String
    }

    static func parts(_ date: Date, _ format: TimeFormat, timeZone: TimeZone = .current) -> Parts {
        let zone = format == .utc24Hour ? TimeZone(identifier: "UTC")! : timeZone

        let seconds = date.timeIntervalSince1970.rounded(.down)
        let tenths = min(9, Int(((date.timeIntervalSince1970 - seconds) * 10).rounded(.down)))
        // Whole seconds, so the calendar can't round up into the next second.
        let whole = Date(timeIntervalSince1970: seconds)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.hour, .minute, .second], from: whole)
        let hour = c.hour!, minute = two(c.minute!), second = two(c.second!)

        let zoneName = format == .utc24Hour ? "UTC" : zone.abbreviation(for: whole) ?? ""
        switch format {
        case .local12Hour:
            let hour12 = hour % 12 == 0 ? 12 : hour % 12
            return Parts(
                time: "\(hour12):\(minute):\(second).\(tenths)",
                suffix: "\(hour < 12 ? "AM" : "PM") \(zoneName)")
        case .local24Hour, .utc24Hour:
            return Parts(time: "\(two(hour)):\(minute):\(second).\(tenths)", suffix: zoneName)
        }
    }

    /// The whole time, as the phone shows it: "2:03:22.4 PM EST".
    static func absolute(_ date: Date, _ format: TimeFormat, timeZone: TimeZone = .current) -> String {
        let p = parts(date, format, timeZone: timeZone)
        return "\(p.time) \(p.suffix)"
    }

    /// How far `time` is from `reference`: "+00:01:05.3", "-1d 02:00:00.0".
    static func relative(_ time: Date, to reference: Date) -> String {
        let micros = Int64(((time.timeIntervalSince1970 - reference.timeIntervalSince1970) * 1_000_000).rounded())
        let sign = micros > 0 ? "+" : micros < 0 ? "-" : ""
        let millis = abs(micros) / 1000

        let totalSeconds = millis / 1000
        let totalDays = totalSeconds / 86_400
        let years = totalDays / 365
        let days = totalDays % 365
        let hours = (totalSeconds / 3600) % 24
        let minutes = (totalSeconds / 60) % 60
        let seconds = totalSeconds % 60
        let tenths = (millis % 1000) / 100

        var components: [String] = []
        if years > 0 { components.append("\(years)y") }
        if days > 0 { components.append("\(days)d") }
        components.append("\(two(Int(hours))):\(two(Int(minutes))):\(two(Int(seconds))).\(tenths)")
        return sign + components.joined(separator: " ")
    }

    /// The day heading for events: "Sun Nov 08, 2026".
    static func day(_ date: Date, _ format: TimeFormat, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = format == .utc24Hour ? TimeZone(identifier: "UTC")! : timeZone
        formatter.dateFormat = "EEE MMM dd, y"
        return formatter.string(from: date)
    }

    private static func two(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
