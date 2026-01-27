import Foundation

// MARK: - Embedded Font
struct EmbeddedFont: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: String
    let encoding: String?
    let embedded: Bool
    let subset: Bool
    let pageNumber: Int

    enum CodingKeys: String, CodingKey {
        case name, type, encoding, embedded, subset, pageNumber
    }
}

// MARK: - Page Resources
struct PageResources: Identifiable, Codable {
    let id = UUID()
    let pageNumber: Int
    let fonts: [String]
    let images: [String]
    let shadings: [String]

    var totalResources: Int {
        fonts.count + images.count + shadings.count
    }

    enum CodingKeys: String, CodingKey {
        case pageNumber, fonts, images, shadings
    }
}

// MARK: - Extracted Image
struct ExtractedImage: Identifiable, Codable {
    let id = UUID()
    let filename: String
    let path: String
    let size: Int64
    let format: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case filename, path, size, format
    }
}

// MARK: - PDF Object Info (for incremental update detection)
struct PDFObjectInfo: Codable {
    var hasIncrementalUpdates: Bool = false
    var previousXRefOffsets: [Int] = []
    var objectCount: Int = 0
    var activeObjects: Int = 0
    var freeObjects: Int = 0

    var updateCount: Int {
        previousXRefOffsets.count
    }

    var suspiciousIndicators: [String] {
        var indicators: [String] = []
        if hasIncrementalUpdates {
            indicators.append("Document has been modified after initial creation")
        }
        if updateCount > 3 {
            indicators.append("Multiple incremental updates detected (\(updateCount))")
        }
        if freeObjects > 0 {
            indicators.append("\(freeObjects) deleted objects found")
        }
        return indicators
    }
}

// MARK: - Stream Content
struct StreamContent: Identifiable, Codable {
    let id = UUID()
    let objectNumber: Int
    let rawContent: String
    let decodedContent: String
    let isCompressed: Bool

    var contentPreview: String {
        String(decodedContent.prefix(500))
    }

    enum CodingKeys: String, CodingKey {
        case objectNumber, rawContent, decodedContent, isCompressed
    }
}

// MARK: - XMP Metadata
struct XMPMetadata: Codable {
    var namespaces: [String: [String: String]] = [:]
    var editHistory: [XMPHistoryEntry] = []

    var hasEditHistory: Bool {
        !editHistory.isEmpty
    }

    var allProperties: [(namespace: String, key: String, value: String)] {
        var result: [(String, String, String)] = []
        for (namespace, properties) in namespaces {
            for (key, value) in properties {
                result.append((namespace, key, value))
            }
        }
        return result.sorted { $0.0 + $0.1 < $1.0 + $1.1 }
    }
}

// MARK: - XMP History Entry
struct XMPHistoryEntry: Identifiable, Codable {
    let id = UUID()
    let action: String
    let when: String
    let softwareAgent: String
    let instanceID: String?

    enum CodingKeys: String, CodingKey {
        case action, when, softwareAgent, instanceID
    }
}

// MARK: - PDF Version History
struct PDFVersionHistory: Codable {
    var createDate: String?
    var modifyDate: String?
    var metadataDate: String?
    var producer: String?
    var creator: String?
    var pdfVersion: String?
    var isLinearized: Bool = false

    var dateDiscrepancy: Bool {
        guard let create = createDate, let modify = modifyDate else {
            return false
        }
        // Check if dates are significantly different (indicating edits)
        return create != modify
    }

    var toolChain: [String] {
        var tools: [String] = []
        if let creator = creator, !creator.isEmpty {
            tools.append("Creator: \(creator)")
        }
        if let producer = producer, !producer.isEmpty {
            tools.append("Producer: \(producer)")
        }
        return tools
    }
}

// MARK: - Embedded Document
struct EmbeddedDocument: Identifiable, Codable {
    let id = UUID()
    let filename: String
    let path: String
    let size: Int64
    let mimeType: String

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    enum CodingKeys: String, CodingKey {
        case filename, path, size, mimeType
    }
}

// MARK: - GPS Location
struct GPSLocation: Identifiable, Codable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: String?
    let source: String

    var coordinateString: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    var mapsURL: URL? {
        URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)")
    }

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, altitude, timestamp, source
    }
}

// MARK: - Forensic Metadata
struct ForensicMetadata: Codable {
    var groups: [String: [String: String]] = [:]

