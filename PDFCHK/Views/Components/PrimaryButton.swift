import SwiftUI

// MARK: - Primary Button
// Uses accent blue per CLAUDE.md rules
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .frame(minWidth: 120)
                .background(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.border)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .frame(minWidth: 100)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Border.radius)
                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(isEnabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Border.width)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
