import Foundation

// MARK: - Tampering Analysis
struct TamperingAnalysis: Codable {
    let indicators: [TamperingIndicator]
    let score: Double // 0-100, higher = more likely tampered
    let likelihood: TamperingLikelihood
    let summary: String

    init(indicators: [TamperingIndicator]) {
        self.indicators = indicators

        // Calculate score based on weighted indicators
        let totalWeight = indicators.reduce(0.0) { $0 + $1.weight }
        self.score = min(100, totalWeight)

        // Determine likelihood
        self.likelihood = TamperingLikelihood.fromScore(score)

        // Generate summary
        let highCount = indicators.filter { $0.severity == .high || $0.severity == .critical }.count
        let mediumCount = indicators.filter { $0.severity == .medium }.count

        if indicators.isEmpty {
            self.summary = "No tampering indicators detected. Document appears unmodified."
        } else if highCount > 0 {
            self.summary = "Strong evidence of modification: \(highCount) high-severity indicator(s) found."
        } else if mediumCount > 0 {
            self.summary = "Document shows signs of editing: \(mediumCount) indicator(s) suggest post-creation changes."
        } else {
            self.summary = "Minor indicators present but document may be unmodified."
        }
    }

    var hasIndicators: Bool {
        !indicators.isEmpty
    }

    var criticalIndicators: [TamperingIndicator] {
        indicators.filter { $0.severity == .critical }
    }

    var highIndicators: [TamperingIndicator] {
        indicators.filter { $0.severity == .high }
    }

    var mediumIndicators: [TamperingIndicator] {
        indicators.filter { $0.severity == .medium }
    }

    var lowIndicators: [TamperingIndicator] {
        indicators.filter { $0.severity == .low || $0.severity == .info }
    }
}

// MARK: - Tampering Indicator
struct TamperingIndicator: Identifiable, Codable {
    let id: UUID
    let type: TamperingIndicatorType
    let severity: Severity
    let title: String
    let description: String
    let details: [String: String]?
    let weight: Double

    init(
        type: TamperingIndicatorType,
        severity: Severity,
        title: String,
        description: String,
        details: [String: String]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.details = details
        self.weight = type.baseWeight * severity.multiplier
    }
}

// MARK: - Tampering Indicator Type
enum TamperingIndicatorType: String, Codable, CaseIterable {
    // Structure indicators
    case incrementalUpdates = "Incremental Updates"
    case deletedObjects = "Deleted Objects"
    case multipleXrefTables = "Multiple XRef Tables"

    // Date indicators
    case dateDiscrepancy = "Date Discrepancy"
    case metadataDateMismatch = "Metadata Date Mismatch"
    case futureDate = "Future Date"
    case suspiciousTimestamp = "Suspicious Timestamp"

    // Signature indicators
    case invalidSignature = "Invalid Signature"
    case partialSignature = "Partial Signature Coverage"
    case signatureAfterModification = "Signature After Modification"

    // Content indicators
    case hiddenContent = "Hidden Content"
    case hiddenLayers = "Hidden Layers"
    case improperRedaction = "Improper Redaction"
    case recoverableContent = "Recoverable Content"

    // Tool chain indicators
    case multipleToolsUsed = "Multiple Tools Used"
    case toolMismatch = "Tool Mismatch"
    case suspiciousProducer = "Suspicious Producer"

    // Metadata indicators
    case xmpEditHistory = "XMP Edit History"
    case metadataStripped = "Metadata Stripped"
    case inconsistentMetadata = "Inconsistent Metadata"

    // Security indicators
    case javascript = "JavaScript Present"
    case embeddedFiles = "Embedded Files"
    case gpsData = "GPS Location Data"

    var baseWeight: Double {
        switch self {
        case .invalidSignature, .partialSignature, .improperRedaction:
            return 30.0
        case .deletedObjects, .incrementalUpdates, .hiddenContent:
            return 20.0
        case .dateDiscrepancy, .metadataDateMismatch, .xmpEditHistory:
            return 15.0
        case .hiddenLayers, .multipleToolsUsed, .recoverableContent:
            return 12.0
        case .javascript, .embeddedFiles, .gpsData:
            return 10.0
        case .multipleXrefTables, .signatureAfterModification:
            return 18.0
        case .toolMismatch, .suspiciousProducer, .metadataStripped:
            return 8.0
        case .futureDate, .suspiciousTimestamp, .inconsistentMetadata:
            return 12.0
        }
    }

    var category: String {
        switch self {
        case .incrementalUpdates, .deletedObjects, .multipleXrefTables:
            return "Structure"
        case .dateDiscrepancy, .metadataDateMismatch, .futureDate, .suspiciousTimestamp:
            return "Timestamps"
        case .invalidSignature, .partialSignature, .signatureAfterModification:
            return "Signatures"
        case .hiddenContent, .hiddenLayers, .improperRedaction, .recoverableContent:
            return "Hidden Content"
        case .multipleToolsUsed, .toolMismatch, .suspiciousProducer:
            return "Tool Chain"
        case .xmpEditHistory, .metadataStripped, .inconsistentMetadata:
            return "Metadata"
        case .javascript, .embeddedFiles, .gpsData:
            return "Security"
        }
    }

    var icon: String {
        switch self {
        case .incrementalUpdates, .deletedObjects, .multipleXrefTables:
            return "doc.badge.gearshape"
        case .dateDiscrepancy, .metadataDateMismatch, .futureDate, .suspiciousTimestamp:
            return "calendar.badge.exclamationmark"
        case .invalidSignature, .partialSignature, .signatureAfterModification:
            return "signature"
        case .hiddenContent, .hiddenLayers, .improperRedaction, .recoverableContent:
            return "eye.slash"
        case .multipleToolsUsed, .toolMismatch, .suspiciousProducer:
            return "wrench.and.screwdriver"
        case .xmpEditHistory, .metadataStripped, .inconsistentMetadata:
            return "info.circle"
        case .javascript, .embeddedFiles, .gpsData:
            return "exclamationmark.shield"
        }
    }
}

// MARK: - Tampering Likelihood
enum TamperingLikelihood: String, Codable {
    case none = "No Evidence"
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"

    static func fromScore(_ score: Double) -> TamperingLikelihood {
        switch score {
        case 0..<5: return .none
        case 5..<20: return .low
        case 20..<45: return .moderate
        case 45..<70: return .high
        default: return .veryHigh
        }
    }

    var color: String {
        switch self {
        case .none: return "accent"
        case .low: return "accent"
        case .moderate: return "orange"
        case .high: return "red"
        case .veryHigh: return "red"
        }
    }
}

// MARK: - Severity Extension for Weight
extension Severity {
    var multiplier: Double {
        switch self {
        case .critical: return 1.5
        case .high: return 1.2
        case .medium: return 1.0
        case .low: return 0.6
        case .info: return 0.3
        }
    }
}
