import Foundation

// MARK: - Severity Level
enum Severity: String, Codable, CaseIterable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case info = "Info"

    var weight: Int {
        switch self {
        case .critical: return 100
        case .high: return 75
        case .medium: return 50
        case .low: return 25
        case .info: return 0
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.weight < rhs.weight
    }
}

// MARK: - Risk Level
enum RiskLevel: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case minimal = "Minimal"

    static func fromScore(_ score: Double) -> RiskLevel {
        switch score {
        case 70...100: return .high
        case 40..<70: return .medium
        case 15..<40: return .low
        default: return .minimal
        }
    }
}

// MARK: - Finding Category
enum FindingCategory: String, Codable, CaseIterable {
    case metadata = "Metadata"
    case text = "Text"
    case visual = "Visual"
    case structure = "Structure"
    case timestamp = "Timestamp"
    case images = "Images"
    case signatures = "Signatures"
    case security = "Security"
    case hidden = "Hidden Content"
    case links = "Links"
    case forensic = "Forensic"
}

// MARK: - Finding
struct Finding: Identifiable, Codable, Hashable {
    let id: UUID
    let category: FindingCategory
    let severity: Severity
    let title: String
    let description: String
    let details: [String: String]?
    let pageNumber: Int?

    init(
        id: UUID = UUID(),
        category: FindingCategory,
        severity: Severity,
        title: String,
        description: String,
        details: [String: String]? = nil,
        pageNumber: Int? = nil
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.description = description
        self.details = details
        self.pageNumber = pageNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Finding, rhs: Finding) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Findings Collection Extension
extension Array where Element == Finding {
    func grouped() -> [FindingCategory: [Finding]] {
        Dictionary(grouping: self, by: { $0.category })
    }

    func sortedBySeverity() -> [Finding] {
        sorted { $0.severity > $1.severity }
    }

    var criticalCount: Int {
        filter { $0.severity == .critical }.count
    }

    var highCount: Int {
        filter { $0.severity == .high }.count
    }

    var mediumCount: Int {
        filter { $0.severity == .medium }.count
    }
}
