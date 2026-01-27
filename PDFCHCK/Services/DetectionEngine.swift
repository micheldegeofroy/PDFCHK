import Foundation
import Combine
import AppKit

// MARK: - Detection Engine
actor DetectionEngine {
    private let pdfAnalyzer = PDFAnalyzer()
    private let metadataAnalyzer = MetadataAnalyzer()
    private let textComparator = TextComparator()
    private let imageComparator = ImageComparator()
    private let structureAnalyzer = StructureAnalyzer()
    private let forensicAnalyzer = ForensicAnalyzer()
    private let forensicComparator = ForensicComparator()

    private var isCancelled = false

    // MARK: - Analysis State
    struct AnalysisState {
        var originalAnalysis: PDFAnalysis?
        var comparisonAnalysis: PDFAnalysis?
        var metadataComparison: MetadataComparison?
        var textComparison: TextComparisonResult?
        var imageComparison: ImageComparisonResult?
        var structureAnalysis: StructureAnalyzer.StructureAnalysisResult?
        var originalForensics: ForensicResult?
        var comparisonForensics: ForensicResult?
        var forensicComparison: ForensicComparisonResult?
    }

    // MARK: - Run Analysis
    func runAnalysis(
        originalURL: URL,
        comparisonURL: URL,
        progressHandler: @escaping (AnalysisProgress) async -> Void
    ) async throws -> DetectionReport {
        isCancelled = false
        var state = AnalysisState()

        // Stage 1: Loading Documents
        await progressHandler(AnalysisProgress(stage: .loading, stageProgress: 0))

        guard !isCancelled else { throw AnalysisError.cancelled }
        state.originalAnalysis = try await pdfAnalyzer.analyze(url: originalURL)
        await progressHandler(AnalysisProgress(stage: .loading, stageProgress: 0.5))

        guard !isCancelled else { throw AnalysisError.cancelled }
        state.comparisonAnalysis = try await pdfAnalyzer.analyze(url: comparisonURL)
        await progressHandler(AnalysisProgress(stage: .loading, stageProgress: 1.0))

        guard let original = state.originalAnalysis,
              let comparison = state.comparisonAnalysis else {
            throw AnalysisError.extractionFailed("Failed to load PDFs")
        }

        // Stage 2: Metadata Analysis
        await progressHandler(AnalysisProgress(stage: .metadata, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        state.metadataComparison = await metadataAnalyzer.compare(original: original, comparison: comparison)
        await progressHandler(AnalysisProgress(stage: .metadata, stageProgress: 1.0))

        // Stage 3: Text Comparison
        await progressHandler(AnalysisProgress(stage: .text, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        state.textComparison = await textComparator.compare(original: original, comparison: comparison)
        await progressHandler(AnalysisProgress(stage: .text, stageProgress: 1.0))

        // Stage 4: Visual Comparison
        await progressHandler(AnalysisProgress(stage: .visual, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        state.imageComparison = await imageComparator.compare(original: original, comparison: comparison)
        await progressHandler(AnalysisProgress(stage: .visual, stageProgress: 1.0))

        // Stage 5: Structure Analysis
        await progressHandler(AnalysisProgress(stage: .structure, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        state.structureAnalysis = await structureAnalyzer.analyze(original: original, comparison: comparison)
        await progressHandler(AnalysisProgress(stage: .structure, stageProgress: 1.0))

        // Stage 6: Embedded Images Analysis
        await progressHandler(AnalysisProgress(stage: .images, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        // Run forensic analysis on both documents
        state.originalForensics = await forensicAnalyzer.analyze(document: original.document, url: originalURL)
        await progressHandler(AnalysisProgress(stage: .images, stageProgress: 0.5))

        state.comparisonForensics = await forensicAnalyzer.analyze(document: comparison.document, url: comparisonURL)
        await progressHandler(AnalysisProgress(stage: .images, stageProgress: 1.0))

        // Stage 7: Security Analysis
        await progressHandler(AnalysisProgress(stage: .security, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        // Update analysis objects with forensic data
        if let origForensics = state.originalForensics {
            state.originalAnalysis?.embeddedImages = origForensics.embeddedImages
            state.originalAnalysis?.links = origForensics.links
            state.originalAnalysis?.layers = origForensics.layers
            state.originalAnalysis?.signatures = origForensics.signatures
            state.originalAnalysis?.hiddenContent = origForensics.hiddenContent
            state.originalAnalysis?.xmpHistory = origForensics.xmpHistory
            state.originalAnalysis?.redactions = origForensics.redactions
            state.originalAnalysis?.suspiciousElements = origForensics.suspiciousElements
        }

        if let compForensics = state.comparisonForensics {
            state.comparisonAnalysis?.embeddedImages = compForensics.embeddedImages
            state.comparisonAnalysis?.links = compForensics.links
            state.comparisonAnalysis?.layers = compForensics.layers
            state.comparisonAnalysis?.signatures = compForensics.signatures
            state.comparisonAnalysis?.hiddenContent = compForensics.hiddenContent
            state.comparisonAnalysis?.xmpHistory = compForensics.xmpHistory
            state.comparisonAnalysis?.redactions = compForensics.redactions
            state.comparisonAnalysis?.suspiciousElements = compForensics.suspiciousElements
        }

        await progressHandler(AnalysisProgress(stage: .security, stageProgress: 1.0))

        // Stage 8: Forensic Comparison
        await progressHandler(AnalysisProgress(stage: .forensics, stageProgress: 0))
        guard !isCancelled else { throw AnalysisError.cancelled }

        if let origForensics = state.originalForensics,
           let compForensics = state.comparisonForensics,
           let origAnalysis = state.originalAnalysis,
           let compAnalysis = state.comparisonAnalysis {
            state.forensicComparison = await forensicComparator.compare(
                original: origForensics,
                comparison: compForensics,
                originalAnalysis: origAnalysis,
                comparisonAnalysis: compAnalysis
            )
        }

        await progressHandler(AnalysisProgress(stage: .forensics, stageProgress: 1.0))

        // Generate report
        return generateReport(state: state, originalURL: originalURL, comparisonURL: comparisonURL)
    }

    // MARK: - Cancel Analysis
    func cancel() {
        isCancelled = true
    }

    // MARK: - Generate Report
    private func generateReport(state: AnalysisState, originalURL: URL, comparisonURL: URL) -> DetectionReport {
        var allFindings: [Finding] = []

        // Collect findings from all analyses
        if let meta = state.metadataComparison {
            allFindings.append(contentsOf: meta.findings)
        }

        if let text = state.textComparison {
            let textFindings = generateTextFindings(from: text)
            allFindings.append(contentsOf: textFindings)
        }

        if let image = state.imageComparison {
            let imageFindings = generateImageFindings(from: image)
            allFindings.append(contentsOf: imageFindings)
        }

        if let structure = state.structureAnalysis {
            allFindings.append(contentsOf: structure.findings)
        }

        if let forensic = state.forensicComparison {
            allFindings.append(contentsOf: forensic.findings)
        }

        // Calculate risk score
        let riskScore = calculateRiskScore(findings: allFindings, state: state)

        // Create file references
        let originalRef = FileReference(
            name: originalURL.lastPathComponent,
            path: originalURL.path,
            size: originalURL.fileSize ?? 0,
            checksum: try? FileHelpers.calculateSHA256(for: originalURL)
        )

        let comparisonRef = FileReference(
            name: comparisonURL.lastPathComponent,
            path: comparisonURL.path,
            size: comparisonURL.fileSize ?? 0,
            checksum: try? FileHelpers.calculateSHA256(for: comparisonURL)
        )

        // Create summary objects
        let textSummary = TextComparisonSummary(
            overallSimilarity: state.textComparison?.similarity ?? 0,
            pageCount: state.textComparison?.pageResults.count ?? 0,
            pagesWithDifferences: state.textComparison?.pageResults.filter { $0.hasChanges }.count ?? 0,
            totalDifferences: state.textComparison?.pageResults.flatMap { $0.differences }.count ?? 0
        )

        let visualSummary = VisualComparisonSummary(
            averageSSIM: state.imageComparison?.averageSSIM ?? 0,
            averagePixelDiff: state.imageComparison?.averagePixelDiff ?? 0,
            pageCount: state.imageComparison?.pageResults.count ?? 0,
            pagesWithDifferences: state.imageComparison?.pagesWithDifferences.count ?? 0
        )

        let metadataSummary = MetadataComparisonSummary(
            pdfMetadataMatch: state.metadataComparison?.pdfMetadataMatch ?? false,
            fileInfoMatch: state.metadataComparison?.fileInfoMatch ?? false,
            timestampAnomalies: state.metadataComparison?.timestampAnalysis.hasAnomalies ?? false,
            differenceCount: state.metadataComparison?.differences.count ?? 0
        )

        return DetectionReport(
            originalFile: originalRef,
            comparisonFile: comparisonRef,
            riskScore: riskScore,
            findings: allFindings.sortedBySeverity(),
            textComparison: textSummary,
            visualComparison: visualSummary,
            metadataComparison: metadataSummary
        )
    }

    // MARK: - Calculate Risk Score
    private func calculateRiskScore(findings: [Finding], state: AnalysisState) -> Double {
        var score: Double = 0

        // Base score from findings severity
        for finding in findings {
            score += Double(finding.severity.weight) * 0.5
        }

        // Adjust based on overall similarities
        if let text = state.textComparison {
            if text.similarity < 0.95 {
                score += (1 - text.similarity) * 30
            }
        }

        if let image = state.imageComparison {
            if image.averageSSIM < 0.98 {
                score += (1 - image.averageSSIM) * 40
            }
        }

        // Cap at 100
        return min(100, max(0, score))
    }

    // MARK: - Generate Findings Helpers
    private func generateTextFindings(from result: TextComparisonResult) -> [Finding] {
        var findings: [Finding] = []

        if result.similarity < 0.95 {
            let severity: Severity = result.similarity < 0.5 ? .critical :
                                    (result.similarity < 0.8 ? .high : .medium)

            findings.append(Finding(
                category: .text,
                severity: severity,
                title: "Text Content Differs",
                description: String(format: "%.1f%% text similarity", result.similarity * 100)
            ))
        }

        return findings
    }

    private func generateImageFindings(from result: ImageComparisonResult) -> [Finding] {
        var findings: [Finding] = []

        if result.averageSSIM < 0.98 {
            let severity: Severity = result.averageSSIM < 0.85 ? .critical :
                                    (result.averageSSIM < 0.95 ? .high : .medium)

            findings.append(Finding(
                category: .visual,
                severity: severity,
                title: "Visual Differences Detected",
                description: String(format: "%.1f%% visual similarity (SSIM)", result.averageSSIM * 100)
            ))
        }

        return findings
    }

    // MARK: - Get Analysis Components
    func getPageImages(state: AnalysisState, page: Int) -> (original: NSImage?, comparison: NSImage?, diff: NSImage?) {
        let origImage = state.originalAnalysis?.pageImages[page]
        let compImage = state.comparisonAnalysis?.pageImages[page]
        let diffImage = state.imageComparison?.pageResults.first { $0.pageNumber == page + 1 }?.diffImage

        return (origImage, compImage, diffImage)
    }
}
