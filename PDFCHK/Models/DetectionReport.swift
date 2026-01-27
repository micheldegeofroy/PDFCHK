import Foundation

// MARK: - Detection Report
struct DetectionReport: Codable {
    let id: UUID
    let timestamp: Date
    let originalFile: FileReference
    let comparisonFile: FileReference
    let riskScore: Double
    let riskLevel: RiskLevel
    let findings: [Finding]
    let textComparison: TextComparisonSummary
    let visualComparison: VisualComparisonSummary
    let metadataComparison: MetadataComparisonSummary
    let externalToolsAnalysis: ExternalToolsComparisonSummary?
    let tamperingAnalysis: TamperingAnalysis?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalFile: FileReference,
        comparisonFile: FileReference,
        riskScore: Double,
        findings: [Finding],
        textComparison: TextComparisonSummary,
        visualComparison: VisualComparisonSummary,
        metadataComparison: MetadataComparisonSummary,
        externalToolsAnalysis: ExternalToolsComparisonSummary? = nil,
        tamperingAnalysis: TamperingAnalysis? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalFile = originalFile
        self.comparisonFile = comparisonFile
        self.riskScore = riskScore
        self.riskLevel = RiskLevel.fromScore(riskScore)
        self.findings = findings
        self.textComparison = textComparison
        self.visualComparison = visualComparison
        self.metadataComparison = metadataComparison
        self.externalToolsAnalysis = externalToolsAnalysis
        self.tamperingAnalysis = tamperingAnalysis
    }

    var criticalFindings: [Finding] {
        findings.filter { $0.severity == .critical }
    }

    var highFindings: [Finding] {
        findings.filter { $0.severity == .high }
    }
}

// MARK: - File Reference
struct FileReference: Codable {
    let name: String
    let path: String
    let size: Int64
    let checksum: String?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - Summary Structs (for report serialization)
struct TextComparisonSummary: Codable {
    let overallSimilarity: Double
    let pageCount: Int
    let pagesWithDifferences: Int
    let totalDifferences: Int
}

struct VisualComparisonSummary: Codable {
    let averageSSIM: Double
    let averagePixelDiff: Double
    let pageCount: Int
    let pagesWithDifferences: Int
}

struct MetadataComparisonSummary: Codable {
    let pdfMetadataMatch: Bool
    let fileInfoMatch: Bool
    let timestampAnomalies: Bool
    let differenceCount: Int
}

// MARK: - External Tools Comparison Summary
struct ExternalToolsComparisonSummary: Codable {
    let toolsAvailable: ToolAvailabilityInfo
    let originalAnalysis: ExternalToolsAnalysis?
    let comparisonAnalysis: ExternalToolsAnalysis?
    let fontComparison: FontComparisonResult?
    let resourceComparison: ResourceComparisonResult?
    let suspiciousFindings: [String]

    var hasFindings: Bool {
        !(suspiciousFindings.isEmpty)
    }

    var fontDifferencesDetected: Bool {
        fontComparison?.hasDifferences ?? false
    }

    var resourceDifferencesDetected: Bool {
        resourceComparison?.hasDifferences ?? false
    }

    var incrementalUpdatesDetected: Bool {
        (originalAnalysis?.pdfObjectInfo?.hasIncrementalUpdates ?? false) ||
        (comparisonAnalysis?.pdfObjectInfo?.hasIncrementalUpdates ?? false)
    }

    var gpsDataFound: Bool {
        !(originalAnalysis?.gpsLocations.isEmpty ?? true) ||
        !(comparisonAnalysis?.gpsLocations.isEmpty ?? true)
    }

    var embeddedDocumentsFound: Bool {
        !(originalAnalysis?.embeddedDocuments.isEmpty ?? true) ||
        !(comparisonAnalysis?.embeddedDocuments.isEmpty ?? true)
    }
}

// MARK: - Report Export
extension DetectionReport {
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func toJSONString() throws -> String {
        let data = try toJSON()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func fromJSON(_ data: Data) throws -> DetectionReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DetectionReport.self, from: data)
    }
}
