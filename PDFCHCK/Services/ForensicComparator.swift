import Foundation
import AppKit

// MARK: - Forensic Comparator
actor ForensicComparator {

    // MARK: - Compare Forensic Results
    func compare(
        original: ForensicResult,
        comparison: ForensicResult,
        originalAnalysis: PDFAnalysis,
        comparisonAnalysis: PDFAnalysis
    ) async -> ForensicComparisonResult {
        var findings: [Finding] = []

        // Compare embedded images
        findings.append(contentsOf: compareEmbeddedImages(original: original.embeddedImages, comparison: comparison.embeddedImages))

        // Compare links
        findings.append(contentsOf: compareLinks(original: original.links, comparison: comparison.links))

        // Compare layers
        findings.append(contentsOf: compareLayers(original: original.layers, comparison: comparison.layers))

        // Analyze signatures
        findings.append(contentsOf: analyzeSignatures(original: original.signatures, comparison: comparison.signatures))

        // Report hidden content
        findings.append(contentsOf: reportHiddenContent(original: original.hiddenContent, comparison: comparison.hiddenContent))

        // Compare XMP history
        findings.append(contentsOf: compareXMPHistory(original: original.xmpHistory, comparison: comparison.xmpHistory))

        // Report redactions
        findings.append(contentsOf: reportRedactions(original: original.redactions, comparison: comparison.redactions))

        // Report suspicious elements
        findings.append(contentsOf: reportSuspiciousElements(original: original.suspiciousElements, comparison: comparison.suspiciousElements))

        // Character-level text comparison
        findings.append(contentsOf: characterLevelComparison(original: originalAnalysis, comparison: comparisonAnalysis))

        return ForensicComparisonResult(findings: findings)
    }

    // MARK: - Compare Embedded Images
    private func compareEmbeddedImages(
        original: [PDFAnalysis.EmbeddedImage],
        comparison: [PDFAnalysis.EmbeddedImage]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Compare by hash to find changed images
        let origHashes = Set(original.map { $0.dataHash })
        let compHashes = Set(comparison.map { $0.dataHash })

        let addedImages = compHashes.subtracting(origHashes)
        let removedImages = origHashes.subtracting(compHashes)

        if !addedImages.isEmpty {
            findings.append(Finding(
                category: .images,
                severity: .high,
                title: "New Images Added",
                description: "\(addedImages.count) image(s) added in comparison document"
            ))
        }

        if !removedImages.isEmpty {
            findings.append(Finding(
                category: .images,
                severity: .high,
                title: "Images Removed",
                description: "\(removedImages.count) image(s) removed from comparison document"
            ))
        }

        // Check for dimension changes on same-position images
        for (index, origImg) in original.enumerated() {
            if index < comparison.count {
                let compImg = comparison[index]
                if origImg.width != compImg.width || origImg.height != compImg.height {
                    findings.append(Finding(
                        category: .images,
                        severity: .medium,
                        title: "Image Dimensions Changed",
                        description: "Image \(index + 1): \(origImg.width)x\(origImg.height) → \(compImg.width)x\(compImg.height)",
                        pageNumber: origImg.pageNumber
                    ))
                }
            }
        }

        // Check for compression changes
        for (index, origImg) in original.enumerated() {
            if index < comparison.count {
                let compImg = comparison[index]
                if origImg.filter != compImg.filter {
                    findings.append(Finding(
                        category: .images,
                        severity: .low,
                        title: "Image Compression Changed",
                        description: "Image \(index + 1): \(origImg.filter ?? "none") → \(compImg.filter ?? "none")",
                        pageNumber: origImg.pageNumber
                    ))
                }
            }
        }

        return findings
    }

    // MARK: - Compare Links
    private func compareLinks(
        original: [PDFAnalysis.PDFLink],
        comparison: [PDFAnalysis.PDFLink]
    ) -> [Finding] {
        var findings: [Finding] = []

        let origURLs = Set(original.compactMap { $0.url })
        let compURLs = Set(comparison.compactMap { $0.url })

        let addedURLs = compURLs.subtracting(origURLs)
        let removedURLs = origURLs.subtracting(compURLs)

        for url in addedURLs {
            findings.append(Finding(
                category: .links,
                severity: .medium,
                title: "New Link Added",
                description: "Link added: \(url)"
            ))
        }

        for url in removedURLs {
            findings.append(Finding(
                category: .links,
                severity: .medium,
                title: "Link Removed",
                description: "Link removed: \(url)"
            ))
        }

        // Check for suspicious links in comparison
        for link in comparison {
            if let url = link.url?.lowercased() {
                if url.contains("bit.ly") || url.contains("tinyurl") || url.contains("goo.gl") {
                    findings.append(Finding(
                        category: .security,
                        severity: .medium,
                        title: "Shortened URL Detected",
                        description: "Document contains shortened URL: \(link.url ?? "")",
                        pageNumber: link.pageNumber
                    ))
                }
            }
        }

        // Compare link counts
        if original.count != comparison.count {
            findings.append(Finding(
                category: .links,
                severity: .low,
                title: "Link Count Changed",
                description: "Links: \(original.count) → \(comparison.count)"
            ))
        }

        return findings
    }

    // MARK: - Compare Layers
    private func compareLayers(
        original: [PDFAnalysis.PDFLayer],
        comparison: [PDFAnalysis.PDFLayer]
    ) -> [Finding] {
        var findings: [Finding] = []

        let origNames = Set(original.map { $0.name })
        let compNames = Set(comparison.map { $0.name })

        let addedLayers = compNames.subtracting(origNames)
        let removedLayers = origNames.subtracting(compNames)

        for name in addedLayers {
            findings.append(Finding(
                category: .hidden,
                severity: .high,
                title: "New Layer Added",
                description: "Layer '\(name)' added in comparison document"
            ))
        }

        for name in removedLayers {
            findings.append(Finding(
                category: .hidden,
                severity: .high,
                title: "Layer Removed",
                description: "Layer '\(name)' removed from comparison document"
            ))
        }

        // Check for visibility changes
        for origLayer in original {
            if let compLayer = comparison.first(where: { $0.name == origLayer.name }) {
                if origLayer.isVisible != compLayer.isVisible {
                    findings.append(Finding(
                        category: .hidden,
                        severity: .medium,
                        title: "Layer Visibility Changed",
                        description: "Layer '\(origLayer.name)': \(origLayer.isVisible ? "visible" : "hidden") → \(compLayer.isVisible ? "visible" : "hidden")"
                    ))
                }
            }
        }

        return findings
    }

    // MARK: - Analyze Signatures
    private func analyzeSignatures(
        original: [PDFAnalysis.DigitalSignature],
        comparison: [PDFAnalysis.DigitalSignature]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Check if signatures were added or removed
        if original.count != comparison.count {
            if comparison.count > original.count {
                findings.append(Finding(
                    category: .signatures,
                    severity: .info,
                    title: "Signature Added",
                    description: "Comparison document has \(comparison.count - original.count) more signature(s)"
                ))
            } else {
                findings.append(Finding(
                    category: .signatures,
                    severity: .critical,
                    title: "Signature Removed",
                    description: "\(original.count - comparison.count) signature(s) removed from comparison document"
                ))
            }
        }

        // Check signature validity
        for sig in comparison {
            if !sig.isValid {
                findings.append(Finding(
                    category: .signatures,
                    severity: .critical,
                    title: "Invalid Signature",
                    description: sig.validationMessage
                ))
            }

            if !sig.coversWholeDocument {
                findings.append(Finding(
                    category: .signatures,
                    severity: .high,
                    title: "Partial Signature Coverage",
                    description: "Signature does not cover entire document - modifications may exist after signing"
                ))
            }
        }

        // Check for different signers
        let origSigners = Set(original.compactMap { $0.signerName })
        let compSigners = Set(comparison.compactMap { $0.signerName })

        if origSigners != compSigners {
            findings.append(Finding(
                category: .signatures,
                severity: .high,
                title: "Different Signers",
                description: "Documents signed by different parties"
            ))
        }

        return findings
    }

    // MARK: - Report Hidden Content
    private func reportHiddenContent(
        original: [PDFAnalysis.HiddenContent],
        comparison: [PDFAnalysis.HiddenContent]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Report hidden content only in comparison
        let compHiddenTypes = comparison.map { $0.type }

        for hidden in comparison {
            let severity: Severity
            switch hidden.type {
            case .invisibleText, .whiteText:
                severity = .high
            case .hiddenLayer:
                severity = .medium
            case .offPageContent:
                severity = .high
            case .coveredContent:
                severity = .high
            case .tinyText:
                severity = .medium
            }

            findings.append(Finding(
                category: .hidden,
                severity: severity,
                title: hidden.type.rawValue,
                description: hidden.description,
                pageNumber: hidden.pageNumber
            ))
        }

        // Note if hidden content differs
        if original.count != comparison.count {
            findings.append(Finding(
                category: .hidden,
                severity: .medium,
                title: "Hidden Content Count Differs",
                description: "Original: \(original.count), Comparison: \(comparison.count)"
            ))
        }

        return findings
    }

    // MARK: - Compare XMP History
    private func compareXMPHistory(
        original: [PDFAnalysis.XMPHistoryEntry],
        comparison: [PDFAnalysis.XMPHistoryEntry]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Check if comparison has more history entries (additional modifications)
        if comparison.count > original.count {
            findings.append(Finding(
                category: .forensic,
                severity: .medium,
                title: "Additional Modification History",
                description: "Comparison document has \(comparison.count - original.count) more modification entries"
            ))
        }

        // Report all tools used in comparison
        let compTools = Set(comparison.compactMap { $0.softwareAgent })
        let origTools = Set(original.compactMap { $0.softwareAgent })

        let newTools = compTools.subtracting(origTools)
        for tool in newTools {
            findings.append(Finding(
                category: .forensic,
                severity: .high,
                title: "Modified With New Tool",
                description: "Document modified with: \(tool)"
            ))
        }

        return findings
    }

    // MARK: - Report Redactions
    private func reportRedactions(
        original: [PDFAnalysis.Redaction],
        comparison: [PDFAnalysis.Redaction]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Check for improper redactions in comparison
        for redaction in comparison {
            if redaction.hasHiddenContent {
                findings.append(Finding(
                    category: .security,
                    severity: .critical,
                    title: "Improper Redaction",
                    description: "Redaction on page \(redaction.pageNumber) covers but does not remove content - text can be extracted",
                    pageNumber: redaction.pageNumber
                ))
            }
        }

        // Note redaction changes
        if comparison.count != original.count {
            if comparison.count > original.count {
                findings.append(Finding(
                    category: .forensic,
                    severity: .medium,
                    title: "Redactions Added",
                    description: "\(comparison.count - original.count) new redaction(s) in comparison document"
                ))
            } else {
                findings.append(Finding(
                    category: .forensic,
                    severity: .high,
                    title: "Redactions Removed",
                    description: "\(original.count - comparison.count) redaction(s) removed from comparison document"
                ))
            }
        }

        return findings
    }

    // MARK: - Report Suspicious Elements
    private func reportSuspiciousElements(
        original: [PDFAnalysis.SuspiciousElement],
        comparison: [PDFAnalysis.SuspiciousElement]
    ) -> [Finding] {
        var findings: [Finding] = []

        // Report all suspicious elements in comparison
        for element in comparison {
            findings.append(Finding(
                category: .security,
                severity: element.severity,
                title: element.type.rawValue,
                description: element.description,
                pageNumber: element.pageNumber
            ))
        }

        // Note new suspicious elements not in original
        let origTypes = Set(original.map { $0.type })
        let compTypes = Set(comparison.map { $0.type })
        let newTypes = compTypes.subtracting(origTypes)

        for type in newTypes {
            if let element = comparison.first(where: { $0.type == type }) {
                findings.append(Finding(
                    category: .forensic,
                    severity: .high,
                    title: "New Suspicious Element",
                    description: "\(type.rawValue) added in comparison document"
                ))
            }
        }

        return findings
    }

    // MARK: - Character Level Comparison
    private func characterLevelComparison(
        original: PDFAnalysis,
        comparison: PDFAnalysis
    ) -> [Finding] {
        var findings: [Finding] = []

        for page in 0..<min(original.pageCount, comparison.pageCount) {
            guard let origText = original.pageTexts[page],
                  let compText = comparison.pageTexts[page] else { continue }

            let charDiffs = findCharacterDifferences(original: origText, comparison: compText)

            for diff in charDiffs {
                // Check for suspicious single-character substitutions
                if diff.isSuspiciousSubstitution {
                    findings.append(Finding(
                        category: .text,
                        severity: .high,
                        title: "Suspicious Character Change",
                        description: "'\(diff.originalChar)' → '\(diff.newChar)' at position \(diff.position)",
                        details: [
                            "Context": diff.context,
                            "Type": diff.substitutionType
                        ],
                        pageNumber: page + 1
                    ))
                }
            }
        }

        return findings
    }

    private func findCharacterDifferences(original: String, comparison: String) -> [CharacterDiff] {
        var diffs: [CharacterDiff] = []

        let origChars = Array(original)
        let compChars = Array(comparison)

        // Simple character-by-character comparison for similar-length strings
        if abs(origChars.count - compChars.count) < origChars.count / 10 {
            for i in 0..<min(origChars.count, compChars.count) {
                if origChars[i] != compChars[i] {
                    let contextStart = max(0, i - 10)
                    let contextEnd = min(origChars.count, i + 10)
                    let context = String(origChars[contextStart..<contextEnd])

                    let diff = CharacterDiff(
                        position: i,
                        originalChar: String(origChars[i]),
                        newChar: String(compChars[i]),
                        context: context
                    )
                    diffs.append(diff)
                }
            }
        }

        return diffs
    }
}

