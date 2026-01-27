import Foundation

// MARK: - Metadata Analyzer
actor MetadataAnalyzer {

    // MARK: - Compare Metadata
    func compare(original: PDFAnalysis, comparison: PDFAnalysis) async -> MetadataComparison {
        var differences: [MetadataDifference] = []
        var findings: [Finding] = []

        // Compare PDF metadata
        let pdfMetaDiffs = comparePDFMetadata(original.metadata, comparison.metadata)
        differences.append(contentsOf: pdfMetaDiffs)

        // Compare file info
        let fileInfoDiffs = compareFileInfo(original.fileInfo, comparison.fileInfo)
        differences.append(contentsOf: fileInfoDiffs)

        // Analyze timestamps
        let timestampAnalysis = analyzeTimestamps(original: original, comparison: comparison)

        // Generate findings from differences
        findings.append(contentsOf: generateFindings(from: differences, timestampAnalysis: timestampAnalysis))

        let pdfMetadataMatch = pdfMetaDiffs.filter { $0.isSignificant }.isEmpty
        let fileInfoMatch = fileInfoDiffs.filter { $0.isSignificant }.isEmpty

        return MetadataComparison(
            pdfMetadataMatch: pdfMetadataMatch,
            fileInfoMatch: fileInfoMatch,
            timestampAnalysis: timestampAnalysis,
            differences: differences,
            findings: findings
        )
    }

    // MARK: - Compare PDF Metadata
    private func comparePDFMetadata(
        _ original: PDFAnalysis.PDFMetadata,
        _ comparison: PDFAnalysis.PDFMetadata
    ) -> [MetadataDifference] {
        var diffs: [MetadataDifference] = []

        // Standard metadata
        if original.title != comparison.title {
            diffs.append(MetadataDifference(
                field: "Title",
                originalValue: original.title,
                comparisonValue: comparison.title,
                isSignificant: false
            ))
        }

        if original.author != comparison.author {
            diffs.append(MetadataDifference(
                field: "Author",
                originalValue: original.author,
                comparisonValue: comparison.author,
                isSignificant: true
            ))
        }

        if original.creator != comparison.creator {
            diffs.append(MetadataDifference(
                field: "Creator",
                originalValue: original.creator,
                comparisonValue: comparison.creator,
                isSignificant: true
            ))
        }

        if original.producer != comparison.producer {
            diffs.append(MetadataDifference(
                field: "Producer",
                originalValue: original.producer,
                comparisonValue: comparison.producer,
                isSignificant: true
            ))
        }

        if original.version != comparison.version {
            diffs.append(MetadataDifference(
                field: "PDF Version",
                originalValue: original.version,
                comparisonValue: comparison.version,
                isSignificant: true
            ))
        }

        if original.isEncrypted != comparison.isEncrypted {
            diffs.append(MetadataDifference(
                field: "Encrypted",
                originalValue: String(original.isEncrypted),
                comparisonValue: String(comparison.isEncrypted),
                isSignificant: true
            ))
        }

        // Extended PDF internals - these are forensically significant
        if original.documentID?.permanent != comparison.documentID?.permanent {
            diffs.append(MetadataDifference(
                field: "Document ID (Permanent)",
                originalValue: original.documentID?.permanent,
                comparisonValue: comparison.documentID?.permanent,
                isSignificant: true
            ))
        }

        if original.documentID?.changing != comparison.documentID?.changing {
            diffs.append(MetadataDifference(
                field: "Document ID (Instance)",
                originalValue: original.documentID?.changing,
                comparisonValue: comparison.documentID?.changing,
                isSignificant: true
            ))
        }

        if original.isLinearized != comparison.isLinearized {
            diffs.append(MetadataDifference(
                field: "Linearized",
                originalValue: String(original.isLinearized),
                comparisonValue: String(comparison.isLinearized),
                isSignificant: false
            ))
        }

        if original.incrementalUpdates != comparison.incrementalUpdates {
            diffs.append(MetadataDifference(
                field: "Incremental Updates",
                originalValue: String(original.incrementalUpdates),
                comparisonValue: String(comparison.incrementalUpdates),
                isSignificant: true
            ))
        }

        if abs(original.objectCount - comparison.objectCount) > 10 {
            diffs.append(MetadataDifference(
                field: "Object Count",
                originalValue: String(original.objectCount),
                comparisonValue: String(comparison.objectCount),
                isSignificant: true
            ))
        }

        if original.hasJavaScript != comparison.hasJavaScript {
            diffs.append(MetadataDifference(
                field: "Contains JavaScript",
                originalValue: String(original.hasJavaScript),
                comparisonValue: String(comparison.hasJavaScript),
                isSignificant: true
            ))
        }

        if original.hasDigitalSignature != comparison.hasDigitalSignature {
            diffs.append(MetadataDifference(
                field: "Digital Signature",
                originalValue: String(original.hasDigitalSignature),
                comparisonValue: String(comparison.hasDigitalSignature),
                isSignificant: true
            ))
        }

        // Compare fonts in detail
        let fontDiffs = compareFonts(original: original.fonts, comparison: comparison.fonts)
        diffs.append(contentsOf: fontDiffs)

        if original.xrefType != comparison.xrefType {
            diffs.append(MetadataDifference(
                field: "XRef Type",
                originalValue: original.xrefType,
                comparisonValue: comparison.xrefType,
                isSignificant: true
            ))
        }

        if original.pdfConformance != comparison.pdfConformance {
            diffs.append(MetadataDifference(
                field: "PDF Conformance",
                originalValue: original.pdfConformance,
                comparisonValue: comparison.pdfConformance,
                isSignificant: false
            ))
        }

        return diffs
    }

    // MARK: - Compare Fonts
    private func compareFonts(
        original: [PDFAnalysis.PDFMetadata.FontInfo],
        comparison: [PDFAnalysis.PDFMetadata.FontInfo]
    ) -> [MetadataDifference] {
        var diffs: [MetadataDifference] = []

        let origFontNames = Set(original.map { $0.name })
        let compFontNames = Set(comparison.map { $0.name })

        // Fonts only in original (removed)
        let removedFonts = origFontNames.subtracting(compFontNames)
        if !removedFonts.isEmpty {
            diffs.append(MetadataDifference(
                field: "Fonts Removed",
                originalValue: removedFonts.sorted().joined(separator: ", "),
                comparisonValue: nil,
                isSignificant: true
            ))
        }

        // Fonts only in comparison (added)
        let addedFonts = compFontNames.subtracting(origFontNames)
        if !addedFonts.isEmpty {
            diffs.append(MetadataDifference(
                field: "Fonts Added",
                originalValue: nil,
                comparisonValue: addedFonts.sorted().joined(separator: ", "),
                isSignificant: true
            ))
        }

        // Check for fonts with same name but different properties
        let commonFonts = origFontNames.intersection(compFontNames)
        for fontName in commonFonts {
            guard let origFont = original.first(where: { $0.name == fontName }),
                  let compFont = comparison.first(where: { $0.name == fontName }) else { continue }

            // Check if embedding status changed
            if origFont.isEmbedded != compFont.isEmbedded {
                let origStatus = origFont.isEmbedded ? "embedded" : "not embedded"
                let compStatus = compFont.isEmbedded ? "embedded" : "not embedded"
                diffs.append(MetadataDifference(
                    field: "Font '\(fontName)' Embedding",
                    originalValue: origStatus,
                    comparisonValue: compStatus,
                    isSignificant: true
                ))
            }

            // Check if font type changed
            if origFont.type != compFont.type && origFont.type != nil && compFont.type != nil {
                diffs.append(MetadataDifference(
                    field: "Font '\(fontName)' Type",
                    originalValue: origFont.type,
                    comparisonValue: compFont.type,
                    isSignificant: true
                ))
            }

            // Check if subsetting changed
            if origFont.isSubset != compFont.isSubset {
                let origStatus = origFont.isSubset ? "subset" : "full"
                let compStatus = compFont.isSubset ? "subset" : "full"
                diffs.append(MetadataDifference(
                    field: "Font '\(fontName)' Subsetting",
                    originalValue: origStatus,
                    comparisonValue: compStatus,
                    isSignificant: false
                ))
            }
        }

        // Overall font count difference
        if original.count != comparison.count {
            diffs.append(MetadataDifference(
                field: "Font Count",
                originalValue: String(original.count),
                comparisonValue: String(comparison.count),
                isSignificant: true
            ))
        }

        return diffs
    }

    // MARK: - Compare File Info
    private func compareFileInfo(
        _ original: PDFAnalysis.FileInfo,
        _ comparison: PDFAnalysis.FileInfo
    ) -> [MetadataDifference] {
        var diffs: [MetadataDifference] = []

        if original.fileSize != comparison.fileSize {
            diffs.append(MetadataDifference(
                field: "File Size",
                originalValue: original.formattedSize,
                comparisonValue: comparison.formattedSize,
                isSignificant: abs(original.fileSize - comparison.fileSize) > 1024
            ))
        }

        // Quarantine status differences are forensically significant
        if original.wasQuarantined != comparison.wasQuarantined {
            diffs.append(MetadataDifference(
                field: "Was Quarantined",
                originalValue: String(original.wasQuarantined),
                comparisonValue: String(comparison.wasQuarantined),
                isSignificant: true
            ))
        }

        if original.quarantineSource != comparison.quarantineSource {
            diffs.append(MetadataDifference(
                field: "Quarantine Source",
                originalValue: original.quarantineSource,
                comparisonValue: comparison.quarantineSource,
                isSignificant: true
            ))
        }

        // Compare download sources
        let origDownload = original.downloadedFrom?.joined(separator: ", ")
        let compDownload = comparison.downloadedFrom?.joined(separator: ", ")
        if origDownload != compDownload {
            diffs.append(MetadataDifference(
                field: "Downloaded From",
                originalValue: origDownload,
                comparisonValue: compDownload,
                isSignificant: true
            ))
        }

        return diffs
    }

    // MARK: - Analyze Timestamps
    private func analyzeTimestamps(original: PDFAnalysis, comparison: PDFAnalysis) -> TimestampAnalysis {
        let origCreate = original.metadata.creationDate
        let origMod = original.metadata.modificationDate
        let compCreate = comparison.metadata.creationDate
        let compMod = comparison.metadata.modificationDate

        var hasAnomalies = false
        var anomalyDescription: String? = nil

        // Check for suspicious timestamp patterns

        // 1. Creation date after modification date
        if let create = compCreate, let mod = compMod, create > mod {
            hasAnomalies = true
            anomalyDescription = "Creation date is after modification date"
        }

        // 2. Future dates
        let now = Date()
        if let create = compCreate, create > now {
            hasAnomalies = true
            anomalyDescription = "Creation date is in the future"
        }
        if let mod = compMod, mod > now {
            hasAnomalies = true
            anomalyDescription = "Modification date is in the future"
        }

        // 3. Significant date differences between documents
        if let origCreate = origCreate, let compCreate = compCreate {
            let diff = abs(origCreate.timeIntervalSince(compCreate))
            if diff > 86400 { // More than 1 day difference
                hasAnomalies = true
                anomalyDescription = "Creation dates differ by more than 1 day"
            }
        }

        // 4. File system dates vs PDF metadata dates mismatch
        if let pdfMod = compMod, let fileMod = comparison.fileInfo.modificationDate {
            let diff = abs(pdfMod.timeIntervalSince(fileMod))
            if diff > 3600 { // More than 1 hour difference
                hasAnomalies = true
                anomalyDescription = "PDF metadata date differs from file system date"
            }
        }

        return TimestampAnalysis(
            originalCreation: origCreate,
            originalModification: origMod,
            comparisonCreation: compCreate,
            comparisonModification: compMod,
            hasAnomalies: hasAnomalies,
            anomalyDescription: anomalyDescription
        )
    }

    // MARK: - Generate Findings
    private func generateFindings(
        from differences: [MetadataDifference],
        timestampAnalysis: TimestampAnalysis
    ) -> [Finding] {
        var findings: [Finding] = []

        // Findings from metadata differences
        for diff in differences where diff.isSignificant {
            let severity: Severity
            switch diff.field {
            case "Producer", "Creator", "Document ID (Permanent)", "Document ID (Instance)":
                severity = .high
            case "Fonts Added", "Fonts Removed":
                severity = .high
            case _ where diff.field.contains("Font '") && diff.field.contains("Embedding"):
                severity = .high
            case _ where diff.field.contains("Font '") && diff.field.contains("Type"):
                severity = .medium
            case "PDF Version", "Encrypted", "Incremental Updates", "Contains JavaScript", "Digital Signature":
                severity = .medium
            case "XRef Type", "Object Count", "Font Count":
                severity = .medium
            case "Was Quarantined", "Downloaded From", "Quarantine Source":
                severity = .info
            case _ where diff.field.contains("Subsetting"):
                severity = .low
            default:
                severity = .low
            }

            // Create appropriate title based on field
            var title = "\(diff.field) Mismatch"
            var description = "The \(diff.field.lowercased()) differs between documents"

            // Special handling for certain fields
            if diff.field == "Contains JavaScript" {
                if diff.comparisonValue == "true" && diff.originalValue == "false" {
                    title = "JavaScript Added"
                    description = "The comparison document contains JavaScript that the original does not"
                } else if diff.comparisonValue == "false" && diff.originalValue == "true" {
                    title = "JavaScript Removed"
                    description = "JavaScript present in original was removed from comparison"
                }
            } else if diff.field == "Digital Signature" {
                if diff.comparisonValue == "true" && diff.originalValue == "false" {
                    title = "Digital Signature Added"
                    description = "The comparison document has a digital signature"
                } else if diff.comparisonValue == "false" && diff.originalValue == "true" {
                    title = "Digital Signature Removed"
                    description = "Digital signature present in original was removed"
                }
            } else if diff.field == "Incremental Updates" {
                title = "Incremental Update Count Differs"
                description = "Different number of modification layers detected"
            } else if diff.field == "Document ID (Permanent)" {
                title = "Different Document Origin"
                description = "Documents have different permanent IDs, suggesting different origins"
            }

            findings.append(Finding(
                category: .metadata,
                severity: severity,
                title: title,
                description: description,
                details: [
                    "Original": diff.originalValue ?? "(none)",
                    "Comparison": diff.comparisonValue ?? "(none)"
                ]
            ))
        }

        // Findings from timestamp analysis
        if timestampAnalysis.hasAnomalies, let desc = timestampAnalysis.anomalyDescription {
            findings.append(Finding(
                category: .timestamp,
                severity: .high,
                title: "Timestamp Anomaly Detected",
                description: desc
            ))
        }

        return findings
    }

    // MARK: - Build Metadata Tree
    func buildMetadataTree(from analysis: PDFAnalysis, label: String) -> MetadataTreeNode {
        var children: [MetadataTreeNode] = []
        let meta = analysis.metadata
        let fileInfo = analysis.fileInfo

        // PDF Metadata section
        var pdfMetaChildren: [MetadataTreeNode] = []

        if let title = meta.title { pdfMetaChildren.append(MetadataTreeNode(name: "Title", value: title)) }
        if let author = meta.author { pdfMetaChildren.append(MetadataTreeNode(name: "Author", value: author)) }
        if let subject = meta.subject { pdfMetaChildren.append(MetadataTreeNode(name: "Subject", value: subject)) }
        if let creator = meta.creator { pdfMetaChildren.append(MetadataTreeNode(name: "Creator", value: creator)) }
        if let producer = meta.producer { pdfMetaChildren.append(MetadataTreeNode(name: "Producer", value: producer)) }
        if let version = meta.version { pdfMetaChildren.append(MetadataTreeNode(name: "PDF Version", value: version)) }
        if let created = meta.creationDate { pdfMetaChildren.append(MetadataTreeNode(name: "Created", value: created.formattedForDisplay)) }
        if let modified = meta.modificationDate { pdfMetaChildren.append(MetadataTreeNode(name: "Modified", value: modified.formattedForDisplay)) }
        pdfMetaChildren.append(MetadataTreeNode(name: "Encrypted", value: meta.isEncrypted ? "Yes" : "No"))
        pdfMetaChildren.append(MetadataTreeNode(name: "Page Count", value: "\(analysis.pageCount)"))
        pdfMetaChildren.append(MetadataTreeNode(name: "Allows Printing", value: meta.allowsPrinting ? "Yes" : "No"))
        pdfMetaChildren.append(MetadataTreeNode(name: "Allows Copying", value: meta.allowsCopying ? "Yes" : "No"))

        children.append(MetadataTreeNode(name: "PDF Metadata", children: pdfMetaChildren))

        // PDF Internals section (forensic data)
        var internalsChildren: [MetadataTreeNode] = []

        if let docID = meta.documentID {
            if let perm = docID.permanent {
                internalsChildren.append(MetadataTreeNode(name: "Document ID (Permanent)", value: perm))
            }
            if let changing = docID.changing {
                internalsChildren.append(MetadataTreeNode(name: "Document ID (Instance)", value: changing))
            }
        }
        internalsChildren.append(MetadataTreeNode(name: "Linearized", value: meta.isLinearized ? "Yes" : "No"))
        internalsChildren.append(MetadataTreeNode(name: "Has XMP Metadata", value: meta.hasXMPMetadata ? "Yes" : "No"))
        internalsChildren.append(MetadataTreeNode(name: "Incremental Updates", value: "\(meta.incrementalUpdates)"))
        internalsChildren.append(MetadataTreeNode(name: "Object Count", value: "\(meta.objectCount)"))
        if let xref = meta.xrefType { internalsChildren.append(MetadataTreeNode(name: "XRef Type", value: xref)) }
        internalsChildren.append(MetadataTreeNode(name: "Tagged PDF", value: meta.isTaggedPDF ? "Yes" : "No"))
        if let conformance = meta.pdfConformance { internalsChildren.append(MetadataTreeNode(name: "Conformance", value: conformance)) }

        children.append(MetadataTreeNode(name: "PDF Internals", children: internalsChildren))

        // Security & Content section
        var securityChildren: [MetadataTreeNode] = []

        securityChildren.append(MetadataTreeNode(name: "Has JavaScript", value: meta.hasJavaScript ? "Yes" : "No"))
        securityChildren.append(MetadataTreeNode(name: "Has Digital Signature", value: meta.hasDigitalSignature ? "Yes" : "No"))
        securityChildren.append(MetadataTreeNode(name: "Embedded Files", value: "\(meta.embeddedFileCount)"))
        securityChildren.append(MetadataTreeNode(name: "Annotations", value: "\(meta.annotationCount)"))
        securityChildren.append(MetadataTreeNode(name: "Form Fields", value: "\(meta.formFieldCount)"))

        children.append(MetadataTreeNode(name: "Security & Content", children: securityChildren))

        // Fonts section
        var fontChildren: [MetadataTreeNode] = []
        fontChildren.append(MetadataTreeNode(name: "Total Fonts", value: "\(meta.fontCount)"))

        for font in meta.fonts {
            var fontDetails: [MetadataTreeNode] = []
            if let type = font.type {
                fontDetails.append(MetadataTreeNode(name: "Type", value: type))
            }
            fontDetails.append(MetadataTreeNode(name: "Embedded", value: font.isEmbedded ? "Yes" : "No"))
            fontDetails.append(MetadataTreeNode(name: "Subset", value: font.isSubset ? "Yes" : "No"))
            if let baseFont = font.baseFont, baseFont != font.name {
                fontDetails.append(MetadataTreeNode(name: "Base Font", value: baseFont))
            }

            fontChildren.append(MetadataTreeNode(name: font.name, children: fontDetails))
        }

        children.append(MetadataTreeNode(name: "Fonts", children: fontChildren))

        // File Info section
        var fileChildren: [MetadataTreeNode] = []

        fileChildren.append(MetadataTreeNode(name: "File Name", value: fileInfo.fileName))
        fileChildren.append(MetadataTreeNode(name: "File Size", value: fileInfo.formattedSize))
        fileChildren.append(MetadataTreeNode(name: "Path", value: fileInfo.filePath))
        if let created = fileInfo.creationDate { fileChildren.append(MetadataTreeNode(name: "Created", value: created.formattedForDisplay)) }
        if let modified = fileInfo.modificationDate { fileChildren.append(MetadataTreeNode(name: "Modified", value: modified.formattedForDisplay)) }

        children.append(MetadataTreeNode(name: "File System", children: fileChildren))

        // macOS Extended Attributes section
        var extAttrChildren: [MetadataTreeNode] = []

        extAttrChildren.append(MetadataTreeNode(name: "Was Quarantined", value: fileInfo.wasQuarantined ? "Yes" : "No"))
        if let source = fileInfo.quarantineSource {
            extAttrChildren.append(MetadataTreeNode(name: "Quarantine Agent", value: source))
        }
        if let urls = fileInfo.downloadedFrom, !urls.isEmpty {
            for (i, url) in urls.enumerated() {
                extAttrChildren.append(MetadataTreeNode(name: "Download URL \(i + 1)", value: url))
            }
        }

        // Show other extended attributes
        let knownAttrs = ["com.apple.quarantine", "com.apple.metadata:kMDItemWhereFroms"]
        let otherAttrs = fileInfo.extendedAttributes.filter { !knownAttrs.contains($0.key) }
        for (key, value) in otherAttrs.sorted(by: { $0.key < $1.key }) {
            let shortKey = key.replacingOccurrences(of: "com.apple.", with: "")
            extAttrChildren.append(MetadataTreeNode(name: shortKey, value: value))
        }

        if !extAttrChildren.isEmpty {
            children.append(MetadataTreeNode(name: "Extended Attributes", children: extAttrChildren))
        }

        return MetadataTreeNode(name: label, children: children)
    }
}
