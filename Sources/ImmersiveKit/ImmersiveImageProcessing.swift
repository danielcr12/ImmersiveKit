import CoreGraphics
import Foundation
import SwiftUI

/// Standalone image-processing operations used by ImmersiveKit's SwiftUI components.
public enum ImmersiveImageProcessing {
    /// Applies the requested crop away from the main actor.
    public static func crop(
        _ image: CGImage?,
        crop: ImmersiveArtworkCrop
    ) async -> CGImage? {
        guard let image else { return nil }
        guard !Task.isCancelled else { return nil }
        return await cropOffMainActor(SendableCGImage(image: image), crop: crop)
    }

    /// Synchronous center-square crop used by the concurrent processing worker and tests.
    internal static func cropSynchronously(
        _ image: CGImage?,
        crop: ImmersiveArtworkCrop
    ) -> CGImage? {
        guard let image else { return nil }
        guard crop == .square else { return image }

        let side = min(image.width, image.height)
        guard side > 0 else { return image }

        let cropRect = CGRect(
            x: CGFloat(image.width - side) / 2,
            y: CGFloat(image.height - side) / 2,
            width: CGFloat(side),
            height: CGFloat(side)
        )
        return image.cropping(to: cropRect) ?? image
    }

    /// Extracts the most common color group across the image as an opaque sRGB color.
    /// Transparent pixels are ignored; partially transparent pixels contribute by opacity.
    /// Throws when the image has no visible pixels.
    @MainActor
    public static func extractBackgroundColor(from image: CGImage) async throws -> Color {
        let source = SendableCGImage(image: image)
        let components = try await extractComponentsOffMainActor(source)

        return Color(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.opacity
        )
    }

    @concurrent
    private static func cropOffMainActor(
        _ source: SendableCGImage,
        crop: ImmersiveArtworkCrop
    ) async -> CGImage? {
        guard !Task.isCancelled else { return nil }
        let image = cropSynchronously(source.image, crop: crop) ?? source.image
        guard !Task.isCancelled else { return nil }
        return image
    }

    @concurrent
    private static func extractComponentsOffMainActor(
        _ source: SendableCGImage
    ) async throws -> RGBAComponents {
        try Task.checkCancellation()

        let components = try prominentComponents(from: source.image)

        try Task.checkCancellation()
        return components
    }

    private static func prominentComponents(from image: CGImage) throws -> RGBAComponents {
        // Bound the work and preserve aspect ratio without creating blended colors.
        let scale = min(1, 64.0 / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            throw ImmersiveImageProcessingError.colorExtractionFailed
        }

        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else {
            throw ImmersiveImageProcessingError.colorExtractionFailed
        }
        let pixels = data.assumingMemoryBound(to: UInt8.self)

        // Eight levels per channel group nearby shades. Average only within the
        // winning group, so unrelated colors cannot mix into a new hue.
        var buckets = [ColorBucket](repeating: ColorBucket(), count: 512)
        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let alpha = Int(pixels[offset + 3])
            guard alpha > 0 else { continue }

            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            // Unpremultiply before grouping; translucent red is still red.
            let r = min(255, red * 255 / alpha) >> 5
            let g = min(255, green * 255 / alpha) >> 5
            let b = min(255, blue * 255 / alpha) >> 5
            let index = (r << 6) | (g << 3) | b
            buckets[index].weight += alpha
            buckets[index].red += red
            buckets[index].green += green
            buckets[index].blue += blue
        }

        guard let dominant = buckets.max(by: { $0.weight < $1.weight }),
              dominant.weight > 0 else {
            throw ImmersiveImageProcessingError.colorExtractionFailed
        }

        return RGBAComponents(
            red: Double(dominant.red) / Double(dominant.weight),
            green: Double(dominant.green) / Double(dominant.weight),
            blue: Double(dominant.blue) / Double(dominant.weight),
            opacity: 1
        )
    }
}

// CGImage is immutable after creation; cross-actor transfer via this wrapper is safe.
private struct SendableCGImage: @unchecked Sendable {
    let image: CGImage
}

private struct RGBAComponents: Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
}

private struct ColorBucket {
    var weight = 0
    var red = 0
    var green = 0
    var blue = 0
}

private enum ImmersiveImageProcessingError: Error {
    case colorExtractionFailed
}
