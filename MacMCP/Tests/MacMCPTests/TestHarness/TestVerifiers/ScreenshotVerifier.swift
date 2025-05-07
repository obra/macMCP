// ABOUTME: This file provides utilities for verifying screenshot results in tests.
// ABOUTME: It contains methods for comparing and validating screenshots.

import Foundation
import XCTest
import CoreGraphics
import AppKit
@testable import MacMCP

/// Verifies screenshot results from tool operations
public struct ScreenshotVerifier {
    /// Result of an image comparison
    public struct ComparisonResult {
        /// Whether the images are considered matching
        public let matches: Bool
        
        /// Difference score between 0 (identical) and 1 (completely different)
        public let differenceScore: Double
        
        /// Areas where the images differ (if available)
        public let differenceMask: NSImage?
        
        /// The target image
        public let targetImage: NSImage
        
        /// The baseline image
        public let baselineImage: NSImage
    }
    
    /// Verifies that a screenshot has the expected dimensions
    /// - Parameters:
    ///   - screenshot: The screenshot result to verify
    ///   - width: The expected width
    ///   - height: The expected height
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the dimensions match
    @discardableResult
    public static func verifyDimensions(
        of screenshot: ScreenshotResult,
        width: Int,
        height: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let widthMatches = screenshot.width == width
        let heightMatches = screenshot.height == height
        
        XCTAssertTrue(
            widthMatches && heightMatches,
            "Screenshot dimensions (\(screenshot.width)x\(screenshot.height)) don't match expected (\(width)x\(height))",
            file: file,
            line: line
        )
        
        return widthMatches && heightMatches
    }
    
    /// Verifies that a screenshot has non-zero dimensions and valid data
    /// - Parameters:
    ///   - screenshot: The screenshot result to verify
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the screenshot is valid
    @discardableResult
    public static func verifyScreenshotIsValid(
        _ screenshot: ScreenshotResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let hasValidWidth = screenshot.width > 0
        let hasValidHeight = screenshot.height > 0
        let hasNonEmptyData = !screenshot.data.isEmpty
        
        XCTAssertTrue(hasValidWidth, "Screenshot width should be > 0", file: file, line: line)
        XCTAssertTrue(hasValidHeight, "Screenshot height should be > 0", file: file, line: line)
        XCTAssertTrue(hasNonEmptyData, "Screenshot data should not be empty", file: file, line: line)
        
        return hasValidWidth && hasValidHeight && hasNonEmptyData
    }
    
