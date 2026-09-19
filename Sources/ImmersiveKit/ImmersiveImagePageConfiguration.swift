import CoreGraphics
import SwiftUI

/// Presentation values for one page in an ``ImmersivePagedImageBackground``.
///
/// Give each page a stable `sourceID` that changes whenever its image changes.
/// ImmersiveKit uses that identifier to keep processed artwork and extracted colors
/// separate in its in-memory caches.
public struct ImmersiveImagePageConfiguration {
    public let sourceID: String
    public let sourceImage: CGImage?
    public let preferredBackgroundColor: Color?
    public let fallbackBackgroundColor: Color
    public let placeholderPaletteKey: String
    public let placeholderSymbolColor: Color
    /// Controls the artwork and background shown while the image is unavailable.
    public let placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle
    public let showsPlaceholder: Bool
    public let crop: ImmersiveArtworkCrop
    public let focalPoint: ImmersiveImageFocalPoint
    public let title: String
    public let subtitle: String
    public let layout: ImmersiveArtworkLayout

    /// Creates a page configuration from the same reusable source value used by
    /// ``ImmersiveImageBackground`` and ``ImmersiveImagePrewarmer``.
    public init(
        source: ImmersiveImageSource,
        fallbackBackgroundColor: Color,
        placeholderPaletteKey: String? = nil,
        placeholderSymbolColor: Color = .white,
        placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle = .gradient,
        showsPlaceholder: Bool = true,
        crop: ImmersiveArtworkCrop = .original,
        focalPoint: ImmersiveImageFocalPoint = .center,
        title: String,
        subtitle: String = "",
        layout: ImmersiveArtworkLayout = .standard
    ) {
        self.init(
            sourceID: source.id,
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
            layout: layout
        )
    }

    public init(
        sourceID: String,
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
        layout: ImmersiveArtworkLayout = .standard
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
        self.focalPoint = focalPoint
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
    }
}
