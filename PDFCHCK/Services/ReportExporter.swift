import Foundation
import AppKit
import PDFKit

// MARK: - Report Exporter
class ReportExporter {

    // MARK: - Export to JSON
    static func exportToJSON(report: DetectionReport, url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonReport = JSONReport(from: report)
        let data = try encoder.encode(jsonReport)
        try data.write(to: url)
    }

    // MARK: - Export to PDF
    static func exportToPDF(report: DetectionReport, url: URL) throws {
        let pdfDocument = PDFDocument()

        // Create pages
        var pageNumber = 0

        // Title page
        if let titlePage = createTitlePage(report: report) {
            pdfDocument.insert(titlePage, at: pageNumber)
            pageNumber += 1
        }

        // Summary page
        if let summaryPage = createSummaryPage(report: report) {
            pdfDocument.insert(summaryPage, at: pageNumber)
            pageNumber += 1
        }

        // Findings pages
        let findingsPages = createFindingsPages(report: report)
        for page in findingsPages {
            pdfDocument.insert(page, at: pageNumber)
            pageNumber += 1
        }

        // Metadata comparison page
        if let metadataPage = createMetadataPage(report: report) {
            pdfDocument.insert(metadataPage, at: pageNumber)
            pageNumber += 1
        }

        // Write to file
        pdfDocument.write(to: url)
    }

    // MARK: - Create Title Page
    private static func createTitlePage(report: DetectionReport) -> PDFPage? {
        let pageSize = CGSize(width: 612, height: 792) // Letter size
        let page = createBlankPage(size: pageSize)

        guard let context = NSGraphicsContext.current?.cgContext else { return page }

        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 28)
        let title = "PDF Forgery Detection Report"
        drawText(title, at: CGPoint(x: 72, y: 700), font: titleFont, context: context)

        // Subtitle
        let subtitleFont = NSFont.systemFont(ofSize: 14)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        let subtitle = "Generated: \(dateFormatter.string(from: Date()))"
        drawText(subtitle, at: CGPoint(x: 72, y: 665), font: subtitleFont, color: .gray, context: context)

        // Risk Score Box
        let riskY: CGFloat = 500
        let riskFont = NSFont.boldSystemFont(ofSize: 48)
        let riskLabel = NSFont.systemFont(ofSize: 16)

        drawText("RISK SCORE", at: CGPoint(x: 250, y: riskY + 70), font: riskLabel, context: context)
        drawText("\(Int(report.riskScore))", at: CGPoint(x: 280, y: riskY), font: riskFont, context: context)
        drawText(report.riskLevel.rawValue.uppercased(), at: CGPoint(x: 260, y: riskY - 30), font: riskLabel, context: context)

        // File info
        let infoY: CGFloat = 350
        let infoFont = NSFont.systemFont(ofSize: 12)

        drawText("Original: \(report.originalFile.name)", at: CGPoint(x: 72, y: infoY), font: infoFont, context: context)
        drawText("Size: \(report.originalFile.formattedSize)", at: CGPoint(x: 72, y: infoY - 20), font: infoFont, color: .gray, context: context)

        drawText("Comparison: \(report.comparisonFile.name)", at: CGPoint(x: 72, y: infoY - 60), font: infoFont, context: context)
        drawText("Size: \(report.comparisonFile.formattedSize)", at: CGPoint(x: 72, y: infoY - 80), font: infoFont, color: .gray, context: context)

        // Footer
        drawText("PDFCHCK - PDF Forgery Detection Tool", at: CGPoint(x: 200, y: 50), font: NSFont.systemFont(ofSize: 10), color: .gray, context: context)

