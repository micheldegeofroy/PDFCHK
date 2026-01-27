import SwiftUI

// MARK: - Analysis Progress View
struct AnalysisProgressView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Title
            Text("Analyzing Documents")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Current stage
            Text(viewModel.analysisProgress.description)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            // Progress bar
            VStack(spacing: DesignSystem.Spacing.sm) {
                ProgressBar(progress: viewModel.analysisProgress.overallProgress)
                    .frame(width: 400, height: 8)

                Text("\(Int(viewModel.analysisProgress.overallProgress * 100))%")
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Stage indicators
            StageIndicatorsView(currentStage: viewModel.analysisProgress.stage)
                .padding(.top, DesignSystem.Spacing.md)

            Spacer()

            // Cancel button
            SecondaryButton(title: "Cancel", action: viewModel.cancelAnalysis)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Progress Bar
// Uses accent blue per CLAUDE.md rules
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.border)

                // Fill - uses accent blue
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: geometry.size.width * CGFloat(min(1, max(0, progress))))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
    }
}

// MARK: - Stage Indicators View
struct StageIndicatorsView: View {
    let currentStage: AnalysisStage

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            ForEach(AnalysisStage.allCases, id: \.self) { stage in
                StageIndicator(
                    stage: stage,
                    isCompleted: stage.index < currentStage.index,
                    isCurrent: stage == currentStage
                )
            }
        }
    }
}

// MARK: - Stage Indicator
struct StageIndicator: View {
    let stage: AnalysisStage
    let isCompleted: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(fillColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )

            Text(stageName)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(isCurrent ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
        }
    }

    private var fillColor: Color {
        if isCompleted {
            return DesignSystem.Colors.accent
        } else if isCurrent {
            return DesignSystem.Colors.accent.opacity(0.5)
        } else {
            return DesignSystem.Colors.background
        }
    }

    private var stageName: String {
        switch stage {
        case .loading: return "Load"
        case .metadata: return "Meta"
        case .text: return "Text"
        case .visual: return "Visual"
        case .structure: return "Struct"
        case .images: return "Images"
        case .security: return "Security"
        case .forensics: return "Forensic"
        }
    }
}

