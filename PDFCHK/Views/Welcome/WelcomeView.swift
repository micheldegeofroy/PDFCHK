import SwiftUI
import UniformTypeIdentifiers

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Logo and Title
            VStack(spacing: DesignSystem.Spacing.sm) {
                if let logoImage = loadLogoImage() {
                    Image(nsImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                }

                Text("PDF Forensic Tool")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Drop zones
            HStack(spacing: DesignSystem.Spacing.lg) {
                DropZoneView(
                    label: "First PDF",
                    fileName: viewModel.droppedFiles.originalFileName,
                    onTap: viewModel.selectOriginalFile,
                    onFileDrop: { url in
                        viewModel.droppedFiles.originalURL = url
                    }
                )

                // Swap button - only when both files selected
                if viewModel.droppedFiles.bothFilesSelected {
                    Button(action: viewModel.swapFiles) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                DropZoneView(
                    label: "Add second PDF for comparison",
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
                // Cancel button - show when any file is loaded
                if viewModel.droppedFiles.originalURL != nil || viewModel.droppedFiles.comparisonURL != nil {
                    SecondaryButton(title: "Cancel", action: viewModel.clearFiles)
                }

                // Single PDF analysis
                if viewModel.droppedFiles.originalURL != nil && viewModel.droppedFiles.comparisonURL == nil {
                    PrimaryButton(
                        title: "Analyze",
                        action: viewModel.startSingleAnalysis,
                        isEnabled: true
                    )
                }

                // Comparative analysis - both files loaded
                if viewModel.droppedFiles.bothFilesSelected {
                    PrimaryButton(
                        title: "Start Comparative Analysis",
                        action: viewModel.startAnalysis,
                        isEnabled: true
                    )
                }
            }

            Spacer()

            // Footer
            Text("Drop a PDF to analyze, or two PDFs for comparative analysis")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Logo Helper
private func loadLogoImage() -> NSImage? {
    // Try loading PNG directly from bundle
    if let url = Bundle.module.url(forResource: "logo", withExtension: "png") {
        return NSImage(contentsOf: url)
    }

    // Try loading from asset catalog
    if let image = Bundle.module.image(forResource: "AppLogo") {
        return image
    }

    // Fallback: try NSImage named
    return NSImage(named: "AppLogo")
}

