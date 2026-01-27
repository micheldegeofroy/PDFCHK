import Foundation
import AppKit

// MARK: - Image Comparison Result
struct ImageComparisonResult {
    let pageResults: [PageImageResult]
    let averageSSIM: Double
    let averagePixelDiff: Double
    let pagesWithDifferences: [Int]

    var overallMatch: Bool {
        averageSSIM >= 0.98 && averagePixelDiff < 0.01
    }
}

// MARK: - Page Image Result
struct PageImageResult: Identifiable {
    let id = UUID()
    let pageNumber: Int
    let ssim: Double
    let pixelDifference: Double
    let originalImage: NSImage?
    let comparisonImage: NSImage?
    let diffImage: NSImage?

    var similarityPercentage: Double {
        ssim * 100
    }

    var hasSignificantDifference: Bool {
        ssim < 0.95 || pixelDifference > 0.05
    }

    var differenceLevel: DifferenceLevel {
        if ssim >= 0.99 && pixelDifference < 0.01 {
            return .identical
        } else if ssim >= 0.95 && pixelDifference < 0.05 {
            return .minor
        } else if ssim >= 0.85 {
            return .moderate
        } else {
            return .significant
        }
    }
}

// MARK: - Difference Level
enum DifferenceLevel: String {
    case identical = "Identical"
    case minor = "Minor Differences"
    case moderate = "Moderate Differences"
    case significant = "Significant Differences"
}

// MARK: - SSIM Components
struct SSIMComponents {
    let luminance: Double
    let contrast: Double
    let structure: Double
    let combined: Double

    static func calculate(luminance: Double, contrast: Double, structure: Double) -> SSIMComponents {
        SSIMComponents(
            luminance: luminance,
            contrast: contrast,
            structure: structure,
            combined: luminance * contrast * structure
        )
    }
}
