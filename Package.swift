// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PDFCHCK",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PDFCHCK", targets: ["PDFCHCK"])
    ],
    targets: [
        .executableTarget(
            name: "PDFCHCK",
            path: "PDFCHCK",
            sources: [
                "App/PDFCHCKApp.swift",
                "App/AppState.swift",
                "Models/Finding.swift",
                "Models/PDFAnalysis.swift",
                "Models/TextComparisonResult.swift",
                "Models/ImageComparisonResult.swift",
                "Models/MetadataComparison.swift",
                "Models/DetectionReport.swift",
                "Models/ExternalToolModels.swift",
                "Models/TamperingAnalysis.swift",
                "Services/PDFAnalyzer.swift",
                "Services/ExternalToolsService.swift",
                "Services/MetadataAnalyzer.swift",
                "Services/SSIMCalculator.swift",
                "Services/TextComparator.swift",
                "Services/ImageComparator.swift",
                "Services/StructureAnalyzer.swift",
                "Services/DetectionEngine.swift",
                "Services/ForensicAnalyzer.swift",
                "Services/ForensicComparator.swift",
                "Services/ReportExporter.swift",
                "Services/TamperingAnalyzer.swift",
                "ViewModels/MainViewModel.swift",
                "ViewModels/ComparisonViewModel.swift",
                "Views/MainView.swift",
                "Views/Welcome/WelcomeView.swift",
                "Views/Welcome/DropZoneView.swift",
                "Views/Analysis/AnalysisProgressView.swift",
                "Views/Results/ResultsView.swift",
                "Views/Results/ComparisonView.swift",
                "Views/Results/ResultsPanel.swift",
                "Views/Results/RiskIndicator.swift",
                "Views/Results/FindingsSection.swift",
                "Views/Results/MetadataTreeView.swift",
                "Views/Components/PrimaryButton.swift",
                "Utilities/DesignSystem.swift",
                "Utilities/FileHelpers.swift",
                "Utilities/DiffHelpers.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
