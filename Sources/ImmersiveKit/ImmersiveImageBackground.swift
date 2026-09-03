import CoreGraphics
import PrismBackgroundFoundation
import SwiftUI

/// A scrolling immersive background backed by an optional `CGImage` and placeholder view.
@MainActor
public struct ImmersiveImageBackground<Placeholder: View, Content: View>: View {
    private let sourceID: String
    private let sourceImage: CGImage?
    private let preferredBackgroundColor: Color?
    private let fallbackBackgroundColor: Color
    private let placeholderPaletteKey: String
    private let placeholderSymbolColor: Color
    private let placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle
    private let showsPlaceholder: Bool
    private let crop: ImmersiveArtworkCrop
    private let title: String
    private let subtitle: String
    private let layout: ImmersiveArtworkLayout
    private let placeholder: Placeholder
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var processedImage: CGImage?
    @State private var extractedBackgroundColor: Color?

    public init(
        sourceID: String,
        sourceImage: CGImage?,
        preferredBackgroundColor: Color? = nil,
        fallbackBackgroundColor: Color,
        placeholderPaletteKey: String,
        placeholderSymbolColor: Color = .white,
        placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle = .gradient,
        showsPlaceholder: Bool = true,
        crop: ImmersiveArtworkCrop = .square,
        title: String,
        subtitle: String,
        layout: ImmersiveArtworkLayout = .standard,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder content: () -> Content
    ) {
        self.sourceID = sourceID
        self.sourceImage = sourceImage
        self.preferredBackgroundColor = preferredBackgroundColor
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.placeholderPaletteKey = placeholderPaletteKey
        self.placeholderSymbolColor = placeholderSymbolColor
        self.placeholderArtworkStyle = placeholderArtworkStyle
        self.showsPlaceholder = showsPlaceholder
        self.crop = crop
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.placeholder = placeholder()
        self.content = content()

        let key = Self.cacheKey(sourceID: sourceID, crop: crop)
        self._processedImage = State(
            initialValue: ImmersiveArtworkMemoryCache.artwork(for: key)
        )
        self._extractedBackgroundColor = State(
            initialValue: ImmersiveArtworkMemoryCache.backgroundColor(for: key)
        )
    }

    public var body: some View {
        ImmersiveArtworkBackground(
            backgroundColor: effectiveBackgroundColor,
            title: title,
            subtitle: subtitle,
            backgroundTreatment: effectiveBackgroundTreatment,
            layout: layout
        ) {
            ImmersiveImageArtworkLayer(
                image: processedImage,
                showsPlaceholder: showsPlaceholder,
                fallbackBackgroundColor: fallbackBackgroundColor,
                paletteKey: placeholderPaletteKey,
                symbolColor: placeholderSymbolColor,
                placeholderArtworkStyle: placeholderArtworkStyle,
                placeholder: placeholder
            )
        } content: {
            content
        }
        .task(id: processingID) {
            await processImage()
        }
    }

    private var effectiveBackgroundColor: Color {
        if usesTransparentPlaceholderBackground {
            return .clear
        }

        if usesSolidPlaceholderBackground {
            return PrismBackgroundConstruction.washedColor(
                fallbackBackgroundColor,
                colorScheme: colorScheme
            )
        }

        if usesPlaceholderArtwork {
            let paletteColor = ImmersivePlaceholderPaletteCache.palette(
                for: placeholderPaletteKey,
                baseColor: fallbackBackgroundColor,
                colorScheme: colorScheme
            ).solidColor
            return PrismBackgroundConstruction.washedColor(
                paletteColor,
                colorScheme: colorScheme
            )
        }

        return preferredBackgroundColor
            ?? extractedBackgroundColor
            ?? ImmersivePlaceholderPaletteCache.palette(
                for: placeholderPaletteKey,
                baseColor: fallbackBackgroundColor,
                colorScheme: colorScheme
            ).solidColor
    }

