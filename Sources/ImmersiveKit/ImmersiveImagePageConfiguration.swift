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
    public let title: String
    public let subtitle: String
    public let layout: ImmersiveArtworkLayout

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
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
    }
}
