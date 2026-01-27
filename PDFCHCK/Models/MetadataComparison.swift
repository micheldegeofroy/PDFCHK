import Foundation

// MARK: - Metadata Comparison
struct MetadataComparison: Codable {
    let pdfMetadataMatch: Bool
    let fileInfoMatch: Bool
    let timestampAnalysis: TimestampAnalysis
    let differences: [MetadataDifference]
    let findings: [Finding]

    var overallMatch: Bool {
        pdfMetadataMatch && fileInfoMatch && !timestampAnalysis.hasAnomalies
    }
}

// MARK: - Timestamp Analysis
struct TimestampAnalysis: Codable {
    let originalCreation: Date?
    let originalModification: Date?
    let comparisonCreation: Date?
    let comparisonModification: Date?
    let hasAnomalies: Bool
    let anomalyDescription: String?

    var creationDifference: TimeInterval? {
        guard let orig = originalCreation, let comp = comparisonCreation else { return nil }
        return abs(comp.timeIntervalSince(orig))
    }

    var modificationDifference: TimeInterval? {
        guard let orig = originalModification, let comp = comparisonModification else { return nil }
        return abs(comp.timeIntervalSince(orig))
    }
}

// MARK: - Metadata Difference
struct MetadataDifference: Codable, Identifiable {
    let id = UUID()
    let field: String
    let originalValue: String?
    let comparisonValue: String?
    let isSignificant: Bool

    private enum CodingKeys: String, CodingKey {
        case field, originalValue, comparisonValue, isSignificant
    }

    var description: String {
        let orig = originalValue ?? "(none)"
        let comp = comparisonValue ?? "(none)"
        return "\(field): '\(orig)' → '\(comp)'"
    }
}

// MARK: - Metadata Field
enum MetadataField: String, CaseIterable {
    case title = "Title"
    case author = "Author"
    case subject = "Subject"
    case creator = "Creator"
    case producer = "Producer"
    case creationDate = "Creation Date"
    case modificationDate = "Modification Date"
    case keywords = "Keywords"
    case version = "PDF Version"
    case encrypted = "Encrypted"
    case fileSize = "File Size"
    case fileName = "File Name"

    var isSignificantForForgery: Bool {
        switch self {
        case .creationDate, .modificationDate, .producer, .creator:
            return true
        default:
            return false
        }
    }
}

// MARK: - Metadata Tree Node (for UI display)
struct MetadataTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let value: String?
    let children: [MetadataTreeNode]
    let isExpanded: Bool

    init(name: String, value: String? = nil, children: [MetadataTreeNode] = [], isExpanded: Bool = true) {
        self.name = name
        self.value = value
        self.children = children
        self.isExpanded = isExpanded
    }

    var isLeaf: Bool {
        children.isEmpty
    }
}
