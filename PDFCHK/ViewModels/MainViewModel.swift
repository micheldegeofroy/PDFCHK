import Foundation
import SwiftUI
import Combine
import PDFKit

// MARK: - Main View Model
@MainActor
class MainViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var viewState: AppViewState = .welcome
    @Published var droppedFiles = DroppedFiles()
    @Published var analysisProgress = AnalysisProgress.initial
    @Published var report: DetectionReport?
    @Published var error: AnalysisError?
    @Published var showError: Bool = false

    // Analysis state (for page viewer)
    @Published var originalAnalysis: PDFAnalysis?
    @Published var comparisonAnalysis: PDFAnalysis?
    @Published var imageComparison: ImageComparisonResult?
    @Published var textComparison: TextComparisonResult?

    // MARK: - Private Properties
    private let detectionEngine = DetectionEngine()
    private var analysisTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {}

    // MARK: - File Handling
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] data, error in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          url.isPDF else {
                        return
                    }

                    Task { @MainActor in
                        self?.addFile(url: url)
                    }
                }
                return true
            }
        }
        return false
    }

    func addFile(url: URL) {
        if droppedFiles.originalURL == nil {
            droppedFiles.originalURL = url
        } else if droppedFiles.comparisonURL == nil {
            droppedFiles.comparisonURL = url
        }
    }

    func selectOriginalFile() {
        selectFile { [weak self] url in
            self?.droppedFiles.originalURL = url
        }
    }

    func selectComparisonFile() {
        selectFile { [weak self] url in
            self?.droppedFiles.comparisonURL = url
        }
    }

    private func selectFile(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        panel.title = "Select PDF"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    completion(url)
                }
            }
        }
    }

    func clearFiles() {
        droppedFiles.clear()
    }

    func swapFiles() {
        let temp = droppedFiles.originalURL
        droppedFiles.originalURL = droppedFiles.comparisonURL
        droppedFiles.comparisonURL = temp
    }

    // MARK: - Analysis

    // Single PDF analysis
    func startSingleAnalysis() {
        guard let originalURL = droppedFiles.originalURL else {
            return
        }

        viewState = .analyzing
        error = nil
        report = nil

        analysisTask = Task {
            do {
                let pdfAnalyzer = PDFAnalyzer()
                let forensicAnalyzer = ForensicAnalyzer()
                let externalToolsService = ExternalToolsService()

                // Stage 1: Loading
                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .loading, stageProgress: 0)
                }

                let analysis = try await pdfAnalyzer.analyze(url: originalURL)

                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .loading, stageProgress: 1.0)
                }

                // Stage 2: Metadata
                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .metadata, stageProgress: 0.5)
                }

                // Stage 3: Structure analysis
                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .structure, stageProgress: 0.5)
                }

                // Stage 4: Security & Forensics
                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .security, stageProgress: 0)
                }

                let forensics = await forensicAnalyzer.analyze(document: analysis.document, url: originalURL)

                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .security, stageProgress: 1.0)
                }

                // Stage 5: External tools (mutool, exiftool)
                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .forensics, stageProgress: 0)
                }

                var externalToolsAnalysis: ExternalToolsAnalysis?
                let toolAvailability = await externalToolsService.checkToolAvailability()

                if toolAvailability.anyToolAvailable {
                    externalToolsAnalysis = await self.runExternalToolsForSinglePDF(
                        service: externalToolsService,
                        url: originalURL,
                        availability: toolAvailability
                    )
                }

                await MainActor.run {
                    self.analysisProgress = AnalysisProgress(stage: .forensics, stageProgress: 1.0)
                }

                // Update analysis with forensic data
                var updatedAnalysis = analysis
                updatedAnalysis.embeddedImages = forensics.embeddedImages
                updatedAnalysis.links = forensics.links
                updatedAnalysis.layers = forensics.layers
                updatedAnalysis.signatures = forensics.signatures
                updatedAnalysis.hiddenContent = forensics.hiddenContent
                updatedAnalysis.xmpHistory = forensics.xmpHistory
                updatedAnalysis.redactions = forensics.redactions
                updatedAnalysis.suspiciousElements = forensics.suspiciousElements

                // Store analysis data
                self.originalAnalysis = updatedAnalysis
                self.comparisonAnalysis = nil
                self.imageComparison = nil
                self.textComparison = nil

                // Create a comprehensive single-file report
                self.report = self.createSingleFileReport(
                    analysis: updatedAnalysis,
                    forensics: forensics,
                    url: originalURL,
                    externalTools: externalToolsAnalysis,
                    toolAvailability: toolAvailability
                )

                self.viewState = .results

            } catch let analysisError as AnalysisError {
                self.error = analysisError
                self.showError = true
                self.viewState = .welcome
            } catch {
                self.error = .unknown(error)
                self.showError = true
                self.viewState = .welcome
            }
        }
    }

    // Run external tools for single PDF
    private func runExternalToolsForSinglePDF(
        service: ExternalToolsService,
        url: URL,
        availability: ExternalToolsService.ToolAvailability
    ) async -> ExternalToolsAnalysis {
        let pdfPath = url.path

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
                analysis.fonts = try await service.extractFonts(from: pdfPath)
            } catch {}

            do {
                analysis.pageResources = try await service.getPageResources(from: pdfPath)
            } catch {}

            do {
                analysis.pdfObjectInfo = try await service.showPDFObjects(from: pdfPath)
            } catch {}
        }

        // Exiftool operations
        if availability.exiftoolAvailable {
            do {
                analysis.xmpMetadata = try await service.extractXMPMetadata(from: pdfPath)
            } catch {}

            do {
                analysis.versionHistory = try await service.extractVersionHistory(from: pdfPath)
            } catch {}

            do {
                analysis.gpsLocations = try await service.extractGPSData(from: pdfPath)
            } catch {}

            do {
                analysis.forensicMetadata = try await service.getForensicMetadata(from: pdfPath)
            } catch {}

            // Extract embedded documents
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("PDFCHK-\(UUID().uuidString)")
                .path

            do {
                analysis.embeddedDocuments = try await service.extractEmbeddedDocuments(from: pdfPath, to: tempDir)
            } catch {}
        }

        return analysis
    }

    // Comparative analysis (two PDFs)
    func startAnalysis() {
        guard let originalURL = droppedFiles.originalURL,
              let comparisonURL = droppedFiles.comparisonURL else {
            return
        }

        viewState = .analyzing
        error = nil
        report = nil

        analysisTask = Task {
            do {
                // Create a local reference to engine for the async closure
                let engine = detectionEngine

                // Run analysis with progress updates
                let result = try await engine.runAnalysis(
                    originalURL: originalURL,
                    comparisonURL: comparisonURL
                ) { [weak self] progress in
                    await MainActor.run {
                        self?.analysisProgress = progress
                    }
                }

                self.report = result

                // Store analysis data for page viewer before transitioning to results
                await self.loadAnalysisData(originalURL: originalURL, comparisonURL: comparisonURL)

                self.viewState = .results

            } catch let analysisError as AnalysisError {
                self.error = analysisError
                self.showError = true
                self.viewState = .welcome
            } catch {
                self.error = .unknown(error)
                self.showError = true
                self.viewState = .welcome
            }
        }
    }

    // Create comprehensive report for single PDF analysis
    private func createSingleFileReport(
        analysis: PDFAnalysis,
        forensics: ForensicResult,
        url: URL,
        externalTools: ExternalToolsAnalysis? = nil,
        toolAvailability: ExternalToolsService.ToolAvailability? = nil
    ) -> DetectionReport {
        var findings: [Finding] = []

        // Document info with details
        var docDetails: [String: String] = [:]
        docDetails["Pages"] = "\(analysis.pageCount)"
        docDetails["PDF Version"] = analysis.metadata.version ?? "Unknown"
        if let title = analysis.metadata.title { docDetails["Title"] = title }
        if let author = analysis.metadata.author { docDetails["Author"] = author }
        if let creator = analysis.metadata.creator { docDetails["Creator"] = creator }
        if let producer = analysis.metadata.producer { docDetails["Producer"] = producer }
        if let created = analysis.metadata.creationDate { docDetails["Created"] = created.formattedForDisplay }
        if let modified = analysis.metadata.modificationDate { docDetails["Modified"] = modified.formattedForDisplay }

        findings.append(Finding(
            category: .metadata,
            severity: .info,
            title: "Document Information",
            description: "\(analysis.pageCount) pages, \(analysis.metadata.version ?? "Unknown") PDF version",
            details: docDetails
        ))

        // Fonts with details
        let fontCount = analysis.metadata.fontCount
        let embeddedFonts = analysis.metadata.fonts.filter { $0.isEmbedded }.count
        var fontDetails: [String: String] = [:]
        for (index, font) in analysis.metadata.fonts.enumerated() {
            let embeddedStatus = font.isEmbedded ? "embedded" : "not embedded"
            let subsetStatus = font.isSubset ? ", subset" : ""
            fontDetails["Font \(index + 1)"] = "\(font.name) (\(font.type ?? "Unknown")\(embeddedStatus)\(subsetStatus))"
        }

        findings.append(Finding(
            category: .metadata,
            severity: .info,
            title: "Fonts",
            description: "\(fontCount) font(s), \(embeddedFonts) embedded",
            details: fontDetails.isEmpty ? nil : fontDetails
        ))

        // Encryption status
        if analysis.metadata.isEncrypted {
            var encDetails: [String: String] = [:]
            encDetails["Allows Printing"] = analysis.metadata.allowsPrinting ? "Yes" : "No"
            encDetails["Allows Copying"] = analysis.metadata.allowsCopying ? "Yes" : "No"

            findings.append(Finding(
                category: .security,
                severity: .info,
                title: "Document Encrypted",
                description: "PDF is password protected",
                details: encDetails
            ))
        }

        // Digital signatures with details
        if !forensics.signatures.isEmpty {
            var sigDetails: [String: String] = [:]
            for (index, sig) in forensics.signatures.enumerated() {
                let status = sig.isValid ? "Valid" : "Invalid"
                let coverage = sig.coversWholeDocument ? "Full document" : "Partial"
                sigDetails["Signature \(index + 1)"] = "\(sig.signerName ?? "Unknown") - \(status), \(coverage)"
            }

            findings.append(Finding(
                category: .signatures,
                severity: forensics.signatures.contains { !$0.isValid } ? .high : .info,
                title: "Digital Signatures",
                description: "\(forensics.signatures.count) signature(s) found",
                details: sigDetails
            ))
        }

        // Hidden content with details
        if !forensics.hiddenContent.isEmpty {
            var hiddenDetails: [String: String] = [:]
            for (index, hidden) in forensics.hiddenContent.enumerated() {
                hiddenDetails["Item \(index + 1)"] = "\(hidden.type.rawValue) on page \(hidden.pageNumber)"
            }

            findings.append(Finding(
                category: .hidden,
                severity: .medium,
                title: "Hidden Content",
                description: "\(forensics.hiddenContent.count) hidden element(s) found",
                details: hiddenDetails
            ))
        }

        // Layers with details
        if !forensics.layers.isEmpty {
            let hiddenLayers = forensics.layers.filter { !$0.isVisible }.count
            var layerDetails: [String: String] = [:]
            for (index, layer) in forensics.layers.enumerated() {
                let visibility = layer.isVisible ? "Visible" : "Hidden"
                layerDetails["Layer \(index + 1)"] = "\(layer.name) (\(visibility))"
            }

            findings.append(Finding(
                category: .structure,
                severity: hiddenLayers > 0 ? .medium : .info,
                title: "PDF Layers (OCG)",
                description: "\(forensics.layers.count) layer(s), \(hiddenLayers) hidden",
                details: layerDetails
            ))
        }

        // Links with details
        if !forensics.links.isEmpty {
            var linkDetails: [String: String] = [:]
            for (index, link) in forensics.links.prefix(20).enumerated() {
                if let url = link.url {
                    linkDetails["Link \(index + 1) (p.\(link.pageNumber))"] = url
                }
            }
            if forensics.links.count > 20 {
                linkDetails["..."] = "and \(forensics.links.count - 20) more"
            }

            findings.append(Finding(
                category: .links,
                severity: .info,
                title: "External Links",
                description: "\(forensics.links.count) link(s) found",
                details: linkDetails
            ))
        }

        // JavaScript
        if analysis.metadata.hasJavaScript {
            findings.append(Finding(
                category: .security,
                severity: .high,
                title: "JavaScript Present",
                description: "Document contains executable JavaScript code"
            ))
        }

        // Embedded files
        if analysis.metadata.embeddedFileCount > 0 {
            findings.append(Finding(
                category: .security,
                severity: .medium,
                title: "Embedded Files",
                description: "\(analysis.metadata.embeddedFileCount) embedded file(s)"
            ))
        }

        // Forms
        if analysis.metadata.formFieldCount > 0 {
            findings.append(Finding(
                category: .structure,
                severity: .info,
                title: "Form Fields",
                description: "\(analysis.metadata.formFieldCount) form field(s)"
            ))
        }

        // Annotations
        if analysis.metadata.annotationCount > 0 {
            findings.append(Finding(
                category: .structure,
                severity: .info,
                title: "Annotations",
                description: "\(analysis.metadata.annotationCount) annotation(s)"
            ))
        }

        // Redactions with details
        if !forensics.redactions.isEmpty {
            let improper = forensics.redactions.filter { $0.hasHiddenContent }.count
            var redactDetails: [String: String] = [:]
            for (index, redact) in forensics.redactions.enumerated() {
                let status = redact.hasHiddenContent ? "IMPROPER - content recoverable" : "Proper"
                redactDetails["Redaction \(index + 1) (p.\(redact.pageNumber))"] = status
            }

            findings.append(Finding(
                category: .security,
                severity: improper > 0 ? .critical : .info,
                title: "Redactions",
                description: "\(forensics.redactions.count) redaction(s), \(improper) improper",
                details: redactDetails
            ))
        }

        // XMP History with details
        if !forensics.xmpHistory.isEmpty {
            var historyDetails: [String: String] = [:]
            for (index, entry) in forensics.xmpHistory.enumerated() {
                historyDetails["Edit \(index + 1)"] = "\(entry.action) - \(entry.softwareAgent ?? "Unknown tool")"
            }

            findings.append(Finding(
                category: .metadata,
                severity: .info,
                title: "Modification History",
                description: "\(forensics.xmpHistory.count) recorded edit(s) in XMP",
                details: historyDetails
            ))
        }

        // Suspicious elements
        for element in forensics.suspiciousElements {
            findings.append(Finding(
                category: .forensic,
                severity: element.severity,
                title: element.type.rawValue,
                description: element.description
            ))
        }

        // Incremental updates - strong tampering indicator
        if analysis.metadata.incrementalUpdates > 0 {
            let severity: Severity = analysis.metadata.incrementalUpdates > 3 ? .high : .medium
            findings.append(Finding(
                category: .forensic,
                severity: severity,
                title: "Incremental Updates Detected",
                description: "Document modified \(analysis.metadata.incrementalUpdates) time(s) after initial creation - indicates post-creation editing",
                details: ["Update Count": "\(analysis.metadata.incrementalUpdates)"]
            ))
        }

        // Date discrepancy - creation vs modification
        if let created = analysis.metadata.creationDate,
           let modified = analysis.metadata.modificationDate {
            let timeDiff = modified.timeIntervalSince(created)
            if timeDiff > 60 { // More than 1 minute difference
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.day, .hour, .minute]
                formatter.unitsStyle = .abbreviated
                let diffString = formatter.string(from: timeDiff) ?? "unknown"

                findings.append(Finding(
                    category: .forensic,
                    severity: .medium,
                    title: "Date Discrepancy",
                    description: "Modification date is \(diffString) after creation date",
                    details: [
                        "Created": created.formattedForDisplay,
                        "Modified": modified.formattedForDisplay,
                        "Time Difference": diffString
                    ]
                ))
            }
        }

        // Tool chain analysis - different creator and producer suggests conversion/editing
        if let creator = analysis.metadata.creator,
           let producer = analysis.metadata.producer,
           !creator.isEmpty && !producer.isEmpty {
            // Normalize for comparison
            let creatorNorm = creator.lowercased()
            let producerNorm = producer.lowercased()

            // Check if they're from different tool families
            let creatorIsWord = creatorNorm.contains("word") || creatorNorm.contains("microsoft")
            let producerIsWord = producerNorm.contains("word") || producerNorm.contains("microsoft")
            let creatorIsAdobe = creatorNorm.contains("adobe") || creatorNorm.contains("acrobat")
            let producerIsAdobe = producerNorm.contains("adobe") || producerNorm.contains("acrobat")

            if (creatorIsWord && !producerIsWord) || (creatorIsAdobe && !producerIsAdobe) ||
               (!creatorNorm.contains(producerNorm) && !producerNorm.contains(creatorNorm)) {
                findings.append(Finding(
                    category: .forensic,
                    severity: .info,
                    title: "Multiple Tools in Creation Chain",
                    description: "Document was created with one tool and processed with another",
                    details: [
                        "Creator": creator,
                        "Producer": producer
                    ]
                ))
            }
        }

        // Partial digital signature coverage - major red flag
        let partialSigs = forensics.signatures.filter { !$0.coversWholeDocument }
        if !partialSigs.isEmpty {
            findings.append(Finding(
                category: .forensic,
                severity: .high,
                title: "Partial Signature Coverage",
                description: "\(partialSigs.count) signature(s) do not cover the entire document - content may have been added after signing",
                details: nil
            ))
        }

        // External tools findings
        if let extTools = externalTools {
            // Extended fonts from mutool
            if !extTools.fonts.isEmpty {
                var extFontDetails: [String: String] = [:]
                for (index, font) in extTools.fonts.enumerated() {
                    let embedded = font.embedded ? "embedded" : "not embedded"
                    let subset = font.subset ? ", subset" : ""
                    extFontDetails["Font \(index + 1)"] = "\(font.name) (\(font.type), \(embedded)\(subset))"
                }

                findings.append(Finding(
                    category: .forensic,
                    severity: .info,
                    title: "Extended Font Analysis (mutool)",
                    description: "\(extTools.fonts.count) font(s) detected",
                    details: extFontDetails
                ))
            }

            // PDF object info - deleted objects are a strong tampering indicator
            if let objInfo = extTools.pdfObjectInfo {
                var objDetails: [String: String] = [:]
                objDetails["Total Objects"] = "\(objInfo.objectCount)"
                objDetails["Active Objects"] = "\(objInfo.activeObjects)"
                objDetails["Deleted Objects"] = "\(objInfo.freeObjects)"
                objDetails["Incremental Updates"] = "\(objInfo.updateCount)"

                // Deleted objects - content was removed but may be recoverable
                if objInfo.freeObjects > 0 {
                    let severity: Severity = objInfo.freeObjects > 10 ? .high : .medium
                    findings.append(Finding(
                        category: .forensic,
                        severity: severity,
                        title: "Deleted Objects Found",
                        description: "\(objInfo.freeObjects) deleted object(s) - content was removed but data may still be in file",
                        details: objDetails
                    ))
                } else if objInfo.hasIncrementalUpdates {
                    findings.append(Finding(
                        category: .forensic,
                        severity: .medium,
                        title: "PDF Object Structure Modified",
                        description: "\(objInfo.objectCount) objects with \(objInfo.updateCount) incremental update(s)",
                        details: objDetails
                    ))
                }
            }

            // XMP from exiftool with details
            if let xmp = extTools.xmpMetadata, xmp.hasEditHistory {
                var xmpDetails: [String: String] = [:]
                for (index, entry) in xmp.editHistory.enumerated() {
                    xmpDetails["Edit \(index + 1)"] = "\(entry.action) at \(entry.when) by \(entry.softwareAgent)"
                }

                let severity: Severity = xmp.editHistory.count > 5 ? .medium : .info
                findings.append(Finding(
                    category: .forensic,
                    severity: severity,
                    title: "XMP Edit History (exiftool)",
                    description: "\(xmp.editHistory.count) modification(s) recorded in metadata",
                    details: xmpDetails
                ))
            }

            // Version history date discrepancy from exiftool
            if let history = extTools.versionHistory, history.dateDiscrepancy {
                var historyDetails: [String: String] = [:]
                if let create = history.createDate { historyDetails["Create Date"] = create }
                if let modify = history.modifyDate { historyDetails["Modify Date"] = modify }
                if let metadata = history.metadataDate { historyDetails["Metadata Date"] = metadata }

                findings.append(Finding(
                    category: .forensic,
                    severity: .medium,
                    title: "Version History Date Discrepancy",
                    description: "Creation and modification dates in PDF history differ",
                    details: historyDetails
                ))
            }

            // GPS locations with details
            if !extTools.gpsLocations.isEmpty {
                var gpsDetails: [String: String] = [:]
                for (index, loc) in extTools.gpsLocations.enumerated() {
                    let coords = String(format: "%.6f, %.6f", loc.latitude, loc.longitude)
                    gpsDetails["Location \(index + 1)"] = "\(coords) (from \(loc.source))"
                }

                findings.append(Finding(
                    category: .forensic,
                    severity: .medium,
                    title: "GPS Location Data",
                    description: "\(extTools.gpsLocations.count) location(s) found in embedded content",
                    details: gpsDetails
                ))
            }

            // Embedded documents with details
            if !extTools.embeddedDocuments.isEmpty {
                var docDetails: [String: String] = [:]
                for (index, doc) in extTools.embeddedDocuments.enumerated() {
                    let sizeInfo = doc.size > 0 ? " (\(ByteCountFormatter.string(fromByteCount: doc.size, countStyle: .file)))" : ""
                    docDetails["File \(index + 1)"] = "\(doc.filename)\(sizeInfo)"
                }

                findings.append(Finding(
                    category: .forensic,
                    severity: .info,
                    title: "Embedded Documents (exiftool)",
                    description: "\(extTools.embeddedDocuments.count) embedded file(s) extracted",
                    details: docDetails
                ))
            }
        }

        // Calculate file checksum
        let checksum = try? FileHelpers.calculateSHA256(for: url)

        // Add checksum finding
        if let hash = checksum {
            findings.append(Finding(
                category: .forensic,
                severity: .info,
                title: "File Checksum (SHA-256)",
                description: "Unique identifier for this file",
                details: ["SHA-256": hash]
            ))
        }

        let fileRef = FileReference(
            name: url.lastPathComponent,
            path: url.path,
            size: url.fileSize ?? 0,
            checksum: checksum
        )

        // Calculate risk score based on findings
        let riskScore = findings.reduce(0.0) { $0 + Double($1.severity.weight) * 0.3 }

        // Create external tools summary for single file
        var externalToolsSummary: ExternalToolsComparisonSummary?
        if let availability = toolAvailability {
            externalToolsSummary = ExternalToolsComparisonSummary(
                toolsAvailable: ToolAvailabilityInfo(
                    mutoolAvailable: availability.mutoolAvailable,
                    exiftoolAvailable: availability.exiftoolAvailable,
                    missingToolsMessage: availability.missingToolsMessage
                ),
                originalAnalysis: externalTools,
                comparisonAnalysis: nil,
                fontComparison: nil,
                resourceComparison: nil,
                suspiciousFindings: externalTools?.suspiciousFindings ?? []
            )
        }

        // Run tampering analysis
        let tamperingAnalyzer = TamperingAnalyzer()
        let tamperingAnalysis = tamperingAnalyzer.analyze(
            metadata: analysis.metadata,
            fileInfo: analysis.fileInfo,
            forensics: forensics,
            externalTools: externalTools
        )

        // Adjust risk score based on tampering analysis
        let tamperingAdjustedScore = riskScore + (tamperingAnalysis.score * 0.5)

        return DetectionReport(
            originalFile: fileRef,
            comparisonFile: fileRef,
            riskScore: min(100, tamperingAdjustedScore),
            findings: findings.sortedBySeverity(),
            textComparison: TextComparisonSummary(overallSimilarity: 1.0, pageCount: analysis.pageCount, pagesWithDifferences: 0, totalDifferences: 0),
            visualComparison: VisualComparisonSummary(averageSSIM: 1.0, averagePixelDiff: 0, pageCount: analysis.pageCount, pagesWithDifferences: 0),
            metadataComparison: MetadataComparisonSummary(pdfMetadataMatch: true, fileInfoMatch: true, timestampAnomalies: false, differenceCount: 0),
            externalToolsAnalysis: externalToolsSummary,
            tamperingAnalysis: tamperingAnalysis
        )
    }

    private func loadAnalysisData(originalURL: URL, comparisonURL: URL) async {
        let pdfAnalyzer = PDFAnalyzer()
        let imageComp = ImageComparator()
        let textComp = TextComparator()

        do {
            let orig = try await pdfAnalyzer.analyze(url: originalURL)
            let comp = try await pdfAnalyzer.analyze(url: comparisonURL)

            self.originalAnalysis = orig
            self.comparisonAnalysis = comp

            self.imageComparison = await imageComp.compare(original: orig, comparison: comp)
            self.textComparison = await textComp.compare(original: orig, comparison: comp)
        } catch {
            // Analysis data couldn't be loaded, but report is still valid
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        Task {
            await detectionEngine.cancel()
        }
        viewState = .welcome
    }

    // MARK: - Reset
    func reset() {
        viewState = .welcome
        droppedFiles.clear()
        analysisProgress = .initial
        report = nil
        error = nil
        originalAnalysis = nil
        comparisonAnalysis = nil
        imageComparison = nil
        textComparison = nil
    }

    // MARK: - Export
    func exportReportAsJSON() {
        guard let report = report else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PDFCHK-Report.json"
        panel.title = "Export Report as JSON"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ReportExporter.exportToJSON(report: report, url: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    func exportReportAsPDF() {
        guard let report = report else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "PDFCHK-Report.pdf"
        panel.title = "Export Report as PDF"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ReportExporter.exportToPDF(report: report, url: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }

    // MARK: - Computed Properties
    var canStartAnalysis: Bool {
        droppedFiles.bothFilesSelected
    }

    var riskLevelText: String {
        report?.riskLevel.rawValue ?? "Unknown"
    }

    var riskScoreText: String {
        guard let score = report?.riskScore else { return "0" }
        return String(format: "%.0f", score)
    }
}