    /// Verifies that a screenshot is not a solid color or blank
    /// - Parameters:
    ///   - screenshot: The screenshot result to verify
    ///   - minColorVariance: Minimum acceptable color variance (0-1)
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the screenshot has sufficient visual content
    @discardableResult
    public static func verifyScreenshotHasContent(
        _ screenshot: ScreenshotResult,
        minColorVariance: Double = 0.01,
        maxSolidColorPercentage: Double = 0.95,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let image = NSImage(data: screenshot.data) else {
            XCTFail("Failed to create image from screenshot data", file: file, line: line)
            return false
        }
        
        guard let bitmap = image.bitmapRepresentation else {
            XCTFail("Failed to get bitmap representation of image", file: file, line: line)
            return false
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        // Sample pixels to determine color variance
        var colors = [NSColor]()
        let sampleSize = min(width * height, 1000) // Cap samples at 1000 pixels
        let sampleInterval = max(1, (width * height) / sampleSize)
        
        var pixelCount = 0
        for y in stride(from: 0, to: height, by: max(1, height / 20)) {
            for x in stride(from: 0, to: width, by: max(1, width / 20)) {
                if pixelCount % sampleInterval == 0, let color = bitmap.colorAt(x: x, y: y) {
                    colors.append(color)
                }
                pixelCount += 1
                if colors.count >= sampleSize {
                    break
                }
            }
            if colors.count >= sampleSize {
                break
            }
        }
        
        if colors.isEmpty {
            XCTFail("Failed to sample any colors from the image", file: file, line: line)
            return false
        }
        
        // Check for solid color by finding the most frequent color
        var colorCounts = [NSColor: Int]()
        for color in colors {
            let key = simplifyColor(color)
            colorCounts[key, default: 0] += 1
        }
        
        let mostFrequentColor = colorCounts.max(by: { $0.value < $1.value })!
        let solidColorPercentage = Double(mostFrequentColor.value) / Double(colors.count)
        
        // Calculate color variance
        var redSum: Double = 0
        var greenSum: Double = 0
        var blueSum: Double = 0
        var redSqSum: Double = 0
        var greenSqSum: Double = 0
        var blueSqSum: Double = 0
        
        for color in colors {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            redSum += c.redComponent
            greenSum += c.greenComponent
            blueSum += c.blueComponent
            redSqSum += c.redComponent * c.redComponent
            greenSqSum += c.greenComponent * c.greenComponent
            blueSqSum += c.blueComponent * c.blueComponent
        }
        
        let count = Double(colors.count)
        let redMean = redSum / count
        let greenMean = greenSum / count
        let blueMean = blueSum / count
        
        // Calculate variance for each channel
        let redVariance = (redSqSum / count) - (redMean * redMean)
        let greenVariance = (greenSqSum / count) - (greenMean * greenMean)
        let blueVariance = (blueSqSum / count) - (blueMean * blueMean)
        
        // Use the average variance across channels
        let averageVariance = (redVariance + greenVariance + blueVariance) / 3.0
        
        let hasVariance = averageVariance >= minColorVariance
        let isNotSolidColor = solidColorPercentage <= maxSolidColorPercentage
        
        XCTAssertTrue(hasVariance, "Screenshot color variance (\(averageVariance)) is below minimum (\(minColorVariance))", file: file, line: line)
        XCTAssertTrue(isNotSolidColor, "Screenshot has \(Int(solidColorPercentage * 100))% solid color, exceeding maximum \(Int(maxSolidColorPercentage * 100))%", file: file, line: line)
        
        return hasVariance && isNotSolidColor
    }
    
    /// Simplify a color for comparison purposes
    private static func simplifyColor(_ color: NSColor) -> NSColor {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        
        // Reduce color precision to group similar colors
        let precision: CGFloat = 0.05
        let r = round(c.redComponent / precision) * precision
        let g = round(c.greenComponent / precision) * precision
        let b = round(c.blueComponent / precision) * precision
        let a = round(c.alphaComponent / precision) * precision
        
        return NSColor(
            calibratedRed: min(1, max(0, r)),
            green: min(1, max(0, g)), 
            blue: min(1, max(0, b)),
            alpha: min(1, max(0, a))
        )
    }
    
    /// Calculate color variance from image data
    /// - Parameter data: The image data to analyze
    /// - Returns: The average color variance (0-1)
    public static func calculateColorVariance(from data: Data) -> Double {
        guard let image = NSImage(data: data),
              let bitmap = image.bitmapRepresentation else {
            return 0
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        var colors = [NSColor]()
        let sampleSize = min(width * height, 1000)
        let sampleInterval = max(1, (width * height) / sampleSize)
        
        var pixelCount = 0
        for y in stride(from: 0, to: height, by: max(1, height / 20)) {
            for x in stride(from: 0, to: width, by: max(1, width / 20)) {
                if pixelCount % sampleInterval == 0, let color = bitmap.colorAt(x: x, y: y) {
                    colors.append(color)
                }
                pixelCount += 1
                if colors.count >= sampleSize {
                    break
                }
            }
            if colors.count >= sampleSize {
                break
            }
        }
        
        if colors.isEmpty {
            return 0
        }
        
        var redSum: Double = 0
        var greenSum: Double = 0
        var blueSum: Double = 0
        var redSqSum: Double = 0
        var greenSqSum: Double = 0
        var blueSqSum: Double = 0
        
        for color in colors {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            redSum += c.redComponent
            greenSum += c.greenComponent
            blueSum += c.blueComponent
            redSqSum += c.redComponent * c.redComponent
            greenSqSum += c.greenComponent * c.greenComponent
            blueSqSum += c.blueComponent * c.blueComponent
        }
        
        let count = Double(colors.count)
        let redMean = redSum / count
        let greenMean = greenSum / count
        let blueMean = blueSum / count
        
        let redVariance = (redSqSum / count) - (redMean * redMean)
        let greenVariance = (greenSqSum / count) - (greenMean * greenMean)
        let blueVariance = (blueSqSum / count) - (blueMean * blueMean)
        
        return (redVariance + greenVariance + blueVariance) / 3.0
    }
    
    /// Calculate the percentage of solid color in an image
    /// - Parameter data: The image data to analyze
    /// - Returns: The percentage (0-1) of the most frequently occurring color
    public static func calculateSolidColorPercentage(from data: Data) -> Double {
        guard let image = NSImage(data: data),
              let bitmap = image.bitmapRepresentation else {
            return 0
        }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        var colors = [NSColor]()
        let sampleSize = min(width * height, 1000)
        let sampleInterval = max(1, (width * height) / sampleSize)
        
        var pixelCount = 0
        for y in stride(from: 0, to: height, by: max(1, height / 20)) {
            for x in stride(from: 0, to: width, by: max(1, width / 20)) {
                if pixelCount % sampleInterval == 0, let color = bitmap.colorAt(x: x, y: y) {
                    colors.append(color)
                }
                pixelCount += 1
                if colors.count >= sampleSize {
                    break
                }
            }
            if colors.count >= sampleSize {
                break
            }
        }
        
        if colors.isEmpty {
            return 0
        }
        
        var colorCounts = [NSColor: Int]()
        for color in colors {
            let key = simplifyColor(color)
            colorCounts[key, default: 0] += 1
        }
        
        let mostFrequentColor = colorCounts.max(by: { $0.value < $1.value })!
        return Double(mostFrequentColor.value) / Double(colors.count)
    }
    
    /// Verifies that a screenshot contains a specific color within a region
    /// - Parameters:
    ///   - screenshot: The screenshot result to verify
    ///   - color: The color to look for
    ///   - region: The region to check (nil for entire image)
    ///   - tolerance: Color matching tolerance (0-1)
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the color is found
    @discardableResult
    public static func verifyScreenshotContainsColor(
        _ screenshot: ScreenshotResult,
        color: NSColor,
        in region: CGRect? = nil,
        tolerance: Double = 0.1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let image = NSImage(data: screenshot.data) else {
            XCTFail("Failed to create image from screenshot data", file: file, line: line)
            return false
        }
        
        let searchRegion = region ?? CGRect(x: 0, y: 0, width: screenshot.width, height: screenshot.height)
        let containsColor = imageContainsColor(image, color: color, in: searchRegion, tolerance: tolerance)
        
        XCTAssertTrue(
            containsColor,
            "Screenshot does not contain the expected color in the specified region",
            file: file,
            line: line
        )
        
        return containsColor
    }
    
    /// Verifies that a screenshot matches a baseline image within a tolerance
    /// - Parameters:
    ///   - screenshot: The screenshot result to verify
    ///   - baselineImagePath: Path to the baseline image
    ///   - threshold: Maximum acceptable difference (0-1)
    ///   - saveDiffImagePath: Optional path to save difference image
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the images match within the threshold
    @discardableResult
    public static func verifyScreenshotMatchesBaseline(
        _ screenshot: ScreenshotResult,
        baselineImagePath: String,
        threshold: Double = 0.1,
        saveDiffImagePath: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        // Load the target image
        guard let targetImage = NSImage(data: screenshot.data) else {
            XCTFail("Failed to create image from screenshot data", file: file, line: line)
            return false
        }
        
        // Load the baseline image
        guard let baselineImage = NSImage(contentsOfFile: baselineImagePath) else {
            XCTFail("Failed to load baseline image from \(baselineImagePath)", file: file, line: line)
            return false
        }
        
        // Compare the images
        let result = compareImages(targetImage, baselineImage)
        
        // Save diff image if needed
        if let savePath = saveDiffImagePath, let diffMask = result.differenceMask {
            do {
                try saveDifferenceImage(diffMask, to: savePath)
            } catch {
                print("Warning: Failed to save difference image: \(error.localizedDescription)")
            }
        }
        
        // Verify the match
        XCTAssertTrue(
            result.differenceScore <= threshold,
            "Screenshot differs from baseline by \(Int(result.differenceScore * 100))%, which exceeds threshold of \(Int(threshold * 100))%",
            file: file,
            line: line
        )
        
        return result.differenceScore <= threshold
    }
    
    /// Checks if an image contains a specific color in a region
    private static func imageContainsColor(_ image: NSImage, color: NSColor, in region: CGRect, tolerance: Double) -> Bool {
        let targetColor = color.usingColorSpace(.deviceRGB) ?? color
        let targetRed = targetColor.redComponent
        let targetGreen = targetColor.greenComponent
        let targetBlue = targetColor.blueComponent
        
        // Create a bitmap representation of the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        
        // Calculate the region to check
        let minX = max(0, Int(region.minX))
        let minY = max(0, Int(region.minY))
        let maxX = min(bitmap.pixelsWide, Int(region.maxX))
        let maxY = min(bitmap.pixelsHigh, Int(region.maxY))
        
        // Check pixels in the region
        for x in minX..<maxX {
            for y in minY..<maxY {
                guard let pixelColor = bitmap.colorAt(x: x, y: y) else {
                    continue
                }
                
                let pixelRed = pixelColor.redComponent
                let pixelGreen = pixelColor.greenComponent
                let pixelBlue = pixelColor.blueComponent
                
                // Calculate color distance
                let redDiff = abs(pixelRed - targetRed)
                let greenDiff = abs(pixelGreen - targetGreen)
                let blueDiff = abs(pixelBlue - targetBlue)
                
                // Average the differences
                let colorDistance = (redDiff + greenDiff + blueDiff) / 3.0
                
                if colorDistance <= tolerance {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Compare two images and generate a difference score and mask
    private static func compareImages(_ image1: NSImage, _ image2: NSImage) -> ComparisonResult {
        // Resize images to the same dimensions if needed
        let resizedImage1: NSImage
        let resizedImage2: NSImage
        
        if image1.size != image2.size {
            let targetSize = CGSize(
                width: max(image1.size.width, image2.size.width),
                height: max(image1.size.height, image2.size.height)
            )
            resizedImage1 = resizeImage(image1, to: targetSize)
            resizedImage2 = resizeImage(image2, to: targetSize)
        } else {
            resizedImage1 = image1
            resizedImage2 = image2
        }
        
        // Convert to bitmap representations
        guard let bitmap1 = resizedImage1.bitmapRepresentation,
              let bitmap2 = resizedImage2.bitmapRepresentation else {
            return ComparisonResult(
                matches: false,
                differenceScore: 1.0,
                differenceMask: nil,
                targetImage: image1,
                baselineImage: image2
            )
        }
        
        let width = bitmap1.pixelsWide
        let height = bitmap1.pixelsHigh
        let totalPixels = width * height
        
        // Create a difference mask
        let diffBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        // Fill with transparent white
        let transparentWhite = NSColor(white: 1.0, alpha: 0.0)
        for x in 0..<width {
            for y in 0..<height {
                diffBitmap.setColor(transparentWhite, atX: x, y: y)
            }
        }
        
        var differentPixels = 0
        
        // Compare pixels
        for x in 0..<width {
            for y in 0..<height {
                let color1 = bitmap1.colorAt(x: x, y: y) ?? .clear
                let color2 = bitmap2.colorAt(x: x, y: y) ?? .clear
                
                if !colorsAreEqual(color1, color2, tolerance: 0.05) {
                    differentPixels += 1
                    
                    // Mark difference in the mask with red
                    diffBitmap.setColor(.red, atX: x, y: y)
                }
            }
        }
        
        // Calculate difference score (0 to 1)
        let differenceScore = Double(differentPixels) / Double(totalPixels)
        
        // Create an image from the difference bitmap
        let diffImage = NSImage(size: NSSize(width: width, height: height))
        diffImage.addRepresentation(diffBitmap)
        
        return ComparisonResult(
            matches: differenceScore <= 0.05,  // 5% threshold for "matching"
            differenceScore: differenceScore,
            differenceMask: diffImage,
            targetImage: image1,
            baselineImage: image2
        )
    }
    
    /// Check if two colors are equal within a tolerance
    private static func colorsAreEqual(_ color1: NSColor, _ color2: NSColor, tolerance: Double) -> Bool {
        let c1 = color1.usingColorSpace(.deviceRGB) ?? color1
        let c2 = color2.usingColorSpace(.deviceRGB) ?? color2
        
        let redDiff = abs(c1.redComponent - c2.redComponent)
        let greenDiff = abs(c1.greenComponent - c2.greenComponent)
        let blueDiff = abs(c1.blueComponent - c2.blueComponent)
        let alphaDiff = abs(c1.alphaComponent - c2.alphaComponent)
        
        return redDiff <= tolerance && greenDiff <= tolerance && blueDiff <= tolerance && alphaDiff <= tolerance
    }
    
    /// Resize an image to a target size
    private static func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        let resizedImage = NSImage(size: targetSize)
        
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
    /// Save a difference image to a file
    private static func saveDifferenceImage(_ image: NSImage, to path: String) throws {
        guard let bitmap = image.bitmapRepresentation,
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "ScreenshotVerifier",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert difference image to PNG data"]
            )
        }
        
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
    }
}

// MARK: - Helper Extensions

extension NSImage {
    /// Get a bitmap representation of the image
    var bitmapRepresentation: NSBitmapImageRep? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage)
    }
    
    /// Get the CGImage representation of the image
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}