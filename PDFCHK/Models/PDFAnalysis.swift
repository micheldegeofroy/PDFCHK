import Foundation
import PDFKit
import AppKit

// MARK: - PDF Document Analysis
struct PDFAnalysis {
    let url: URL
    let document: PDFDocument
    let pageCount: Int
    let metadata: PDFMetadata
    let fileInfo: FileInfo
    let pageTexts: [Int: String]
    let pageImages: [Int: NSImage]

    // Extended analysis data
    var embeddedImages: [EmbeddedImage]
    var links: [PDFLink]
    var layers: [PDFLayer]
    var signatures: [DigitalSignature]
    var hiddenContent: [HiddenContent]
    var xmpHistory: [XMPHistoryEntry]
    var redactions: [Redaction]
    var suspiciousElements: [SuspiciousElement]

    // MARK: - Embedded Image
    struct EmbeddedImage: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let index: Int
        let width: Int
        let height: Int
        let bitsPerComponent: Int
        let colorSpace: String
        let filter: String?  // compression type
        let dataHash: String
        let image: NSImage?
    }

    // MARK: - PDF Link
    struct PDFLink: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let url: String?
        let destination: String?
        let actionType: String
        let bounds: CGRect
    }

    // MARK: - PDF Layer (OCG)
    struct PDFLayer: Identifiable {
        let id = UUID()
        let name: String
        let isVisible: Bool
        let isLocked: Bool
        let intent: String?
    }

    // MARK: - Digital Signature
    struct DigitalSignature: Identifiable {
        let id = UUID()
        let signerName: String?
        let signDate: Date?
        let reason: String?
        let location: String?
        let isValid: Bool
        let validationMessage: String
        let coversWholeDocument: Bool
        let certificateInfo: CertificateInfo?
    }

    struct CertificateInfo: Codable {
        let issuer: String?
        let subject: String?
        let serialNumber: String?
        let validFrom: Date?
        let validTo: Date?
        let isExpired: Bool
        let isSelfSigned: Bool
    }

    // MARK: - Hidden Content
    struct HiddenContent: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let type: HiddenContentType
        let description: String
        let bounds: CGRect?
    }

    enum HiddenContentType: String {
        case invisibleText = "Invisible Text"
        case whiteText = "White Text"
        case hiddenLayer = "Hidden Layer"
        case offPageContent = "Off-Page Content"
        case coveredContent = "Covered Content"
        case tinyText = "Microscopic Text"
    }

    // MARK: - XMP History Entry
    struct XMPHistoryEntry: Identifiable {
        let id = UUID()
        let action: String
        let when: Date?
        let softwareAgent: String?
        let parameters: String?
    }

    // MARK: - Redaction
    struct Redaction: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let bounds: CGRect
        let isProperlyApplied: Bool  // true if content actually removed
        let hasHiddenContent: Bool   // true if content just covered
    }

    // MARK: - Suspicious Element
    struct SuspiciousElement: Identifiable {
        let id = UUID()
        let type: SuspiciousType
        let description: String
        let pageNumber: Int?
        let severity: Severity
    }

    enum SuspiciousType: String {
        case javascriptAction = "JavaScript Action"
        case launchAction = "Launch Action"
        case orphanedObject = "Orphaned Object"
        case hiddenData = "Hidden Data"
        case toolMismatch = "Tool Mismatch"
        case modifiedAfterSigning = "Modified After Signing"
        case inconsistentDates = "Inconsistent Dates"
        case suspiciousRedaction = "Suspicious Redaction"
    }

    struct PDFMetadata: Codable {
        // Standard PDF metadata
        let title: String?
        let author: String?
        let subject: String?
        let creator: String?
        let producer: String?
        let creationDate: Date?
        let modificationDate: Date?
        let keywords: [String]?
        let version: String?
        let isEncrypted: Bool
        let allowsPrinting: Bool
        let allowsCopying: Bool

        // Extended PDF internals
        let documentID: DocumentID?
        let isLinearized: Bool
        let hasXMPMetadata: Bool
        let incrementalUpdates: Int
        let objectCount: Int
        let hasJavaScript: Bool
        let hasDigitalSignature: Bool
        let embeddedFileCount: Int
        let fontCount: Int
        let fonts: [FontInfo]  // Actual font details
        let annotationCount: Int
        let formFieldCount: Int
        let isTaggedPDF: Bool
        let pdfConformance: String?  // PDF/A, PDF/X, etc.
        let xrefType: String?  // "table" or "stream"

        struct DocumentID: Codable {
            let permanent: String?
            let changing: String?
        }

        struct FontInfo: Codable, Hashable {
            let name: String
            let type: String?  // Type1, TrueType, Type0, etc.
            let baseFont: String?
            let isEmbedded: Bool
            let isSubset: Bool
        }
    }

    struct FileInfo: Codable {
        let fileName: String
        let fileSize: Int64
        let creationDate: Date?
        let modificationDate: Date?
        let contentModificationDate: Date?
        let filePath: String

        // Extended macOS attributes
        let wasQuarantined: Bool
        let quarantineSource: String?
        let downloadedFrom: [String]?
        let extendedAttributes: [String: String]

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }
}

// MARK: - Page Comparison Result
struct PageComparisonResult {
    let pageNumber: Int
    let ssim: Double
    let pixelDifference: Double
    let diffImage: NSImage?
    let textSimilarity: Double

    var hasSignificantDifference: Bool {
        ssim < 0.95 || pixelDifference > 0.05
    }
}

// MARK: - Analysis Stage
enum AnalysisStage: String, CaseIterable {
    case loading = "Loading Documents"
    case metadata = "Analyzing Metadata"
    case text = "Comparing Text"
    case visual = "Visual Comparison"
    case structure = "Structure Analysis"
    case images = "Comparing Images"
    case security = "Security Analysis"
    case forensics = "Forensic Analysis"

    var index: Int {
        AnalysisStage.allCases.firstIndex(of: self) ?? 0
    }

    static var totalStages: Int {
        allCases.count
    }
}

// MARK: - Analysis Progress
struct AnalysisProgress {
    var stage: AnalysisStage
    var stageProgress: Double  // 0.0 to 1.0 within current stage
    var currentPage: Int?
    var totalPages: Int?

    var overallProgress: Double {
        let stageWeight = 1.0 / Double(AnalysisStage.totalStages)
        let stageStart = Double(stage.index) * stageWeight
        return stageStart + (stageProgress * stageWeight)
    }

    var description: String {
        if let current = currentPage, let total = totalPages {
            return "\(stage.rawValue) (\(current)/\(total))"
        }
        return stage.rawValue
    }

    static var initial: AnalysisProgress {
        AnalysisProgress(stage: .loading, stageProgress: 0)
    }
}
