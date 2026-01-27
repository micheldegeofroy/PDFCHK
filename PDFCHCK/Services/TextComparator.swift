import Foundation

// MARK: - Text Comparator
actor TextComparator {

    // MARK: - Compare Documents
    func compare(original: PDFAnalysis, comparison: PDFAnalysis) async -> TextComparisonResult {
        let pageCount = min(original.pageCount, comparison.pageCount)
        var pageResults: [PageTextResult] = []
        var allDiffOperations: [DiffOperation] = []

        var totalCharsOriginal = 0
        var totalCharsComparison = 0

        for pageNum in 0..<pageCount {
            let origText = original.pageTexts[pageNum] ?? ""
            let compText = comparison.pageTexts[pageNum] ?? ""

            totalCharsOriginal += origText.count
            totalCharsComparison += compText.count

            let similarity = DiffHelpers.calculateSimilarity(original: origText, modified: compText)
            let differences = findDifferences(original: origText, modified: compText)
            let diffOps = DiffHelpers.diff(original: origText, modified: compText)

            allDiffOperations.append(contentsOf: diffOps)

            pageResults.append(PageTextResult(
                pageNumber: pageNum + 1,
                similarity: similarity,
                originalText: origText,
                comparisonText: compText,
                differences: differences
            ))
        }

        // Handle extra pages in comparison document
        if comparison.pageCount > original.pageCount {
            for pageNum in original.pageCount..<comparison.pageCount {
                let compText = comparison.pageTexts[pageNum] ?? ""
                totalCharsComparison += compText.count

                pageResults.append(PageTextResult(
                    pageNumber: pageNum + 1,
                    similarity: 0.0,
                    originalText: "",
                    comparisonText: compText,
                    differences: [TextDifference(
                        type: .insertion,
                        originalRange: nil,
                        comparisonRange: 0..<compText.count,
                        originalText: "",
                        comparisonText: compText
                    )]
                ))
            }
        }

        // Calculate overall similarity
        let overallSimilarity = calculateOverallSimilarity(pageResults: pageResults)

        return TextComparisonResult(
            similarity: overallSimilarity,
            pageResults: pageResults,
            totalCharactersOriginal: totalCharsOriginal,
            totalCharactersComparison: totalCharsComparison,
            diffOperations: allDiffOperations
        )
    }

    // MARK: - Find Differences
    private func findDifferences(original: String, modified: String) -> [TextDifference] {
        if original == modified {
            return []
        }

        let diffOps = DiffHelpers.diff(original: original, modified: modified)
        var differences: [TextDifference] = []

        var origPos = 0
        var modPos = 0

        for op in diffOps {
            switch op {
            case .equal(let text):
                origPos += text.count
                modPos += text.count

            case .delete(let text):
                differences.append(TextDifference(
                    type: .deletion,
                    originalRange: origPos..<(origPos + text.count),
                    comparisonRange: nil,
                    originalText: text,
                    comparisonText: ""
                ))
                origPos += text.count

            case .insert(let text):
                differences.append(TextDifference(
                    type: .insertion,
                    originalRange: nil,
                    comparisonRange: modPos..<(modPos + text.count),
                    originalText: "",
                    comparisonText: text
                ))
                modPos += text.count
            }
        }

        return differences
    }

    // MARK: - Calculate Overall Similarity
    private func calculateOverallSimilarity(pageResults: [PageTextResult]) -> Double {
        if pageResults.isEmpty { return 1.0 }

        // Weight by text length
        var totalChars = 0
        var weightedSimilarity = 0.0

        for result in pageResults {
            let pageChars = max(result.originalText.count, result.comparisonText.count)
            totalChars += pageChars
            weightedSimilarity += result.similarity * Double(pageChars)
        }

        return totalChars > 0 ? weightedSimilarity / Double(totalChars) : 1.0
    }

    // MARK: - Generate Findings
    func generateFindings(from result: TextComparisonResult) -> [Finding] {
        var findings: [Finding] = []

        // Overall text similarity finding
        if result.similarity < 0.95 {
            let severity: Severity
            if result.similarity < 0.5 {
                severity = .critical
            } else if result.similarity < 0.8 {
                severity = .high
            } else if result.similarity < 0.95 {
                severity = .medium
            } else {
                severity = .low
            }

            findings.append(Finding(
                category: .text,
                severity: severity,
                title: "Text Content Differences",
                description: String(format: "Overall text similarity is %.1f%%", result.similarity * 100),
                details: [
                    "Original Characters": "\(result.totalCharactersOriginal)",
                    "Comparison Characters": "\(result.totalCharactersComparison)"
                ]
            ))
        }

        // Per-page findings for significant differences
        for pageResult in result.pageResults where pageResult.similarity < 0.9 {
            findings.append(Finding(
                category: .text,
                severity: pageResult.similarity < 0.5 ? .high : .medium,
                title: "Page \(pageResult.pageNumber) Text Differs",
                description: String(format: "Page has %.1f%% text similarity with %d changes",
                                   pageResult.similarity * 100,
                                   pageResult.differences.count),
                pageNumber: pageResult.pageNumber
            ))
        }

        return findings
    }
}
