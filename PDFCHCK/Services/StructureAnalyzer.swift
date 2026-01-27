import Foundation
import PDFKit

// MARK: - Structure Analyzer
actor StructureAnalyzer {

    // MARK: - Structure Analysis Result
    struct StructureAnalysisResult {
        let pageCountMatch: Bool
        let pageSizeMatch: Bool
        let fontAnalysis: FontAnalysis
        let annotationAnalysis: AnnotationAnalysis
        let linkAnalysis: LinkAnalysis
        let findings: [Finding]
    }

    struct FontAnalysis {
        let originalFonts: Set<String>
        let comparisonFonts: Set<String>
        let commonFonts: Set<String>
        let addedFonts: Set<String>
        let removedFonts: Set<String>

        var hasDifferences: Bool {
            !addedFonts.isEmpty || !removedFonts.isEmpty
        }
    }

    struct AnnotationAnalysis {
        let originalCount: Int
        let comparisonCount: Int
        let differenceCount: Int

        var hasDifferences: Bool {
            originalCount != comparisonCount
        }
    }

    struct LinkAnalysis {
        let originalLinks: [String]
        let comparisonLinks: [String]
        let addedLinks: [String]
        let removedLinks: [String]

        var hasDifferences: Bool {
            !addedLinks.isEmpty || !removedLinks.isEmpty
        }
    }

    // MARK: - Analyze Structure
    func analyze(original: PDFAnalysis, comparison: PDFAnalysis) async -> StructureAnalysisResult {
        var findings: [Finding] = []

        // Page count comparison
        let pageCountMatch = original.pageCount == comparison.pageCount
        if !pageCountMatch {
            findings.append(Finding(
                category: .structure,
                severity: .critical,
                title: "Page Count Mismatch",
                description: "Documents have different number of pages",
                details: [
                    "Original": "\(original.pageCount) pages",
                    "Comparison": "\(comparison.pageCount) pages"
                ]
            ))
        }

        // Page size comparison
        let pageSizeMatch = comparePageSizes(original: original.document, comparison: comparison.document)
        if !pageSizeMatch {
            findings.append(Finding(
                category: .structure,
                severity: .medium,
                title: "Page Size Differences",
                description: "One or more pages have different dimensions"
            ))
        }

        // Font analysis
        let fontAnalysis = analyzeFonts(original: original.document, comparison: comparison.document)
        if fontAnalysis.hasDifferences {
            findings.append(Finding(
                category: .structure,
                severity: .high,
                title: "Font Differences Detected",
                description: "Documents use different fonts",
                details: [
                    "Added Fonts": fontAnalysis.addedFonts.joined(separator: ", "),
                    "Removed Fonts": fontAnalysis.removedFonts.joined(separator: ", ")
                ]
            ))
        }

        // Annotation analysis
        let annotationAnalysis = analyzeAnnotations(original: original.document, comparison: comparison.document)
        if annotationAnalysis.hasDifferences {
            findings.append(Finding(
                category: .structure,
                severity: .medium,
                title: "Annotation Count Differs",
                description: "Documents have different numbers of annotations",
                details: [
                    "Original": "\(annotationAnalysis.originalCount)",
                    "Comparison": "\(annotationAnalysis.comparisonCount)"
                ]
            ))
        }

        // Link analysis
        let linkAnalysis = analyzeLinks(original: original.document, comparison: comparison.document)
        if linkAnalysis.hasDifferences {
            findings.append(Finding(
                category: .structure,
                severity: .high,
                title: "Link Differences Detected",
                description: "Documents have different hyperlinks",
                details: [
                    "Added Links": linkAnalysis.addedLinks.joined(separator: ", "),
                    "Removed Links": linkAnalysis.removedLinks.joined(separator: ", ")
                ]
            ))
        }

        return StructureAnalysisResult(
            pageCountMatch: pageCountMatch,
            pageSizeMatch: pageSizeMatch,
            fontAnalysis: fontAnalysis,
            annotationAnalysis: annotationAnalysis,
            linkAnalysis: linkAnalysis,
            findings: findings
        )
    }

    // MARK: - Compare Page Sizes
    private func comparePageSizes(original: PDFDocument, comparison: PDFDocument) -> Bool {
        let pageCount = min(original.pageCount, comparison.pageCount)

        for i in 0..<pageCount {
            guard let origPage = original.page(at: i),
                  let compPage = comparison.page(at: i) else {
                continue
            }

            let origBounds = origPage.bounds(for: .mediaBox)
            let compBounds = compPage.bounds(for: .mediaBox)

            // Allow small tolerance for floating point comparison
            let tolerance: CGFloat = 1.0
            if abs(origBounds.width - compBounds.width) > tolerance ||
               abs(origBounds.height - compBounds.height) > tolerance {
                return false
            }
        }

        return true
    }

    // MARK: - Analyze Fonts
    private func analyzeFonts(original: PDFDocument, comparison: PDFDocument) -> FontAnalysis {
        let originalFonts = extractFonts(from: original)
        let comparisonFonts = extractFonts(from: comparison)

        let commonFonts = originalFonts.intersection(comparisonFonts)
        let addedFonts = comparisonFonts.subtracting(originalFonts)
        let removedFonts = originalFonts.subtracting(comparisonFonts)

        return FontAnalysis(
            originalFonts: originalFonts,
            comparisonFonts: comparisonFonts,
            commonFonts: commonFonts,
            addedFonts: addedFonts,
            removedFonts: removedFonts
        )
    }

    private func extractFonts(from document: PDFDocument) -> Set<String> {
        var fonts: Set<String> = []

        // PDFKit doesn't directly expose font information
        // We extract from page string attributes where possible
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i),
                  let attributedString = page.attributedString else {
                continue
            }

            attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length)) { value, _, _ in
                if let font = value as? NSFont {
                    fonts.insert(font.fontName)
                }
            }
        }

        return fonts
    }

    // MARK: - Analyze Annotations
    private func analyzeAnnotations(original: PDFDocument, comparison: PDFDocument) -> AnnotationAnalysis {
        var originalCount = 0
        var comparisonCount = 0

        for i in 0..<original.pageCount {
            if let page = original.page(at: i) {
                originalCount += page.annotations.count
            }
        }

        for i in 0..<comparison.pageCount {
            if let page = comparison.page(at: i) {
                comparisonCount += page.annotations.count
            }
        }

        return AnnotationAnalysis(
            originalCount: originalCount,
            comparisonCount: comparisonCount,
            differenceCount: abs(originalCount - comparisonCount)
        )
    }

    // MARK: - Analyze Links
    private func analyzeLinks(original: PDFDocument, comparison: PDFDocument) -> LinkAnalysis {
        let originalLinks = extractLinks(from: original)
        let comparisonLinks = extractLinks(from: comparison)

        let originalSet = Set(originalLinks)
        let comparisonSet = Set(comparisonLinks)

        let addedLinks = Array(comparisonSet.subtracting(originalSet))
        let removedLinks = Array(originalSet.subtracting(comparisonSet))

        return LinkAnalysis(
            originalLinks: originalLinks,
            comparisonLinks: comparisonLinks,
            addedLinks: addedLinks,
            removedLinks: removedLinks
        )
    }

    private func extractLinks(from document: PDFDocument) -> [String] {
        var links: [String] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }

            for annotation in page.annotations {
                if let linkAnnotation = annotation as? PDFAnnotation,
                   linkAnnotation.type == "Link",
                   let action = linkAnnotation.action as? PDFActionURL,
                   let url = action.url {
                    links.append(url.absoluteString)
                }
            }
        }

        return links
    }
}
