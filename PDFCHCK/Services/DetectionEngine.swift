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
    private let externalToolsService = ExternalToolsService()

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
        var originalExternalTools: ExternalToolsAnalysis?
        var comparisonExternalTools: ExternalToolsAnalysis?
        var toolAvailability: ExternalToolsService.ToolAvailability?
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

        // Stage 8: Forensic Comparison + External Tools
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

        await progressHandler(AnalysisProgress(stage: .forensics, stageProgress: 0.3))

        // Run external tools analysis (mutool, exiftool)
        state.toolAvailability = await externalToolsService.checkToolAvailability()

        if state.toolAvailability?.anyToolAvailable == true {
            state.originalExternalTools = await runExternalToolsAnalysis(for: originalURL)
            await progressHandler(AnalysisProgress(stage: .forensics, stageProgress: 0.6))

            state.comparisonExternalTools = await runExternalToolsAnalysis(for: comparisonURL)
        }

        await progressHandler(AnalysisProgress(stage: .forensics, stageProgress: 1.0))

        // Generate report
        return generateReport(state: state, originalURL: originalURL, comparisonURL: comparisonURL)
    }

    // MARK: - Cancel Analysis
    func cancel() {
        isCancelled = true
    }

    // MARK: - External Tools Analysis
    private func runExternalToolsAnalysis(for url: URL) async -> ExternalToolsAnalysis {
        let pdfPath = url.path
        let availability = await externalToolsService.checkToolAvailability()

        var analysis = ExternalToolsAnalysis(
            toolAvailability: ToolAvailabilityInfo(
                mutoolAvailable: availability.mutoolAvailable,
                exiftoolAvailable: availability.exiftoolAvailable,
                missingToolsMessage: availability.missingToolsMessage
            )
        )

        // Mutool operations
        if availability.mutoolAvailable {
            do {
                analysis.fonts = try await externalToolsService.extractFonts(from: pdfPath)
            } catch {
                // Font extraction failed, continue with other analyses
            }

            do {
                analysis.pageResources = try await externalToolsService.getPageResources(from: pdfPath)
            } catch {
                // Resource extraction failed, continue
            }

            do {
                analysis.pdfObjectInfo = try await externalToolsService.showPDFObjects(from: pdfPath)
            } catch {
                // Object info failed, continue
            }
        }

        // Exiftool operations
        if availability.exiftoolAvailable {
            do {
                analysis.xmpMetadata = try await externalToolsService.extractXMPMetadata(from: pdfPath)
            } catch {
                // XMP extraction failed, continue
            }

            do {
                analysis.versionHistory = try await externalToolsService.extractVersionHistory(from: pdfPath)
            } catch {
                // Version history failed, continue
            }

            do {
                analysis.gpsLocations = try await externalToolsService.extractGPSData(from: pdfPath)
            } catch {
                // GPS extraction failed, continue
            }

            do {
                analysis.forensicMetadata = try await externalToolsService.getForensicMetadata(from: pdfPath)
            } catch {
                // Forensic metadata failed, continue
            }

            // Extract embedded documents to temp directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("PDFCHCK-\(UUID().uuidString)")
                .path

            do {
                analysis.embeddedDocuments = try await externalToolsService.extractEmbeddedDocuments(
                    from: pdfPath,
                    to: tempDir
                )
            } catch {
                // Embedded docs extraction failed, continue
            }
        }

        return analysis
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

        // Add findings from external tools analysis
        let externalToolsFindings = generateExternalToolsFindings(state: state)
        allFindings.append(contentsOf: externalToolsFindings)

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

        // Create external tools comparison summary
        let externalToolsSummary = createExternalToolsSummary(state: state)

        return DetectionReport(
            originalFile: originalRef,
            comparisonFile: comparisonRef,
            riskScore: riskScore,
            findings: allFindings.sortedBySeverity(),
            textComparison: textSummary,
            visualComparison: visualSummary,
            metadataComparison: metadataSummary,
            externalToolsAnalysis: externalToolsSummary
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

    // MARK: - External Tools Findings
    private func generateExternalToolsFindings(state: AnalysisState) -> [Finding] {
        var findings: [Finding] = []

        guard let origTools = state.originalExternalTools,
              let compTools = state.comparisonExternalTools else {
            return findings
        }

        // Font comparison
        let fontComparison = FontComparisonResult.compare(
            original: origTools.fonts,
            comparison: compTools.fonts
        )

        if fontComparison.hasDifferences {
            let severity: Severity = (fontComparison.addedFonts.count + fontComparison.removedFonts.count) > 3 ? .high : .medium

            var description = ""
            if !fontComparison.addedFonts.isEmpty {
                description += "Added fonts: \(fontComparison.addedFonts.joined(separator: ", ")). "
            }
            if !fontComparison.removedFonts.isEmpty {
                description += "Removed fonts: \(fontComparison.removedFonts.joined(separator: ", "))."
            }

            findings.append(Finding(
                category: .forensic,
                severity: severity,
                title: "Font Differences Detected",
                description: description.trimmingCharacters(in: .whitespaces)
            ))
        }

        // Incremental updates
        if let origObj = origTools.pdfObjectInfo, origObj.hasIncrementalUpdates {
            findings.append(Finding(
                category: .forensic,
                severity: .medium,
                title: "Original Document Has Incremental Updates",
                description: "Document has been modified after initial creation (\(origObj.updateCount) updates)"
            ))
        }

        if let compObj = compTools.pdfObjectInfo, compObj.hasIncrementalUpdates {
            findings.append(Finding(
                category: .forensic,
                severity: .high,
                title: "Comparison Document Has Incremental Updates",
                description: "Document has been modified after initial creation (\(compObj.updateCount) updates)"
            ))
        }

        // XMP edit history differences
        let origHistoryCount = origTools.xmpMetadata?.editHistory.count ?? 0
        let compHistoryCount = compTools.xmpMetadata?.editHistory.count ?? 0

        if origHistoryCount != compHistoryCount {
            findings.append(Finding(
                category: .forensic,
                severity: .medium,
                title: "XMP Edit History Differs",
                description: "Original: \(origHistoryCount) edits, Comparison: \(compHistoryCount) edits"
            ))
        }

        // GPS location data (privacy concern)
        if !origTools.gpsLocations.isEmpty || !compTools.gpsLocations.isEmpty {
            let totalLocations = origTools.gpsLocations.count + compTools.gpsLocations.count
            findings.append(Finding(
                category: .forensic,
                severity: .info,
                title: "GPS Location Data Found",
                description: "\(totalLocations) GPS coordinate(s) found in embedded content"
            ))
        }

        // Embedded documents
        if !origTools.embeddedDocuments.isEmpty || !compTools.embeddedDocuments.isEmpty {
            let totalDocs = origTools.embeddedDocuments.count + compTools.embeddedDocuments.count
            findings.append(Finding(
                category: .forensic,
                severity: .info,
                title: "Embedded Documents Found",
                description: "\(totalDocs) embedded file(s) detected"
            ))
        }

        // Version history date discrepancies
        if origTools.versionHistory?.dateDiscrepancy == true ||
           compTools.versionHistory?.dateDiscrepancy == true {
            findings.append(Finding(
                category: .metadata,
                severity: .medium,
                title: "Date Discrepancy Detected",
                description: "Creation and modification dates differ significantly"
            ))
        }

        return findings
    }

    // MARK: - Create External Tools Summary
    private func createExternalToolsSummary(state: AnalysisState) -> ExternalToolsComparisonSummary? {
        guard let availability = state.toolAvailability else {
            return nil
        }

        let toolInfo = ToolAvailabilityInfo(
            mutoolAvailable: availability.mutoolAvailable,
            exiftoolAvailable: availability.exiftoolAvailable,
            missingToolsMessage: availability.missingToolsMessage
        )

        // If no tools available, return basic summary with message
        guard availability.anyToolAvailable else {
            return ExternalToolsComparisonSummary(
                toolsAvailable: toolInfo,
                originalAnalysis: nil,
                comparisonAnalysis: nil,
                fontComparison: nil,
                resourceComparison: nil,
                suspiciousFindings: []
            )
        }

        var fontComparison: FontComparisonResult?
        var resourceComparison: ResourceComparisonResult?
        var suspiciousFindings: [String] = []

        if let origTools = state.originalExternalTools,
           let compTools = state.comparisonExternalTools {

            // Font comparison
            fontComparison = FontComparisonResult.compare(
                original: origTools.fonts,
                comparison: compTools.fonts
            )

            // Resource comparison
            resourceComparison = ResourceComparisonResult.compare(
                original: origTools.pageResources,
                comparison: compTools.pageResources
            )

            // Collect suspicious findings
            suspiciousFindings.append(contentsOf: origTools.suspiciousFindings)
            suspiciousFindings.append(contentsOf: compTools.suspiciousFindings)
        }

        return ExternalToolsComparisonSummary(
            toolsAvailable: toolInfo,
            originalAnalysis: state.originalExternalTools,
            comparisonAnalysis: state.comparisonExternalTools,
            fontComparison: fontComparison,
            resourceComparison: resourceComparison,
            suspiciousFindings: suspiciousFindings
        )
    }

    // MARK: - Get Analysis Components
    func getPageImages(state: AnalysisState, page: Int) -> (original: NSImage?, comparison: NSImage?, diff: NSImage?) {
        let origImage = state.originalAnalysis?.pageImages[page]
        let compImage = state.comparisonAnalysis?.pageImages[page]
        let diffImage = state.imageComparison?.pageResults.first { $0.pageNumber == page + 1 }?.diffImage

        return (origImage, compImage, diffImage)
    }
}
