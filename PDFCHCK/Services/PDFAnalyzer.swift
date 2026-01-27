import Foundation
import PDFKit
import AppKit

// MARK: - PDF Analyzer
actor PDFAnalyzer {

    // MARK: - Analyze PDF
    func analyze(url: URL) async throws -> PDFAnalysis {
        guard let document = PDFDocument(url: url) else {
            throw AnalysisError.invalidPDF(url.lastPathComponent)
        }

        let pageCount = document.pageCount
        let metadata = extractMetadata(from: document)
        let fileInfo = try FileHelpers.getFileInfo(for: url)

        // Extract text from all pages
        var pageTexts: [Int: String] = [:]
        for i in 0..<pageCount {
            if let page = document.page(at: i),
               let text = page.string {
                pageTexts[i] = text
            }
        }

        // Render page images (for visual comparison)
        var pageImages: [Int: NSImage] = [:]
        for i in 0..<pageCount {
            if let page = document.page(at: i) {
                pageImages[i] = renderPage(page, at: 150)  // 150 DPI for comparison
            }
        }

        return PDFAnalysis(
            url: url,
            document: document,
            pageCount: pageCount,
            metadata: metadata,
            fileInfo: fileInfo,
            pageTexts: pageTexts,
            pageImages: pageImages,
            embeddedImages: [],
            links: [],
            layers: [],
            signatures: [],
            hiddenContent: [],
            xmpHistory: [],
            redactions: [],
            suspiciousElements: []
        )
    }

    // MARK: - Extract Metadata
    private func extractMetadata(from document: PDFDocument) -> PDFAnalysis.PDFMetadata {
        let attrs = document.documentAttributes ?? [:]

        let title = attrs[PDFDocumentAttribute.titleAttribute] as? String
        let author = attrs[PDFDocumentAttribute.authorAttribute] as? String
        let subject = attrs[PDFDocumentAttribute.subjectAttribute] as? String
        let creator = attrs[PDFDocumentAttribute.creatorAttribute] as? String
        let producer = attrs[PDFDocumentAttribute.producerAttribute] as? String
        let creationDate = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
        let modificationDate = attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date
        let keywordsString = attrs[PDFDocumentAttribute.keywordsAttribute] as? String
        let keywords = keywordsString?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // Extract PDF version and raw internals
        let version = extractPDFVersion(from: document)
        let rawInfo = extractRawPDFInfo(from: document)

        return PDFAnalysis.PDFMetadata(
            title: title,
            author: author,
            subject: subject,
            creator: creator,
            producer: producer,
            creationDate: creationDate,
            modificationDate: modificationDate,
            keywords: keywords,
            version: version,
            isEncrypted: document.isEncrypted,
            allowsPrinting: document.allowsPrinting,
            allowsCopying: document.allowsCopying,
            documentID: rawInfo.documentID,
            isLinearized: rawInfo.isLinearized,
            hasXMPMetadata: rawInfo.hasXMPMetadata,
            incrementalUpdates: rawInfo.incrementalUpdates,
            objectCount: rawInfo.objectCount,
            hasJavaScript: rawInfo.hasJavaScript,
            hasDigitalSignature: rawInfo.hasDigitalSignature,
            embeddedFileCount: rawInfo.embeddedFileCount,
            fontCount: rawInfo.fontCount,
            fonts: rawInfo.fonts,
            annotationCount: countAnnotations(in: document),
            formFieldCount: rawInfo.formFieldCount,
            isTaggedPDF: rawInfo.isTaggedPDF,
            pdfConformance: rawInfo.pdfConformance,
            xrefType: rawInfo.xrefType
        )
    }

    // MARK: - Raw PDF Info Structure
    private struct RawPDFInfo {
        var documentID: PDFAnalysis.PDFMetadata.DocumentID?
        var isLinearized: Bool = false
        var hasXMPMetadata: Bool = false
        var incrementalUpdates: Int = 0
        var objectCount: Int = 0
        var hasJavaScript: Bool = false
        var hasDigitalSignature: Bool = false
        var embeddedFileCount: Int = 0
        var fontCount: Int = 0
        var fonts: [PDFAnalysis.PDFMetadata.FontInfo] = []
        var formFieldCount: Int = 0
        var isTaggedPDF: Bool = false
        var pdfConformance: String?
        var xrefType: String?
    }

    // MARK: - Extract Raw PDF Info
    private func extractRawPDFInfo(from document: PDFDocument) -> RawPDFInfo {
        var info = RawPDFInfo()

        guard let data = document.dataRepresentation() else { return info }
        let content = String(decoding: data, as: UTF8.self)

        // Check for linearization (fast web view)
        info.isLinearized = content.contains("/Linearized")

        // Check for XMP metadata
        info.hasXMPMetadata = content.contains("<x:xmpmeta") || content.contains("<?xpacket")

        // Count incremental updates (%%EOF markers minus 1)
        let eofMatches = content.components(separatedBy: "%%EOF")
        info.incrementalUpdates = max(0, eofMatches.count - 2)

        // Count objects (approximate by counting "obj" definitions)
        let objPattern = "\\d+\\s+\\d+\\s+obj"
        if let regex = try? NSRegularExpression(pattern: objPattern) {
            let range = NSRange(content.startIndex..., in: content)
            info.objectCount = regex.numberOfMatches(in: content, range: range)
        }

        // Check for JavaScript
        info.hasJavaScript = content.contains("/JavaScript") || content.contains("/JS")

        // Check for digital signatures
        info.hasDigitalSignature = content.contains("/Sig") && content.contains("/ByteRange")

        // Count embedded files
        let embeddedPattern = "/EmbeddedFile"
        info.embeddedFileCount = content.components(separatedBy: embeddedPattern).count - 1

        // Extract fonts with details
        info.fonts = extractFonts(from: content)
        info.fontCount = info.fonts.count

        // Check for form fields (AcroForm)
        if content.contains("/AcroForm") {
            let fieldsPattern = "/Fields\\s*\\["
            if content.range(of: fieldsPattern, options: .regularExpression) != nil {
                // Count /T entries as approximate field count
                info.formFieldCount = content.components(separatedBy: "/FT").count - 1
            }
        }

        // Check for tagged PDF
        info.isTaggedPDF = content.contains("/MarkInfo") && content.contains("/Marked true")

        // Check PDF conformance (PDF/A, PDF/X, etc.)
        if content.contains("pdfaid:part") || content.contains("PDF/A") {
            info.pdfConformance = "PDF/A"
        } else if content.contains("pdfxid:GTS_PDFXVersion") || content.contains("PDF/X") {
            info.pdfConformance = "PDF/X"
        } else if content.contains("PDF/UA") {
            info.pdfConformance = "PDF/UA"
        }

        // Determine xref type
        if content.contains("/Type /XRef") || content.contains("/Type/XRef") {
            info.xrefType = "stream"
        } else if content.contains("xref") {
            info.xrefType = "table"
        }

        // Extract Document ID
        info.documentID = extractDocumentID(from: content)

        return info
    }

    // MARK: - Extract Document ID
    private func extractDocumentID(from content: String) -> PDFAnalysis.PDFMetadata.DocumentID? {
        // Document ID format: /ID [<hex1> <hex2>] or /ID [(...) (...)]
        let patterns = [
            "/ID\\s*\\[\\s*<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>\\s*\\]",
            "/ID\\s*\\[\\s*\\(([^)]+)\\)\\s*\\(([^)]+)\\)\\s*\\]"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                let range1 = Range(match.range(at: 1), in: content)
                let range2 = Range(match.range(at: 2), in: content)
                if let r1 = range1, let r2 = range2 {
                    return PDFAnalysis.PDFMetadata.DocumentID(
                        permanent: String(content[r1]),
                        changing: String(content[r2])
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Extract Fonts
    private func extractFonts(from content: String) -> [PDFAnalysis.PDFMetadata.FontInfo] {
        var fonts: [PDFAnalysis.PDFMetadata.FontInfo] = []
        var seenFonts: Set<String> = []

        // Pattern to find font definitions with BaseFont
        // Matches: /Type /Font ... /BaseFont /FontName or /BaseFont/FontName
        let baseFontPattern = "/BaseFont\\s*/([A-Za-z0-9+\\-_]+)"

        if let regex = try? NSRegularExpression(pattern: baseFontPattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let fontRange = Range(match.range(at: 1), in: content) {
                    let fontName = String(content[fontRange])

                    // Skip if we've already seen this font
                    guard !seenFonts.contains(fontName) else { continue }
                    seenFonts.insert(fontName)

                    // Check if it's a subset (has 6-char prefix + '+')
                    let isSubset = fontName.contains("+") && fontName.firstIndex(of: "+")!.utf16Offset(in: fontName) == 6

                    // Extract the actual font name (remove subset prefix if present)
                    let baseName: String
                    if isSubset, let plusIndex = fontName.firstIndex(of: "+") {
                        baseName = String(fontName[fontName.index(after: plusIndex)...])
                    } else {
                        baseName = fontName
                    }

                    // Try to determine font type from nearby content
                    let fontType = determineFontType(for: fontName, in: content)

                    // Check if font is embedded (look for FontFile, FontFile2, or FontFile3)
                    let isEmbedded = checkFontEmbedded(fontName: fontName, in: content)

                    fonts.append(PDFAnalysis.PDFMetadata.FontInfo(
                        name: baseName,
                        type: fontType,
                        baseFont: fontName,
                        isEmbedded: isEmbedded,
                        isSubset: isSubset
                    ))
                }
            }
        }

        return fonts.sorted { $0.name < $1.name }
    }

    // MARK: - Determine Font Type
    private func determineFontType(for fontName: String, in content: String) -> String? {
        // Look for font type near the font definition
        // This is approximate - PDF structure makes exact matching complex

        // Find approximate location of this font
        guard let fontLocation = content.range(of: "/BaseFont /\(fontName)") ??
                                 content.range(of: "/BaseFont/\(fontName)") else {
            return nil
        }

        // Look at nearby content (500 chars before and after)
        let start = content.index(fontLocation.lowerBound, offsetBy: -500, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(fontLocation.upperBound, offsetBy: 500, limitedBy: content.endIndex) ?? content.endIndex
        let context = String(content[start..<end])

        if context.contains("/Subtype /Type1") || context.contains("/Subtype/Type1") {
            return "Type1"
        } else if context.contains("/Subtype /TrueType") || context.contains("/Subtype/TrueType") {
            return "TrueType"
        } else if context.contains("/Subtype /Type0") || context.contains("/Subtype/Type0") {
            return "Type0"
        } else if context.contains("/Subtype /Type3") || context.contains("/Subtype/Type3") {
            return "Type3"
        } else if context.contains("/Subtype /CIDFontType0") {
            return "CIDFontType0"
        } else if context.contains("/Subtype /CIDFontType2") {
            return "CIDFontType2"
        } else if context.contains("/Subtype /OpenType") {
            return "OpenType"
        }

        return nil
    }

    // MARK: - Check Font Embedded
    private func checkFontEmbedded(fontName: String, in content: String) -> Bool {
        // Look for FontFile, FontFile2, or FontFile3 references near the font definition
        guard let fontLocation = content.range(of: "/BaseFont /\(fontName)") ??
                                 content.range(of: "/BaseFont/\(fontName)") else {
            return false
        }

        let start = content.index(fontLocation.lowerBound, offsetBy: -1000, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(fontLocation.upperBound, offsetBy: 1000, limitedBy: content.endIndex) ?? content.endIndex
        let context = String(content[start..<end])

        return context.contains("/FontFile") || context.contains("/FontFile2") || context.contains("/FontFile3")
    }

    // MARK: - Count Annotations
    private func countAnnotations(in document: PDFDocument) -> Int {
        var count = 0
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                count += page.annotations.count
            }
        }
        return count
    }

    // MARK: - Extract PDF Version
    private func extractPDFVersion(from document: PDFDocument) -> String? {
        // PDFKit doesn't directly expose the PDF version
        // We can get it from the document's data representation header
        guard let data = document.dataRepresentation(),
              data.count > 8 else { return nil }

        let header = data.prefix(8)
        if let headerString = String(data: header, encoding: .ascii),
           headerString.hasPrefix("%PDF-") {
            let versionStart = headerString.index(headerString.startIndex, offsetBy: 5)
            let versionEnd = headerString.index(versionStart, offsetBy: 3, limitedBy: headerString.endIndex) ?? headerString.endIndex
            return String(headerString[versionStart..<versionEnd])
        }

        return nil
    }

    // MARK: - Render Page
    func renderPage(_ page: PDFPage, at dpi: CGFloat) -> NSImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0

        let width = pageRect.width * scale
        let height = pageRect.height * scale

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        // Fill with white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        // Apply scale transform
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()

        // Draw the page
        page.draw(with: .mediaBox, to: NSGraphicsContext.current!.cgContext)

        image.unlockFocus()

        return image
    }

    // MARK: - Get Page Text
    func getPageText(from document: PDFDocument, page: Int) -> String? {
        guard let pdfPage = document.page(at: page) else { return nil }
        return pdfPage.string
    }

    // MARK: - Get All Text
    func getAllText(from document: PDFDocument) -> String {
        var allText = ""
        for i in 0..<document.pageCount {
            if let pageText = getPageText(from: document, page: i) {
                allText += pageText + "\n"
            }
        }
        return allText
    }
}
