import SwiftUI
import UniformTypeIdentifiers

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Title
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("PDFCHCK")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("PDF Forgery Detection")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Drop zones
            HStack(spacing: DesignSystem.Spacing.lg) {
                DropZoneView(
                    label: "Original PDF",
                    fileName: viewModel.droppedFiles.originalFileName,
                    onTap: viewModel.selectOriginalFile,
                    onFileDrop: { url in
                        viewModel.droppedFiles.originalURL = url
                    }
                )

                // Swap button
                if viewModel.droppedFiles.bothFilesSelected {
                    Button(action: viewModel.swapFiles) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                DropZoneView(
                    label: "Comparison PDF",
                    fileName: viewModel.droppedFiles.comparisonFileName,
                    onTap: viewModel.selectComparisonFile,
                    onFileDrop: { url in
                        viewModel.droppedFiles.comparisonURL = url
                    }
                )
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, DesignSystem.Spacing.xxl)

            // Action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.droppedFiles.originalURL != nil || viewModel.droppedFiles.comparisonURL != nil {
                    SecondaryButton(title: "Clear", action: viewModel.clearFiles)
                }

                PrimaryButton(
                    title: "Start Analysis",
                    action: viewModel.startAnalysis,
                    isEnabled: viewModel.canStartAnalysis
                )
            }

            Spacer()

            // Footer
            Text("Drop two PDF files to compare and detect potential forgery")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}


