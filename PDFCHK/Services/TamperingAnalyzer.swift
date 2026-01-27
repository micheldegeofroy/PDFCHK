import Foundation

// MARK: - Tampering Analyzer
class TamperingAnalyzer {

    // MARK: - Analyze Single PDF
    func analyze(
        metadata: PDFAnalysis.PDFMetadata,
        fileInfo: PDFAnalysis.FileInfo,
        forensics: ForensicResult,
        externalTools: ExternalToolsAnalysis?
    ) -> TamperingAnalysis {
        var indicators: [TamperingIndicator] = []

        // Structure indicators
        indicators.append(contentsOf: analyzeStructure(metadata: metadata, externalTools: externalTools))

        // Date indicators
        indicators.append(contentsOf: analyzeDates(metadata: metadata, fileInfo: fileInfo, externalTools: externalTools))

        // Signature indicators
        indicators.append(contentsOf: analyzeSignatures(forensics: forensics))

        // Hidden content indicators
        indicators.append(contentsOf: analyzeHiddenContent(forensics: forensics))

        // Tool chain indicators
        indicators.append(contentsOf: analyzeToolChain(metadata: metadata, externalTools: externalTools))

        // Metadata indicators
        indicators.append(contentsOf: analyzeMetadata(metadata: metadata, externalTools: externalTools))

        // Security indicators
        indicators.append(contentsOf: analyzeSecurity(metadata: metadata, forensics: forensics, externalTools: externalTools))

        return TamperingAnalysis(indicators: indicators)
    }

    // MARK: - Structure Analysis
    private func analyzeStructure(
        metadata: PDFAnalysis.PDFMetadata,
        externalTools: ExternalToolsAnalysis?
    ) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        // Incremental updates
        if metadata.incrementalUpdates > 0 {
            let severity: Severity = metadata.incrementalUpdates > 3 ? .high : .medium
            indicators.append(TamperingIndicator(
                type: .incrementalUpdates,
                severity: severity,
                title: "Incremental Updates Detected",
                description: "Document was modified \(metadata.incrementalUpdates) time(s) after initial creation",
                details: ["Update Count": "\(metadata.incrementalUpdates)"]
            ))
        }

        // Deleted objects from external tools
        if let objInfo = externalTools?.pdfObjectInfo, objInfo.freeObjects > 0 {
            let severity: Severity = objInfo.freeObjects > 10 ? .high : .medium
            indicators.append(TamperingIndicator(
                type: .deletedObjects,
                severity: severity,
                title: "Deleted Objects Found",
                description: "\(objInfo.freeObjects) object(s) were deleted - content may be recoverable",
                details: [
                    "Deleted Objects": "\(objInfo.freeObjects)",
                    "Total Objects": "\(objInfo.objectCount)",
                    "Active Objects": "\(objInfo.activeObjects)"
                ]
            ))
        }

        // Multiple XRef tables
        if let objInfo = externalTools?.pdfObjectInfo, objInfo.updateCount > 1 {
            indicators.append(TamperingIndicator(
                type: .multipleXrefTables,
                severity: .medium,
                title: "Multiple Cross-Reference Tables",
                description: "Document contains \(objInfo.updateCount) XRef sections indicating modifications",
                details: ["XRef Sections": "\(objInfo.updateCount)"]
            ))
        }

