import Foundation
import Accelerate
import AppKit

// MARK: - SSIM Calculator
// Structural Similarity Index Measure implementation using Accelerate framework
actor SSIMCalculator {

    // SSIM constants
    private let k1: Float = 0.01
    private let k2: Float = 0.03
    private let L: Float = 255.0  // Dynamic range for 8-bit images

    // MARK: - Calculate SSIM
    func calculateSSIM(image1: NSImage, image2: NSImage) async -> Double {
        guard let bitmap1 = convertToGrayscale(image1),
              let bitmap2 = convertToGrayscale(image2) else {
            return 0.0
        }

        // Ensure same size
        guard bitmap1.count == bitmap2.count else {
            return 0.0
        }

        let c1 = pow(k1 * L, 2)
        let c2 = pow(k2 * L, 2)

        // Calculate means
        var mean1: Float = 0
        var mean2: Float = 0
        vDSP_meanv(bitmap1, 1, &mean1, vDSP_Length(bitmap1.count))
        vDSP_meanv(bitmap2, 1, &mean2, vDSP_Length(bitmap2.count))

        // Calculate variances and covariance
        var variance1: Float = 0
        var variance2: Float = 0
        var covariance: Float = 0

        var diff1 = [Float](repeating: 0, count: bitmap1.count)
        var diff2 = [Float](repeating: 0, count: bitmap2.count)

        // diff1 = bitmap1 - mean1
        var negMean1 = -mean1
        vDSP_vsadd(bitmap1, 1, &negMean1, &diff1, 1, vDSP_Length(bitmap1.count))

        // diff2 = bitmap2 - mean2
        var negMean2 = -mean2
        vDSP_vsadd(bitmap2, 1, &negMean2, &diff2, 1, vDSP_Length(bitmap2.count))

        // variance1 = mean(diff1^2)
        var squared1 = [Float](repeating: 0, count: bitmap1.count)
        vDSP_vsq(diff1, 1, &squared1, 1, vDSP_Length(bitmap1.count))
        vDSP_meanv(squared1, 1, &variance1, vDSP_Length(bitmap1.count))

        // variance2 = mean(diff2^2)
        var squared2 = [Float](repeating: 0, count: bitmap2.count)
        vDSP_vsq(diff2, 1, &squared2, 1, vDSP_Length(bitmap2.count))
        vDSP_meanv(squared2, 1, &variance2, vDSP_Length(bitmap2.count))

        // covariance = mean(diff1 * diff2)
        var product = [Float](repeating: 0, count: bitmap1.count)
        vDSP_vmul(diff1, 1, diff2, 1, &product, 1, vDSP_Length(bitmap1.count))
        vDSP_meanv(product, 1, &covariance, vDSP_Length(bitmap1.count))

        // Calculate SSIM
        let numerator = (2 * mean1 * mean2 + c1) * (2 * covariance + c2)
        let denominator = (mean1 * mean1 + mean2 * mean2 + c1) * (variance1 + variance2 + c2)

        let ssim = numerator / denominator

        return Double(max(0, min(1, ssim)))
    }

    // MARK: - Calculate SSIM Components
    func calculateSSIMComponents(image1: NSImage, image2: NSImage) async -> SSIMComponents {
        guard let bitmap1 = convertToGrayscale(image1),
              let bitmap2 = convertToGrayscale(image2) else {
            return SSIMComponents(luminance: 0, contrast: 0, structure: 0, combined: 0)
        }

        guard bitmap1.count == bitmap2.count else {
            return SSIMComponents(luminance: 0, contrast: 0, structure: 0, combined: 0)
        }

        let c1 = pow(k1 * L, 2)
        let c2 = pow(k2 * L, 2)
        let c3 = c2 / 2

        // Calculate means
        var mean1: Float = 0
        var mean2: Float = 0
        vDSP_meanv(bitmap1, 1, &mean1, vDSP_Length(bitmap1.count))
        vDSP_meanv(bitmap2, 1, &mean2, vDSP_Length(bitmap2.count))

        // Calculate standard deviations
        var diff1 = [Float](repeating: 0, count: bitmap1.count)
        var diff2 = [Float](repeating: 0, count: bitmap2.count)

        var negMean1 = -mean1
        var negMean2 = -mean2
        vDSP_vsadd(bitmap1, 1, &negMean1, &diff1, 1, vDSP_Length(bitmap1.count))
        vDSP_vsadd(bitmap2, 1, &negMean2, &diff2, 1, vDSP_Length(bitmap2.count))

        var variance1: Float = 0
        var variance2: Float = 0
        var squared1 = [Float](repeating: 0, count: bitmap1.count)
        var squared2 = [Float](repeating: 0, count: bitmap2.count)

        vDSP_vsq(diff1, 1, &squared1, 1, vDSP_Length(bitmap1.count))
        vDSP_vsq(diff2, 1, &squared2, 1, vDSP_Length(bitmap2.count))
        vDSP_meanv(squared1, 1, &variance1, vDSP_Length(bitmap1.count))
        vDSP_meanv(squared2, 1, &variance2, vDSP_Length(bitmap2.count))

        let sigma1 = sqrt(variance1)
        let sigma2 = sqrt(variance2)

        // Calculate covariance
        var covariance: Float = 0
        var product = [Float](repeating: 0, count: bitmap1.count)
        vDSP_vmul(diff1, 1, diff2, 1, &product, 1, vDSP_Length(bitmap1.count))
        vDSP_meanv(product, 1, &covariance, vDSP_Length(bitmap1.count))

        // Calculate components
        let luminance = (2 * mean1 * mean2 + c1) / (mean1 * mean1 + mean2 * mean2 + c1)
        let contrast = (2 * sigma1 * sigma2 + c2) / (variance1 + variance2 + c2)
        let structure = (covariance + c3) / (sigma1 * sigma2 + c3)

        return SSIMComponents.calculate(
            luminance: Double(luminance),
            contrast: Double(contrast),
            structure: Double(structure)
        )
    }

    // MARK: - Convert to Grayscale
    private func convertToGrayscale(_ image: NSImage) -> [Float]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to grayscale using luminance formula
        var grayscale = [Float](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let offset = i * bytesPerPixel
            let r = Float(pixelData[offset])
            let g = Float(pixelData[offset + 1])
            let b = Float(pixelData[offset + 2])
            grayscale[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        return grayscale
    }

    // MARK: - Calculate Pixel Difference
    func calculatePixelDifference(image1: NSImage, image2: NSImage) async -> Double {
        guard let bitmap1 = convertToGrayscale(image1),
              let bitmap2 = convertToGrayscale(image2) else {
            return 1.0
        }

        guard bitmap1.count == bitmap2.count else {
            return 1.0
        }

        var diff = [Float](repeating: 0, count: bitmap1.count)
        vDSP_vsub(bitmap2, 1, bitmap1, 1, &diff, 1, vDSP_Length(bitmap1.count))

        // Calculate absolute difference
        vDSP_vabs(diff, 1, &diff, 1, vDSP_Length(bitmap1.count))

        // Calculate mean absolute difference
        var meanDiff: Float = 0
        vDSP_meanv(diff, 1, &meanDiff, vDSP_Length(bitmap1.count))

        // Normalize to 0-1 range
        return Double(meanDiff / 255.0)
    }
}
