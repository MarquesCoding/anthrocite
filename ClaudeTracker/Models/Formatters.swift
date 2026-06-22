import Foundation

enum Fmt {
    /// 1234 -> "1.2K", 3_400_000 -> "3.4M", 20_000_000_000 -> "20.0B".
    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        switch n {
        case 1_000_000_000...: return String(format: "%.1fB", v / 1_000_000_000)
        case 1_000_000...:     return String(format: "%.1fM", v / 1_000_000)
        case 1_000...:         return String(format: "%.1fK", v / 1_000)
        default:               return "\(n)"
        }
    }

    static func usd(_ amount: Double) -> String {
        if amount > 0 && amount < 0.01 { return "<$0.01" }
        return String(format: "$%.2f", amount)
    }

    /// Time remaining until `date`, e.g. "2h 13m" or "4d 6h" or "now".
    static func countdown(to date: Date, now: Date = Date()) -> String {
        let secs = Int(date.timeIntervalSince(now))
        if secs <= 0 { return "now" }
        let d = secs / 86_400
        let h = (secs % 86_400) / 3_600
        let m = (secs % 3_600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func resetClock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f.string(from: date)
    }
}
