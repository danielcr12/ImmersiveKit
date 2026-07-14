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
        let source = SendableCGImage(image: image)

        return await Task.detached(priority: .userInitiated) {
            SendableCGImage(
                image: cropSynchronously(source.image, crop: crop) ?? source.image
            )
        }.value.image
    }

    static func cropSynchronously(
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

    @MainActor
    /// Extracts an average SwiftUI color from the bottom 30 percent of an image.
    public static func extractBackgroundColor(from image: CGImage) async throws -> Color {
        let source = SendableCGImage(image: image)
        let components = try await Task.detached(priority: .userInitiated) {
            let context = CIContext(options: [.cacheIntermediates: false])
            let image = CIImage(cgImage: source.image)
            return try averageBottomComponents(
                from: image,
                extent: image.extent,
                context: context
            )
        }.value

        return Color(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.opacity
        )
    }

    private static func averageBottomComponents(
        from image: CIImage,
        extent: CGRect,
        context: CIContext
    ) throws -> RGBAComponents {
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

@MainActor
enum ImmersiveArtworkMemoryCache {
    private final class CGImageBox {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private static var colors: [String: Color] = [:]
    private static var accessOrder: [String] = []
    private static let maxColorEntries = 50
    private static let artworkCache: NSCache<NSString, CGImageBox> = {
        let cache = NSCache<NSString, CGImageBox>()
        cache.countLimit = 16
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func backgroundColor(for key: String) -> Color? {
        guard let color = colors[key] else { return nil }
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.append(accessOrder.remove(at: index))
        }
        return color
    }

    static func store(_ color: Color, for key: String) {
        if colors[key] == nil,
           colors.count >= maxColorEntries,
           let oldest = accessOrder.first {
            colors.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        colors[key] = color
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    static func artwork(for key: String) -> CGImage? {
        artworkCache.object(forKey: key as NSString)?.image
    }

    static func storeArtwork(_ image: CGImage, for key: String) {
        artworkCache.setObject(
            CGImageBox(image),
            forKey: key as NSString,
            cost: image.bytesPerRow * image.height
        )
    }
}
