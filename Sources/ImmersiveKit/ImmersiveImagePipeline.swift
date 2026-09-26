import CoreGraphics
import SwiftUI

struct ImmersiveImageRequestID: Hashable {
    let cacheKey: ImmersiveArtworkCacheKey
    let contentID: String
    let hasSourceImage: Bool
    let extractsBackgroundColor: Bool

    init(
        cacheKey: ImmersiveArtworkCacheKey,
        contentID: String? = nil,
        sourceImage: CGImage?,
        extractsBackgroundColor: Bool
    ) {
        self.cacheKey = cacheKey
        self.contentID = contentID ?? cacheKey.sourceID
        self.hasSourceImage = sourceImage != nil
        self.extractsBackgroundColor = extractsBackgroundColor
    }

    func matchesImageInput(of other: ImmersiveImageRequestID) -> Bool {
        cacheKey == other.cacheKey && hasSourceImage == other.hasSourceImage
    }
}

struct ImmersiveProcessedImage {
    let image: CGImage
    let extractedBackgroundColor: Color?
}

struct ImmersiveImageLoadState {
    let requestID: ImmersiveImageRequestID
    let result: ImmersiveProcessedImage?

    /// Keep a ready rendition during upgrades of the same logical content,
    /// but never carry it across deletion or a different profile/page.
    func displayedResult(
        for request: ImmersiveImageRequestID,
        cachedResult: ImmersiveProcessedImage?
    ) -> ImmersiveProcessedImage? {
        guard request.hasSourceImage else { return nil }
        if let cachedResult { return cachedResult }
        guard requestID.contentID == request.contentID else { return nil }
        return result
    }
}

/// Owns cache lookup, image preparation, and color extraction so rendering and
/// prewarming always use the same processing rules.
@MainActor
enum ImmersiveImagePipeline {
    static func cachedResult(
        key: ImmersiveArtworkCacheKey,
        extractsBackgroundColor: Bool
    ) -> ImmersiveProcessedImage? {
        guard let image = ImmersiveArtworkMemoryCache.artwork(for: key) else {
            return nil
        }

        let color = extractsBackgroundColor
            ? ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key)
            : nil
        return ImmersiveProcessedImage(
            image: image,
            extractedBackgroundColor: color
        )
    }

    static func process(
        sourceImage: CGImage?,
        key: ImmersiveArtworkCacheKey,
        extractsBackgroundColor: Bool
    ) async -> ImmersiveProcessedImage? {
        let image: CGImage
        if let cachedImage = ImmersiveArtworkMemoryCache.artwork(for: key) {
            image = cachedImage
        } else {
            guard let processedImage = await ImmersiveImageProcessing.crop(
                sourceImage,
                crop: key.crop
            ) else {
                return nil
            }
            guard !Task.isCancelled else { return nil }
            ImmersiveArtworkMemoryCache.storeArtwork(
                processedImage,
                for: key
            )
            image = processedImage
        }

        guard extractsBackgroundColor else {
            return ImmersiveProcessedImage(
                image: image,
                extractedBackgroundColor: nil
            )
        }

        if let cachedColor = ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key) {
            return ImmersiveProcessedImage(
                image: image,
                extractedBackgroundColor: cachedColor
            )
        }

        let color: Color?
        do {
            color = try await ImmersiveImageProcessing.extractBackgroundColor(from: image)
        } catch {
            color = nil
        }
        guard !Task.isCancelled else { return nil }

        if let color {
            ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
                color,
                for: key
            )
        }

        return ImmersiveProcessedImage(
            image: image,
            extractedBackgroundColor: color
        )
    }
}
