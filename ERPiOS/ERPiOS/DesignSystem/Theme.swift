import SwiftUI

enum ERPTheme {
    static let brand = Color(red: 0.14, green: 0.40, blue: 0.92)
    static let brandDeep = Color(red: 0.09, green: 0.26, blue: 0.64)
    static let accent = Color(red: 0.46, green: 0.34, blue: 0.92)

    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    static let success = Color(red: 0.12, green: 0.66, blue: 0.38)
    static let warning = Color(red: 0.95, green: 0.60, blue: 0.10)
    static let danger = Color(red: 0.90, green: 0.27, blue: 0.28)
    static let info = Color(red: 0.16, green: 0.48, blue: 0.94)
    static let neutral = Color(red: 0.52, green: 0.56, blue: 0.62)
    static let purple = Color(red: 0.52, green: 0.38, blue: 0.92)

    static let cardRadius: CGFloat = 16
    static let tileRadius: CGFloat = 12
    static let pagePadding: CGFloat = 16

    static func tone(_ tone: StatusTone) -> Color {
        switch tone {
        case .neutral: return neutral
        case .info: return info
        case .warning: return warning
        case .success: return success
        case .danger: return danger
        case .accent: return purple
        }
    }

    static func gradient(_ tone: StatusTone) -> LinearGradient {
        let c = self.tone(tone)
        return LinearGradient(colors: [c, c.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
