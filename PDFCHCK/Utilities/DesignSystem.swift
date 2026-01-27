import SwiftUI

// MARK: - Design System
// Follows CLAUDE.md design rules strictly

enum DesignSystem {

    // MARK: - Colors
    enum Colors {
        // Backgrounds - WHITE ONLY
        static let background = Color.white  // #FFFFFF
        static let panelBackground = Color.white
        static let cardBackground = Color.white
        static let inputBackground = Color.white

        // Text
        static let textPrimary = Color(hex: "111827")  // Dark grey
        static let textSecondary = Color(hex: "6B7280")  // Medium grey

        // Borders
        static let border = Color(hex: "E5E7EB")  // Light grey, 1px only

        // Accent - ONLY for buttons, progress bars, sliders
        static let accent = Color(hex: "2563EB")  // Blue

        // Risk levels (for text/badges only, not backgrounds)
        static let riskHigh = Color(hex: "111827")  // Use dark text, not red
        static let riskMedium = Color(hex: "6B7280")
        static let riskLow = Color(hex: "6B7280")
    }

    // MARK: - Typography
    enum Typography {
        static let fontFamily = "Helvetica Neue"
        static let fallbackFamily = "Arial"

        // Body text: 14px
        static let bodySize: CGFloat = 14
        // Labels: 13-14px
        static let labelSize: CGFloat = 13
        // Section headers: 12-13px, weight 600
        static let sectionHeaderSize: CGFloat = 13

        static var body: Font {
            .system(size: bodySize)
        }

        static var label: Font {
            .system(size: labelSize)
        }

        static var sectionHeader: Font {
            .system(size: sectionHeaderSize, weight: .semibold)
        }

        static var title: Font {
            .system(size: 18, weight: .semibold)
        }

        static var largeTitle: Font {
            .system(size: 24, weight: .semibold)
        }

        static var caption: Font {
            .system(size: 11)
        }
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Border
    enum Border {
        static let width: CGFloat = 1
        static let radius: CGFloat = 6
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
extension View {
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }

    func panelStyle() -> some View {
        self
            .background(DesignSystem.Colors.panelBackground)
    }
}
