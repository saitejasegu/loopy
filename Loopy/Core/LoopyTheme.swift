import SwiftUI

enum LoopyTheme {
    static let coral = Color(red: 1, green: 107 / 255, blue: 74 / 255)
    static let green = Color(red: 76 / 255, green: 195 / 255, blue: 138 / 255)

    static let background = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 18 / 255, blue: 16 / 255, alpha: 1)
                : UIColor(red: 244 / 255, green: 240 / 255, blue: 232 / 255, alpha: 1)
        }
    )

    static let card = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 33 / 255, green: 30 / 255, blue: 27 / 255, alpha: 1)
                : .white
        }
    )

    static let secondaryText = Color(
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 156 / 255, green: 148 / 255, blue: 136 / 255, alpha: 1)
                : UIColor(red: 138 / 255, green: 131 / 255, blue: 120 / 255, alpha: 1)
        }
    )
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch cleaned.count {
        case 3:
            red = (value >> 8) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
        default:
            red = value >> 16
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        }

        self.init(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

extension View {
    func loopyCard() -> some View {
        self
            .background(LoopyTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.06))
            }
    }
}