        return page
    }

    // MARK: - Create Summary Page
    private static func createSummaryPage(report: DetectionReport) -> PDFPage? {
        let pageSize = CGSize(width: 612, height: 792)
        let page = createBlankPage(size: pageSize)

        guard let context = NSGraphicsContext.current?.cgContext else { return page }

        var y: CGFloat = 720

        // Header
        drawText("Analysis Summary", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 20), context: context)
        y -= 40

        // Similarity scores
        drawText("Similarity Analysis", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 14), context: context)
        y -= 25

        drawText("Text Similarity: \(String(format: "%.1f%%", report.textComparison.overallSimilarity * 100))",
                 at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 20

        drawText("Visual Similarity (SSIM): \(String(format: "%.1f%%", report.visualComparison.averageSSIM * 100))",
                 at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 40

        // Findings summary
        drawText("Findings Summary", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 14), context: context)
        y -= 25

        let criticalCount = report.findings.filter { $0.severity == .critical }.count
        let highCount = report.findings.filter { $0.severity == .high }.count
        let mediumCount = report.findings.filter { $0.severity == .medium }.count
        let lowCount = report.findings.filter { $0.severity == .low }.count

        drawText("Critical: \(criticalCount)", at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), color: criticalCount > 0 ? .red : .black, context: context)
        y -= 20
        drawText("High: \(highCount)", at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 20
        drawText("Medium: \(mediumCount)", at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 20
        drawText("Low/Info: \(lowCount)", at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 40

        // Metadata summary
        drawText("Metadata Comparison", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 14), context: context)
        y -= 25

        drawText("PDF Metadata Match: \(report.metadataComparison.pdfMetadataMatch ? "Yes" : "No")",
                 at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 20
        drawText("File Info Match: \(report.metadataComparison.fileInfoMatch ? "Yes" : "No")",
                 at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), context: context)
        y -= 20
        drawText("Timestamp Anomalies: \(report.metadataComparison.timestampAnomalies ? "Yes" : "No")",
                 at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 12), color: report.metadataComparison.timestampAnomalies ? .red : .black, context: context)

        return page
    }

    // MARK: - Create Findings Pages
    private static func createFindingsPages(report: DetectionReport) -> [PDFPage] {
        var pages: [PDFPage] = []
        let pageSize = CGSize(width: 612, height: 792)

        var currentPage = createBlankPage(size: pageSize)
        var y: CGFloat = 720

        guard let context = NSGraphicsContext.current?.cgContext else { return pages }

        // Header
        drawText("Detailed Findings", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 20), context: context)
        y -= 40

        let sortedFindings = report.findings.sorted { $0.severity > $1.severity }

        for finding in sortedFindings {
            // Check if we need a new page
            if y < 100 {
                pages.append(currentPage)
                currentPage = createBlankPage(size: pageSize)
                y = 720
            }

            // Severity indicator
            let severityColor: NSColor
            switch finding.severity {
            case .critical: severityColor = .red
            case .high: severityColor = .orange
            case .medium: severityColor = .yellow
            case .low: severityColor = .gray
            case .info: severityColor = .blue
            }

            // Finding box
            drawText("[\(finding.severity.rawValue.uppercased())]", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 10), color: severityColor, context: context)
            drawText(finding.title, at: CGPoint(x: 140, y: y), font: NSFont.boldSystemFont(ofSize: 12), context: context)
            y -= 18

            drawText(finding.description, at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 11), color: .darkGray, context: context)
            y -= 18

            if let page = finding.pageNumber {
                drawText("Page: \(page)", at: CGPoint(x: 90, y: y), font: NSFont.systemFont(ofSize: 10), color: .gray, context: context)
                y -= 15
            }

            y -= 15 // Spacing between findings
        }

        pages.append(currentPage)
        return pages
    }

    // MARK: - Create Metadata Page
    private static func createMetadataPage(report: DetectionReport) -> PDFPage? {
        let pageSize = CGSize(width: 612, height: 792)
        let page = createBlankPage(size: pageSize)

        guard let context = NSGraphicsContext.current?.cgContext else { return page }

        var y: CGFloat = 720

        drawText("File Checksums", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 20), context: context)
        y -= 40

        drawText("Original SHA-256:", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 10), context: context)
        y -= 15
        drawText(report.originalFile.checksum ?? "N/A", at: CGPoint(x: 72, y: y), font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular), context: context)
        y -= 30

        drawText("Comparison SHA-256:", at: CGPoint(x: 72, y: y), font: NSFont.boldSystemFont(ofSize: 10), context: context)
        y -= 15
        drawText(report.comparisonFile.checksum ?? "N/A", at: CGPoint(x: 72, y: y), font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular), context: context)

        return page
    }

    // MARK: - Helper Functions
    private static func createBlankPage(size: CGSize) -> PDFPage {
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        image.unlockFocus()

        return PDFPage(image: image) ?? PDFPage()
    }

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .black, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        context.saveGState()
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

// MARK: - JSON Report Structure
struct JSONReport: Codable {
    let generatedAt: Date
    let version: String
    let riskScore: Double
    let riskLevel: String

    let originalFile: JSONFileInfo
    let comparisonFile: JSONFileInfo

    let textSimilarity: Double
    let visualSimilarity: Double

    let findings: [JSONFinding]

    let metadata: JSONMetadataComparison

    init(from report: DetectionReport) {
        self.generatedAt = Date()
        self.version = "1.0"
        self.riskScore = report.riskScore
        self.riskLevel = report.riskLevel.rawValue

        self.originalFile = JSONFileInfo(from: report.originalFile)
        self.comparisonFile = JSONFileInfo(from: report.comparisonFile)

        self.textSimilarity = report.textComparison.overallSimilarity
        self.visualSimilarity = report.visualComparison.averageSSIM

        self.findings = report.findings.map { JSONFinding(from: $0) }

        self.metadata = JSONMetadataComparison(from: report.metadataComparison)
    }
}

struct JSONFileInfo: Codable {
    let name: String
    let path: String
    let size: Int64
    let sizeFormatted: String
    let checksum: String?

    init(from file: FileReference) {
        self.name = file.name
        self.path = file.path
        self.size = file.size
        self.sizeFormatted = file.formattedSize
        self.checksum = file.checksum
    }
}

struct JSONFinding: Codable {
    let category: String
    let severity: String
    let title: String
    let description: String
    let details: [String: String]?
    let pageNumber: Int?

    init(from finding: Finding) {
        self.category = finding.category.rawValue
        self.severity = finding.severity.rawValue
        self.title = finding.title
        self.description = finding.description
        self.details = finding.details
        self.pageNumber = finding.pageNumber
    }
}

struct JSONMetadataComparison: Codable {
    let pdfMetadataMatch: Bool
    let fileInfoMatch: Bool
    let timestampAnomalies: Bool
    let differenceCount: Int

    init(from comparison: MetadataComparisonSummary) {
        self.pdfMetadataMatch = comparison.pdfMetadataMatch
        self.fileInfoMatch = comparison.fileInfoMatch
        self.timestampAnomalies = comparison.timestampAnomalies
        self.differenceCount = comparison.differenceCount
    }
}
