import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
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

    /// Extracts an average SwiftUI color from the bottom 30 percent of an image.
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

        let context = CIContext(options: [.cacheIntermediates: false])
        let image = CIImage(cgImage: source.image)
        let components = try averageBottomComponents(
            from: image,
            extent: image.extent,
            context: context
        )

        try Task.checkCancellation()
        return components
    }

    private static func averageBottomComponents(
        from image: CIImage,
        extent: CGRect,
        context: CIContext
    ) throws -> RGBAComponents {
        // Core Image uses a bottom-left origin, so `extent.minY` is the bottom of the image.
        // This rect therefore samples the lowest 30 % of the image in visual terms.
        let sampleRect = CGRect(
            x: extent.minX,
            y: extent.minY,
            width: extent.width,
            height: extent.height * 0.3
        )

        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = sampleRect

        guard let outputImage = filter.outputImage else {
            throw ImmersiveImageProcessingError.colorExtractionFailed
        }

        var rgba = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &rgba,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )

        return RGBAComponents(
            red: Double(rgba[0]) / 255,
            green: Double(rgba[1]) / 255,
            blue: Double(rgba[2]) / 255,
            opacity: Double(rgba[3]) / 255
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

private enum ImmersiveImageProcessingError: Error {
    case colorExtractionFailed
}
