import Foundation
import AppKit
import CoreImage

// MARK: - Image Comparator
actor ImageComparator {
    private let ssimCalculator = SSIMCalculator()
    private let ciContext = CIContext()

    // MARK: - Compare Documents
    func compare(original: PDFAnalysis, comparison: PDFAnalysis) async -> ImageComparisonResult {
        let pageCount = min(original.pageCount, comparison.pageCount)
        var pageResults: [PageImageResult] = []
        var pagesWithDiffs: [Int] = []

        var totalSSIM: Double = 0
        var totalPixelDiff: Double = 0

        for pageNum in 0..<pageCount {
            let origImage = original.pageImages[pageNum]
            let compImage = comparison.pageImages[pageNum]

            if let orig = origImage, let comp = compImage {
                let ssim = await ssimCalculator.calculateSSIM(image1: orig, image2: comp)
                let pixelDiff = await ssimCalculator.calculatePixelDifference(image1: orig, image2: comp)
                let diffImage = await createDiffImage(original: orig, comparison: comp)

                totalSSIM += ssim
                totalPixelDiff += pixelDiff

                let result = PageImageResult(
                    pageNumber: pageNum + 1,
                    ssim: ssim,
                    pixelDifference: pixelDiff,
                    originalImage: orig,
                    comparisonImage: comp,
                    diffImage: diffImage
                )

                pageResults.append(result)

                if result.hasSignificantDifference {
                    pagesWithDiffs.append(pageNum + 1)
                }
            }
        }

        let avgSSIM = pageCount > 0 ? totalSSIM / Double(pageCount) : 0
        let avgPixelDiff = pageCount > 0 ? totalPixelDiff / Double(pageCount) : 1

        return ImageComparisonResult(
            pageResults: pageResults,
            averageSSIM: avgSSIM,
            averagePixelDiff: avgPixelDiff,
            pagesWithDifferences: pagesWithDiffs
        )
    }

    // MARK: - Create Diff Image
    private func createDiffImage(original: NSImage, comparison: NSImage) async -> NSImage? {
        guard let origCG = original.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let compCG = comparison.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let origCI = CIImage(cgImage: origCG)
        let compCI = CIImage(cgImage: compCG)

        // Use difference blend mode to highlight changes
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            return nil
        }

        diffFilter.setValue(origCI, forKey: kCIInputImageKey)
        diffFilter.setValue(compCI, forKey: kCIInputBackgroundImageKey)

        guard let diffOutput = diffFilter.outputImage else {
            return nil
        }

        // Enhance the diff for visibility
        guard let contrastFilter = CIFilter(name: "CIColorControls") else {
            return nil
        }

        contrastFilter.setValue(diffOutput, forKey: kCIInputImageKey)
        contrastFilter.setValue(2.0, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.5, forKey: kCIInputBrightnessKey)

        guard let enhancedOutput = contrastFilter.outputImage,
              let cgImage = ciContext.createCGImage(enhancedOutput, from: enhancedOutput.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: original.size)
    }

    // MARK: - Create Overlay Image
    func createOverlayImage(original: NSImage, comparison: NSImage, opacity: Double = 0.5) async -> NSImage? {
        let size = original.size
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw original at full opacity
        original.draw(in: NSRect(origin: .zero, size: size))

        // Draw comparison with specified opacity
        comparison.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: comparison.size),
            operation: .sourceOver,
            fraction: CGFloat(opacity)
        )

        image.unlockFocus()

        return image
    }

    // MARK: - Create Side-by-Side Image
    func createSideBySideImage(original: NSImage, comparison: NSImage) async -> NSImage? {
        let maxWidth = max(original.size.width, comparison.size.width)
        let maxHeight = max(original.size.height, comparison.size.height)
        let totalWidth = maxWidth * 2 + 10  // 10px gap

        let size = NSSize(width: totalWidth, height: maxHeight)
        let image = NSImage(size: size)

        image.lockFocus()

        // White background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw original on left
        original.draw(in: NSRect(x: 0, y: 0, width: original.size.width, height: original.size.height))

        // Draw comparison on right
        comparison.draw(in: NSRect(x: maxWidth + 10, y: 0, width: comparison.size.width, height: comparison.size.height))

        image.unlockFocus()

        return image
    }

    // MARK: - Generate Findings
    func generateFindings(from result: ImageComparisonResult) -> [Finding] {
        var findings: [Finding] = []

        // Overall visual similarity finding
        if result.averageSSIM < 0.98 {
            let severity: Severity
            if result.averageSSIM < 0.85 {
                severity = .critical
            } else if result.averageSSIM < 0.95 {
                severity = .high
            } else {
                severity = .medium
            }

            findings.append(Finding(
                category: .visual,
                severity: severity,
                title: "Visual Differences Detected",
                description: String(format: "Average visual similarity is %.1f%%", result.averageSSIM * 100),
                details: [
                    "Average SSIM": String(format: "%.4f", result.averageSSIM),
                    "Pages with Differences": "\(result.pagesWithDifferences.count)"
                ]
            ))
        }

        // Per-page findings for significant visual differences
        for pageResult in result.pageResults where pageResult.hasSignificantDifference {
            findings.append(Finding(
                category: .visual,
                severity: pageResult.ssim < 0.9 ? .high : .medium,
                title: "Page \(pageResult.pageNumber) Visual Difference",
                description: String(format: "SSIM: %.2f%%, Pixel diff: %.2f%%",
                                   pageResult.ssim * 100,
                                   pageResult.pixelDifference * 100),
                pageNumber: pageResult.pageNumber
            ))
        }

        return findings
    }
}
