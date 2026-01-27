import Foundation
import PDFKit
import AppKit
import CryptoKit

// MARK: - Forensic Analyzer
actor ForensicAnalyzer {

    // MARK: - Full Forensic Analysis
    func analyze(document: PDFDocument, url: URL) async -> ForensicResult {
        let pdfData = document.dataRepresentation() ?? Data()
        let content = String(decoding: pdfData, as: UTF8.self)

        let embeddedImages = extractEmbeddedImages(from: document, content: content)
        let links = extractLinks(from: document)
        let layers = extractLayers(from: content)
        let signatures = analyzeSignatures(from: document, content: content)
        let hiddenContent = detectHiddenContent(from: document, content: content)
        let xmpHistory = extractXMPHistory(from: content)
        let redactions = detectRedactions(from: document, content: content)
        let suspicious = detectSuspiciousElements(from: document, content: content)

        return ForensicResult(
            embeddedImages: embeddedImages,
            links: links,
            layers: layers,
            signatures: signatures,
            hiddenContent: hiddenContent,
            xmpHistory: xmpHistory,
            redactions: redactions,
            suspiciousElements: suspicious
        )
    }

    // MARK: - Extract Embedded Images
    private func extractEmbeddedImages(from document: PDFDocument, content: String) -> [PDFAnalysis.EmbeddedImage] {
        var images: [PDFAnalysis.EmbeddedImage] = []

        // Parse image XObjects from PDF content
        let imagePattern = "/(Im\\d+|Image\\d+|X\\d+)\\s+\\d+\\s+\\d+\\s+R"
        let streamPattern = "/Subtype\\s*/Image.*?/Width\\s+(\\d+).*?/Height\\s+(\\d+).*?/BitsPerComponent\\s+(\\d+).*?/ColorSpace\\s*/([A-Za-z]+)"

        // Extract from each page using PDFKit
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            // Get page annotations that might contain images
            for (index, annotation) in page.annotations.enumerated() {
                if annotation.type == "Stamp" || annotation.type == "Widget" {
                    images.append(PDFAnalysis.EmbeddedImage(
                        pageNumber: pageIndex + 1,
                        index: index,
                        width: Int(annotation.bounds.width),
                        height: Int(annotation.bounds.height),
                        bitsPerComponent: 8,
                        colorSpace: "RGB",
                        filter: nil,
                        dataHash: hashData(Data("\(annotation.bounds)".utf8)),
                        image: nil
                    ))
                }
            }
        }

        // Parse raw image objects from content
        if let regex = try? NSRegularExpression(pattern: "/Type\\s*/XObject.*?/Subtype\\s*/Image", options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for (index, match) in matches.enumerated() {
                if let matchRange = Range(match.range, in: content) {
                    let context = extractContext(around: matchRange, in: content, chars: 500)

                    let width = extractNumber(after: "/Width", in: context) ?? 0
                    let height = extractNumber(after: "/Height", in: context) ?? 0
                    let bpc = extractNumber(after: "/BitsPerComponent", in: context) ?? 8
                    let colorSpace = extractValue(after: "/ColorSpace", in: context) ?? "DeviceRGB"
                    let filter = extractValue(after: "/Filter", in: context)

                    images.append(PDFAnalysis.EmbeddedImage(
                        pageNumber: 0, // Page unknown from raw parsing
                        index: index,
                        width: width,
                        height: height,
                        bitsPerComponent: bpc,
                        colorSpace: colorSpace,
                        filter: filter,
                        dataHash: hashData(Data(context.utf8)),
                        image: nil
                    ))
                }
            }
        }

        return images
    }

    // MARK: - Extract Links
    private func extractLinks(from document: PDFDocument) -> [PDFAnalysis.PDFLink] {
        var links: [PDFAnalysis.PDFLink] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            for annotation in page.annotations {
                guard annotation.type == "Link" else { continue }

                var urlString: String?
                var destination: String?
                var actionType = "Unknown"

                if let action = annotation.action {
                    if let urlAction = action as? PDFActionURL {
                        urlString = urlAction.url?.absoluteString
                        actionType = "URL"
                    } else if let gotoAction = action as? PDFActionGoTo {
                        let dest = gotoAction.destination
                        destination = "Page \(dest.page?.label ?? "?")"
                        actionType = "GoTo"
                    } else if let namedAction = action as? PDFActionNamed {
                        actionType = "Named: \(namedAction.name.rawValue)"
                    } else if let remoteAction = action as? PDFActionRemoteGoTo {
                        urlString = remoteAction.url.absoluteString
                        actionType = "RemoteGoTo"
                    }
                }

                links.append(PDFAnalysis.PDFLink(
                    pageNumber: pageIndex + 1,
                    url: urlString,
                    destination: destination,
                    actionType: actionType,
                    bounds: annotation.bounds
                ))
            }
        }

        return links
    }

    // MARK: - Extract Layers (OCG)
    private func extractLayers(from content: String) -> [PDFAnalysis.PDFLayer] {
        var layers: [PDFAnalysis.PDFLayer] = []

        // Look for Optional Content Groups
        let ocgPattern = "/Type\\s*/OCG.*?/Name\\s*\\(([^)]+)\\)"

        if let regex = try? NSRegularExpression(pattern: ocgPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: content) {
                    let name = String(content[nameRange])
                    let context = extractContext(around: nameRange, in: content, chars: 300)

                    let isVisible = !context.contains("/OFF")
                    let isLocked = context.contains("/Locked")
                    let intent = extractValue(after: "/Intent", in: context)

                    layers.append(PDFAnalysis.PDFLayer(
                        name: name,
                        isVisible: isVisible,
                        isLocked: isLocked,
                        intent: intent
                    ))
                }
            }
        }

        return layers
    }

    // MARK: - Analyze Signatures
    private func analyzeSignatures(from document: PDFDocument, content: String) -> [PDFAnalysis.DigitalSignature] {
        var signatures: [PDFAnalysis.DigitalSignature] = []

        // Look for signature fields
        let sigPattern = "/Type\\s*/Sig.*?/Filter\\s*/([A-Za-z.]+)"

        if let regex = try? NSRegularExpression(pattern: sigPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                if let matchRange = Range(match.range, in: content) {
                    let context = extractContext(around: matchRange, in: content, chars: 1000)

                    let signerName = extractPDFString(after: "/Name", in: context)
                    let reason = extractPDFString(after: "/Reason", in: context)
                    let location = extractPDFString(after: "/Location", in: context)
                    let signDate = extractPDFDate(after: "/M", in: context)

                    // Check if signature covers whole document
                    let coversWhole = checkSignatureCoversWholeDocument(context: context, content: content)

                    // Basic validation (would need proper crypto for full validation)
                    let hasContents = context.contains("/Contents")
                    let hasByteRange = context.contains("/ByteRange")

                    signatures.append(PDFAnalysis.DigitalSignature(
                        signerName: signerName,
                        signDate: signDate,
                        reason: reason,
                        location: location,
                        isValid: hasContents && hasByteRange,
                        validationMessage: hasContents && hasByteRange ? "Signature structure valid" : "Incomplete signature",
                        coversWholeDocument: coversWhole,
                        certificateInfo: extractCertificateInfo(from: context)
                    ))
                }
            }
        }

        return signatures
    }

    private func checkSignatureCoversWholeDocument(context: String, content: String) -> Bool {
        // Check ByteRange - if it covers the whole file, second range should go to EOF
        if let byteRangePattern = try? NSRegularExpression(pattern: "/ByteRange\\s*\\[\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(\\d+)\\s*\\]"),
           let match = byteRangePattern.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)) {
            // The second range end should be close to file size
            if let range4 = Range(match.range(at: 4), in: context),
               let endOffset = Int(context[range4]) {
                let contentSize = content.count
                // Allow some tolerance
                return abs(contentSize - endOffset) < 100
            }
        }
        return false
    }

    private func extractCertificateInfo(from context: String) -> PDFAnalysis.CertificateInfo? {
        // Basic certificate info extraction from signature context
        // Full implementation would require parsing the PKCS#7 data
        return nil
    }

    // MARK: - Detect Hidden Content
    private func detectHiddenContent(from document: PDFDocument, content: String) -> [PDFAnalysis.HiddenContent] {
        var hidden: [PDFAnalysis.HiddenContent] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)

            // Check for white text (text with same color as background)
            hidden.append(contentsOf: detectWhiteText(on: page, pageNumber: pageIndex + 1))

            // Check for tiny/invisible text
            hidden.append(contentsOf: detectTinyText(on: page, pageNumber: pageIndex + 1))

            // Check for content outside page bounds
            hidden.append(contentsOf: detectOffPageContent(on: page, pageNumber: pageIndex + 1, bounds: pageBounds))
        }

        // Check for hidden layers
        let hiddenLayers = extractLayers(from: content).filter { !$0.isVisible }
        for layer in hiddenLayers {
            hidden.append(PDFAnalysis.HiddenContent(
                pageNumber: 0,
                type: .hiddenLayer,
                description: "Hidden layer: \(layer.name)",
                bounds: nil
            ))
        }

        return hidden
    }

    private func detectWhiteText(on page: PDFPage, pageNumber: Int) -> [PDFAnalysis.HiddenContent] {
        var hidden: [PDFAnalysis.HiddenContent] = []

        // Check annotations for hidden content
        for annotation in page.annotations {
            if let contents = annotation.contents,
               !contents.isEmpty,
               annotation.color == NSColor.white {
                hidden.append(PDFAnalysis.HiddenContent(
                    pageNumber: pageNumber,
                    type: .whiteText,
                    description: "Annotation with white text",
                    bounds: annotation.bounds
                ))
            }
        }

        return hidden
    }

    private func detectTinyText(on page: PDFPage, pageNumber: Int) -> [PDFAnalysis.HiddenContent] {
        var hidden: [PDFAnalysis.HiddenContent] = []

        for annotation in page.annotations {
            // Check for very small annotation bounds that might hide text
            if annotation.bounds.width < 2 || annotation.bounds.height < 2 {
                if annotation.contents?.isEmpty == false {
                    hidden.append(PDFAnalysis.HiddenContent(
                        pageNumber: pageNumber,
                        type: .tinyText,
                        description: "Microscopic annotation with content",
                        bounds: annotation.bounds
                    ))
                }
            }
        }

        return hidden
    }

    private func detectOffPageContent(on page: PDFPage, pageNumber: Int, bounds: CGRect) -> [PDFAnalysis.HiddenContent] {
        var hidden: [PDFAnalysis.HiddenContent] = []

        for annotation in page.annotations {
            let annBounds = annotation.bounds
            // Check if annotation is completely outside page bounds
            if annBounds.maxX < 0 || annBounds.minX > bounds.width ||
               annBounds.maxY < 0 || annBounds.minY > bounds.height {
                hidden.append(PDFAnalysis.HiddenContent(
                    pageNumber: pageNumber,
                    type: .offPageContent,
                    description: "Content placed outside visible page area",
                    bounds: annBounds
                ))
            }
        }

        return hidden
    }

    // MARK: - Extract XMP History
    private func extractXMPHistory(from content: String) -> [PDFAnalysis.XMPHistoryEntry] {
        var history: [PDFAnalysis.XMPHistoryEntry] = []

        // Look for xmpMM:History entries
        let historyPattern = "<rdf:li[^>]*>.*?<stEvt:action>([^<]+)</stEvt:action>.*?(?:<stEvt:when>([^<]+)</stEvt:when>)?.*?(?:<stEvt:softwareAgent>([^<]+)</stEvt:softwareAgent>)?.*?(?:<stEvt:parameters>([^<]+)</stEvt:parameters>)?.*?</rdf:li>"

        if let regex = try? NSRegularExpression(pattern: historyPattern, options: [.dotMatchesLineSeparators]) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)

            for match in matches {
                let action = extractGroup(match, at: 1, in: content) ?? "Unknown"
                let whenStr = extractGroup(match, at: 2, in: content)
                let software = extractGroup(match, at: 3, in: content)
                let params = extractGroup(match, at: 4, in: content)

                var when: Date?
                if let whenStr = whenStr {
                    let formatter = ISO8601DateFormatter()
                    when = formatter.date(from: whenStr)
                }

                history.append(PDFAnalysis.XMPHistoryEntry(
                    action: action,
                    when: when,
                    softwareAgent: software,
                    parameters: params
                ))
            }
        }

        return history
    }

    // MARK: - Detect Redactions
    private func detectRedactions(from document: PDFDocument, content: String) -> [PDFAnalysis.Redaction] {
        var redactions: [PDFAnalysis.Redaction] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            for annotation in page.annotations {
                // Check for redaction annotations
                if annotation.type == "Redact" ||
                   (annotation.type == "Square" && annotation.color == NSColor.black) ||
                   (annotation.type == "FreeText" && annotation.color == NSColor.black) {

                    // Check if text still exists under the redaction
                    let hasHiddenContent = checkForContentUnderRedaction(page: page, bounds: annotation.bounds)

                    redactions.append(PDFAnalysis.Redaction(
                        pageNumber: pageIndex + 1,
                        bounds: annotation.bounds,
                        isProperlyApplied: !hasHiddenContent,
                        hasHiddenContent: hasHiddenContent
                    ))
                }
            }
        }

        return redactions
    }

    private func checkForContentUnderRedaction(page: PDFPage, bounds: CGRect) -> Bool {
        // Try to select text in the redacted area
        if let selection = page.selection(for: bounds) {
            if let text = selection.string, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                return true // Content still exists under redaction
            }
        }
        return false
    }

    // MARK: - Detect Suspicious Elements
    private func detectSuspiciousElements(from document: PDFDocument, content: String) -> [PDFAnalysis.SuspiciousElement] {
        var suspicious: [PDFAnalysis.SuspiciousElement] = []

        // Check for JavaScript
        if content.contains("/JavaScript") || content.contains("/JS ") || content.contains("/JS(") {
            suspicious.append(PDFAnalysis.SuspiciousElement(
                type: .javascriptAction,
                description: "Document contains JavaScript code",
                pageNumber: nil,
                severity: .high
            ))
        }

        // Check for Launch actions
        if content.contains("/Launch") || content.contains("/S /Launch") {
            suspicious.append(PDFAnalysis.SuspiciousElement(
                type: .launchAction,
                description: "Document contains Launch action (can execute external programs)",
                pageNumber: nil,
                severity: .critical
            ))
        }

        // Check for orphaned objects (objects not referenced)
        let orphaned = detectOrphanedObjects(in: content)
        if orphaned > 0 {
            suspicious.append(PDFAnalysis.SuspiciousElement(
                type: .orphanedObject,
                description: "\(orphaned) orphaned objects detected (possible remnants of deleted content)",
                pageNumber: nil,
                severity: .medium
            ))
        }

        // Check for tool fingerprint mismatches
        if let mismatch = detectToolMismatch(in: content) {
            suspicious.append(PDFAnalysis.SuspiciousElement(
                type: .toolMismatch,
                description: mismatch,
                pageNumber: nil,
                severity: .high
            ))
        }

        return suspicious
    }

    private func detectOrphanedObjects(in content: String) -> Int {
        // Count object definitions
        var definedObjects = Set<String>()
        var referencedObjects = Set<String>()

        // Find all object definitions (e.g., "5 0 obj")
        let defPattern = "(\\d+)\\s+0\\s+obj"
        if let regex = try? NSRegularExpression(pattern: defPattern) {
            let range = NSRange(content.startIndex..., in: content)
            for match in regex.matches(in: content, range: range) {
                if let r = Range(match.range(at: 1), in: content) {
                    definedObjects.insert(String(content[r]))
                }
            }
        }

        // Find all object references (e.g., "5 0 R")
        let refPattern = "(\\d+)\\s+0\\s+R"
        if let regex = try? NSRegularExpression(pattern: refPattern) {
            let range = NSRange(content.startIndex..., in: content)
            for match in regex.matches(in: content, range: range) {
                if let r = Range(match.range(at: 1), in: content) {
                    referencedObjects.insert(String(content[r]))
                }
            }
        }

        // Orphaned = defined but not referenced
        let orphaned = definedObjects.subtracting(referencedObjects)
        // Subtract common unreferenced objects like catalog (usually obj 1)
        return max(0, orphaned.count - 3)
    }

    private func detectToolMismatch(in content: String) -> String? {
        // Extract Creator and Producer
        var creator: String?
        var producer: String?

        if let creatorMatch = content.range(of: "/Creator\\s*\\(([^)]+)\\)", options: .regularExpression) {
            creator = String(content[creatorMatch])
        }
        if let producerMatch = content.range(of: "/Producer\\s*\\(([^)]+)\\)", options: .regularExpression) {
            producer = String(content[producerMatch])
        }

        // Check for suspicious combinations
        if let c = creator?.lowercased(), let p = producer?.lowercased() {
            // Original created in Word but modified with something suspicious
            if c.contains("word") && (p.contains("unknown") || p.contains("pdfedit") || p.contains("hexedit")) {
                return "Document created in Word but producer suggests manual editing"
            }
            // Adobe created but different tool modified
            if c.contains("adobe") && !p.contains("adobe") && !p.contains("acrobat") {
                return "Document created with Adobe but modified with different tool: \(producer ?? "unknown")"
            }
        }

        return nil
    }

    // MARK: - Helper Functions
    private func hashData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.prefix(8).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func extractContext(around range: Range<String.Index>, in content: String, chars: Int) -> String {
        let start = content.index(range.lowerBound, offsetBy: -chars, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: chars, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[start..<end])
    }

    private func extractNumber(after key: String, in context: String) -> Int? {
        let pattern = "\(key)\\s+(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
           let range = Range(match.range(at: 1), in: context) {
            return Int(context[range])
        }
        return nil
    }

    private func extractValue(after key: String, in context: String) -> String? {
        let pattern = "\(key)\\s*/([A-Za-z0-9]+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
           let range = Range(match.range(at: 1), in: context) {
            return String(context[range])
        }
        return nil
    }

    private func extractPDFString(after key: String, in context: String) -> String? {
        let pattern = "\(key)\\s*\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
           let range = Range(match.range(at: 1), in: context) {
            return String(context[range])
        }
        return nil
    }

    private func extractPDFDate(after key: String, in context: String) -> Date? {
        guard let dateStr = extractPDFString(after: key, in: context) else { return nil }
        // PDF date format: D:YYYYMMDDHHmmSS+HH'mm'
        let pattern = "D:(\\d{4})(\\d{2})(\\d{2})(\\d{2})?(\\d{2})?(\\d{2})?"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: dateStr, range: NSRange(dateStr.startIndex..., in: dateStr)) {
            var components = DateComponents()
            if let r = Range(match.range(at: 1), in: dateStr) { components.year = Int(dateStr[r]) }
            if let r = Range(match.range(at: 2), in: dateStr) { components.month = Int(dateStr[r]) }
            if let r = Range(match.range(at: 3), in: dateStr) { components.day = Int(dateStr[r]) }
            if let r = Range(match.range(at: 4), in: dateStr) { components.hour = Int(dateStr[r]) }
            if let r = Range(match.range(at: 5), in: dateStr) { components.minute = Int(dateStr[r]) }
            if let r = Range(match.range(at: 6), in: dateStr) { components.second = Int(dateStr[r]) }
            return Calendar.current.date(from: components)
        }
        return nil
    }

    private func extractGroup(_ match: NSTextCheckingResult, at index: Int, in content: String) -> String? {
        guard match.numberOfRanges > index,
              let range = Range(match.range(at: index), in: content) else { return nil }
        return String(content[range])
    }
}

// MARK: - Forensic Result
struct ForensicResult {
    let embeddedImages: [PDFAnalysis.EmbeddedImage]
    let links: [PDFAnalysis.PDFLink]
    let layers: [PDFAnalysis.PDFLayer]
    let signatures: [PDFAnalysis.DigitalSignature]
    let hiddenContent: [PDFAnalysis.HiddenContent]
    let xmpHistory: [PDFAnalysis.XMPHistoryEntry]
    let redactions: [PDFAnalysis.Redaction]
    let suspiciousElements: [PDFAnalysis.SuspiciousElement]
}
