import SwiftUI

// MARK: - Results View
// VSplitView: Top is ComparisonView, Bottom is ResultsPanel
struct ResultsView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var topHeight: CGFloat = 400

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Toolbar
                ResultsToolbar()
                    .environmentObject(viewModel)

                // Split view content
                VSplitView {
                    // Top: PDF Comparison
                    if let report = viewModel.report {
                        ComparisonView(
                            originalAnalysis: viewModel.originalAnalysis,
                            comparisonAnalysis: viewModel.comparisonAnalysis,
                            imageComparison: viewModel.imageComparison
                        )
                        .frame(minHeight: 200)
                    }

                    // Bottom: Results Panel
                    if let report = viewModel.report {
                        ResultsPanel(
                            report: report,
                            originalAnalysis: viewModel.originalAnalysis,
                            comparisonAnalysis: viewModel.comparisonAnalysis
                        )
                        .frame(minHeight: 200)
                    }
                }
            }
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Results Toolbar
struct ResultsToolbar: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // New comparison button
            SecondaryButton(title: "New Comparison", action: viewModel.reset)

            Spacer()

            // Risk indicator (compact)
            if let report = viewModel.report {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Risk:")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(report.riskLevel.rawValue)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("(\(Int(report.riskScore)))")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(DesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider()
                .frame(height: 20)

            // Export buttons
            Menu {
                Button("Export as JSON") {
                    viewModel.exportReportAsJSON()
                }
                Button("Export as PDF") {
                    viewModel.exportReportAsPDF()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Export")
                        .font(DesignSystem.Typography.body)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Border.radius))
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }
}

// MARK: - Resizable Split View
// Custom VSplitView that works with SwiftUI
struct VSplitView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Use HSplitView rotated for vertical split, or native VSplitView
        // Since we're on macOS, we can use the native split view
        content()
    }
}