        return indicators
    }

    // MARK: - Date Analysis
    private func analyzeDates(
        metadata: PDFAnalysis.PDFMetadata,
        fileInfo: PDFAnalysis.FileInfo,
        externalTools: ExternalToolsAnalysis?
    ) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        // Creation vs Modification date discrepancy
        if let created = metadata.creationDate, let modified = metadata.modificationDate {
            let timeDiff = modified.timeIntervalSince(created)

            if timeDiff > 60 { // More than 1 minute
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.day, .hour, .minute]
                formatter.unitsStyle = .abbreviated
                let diffString = formatter.string(from: timeDiff) ?? "unknown"

                let severity: Severity = timeDiff > 86400 ? .medium : .low // More than 1 day
                indicators.append(TamperingIndicator(
                    type: .dateDiscrepancy,
                    severity: severity,
                    title: "Creation/Modification Date Discrepancy",
                    description: "Document was modified \(diffString) after creation",
                    details: [
                        "Created": created.formattedForDisplay,
                        "Modified": modified.formattedForDisplay,
                        "Time Difference": diffString
                    ]
                ))
            }

            // Future date check
            let now = Date()
            if created > now || modified > now {
                indicators.append(TamperingIndicator(
                    type: .futureDate,
                    severity: .high,
                    title: "Future Date Detected",
                    description: "Document contains dates in the future - possible clock manipulation",
                    details: [
                        "Created": created.formattedForDisplay,
                        "Modified": modified.formattedForDisplay,
                        "Current Time": now.formattedForDisplay
                    ]
                ))
            }
        }

        // File system vs PDF metadata date mismatch
        if let pdfModified = metadata.modificationDate,
           let fileModified = fileInfo.modificationDate {
            let timeDiff = abs(pdfModified.timeIntervalSince(fileModified))
            if timeDiff > 3600 { // More than 1 hour difference
                indicators.append(TamperingIndicator(
                    type: .metadataDateMismatch,
                    severity: .medium,
                    title: "File System / PDF Date Mismatch",
                    description: "PDF metadata date doesn't match file system modification date",
                    details: [
                        "PDF Modified": pdfModified.formattedForDisplay,
                        "File Modified": fileModified.formattedForDisplay
                    ]
                ))
            }
        }

        // Version history date discrepancy from exiftool
        if let history = externalTools?.versionHistory, history.dateDiscrepancy {
            var details: [String: String] = [:]
            if let create = history.createDate { details["Create Date"] = create }
            if let modify = history.modifyDate { details["Modify Date"] = modify }
            if let metadata = history.metadataDate { details["Metadata Date"] = metadata }

            indicators.append(TamperingIndicator(
                type: .metadataDateMismatch,
                severity: .medium,
                title: "Version History Date Discrepancy",
                description: "Internal PDF dates are inconsistent",
                details: details
            ))
        }

        return indicators
    }

    // MARK: - Signature Analysis
    private func analyzeSignatures(forensics: ForensicResult) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        for sig in forensics.signatures {
            // Invalid signature
            if !sig.isValid {
                indicators.append(TamperingIndicator(
                    type: .invalidSignature,
                    severity: .critical,
                    title: "Invalid Digital Signature",
                    description: "Signature by '\(sig.signerName ?? "Unknown")' failed validation - document was modified after signing",
                    details: [
                        "Signer": sig.signerName ?? "Unknown",
                        "Status": "INVALID"
                    ]
                ))
            }

            // Partial signature coverage
            if !sig.coversWholeDocument {
                indicators.append(TamperingIndicator(
                    type: .partialSignature,
                    severity: .high,
                    title: "Partial Signature Coverage",
                    description: "Signature does not cover entire document - content may have been added after signing",
                    details: [
                        "Signer": sig.signerName ?? "Unknown",
                        "Coverage": "Partial"
                    ]
                ))
            }
        }

        return indicators
    }

    // MARK: - Hidden Content Analysis
    private func analyzeHiddenContent(forensics: ForensicResult) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        // Hidden content
        if !forensics.hiddenContent.isEmpty {
            var details: [String: String] = [:]
            for (index, hidden) in forensics.hiddenContent.prefix(10).enumerated() {
                details["Item \(index + 1)"] = "\(hidden.type.rawValue) on page \(hidden.pageNumber)"
            }
            if forensics.hiddenContent.count > 10 {
                details["..."] = "and \(forensics.hiddenContent.count - 10) more"
            }

            indicators.append(TamperingIndicator(
                type: .hiddenContent,
                severity: .medium,
                title: "Hidden Content Detected",
                description: "\(forensics.hiddenContent.count) hidden element(s) found in document",
                details: details
            ))
        }

        // Hidden layers
        let hiddenLayers = forensics.layers.filter { !$0.isVisible }
        if !hiddenLayers.isEmpty {
            var details: [String: String] = [:]
            for (index, layer) in hiddenLayers.prefix(5).enumerated() {
                details["Layer \(index + 1)"] = layer.name
            }

            indicators.append(TamperingIndicator(
                type: .hiddenLayers,
                severity: .medium,
                title: "Hidden Layers Present",
                description: "\(hiddenLayers.count) hidden layer(s) may contain concealed content",
                details: details
            ))
        }

        // Improper redactions
        let improperRedactions = forensics.redactions.filter { $0.hasHiddenContent }
        if !improperRedactions.isEmpty {
            var details: [String: String] = [:]
            for redaction in improperRedactions {
                details["Page \(redaction.pageNumber)"] = "Content recoverable"
            }

            indicators.append(TamperingIndicator(
                type: .improperRedaction,
                severity: .critical,
                title: "Improper Redactions",
                description: "\(improperRedactions.count) redaction(s) can be reversed - hidden content is recoverable",
                details: details
            ))
        }

        return indicators
    }

    // MARK: - Tool Chain Analysis
    private func analyzeToolChain(
        metadata: PDFAnalysis.PDFMetadata,
        externalTools: ExternalToolsAnalysis?
    ) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        guard let creator = metadata.creator, !creator.isEmpty,
              let producer = metadata.producer, !producer.isEmpty else {
            return indicators
        }

        let creatorLower = creator.lowercased()
        let producerLower = producer.lowercased()

        // Check for different tool families
        let creatorIsWord = creatorLower.contains("word") || creatorLower.contains("microsoft")
        let producerIsWord = producerLower.contains("word") || producerLower.contains("microsoft")
        let creatorIsAdobe = creatorLower.contains("adobe") || creatorLower.contains("acrobat") || creatorLower.contains("indesign")
        let producerIsAdobe = producerLower.contains("adobe") || producerLower.contains("acrobat")
        let creatorIsLibreOffice = creatorLower.contains("libreoffice") || creatorLower.contains("openoffice")
        let producerIsLibreOffice = producerLower.contains("libreoffice") || producerLower.contains("openoffice")

        // Different tool families
        if (creatorIsWord && producerIsAdobe) ||
           (creatorIsAdobe && producerIsWord) ||
           (creatorIsLibreOffice && producerIsAdobe) {
            indicators.append(TamperingIndicator(
                type: .multipleToolsUsed,
                severity: .info,
                title: "Multiple Creation Tools",
                description: "Document was created with one application and processed with another",
                details: [
                    "Creator": creator,
                    "Producer": producer
                ]
            ))
        }

        // Suspicious producer (generic or stripped)
        let suspiciousProducers = ["pdf", "unknown", "none", ""]
        if suspiciousProducers.contains(producerLower) || producer.count < 3 {
            indicators.append(TamperingIndicator(
                type: .suspiciousProducer,
                severity: .medium,
                title: "Suspicious Producer Metadata",
                description: "PDF producer field is generic or stripped - may indicate tampering",
                details: ["Producer": producer.isEmpty ? "(empty)" : producer]
            ))
        }

        return indicators
    }

    // MARK: - Metadata Analysis
    private func analyzeMetadata(
        metadata: PDFAnalysis.PDFMetadata,
        externalTools: ExternalToolsAnalysis?
    ) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        // XMP Edit History
        if let xmp = externalTools?.xmpMetadata, xmp.hasEditHistory {
            let editCount = xmp.editHistory.count
            let severity: Severity = editCount > 10 ? .high : (editCount > 5 ? .medium : .info)

            var details: [String: String] = ["Total Edits": "\(editCount)"]
            for (index, entry) in xmp.editHistory.prefix(5).enumerated() {
                details["Edit \(index + 1)"] = "\(entry.action) by \(entry.softwareAgent)"
            }
            if editCount > 5 {
                details["..."] = "and \(editCount - 5) more"
            }

            indicators.append(TamperingIndicator(
                type: .xmpEditHistory,
                severity: severity,
                title: "XMP Edit History Present",
                description: "\(editCount) modification(s) recorded in XMP metadata",
                details: details
            ))
        }

        // Check for stripped/missing metadata
        if metadata.title == nil && metadata.author == nil &&
           metadata.creator == nil && metadata.producer == nil {
            indicators.append(TamperingIndicator(
                type: .metadataStripped,
                severity: .medium,
                title: "Metadata Appears Stripped",
                description: "All standard metadata fields are empty - may indicate intentional removal",
                details: nil
            ))
        }

        return indicators
    }

    // MARK: - Security Analysis
    private func analyzeSecurity(
        metadata: PDFAnalysis.PDFMetadata,
        forensics: ForensicResult,
        externalTools: ExternalToolsAnalysis?
    ) -> [TamperingIndicator] {
        var indicators: [TamperingIndicator] = []

        // JavaScript
        if metadata.hasJavaScript {
            indicators.append(TamperingIndicator(
                type: .javascript,
                severity: .high,
                title: "JavaScript Code Present",
                description: "Document contains executable JavaScript - potential security risk",
                details: nil
            ))
        }

        // Embedded files
        if metadata.embeddedFileCount > 0 {
            indicators.append(TamperingIndicator(
                type: .embeddedFiles,
                severity: .medium,
                title: "Embedded Files Found",
                description: "\(metadata.embeddedFileCount) file(s) embedded in document",
                details: ["Count": "\(metadata.embeddedFileCount)"]
            ))
        }

        // GPS data
        if let gps = externalTools?.gpsLocations, !gps.isEmpty {
            var details: [String: String] = ["Locations Found": "\(gps.count)"]
            for (index, loc) in gps.prefix(3).enumerated() {
                details["Location \(index + 1)"] = loc.coordinateString
            }

            indicators.append(TamperingIndicator(
                type: .gpsData,
                severity: .medium,
                title: "GPS Location Data",
                description: "Geographic coordinates found in embedded content",
                details: details
            ))
        }

        return indicators
    }
}