// MARK: - Character Diff
struct CharacterDiff {
    let position: Int
    let originalChar: String
    let newChar: String
    let context: String

    var isSuspiciousSubstitution: Bool {
        // Common fraudulent substitutions
        let suspiciousPairs: [(String, String)] = [
            ("0", "O"), ("O", "0"),
            ("1", "l"), ("l", "1"),
            ("1", "I"), ("I", "1"),
            ("5", "S"), ("S", "5"),
            ("8", "B"), ("B", "8"),
            ("2", "Z"), ("Z", "2"),
            ("6", "G"), ("G", "6"),
            (".", ","), (",", "."),
            ("0", "o"), ("o", "0"),
        ]

        for (a, b) in suspiciousPairs {
            if (originalChar == a && newChar == b) || (originalChar == b && newChar == a) {
                return true
            }
        }

        // Check for space/non-space changes in numbers
        if originalChar.first?.isNumber == true || newChar.first?.isNumber == true {
            if originalChar.first?.isWhitespace == true || newChar.first?.isWhitespace == true {
                return true
            }
        }

        return false
    }

    var substitutionType: String {
        if originalChar.first?.isNumber == true && newChar.first?.isLetter == true {
            return "Number to Letter"
        }
        if originalChar.first?.isLetter == true && newChar.first?.isNumber == true {
            return "Letter to Number"
        }
        if originalChar == "." && newChar == "," || originalChar == "," && newChar == "." {
            return "Decimal Separator Change"
        }
        return "Character Substitution"
    }
}

// MARK: - Forensic Comparison Result
struct ForensicComparisonResult {
    let findings: [Finding]
}
