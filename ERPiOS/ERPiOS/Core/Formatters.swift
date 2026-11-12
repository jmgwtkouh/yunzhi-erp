import Foundation

enum ERPFormat {
    private static let decimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f
    }()

    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f
    }()

    static func money(_ value: Double) -> String {
        "¥" + (decimal.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value))
    }

    static func compactMoney(_ value: Double) -> String {
        if value >= 100_000_000 { return String(format: "%.2f亿", value / 100_000_000) }
        if value >= 10_000 { return String(format: "%.1f万", value / 10_000) }
        return String(format: "%.0f", value)
    }

    static func number(_ value: Int) -> String {
        integer.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    static func signedPercent(_ value: Double) -> String {
        String(format: "%+.1f%%", value * 100)
    }

    static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
