import Foundation
import SwiftUI

// MARK: - App State
enum AppViewState: Equatable {
    case welcome
    case analyzing
    case results

    static func == (lhs: AppViewState, rhs: AppViewState) -> Bool {
        switch (lhs, rhs) {
        case (.welcome, .welcome): return true
        case (.analyzing, .analyzing): return true
        case (.results, .results): return true
        default: return false
        }
    }
}

// MARK: - Dropped Files
struct DroppedFiles {
    var originalURL: URL?
    var comparisonURL: URL?

    var bothFilesSelected: Bool {
        originalURL != nil && comparisonURL != nil
    }

    var originalFileName: String? {
        originalURL?.lastPathComponent
    }

    var comparisonFileName: String? {
        comparisonURL?.lastPathComponent
    }

    mutating func clear() {
        originalURL = nil
        comparisonURL = nil
    }
}

// MARK: - Analysis Error
enum AnalysisError: Error, LocalizedError {
    case invalidPDF(String)
    case pageCountMismatch(Int, Int)
    case extractionFailed(String)
    case comparisonFailed(String)
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidPDF(let name):
            return "Invalid PDF file: \(name)"
        case .pageCountMismatch(let orig, let comp):
            return "Page count mismatch: Original has \(orig) pages, comparison has \(comp)"
        case .extractionFailed(let reason):
            return "Failed to extract content: \(reason)"
        case .comparisonFailed(let reason):
            return "Comparison failed: \(reason)"
        case .cancelled:
            return "Analysis was cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
