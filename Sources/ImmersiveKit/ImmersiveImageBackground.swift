import CoreGraphics
import PrismCoreBackgrounds
import SwiftUI

/// A scrolling immersive background backed by an optional `CGImage` and placeholder view.
@MainActor
public struct ImmersiveImageBackground<Placeholder: View, Content: View>: View {
    private let sourceID: String
    private let contentID: String?
    private let sourceImage: CGImage?
    private let preferredBackgroundColor: Color?
    private let fallbackBackgroundColor: Color
    private let placeholderPaletteKey: String
    private let placeholderSymbolColor: Color
    private let placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle
    private let showsPlaceholder: Bool
    private let crop: ImmersiveArtworkCrop
    private let focalPoint: ImmersiveImageFocalPoint
    private let title: String
    private let subtitle: String
    private let layout: ImmersiveArtworkLayout
    private let placeholder: Placeholder
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var loadState: ImmersiveImageLoadState

    /// Creates an image-backed immersive screen from a reusable source value.
    /// The source ID is also used as the default placeholder palette identity.
    /// Supply a stable `contentID` for multiple renditions of the same photo.
    /// Keep the source ID revision-specific so processing caches stay correct.
    public init(
        source: ImmersiveImageSource,
        contentID: String? = nil,
        fallbackBackgroundColor: Color,
        placeholderPaletteKey: String? = nil,
        placeholderSymbolColor: Color = .white,
        placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle = .gradient,
        showsPlaceholder: Bool = true,
        crop: ImmersiveArtworkCrop = .original,
        focalPoint: ImmersiveImageFocalPoint = .center,
        title: String,
        subtitle: String = "",
        layout: ImmersiveArtworkLayout = .standard,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            sourceID: source.id,
            contentID: contentID,
            sourceImage: source.image,
            preferredBackgroundColor: source.preferredBackgroundColor,
            fallbackBackgroundColor: fallbackBackgroundColor,
            placeholderPaletteKey: placeholderPaletteKey ?? source.id,
            placeholderSymbolColor: placeholderSymbolColor,
            placeholderArtworkStyle: placeholderArtworkStyle,
            showsPlaceholder: showsPlaceholder,
            crop: crop,
            focalPoint: focalPoint,
            title: title,
            subtitle: subtitle,
            layout: layout,
            placeholder: placeholder,
            content: content
        )
    }

    /// `contentID` identifies the logical artwork across source revisions. When
    /// supplied, an existing rendition stays visible until its replacement is
    /// processed. A nil source image still clears artwork immediately.
    public init(
        sourceID: String,
        contentID: String? = nil,
        sourceImage: CGImage?,
        preferredBackgroundColor: Color? = nil,
        fallbackBackgroundColor: Color,
        placeholderPaletteKey: String,
        placeholderSymbolColor: Color = .white,
        placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle = .gradient,
        showsPlaceholder: Bool = true,
        crop: ImmersiveArtworkCrop = .original,
        focalPoint: ImmersiveImageFocalPoint = .center,
        title: String,
        subtitle: String,
        layout: ImmersiveArtworkLayout = .standard,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder content: () -> Content
    ) {
        self.sourceID = sourceID
        self.contentID = contentID
        self.sourceImage = sourceImage
        self.preferredBackgroundColor = preferredBackgroundColor
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.placeholderPaletteKey = placeholderPaletteKey
        self.placeholderSymbolColor = placeholderSymbolColor
        self.placeholderArtworkStyle = placeholderArtworkStyle
        self.showsPlaceholder = showsPlaceholder
        self.crop = crop
        self.focalPoint = focalPoint
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.placeholder = placeholder()
        self.content = content()

        let requestID = Self.requestID(
            sourceID: sourceID,
            contentID: contentID,
            sourceImage: sourceImage,
            crop: crop,
            extractsBackgroundColor: preferredBackgroundColor == nil
        )
        self._loadState = State(
            initialValue: ImmersiveImageLoadState(
                requestID: requestID,
                result: ImmersiveImagePipeline.cachedResult(
                    key: requestID.cacheKey,
                    extractsBackgroundColor: requestID.extractsBackgroundColor
                )
            )
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
                image: currentResult?.image,
                showsPlaceholder: showsPlaceholder,
                fallbackBackgroundColor: fallbackBackgroundColor,
                paletteKey: placeholderPaletteKey,
                symbolColor: placeholderSymbolColor,
                placeholderArtworkStyle: placeholderArtworkStyle,
                focalPoint: focalPoint,
                placeholder: placeholder
            )
        } content: {
            content
        }
        .task(id: requestID) {
            await processImage(for: requestID)
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
            ?? currentResult?.extractedBackgroundColor
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
        return currentResult == nil ? .exact : .prismAdaptive
    }

    private var usesTransparentPlaceholderBackground: Bool {
        usesPlaceholderArtwork && placeholderArtworkStyle == .transparent
    }

    private var usesSolidPlaceholderBackground: Bool {
        usesPlaceholderArtwork && placeholderArtworkStyle == .solid
    }

    private var usesPlaceholderArtwork: Bool {
        currentResult == nil && showsPlaceholder
    }

    private var requestID: ImmersiveImageRequestID {
        Self.requestID(
            sourceID: sourceID,
            contentID: contentID,
            sourceImage: sourceImage,
            crop: crop,
            extractsBackgroundColor: preferredBackgroundColor == nil
        )
    }

    private var currentResult: ImmersiveProcessedImage? {
        let request = requestID
        guard request.hasSourceImage else { return nil }
        if loadState.requestID == request { return loadState.result }
        return loadState.displayedResult(
            for: request,
            cachedResult: ImmersiveImagePipeline.cachedResult(
                key: request.cacheKey,
                extractsBackgroundColor: request.extractsBackgroundColor
            )
        )
    }

    private func processImage(for requestID: ImmersiveImageRequestID) async {
        let result = await ImmersiveImagePipeline.process(
            sourceImage: sourceImage,
            key: requestID.cacheKey,
            extractsBackgroundColor: requestID.extractsBackgroundColor
        )
        guard !Task.isCancelled, requestID == self.requestID else { return }
        // A failed replacement must not erase a previously ready rendition.
        guard result != nil || sourceImage == nil else { return }
        loadState = ImmersiveImageLoadState(requestID: requestID, result: result)
    }

    private static func requestID(
        sourceID: String,
        contentID: String?,
        sourceImage: CGImage?,
        crop: ImmersiveArtworkCrop,
        extractsBackgroundColor: Bool
    ) -> ImmersiveImageRequestID {
        ImmersiveImageRequestID(
            cacheKey: ImmersiveArtworkCacheKey(sourceID: sourceID, crop: crop),
            contentID: contentID,
            sourceImage: sourceImage,
            extractsBackgroundColor: extractsBackgroundColor
        )
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
        source: ImmersiveImageSource,
        crop: ImmersiveArtworkCrop = .original
    ) async {
        await prewarm(
            sourceID: source.id,
            sourceImage: source.image,
            preferredBackgroundColor: source.preferredBackgroundColor,
            crop: crop
        )
    }

    public static func prewarm(
        sourceID: String,
        sourceImage: CGImage?,
        preferredBackgroundColor: Color? = nil,
        crop: ImmersiveArtworkCrop = .original
    ) async {
        let key = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: crop)
        _ = await ImmersiveImagePipeline.process(
            sourceImage: sourceImage,
            key: key,
            extractsBackgroundColor: preferredBackgroundColor == nil
        )
    }
}
