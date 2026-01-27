import Foundation

// MARK: - Text Comparison Result
struct TextComparisonResult: Codable {
    let similarity: Double  // 0.0 to 1.0
    let pageResults: [PageTextResult]
    let totalCharactersOriginal: Int
    let totalCharactersComparison: Int
    let diffOperations: [DiffOperation]

    var overallMatch: Bool {
        similarity >= 0.99
    }
}

// MARK: - Page Text Result
struct PageTextResult: Codable, Identifiable {
    let id = UUID()
    let pageNumber: Int
    let similarity: Double
    let originalText: String
    let comparisonText: String
    let differences: [TextDifference]

    var hasChanges: Bool {
        similarity < 1.0
    }

    private enum CodingKeys: String, CodingKey {
        case pageNumber, similarity, originalText, comparisonText, differences
    }
}

// MARK: - Text Difference
struct TextDifference: Codable, Identifiable {
    let id = UUID()
    let type: DifferenceType
    let originalRange: Range<Int>?
    let comparisonRange: Range<Int>?
    let originalText: String
    let comparisonText: String

    enum DifferenceType: String, Codable {
        case insertion
        case deletion
        case modification
    }

    private enum CodingKeys: String, CodingKey {
        case type, originalRange, comparisonRange, originalText, comparisonText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(DifferenceType.self, forKey: .type)
        originalText = try container.decode(String.self, forKey: .originalText)
        comparisonText = try container.decode(String.self, forKey: .comparisonText)

        if let rangeArray = try container.decodeIfPresent([Int].self, forKey: .originalRange),
           rangeArray.count == 2 {
            originalRange = rangeArray[0]..<rangeArray[1]
        } else {
            originalRange = nil
        }

        if let rangeArray = try container.decodeIfPresent([Int].self, forKey: .comparisonRange),
           rangeArray.count == 2 {
            comparisonRange = rangeArray[0]..<rangeArray[1]
        } else {
            comparisonRange = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(comparisonText, forKey: .comparisonText)

        if let range = originalRange {
            try container.encode([range.lowerBound, range.upperBound], forKey: .originalRange)
        }
        if let range = comparisonRange {
            try container.encode([range.lowerBound, range.upperBound], forKey: .comparisonRange)
        }
    }

    init(type: DifferenceType, originalRange: Range<Int>?, comparisonRange: Range<Int>?,
         originalText: String, comparisonText: String) {
        self.type = type
        self.originalRange = originalRange
        self.comparisonRange = comparisonRange
        self.originalText = originalText
        self.comparisonText = comparisonText
    }
}

// MARK: - Diff Operation (for LCS algorithm)
enum DiffOperation: Codable, Equatable {
    case equal(String)
    case insert(String)
    case delete(String)

    var text: String {
        switch self {
        case .equal(let t), .insert(let t), .delete(let t):
            return t
        }
    }
}