    private var effectiveBackgroundTreatment: ImmersiveBackgroundTreatment {
        if usesSolidPlaceholderBackground || usesTransparentPlaceholderBackground {
            return .solidPlaceholder
        }
        return processedImage == nil ? .exact : .prismAdaptive
    }

    private var usesTransparentPlaceholderBackground: Bool {
        usesPlaceholderArtwork && placeholderArtworkStyle == .transparent
    }

    private var usesSolidPlaceholderBackground: Bool {
        usesPlaceholderArtwork && placeholderArtworkStyle == .solid
    }

    private var usesPlaceholderArtwork: Bool {
        processedImage == nil && showsPlaceholder
    }

    private var processingID: ImmersiveArtworkCacheKey {
        Self.cacheKey(sourceID: sourceID, crop: crop)
    }

    private func processImage() async {
        let key = processingID
        guard !Task.isCancelled else { return }

        guard let image = await loadImage(for: key) else {
            guard !Task.isCancelled else { return }
            processedImage = nil
            extractedBackgroundColor = nil
            return
        }

        guard !Task.isCancelled else { return }
        processedImage = image

        guard let color = await loadBackgroundColor(for: key, image: image) else {
            return
        }

        guard !Task.isCancelled else { return }
        extractedBackgroundColor = color
        ImmersiveArtworkMemoryCache.store(color, for: key)
    }

    private func loadImage(for key: ImmersiveArtworkCacheKey) async -> CGImage? {
        if let cachedImage = ImmersiveArtworkMemoryCache.artwork(for: key) {
            return cachedImage
        }

        guard let image = await ImmersiveImageProcessing.crop(sourceImage, crop: crop) else {
            return nil
        }
        guard !Task.isCancelled else { return nil }

        ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        return image
    }

    private func loadBackgroundColor(
        for key: ImmersiveArtworkCacheKey,
        image: CGImage
    ) async -> Color? {
        if let preferredBackgroundColor {
            ImmersiveArtworkMemoryCache.store(preferredBackgroundColor, for: key)
            return preferredBackgroundColor
        }

        if let cachedColor = ImmersiveArtworkMemoryCache.backgroundColor(for: key) {
            return cachedColor
        }

        do {
            return try await ImmersiveImageProcessing.extractBackgroundColor(from: image)
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private static func cacheKey(
        sourceID: String,
        crop: ImmersiveArtworkCrop
    ) -> ImmersiveArtworkCacheKey {
        ImmersiveArtworkCacheKey(sourceID: sourceID, crop: crop)
    }
}

/// Primes ImmersiveKit's in-memory crop and color caches for upcoming artwork.
///
/// Checks both the artwork cache and the color cache independently.
/// `NSCache` may silently evict artwork under memory pressure; prewarm re-crops
/// the image if needed rather than bailing out early on a color-only cache hit.
@MainActor
public enum ImmersiveImagePrewarmer {
    public static func prewarm(
        sourceID: String,
        sourceImage: CGImage?,
        preferredBackgroundColor: Color? = nil,
        crop: ImmersiveArtworkCrop = .square
    ) async {
        let key = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: crop)

        if ImmersiveArtworkMemoryCache.artwork(for: key) == nil {
            guard let image = await ImmersiveImageProcessing.crop(sourceImage, crop: crop) else {
                return
            }
            guard !Task.isCancelled else { return }
            ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        }

        guard !Task.isCancelled else { return }
        guard ImmersiveArtworkMemoryCache.backgroundColor(for: key) == nil else { return }

        if let preferredBackgroundColor {
            ImmersiveArtworkMemoryCache.store(preferredBackgroundColor, for: key)
            return
        }

        guard let artwork = ImmersiveArtworkMemoryCache.artwork(for: key) else { return }
        do {
            let color = try await ImmersiveImageProcessing.extractBackgroundColor(
                from: artwork
            )
            guard !Task.isCancelled else { return }
            ImmersiveArtworkMemoryCache.store(color, for: key)
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }
}