    var allGroups: [String] {
        groups.keys.sorted()
    }

    func properties(for group: String) -> [(key: String, value: String)] {
        guard let props = groups[group] else { return [] }
        return props.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
}

// MARK: - External Tools Analysis Result
struct ExternalToolsAnalysis: Codable {
    var toolAvailability: ToolAvailabilityInfo
    var fonts: [EmbeddedFont] = []
    var pageResources: [PageResources] = []
    var extractedImages: [ExtractedImage] = []
    var pdfObjectInfo: PDFObjectInfo?
    var xmpMetadata: XMPMetadata?
    var versionHistory: PDFVersionHistory?
    var embeddedDocuments: [EmbeddedDocument] = []
    var gpsLocations: [GPSLocation] = []
    var forensicMetadata: ForensicMetadata?

    var hasFindings: Bool {
        !fonts.isEmpty ||
        !pageResources.isEmpty ||
        pdfObjectInfo?.hasIncrementalUpdates == true ||
        xmpMetadata?.hasEditHistory == true ||
        !embeddedDocuments.isEmpty ||
        !gpsLocations.isEmpty
    }

    var suspiciousFindings: [String] {
        var findings: [String] = []

        // Font inconsistencies
        let fontNames = Set(fonts.map { $0.name })
        if fontNames.count > 10 {
            findings.append("Unusually high number of fonts (\(fontNames.count))")
        }

        // Incremental updates
        if let objInfo = pdfObjectInfo {
            findings.append(contentsOf: objInfo.suspiciousIndicators)
        }

        // Edit history
        if let xmp = xmpMetadata, xmp.hasEditHistory {
            findings.append("XMP edit history shows \(xmp.editHistory.count) modifications")
        }

        // Date discrepancies
        if versionHistory?.dateDiscrepancy == true {
            findings.append("Creation and modification dates differ")
        }

        // GPS data (potential privacy concern)
        if !gpsLocations.isEmpty {
            findings.append("GPS location data found in embedded content")
        }

        return findings
    }
}

// MARK: - Tool Availability Info (Codable version)
struct ToolAvailabilityInfo: Codable {
    var mutoolAvailable: Bool
    var exiftoolAvailable: Bool
    var missingToolsMessage: String?
}

// MARK: - Font Comparison Result
struct FontComparisonResult: Codable {
    let originalFonts: [EmbeddedFont]
    let comparisonFonts: [EmbeddedFont]
    let addedFonts: [String]
    let removedFonts: [String]
    let commonFonts: [String]

    var hasDifferences: Bool {
        !addedFonts.isEmpty || !removedFonts.isEmpty
    }

    static func compare(original: [EmbeddedFont], comparison: [EmbeddedFont]) -> FontComparisonResult {
        let originalNames = Set(original.map { $0.name })
        let comparisonNames = Set(comparison.map { $0.name })

        return FontComparisonResult(
            originalFonts: original,
            comparisonFonts: comparison,
            addedFonts: Array(comparisonNames.subtracting(originalNames)).sorted(),
            removedFonts: Array(originalNames.subtracting(comparisonNames)).sorted(),
            commonFonts: Array(originalNames.intersection(comparisonNames)).sorted()
        )
    }
}

// MARK: - Resource Comparison Result
struct ResourceComparisonResult: Codable {
    let originalResources: [PageResources]
    let comparisonResources: [PageResources]
    let pagesWithDifferentResources: [Int]

    var hasDifferences: Bool {
        !pagesWithDifferentResources.isEmpty
    }

    static func compare(original: [PageResources], comparison: [PageResources]) -> ResourceComparisonResult {
        var differentPages: [Int] = []

        let maxPages = max(original.count, comparison.count)
        for i in 0..<maxPages {
            let origPage = original.first { $0.pageNumber == i + 1 }
            let compPage = comparison.first { $0.pageNumber == i + 1 }

            if origPage?.fonts.count != compPage?.fonts.count ||
               origPage?.images.count != compPage?.images.count ||
               origPage?.shadings.count != compPage?.shadings.count {
                differentPages.append(i + 1)
            }
        }

        return ResourceComparisonResult(
            originalResources: original,
            comparisonResources: comparison,
            pagesWithDifferentResources: differentPages
        )
    }
}
