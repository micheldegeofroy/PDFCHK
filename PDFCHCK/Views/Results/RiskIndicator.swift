import SwiftUI

// MARK: - Risk Indicator
struct RiskIndicator: View {
    let riskLevel: RiskLevel
    let score: Double

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Risk level text
            Text(riskLevel.rawValue.uppercased())
                .font(DesignSystem.Typography.sectionHeader)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Score
            Text("\(Int(score))")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Risk Score")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}

// MARK: - Similarity Bar
// Uses accent blue for the fill per CLAUDE.md rules
struct SimilarityBar: View {
    let label: String
    let value: Double  // 0.0 to 1.0
    let showPercentage: Bool

    init(label: String, value: Double, showPercentage: Bool = true) {
        self.label = label
        self.value = value
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if showPercentage {
                    Text(String(format: "%.1f%%", value * 100))
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignSystem.Colors.border)

                    // Fill - uses accent blue
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: geometry.size.width * CGFloat(min(1, max(0, value))))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?

    init(title: String, value: String, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text(value)
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if let sub = subtitle {
                Text(sub)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
    }
}
