import Foundation
import SwiftUI

/// How standalone artwork blends into the surrounding hero background.
public enum ImmersiveArtworkBlending: Sendable {
    /// Fades asset and image artwork; keeps symbols and emoji fully visible.
    case automatic
    /// Keeps the entire artwork fully visible.
    case none
    /// Gradually fades the lower portion of the artwork into its background.
    case bottomFade
}

/// Artwork rendered natively by SwiftUI inside an immersive hero.
///
/// Use an asset name for image-catalog artwork so vector assets keep their
/// scalable representation, a symbol name for SF Symbols, or emoji text for
/// emoji artwork. Images fill the hero; symbols and emoji use a centered inset.
@MainActor
public struct ImmersiveArtwork: View {
    private enum Source {
        case asset(name: String, bundle: Bundle?)
        case symbol(name: String)
        case emoji(String)
        case image(Image)
    }

    private let source: Source
    private let blending: ImmersiveArtworkBlending
    private let scale: CGFloat
    private let contentMode: ContentMode

    /// Creates artwork from an image-catalog asset. Vector assets remain native
    /// SwiftUI images instead of being converted to `CGImage` first. The default
    /// fill preserves proportions and crops any overflow to the hero bounds.
    public init(
        asset name: String,
        bundle: Bundle? = nil,
        blending: ImmersiveArtworkBlending = .automatic,
        contentMode: ContentMode = .fill,
        scale: CGFloat = 1
    ) {
        source = .asset(name: name, bundle: bundle)
        self.blending = blending
        self.scale = scale
        self.contentMode = contentMode
    }

    /// Creates artwork from an SF Symbol name.
    public init(
        symbol name: String,
        blending: ImmersiveArtworkBlending = .automatic,
        scale: CGFloat = 1
    ) {
        source = .symbol(name: name)
        self.blending = blending
        self.scale = scale
        self.contentMode = .fit
    }

    /// Creates artwork from one or more emoji graphemes.
    public init(
        emoji: String,
        blending: ImmersiveArtworkBlending = .automatic,
        scale: CGFloat = 1
    ) {
        source = .emoji(emoji)
        self.blending = blending
        self.scale = scale
        self.contentMode = .fit
    }

    /// Wraps a SwiftUI image when the caller already has an `Image` value.
    public init(
        image: Image,
        blending: ImmersiveArtworkBlending = .automatic,
        contentMode: ContentMode = .fill,
        scale: CGFloat = 1
    ) {
        source = .image(image)
        self.blending = blending
        self.scale = scale
        self.contentMode = contentMode
    }

    public var body: some View {
        GeometryReader { geometry in
            let artworkWidth = geometry.size.width * (contentMode == .fill ? 1 : 0.82 * scale)
            let artworkHeight = geometry.size.height * (contentMode == .fill ? 1 : 0.72 * scale)

            Group {
                switch source {
                case let .asset(name, bundle):
                    presentedImage(
                        Image(name, bundle: bundle),
                        width: artworkWidth,
                        height: artworkHeight
                    )
                case let .symbol(name):
                    presentedImage(
                        Image(systemName: name),
                        width: artworkWidth,
                        height: artworkHeight
                    )
                case let .emoji(value):
                    Text(value)
                        .font(.system(size: min(artworkWidth, artworkHeight)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .mask {
                            ImmersiveHeroArtworkFadeMask(isEnabled: usesBottomFade)
                        }
                        .frame(width: artworkWidth, height: artworkHeight)
                case let .image(image):
                    presentedImage(image, width: artworkWidth, height: artworkHeight)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func presentedImage(_ image: Image, width: CGFloat, height: CGFloat) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            // Fade the image's own edge when it can end inside the viewport.
            .mask {
                ImmersiveHeroArtworkFadeMask(
                    isEnabled: usesBottomFade && (contentMode == .fit || scale < 1)
                )
            }
            // Adjust the filled image within the full hero viewport, so easing
            // its zoom does not shrink the viewport or move the hero labels.
            .scaleEffect(contentMode == .fill ? scale : 1)
            .frame(width: width, height: height)
            .clipped()
            .mask {
                ImmersiveHeroArtworkFadeMask(
                    isEnabled: usesBottomFade && contentMode == .fill
                )
            }
    }

    private var usesBottomFade: Bool {
        switch blending {
        case .none:
            false
        case .bottomFade:
            true
        case .automatic:
            switch source {
            case .asset, .image:
                true
            case .symbol, .emoji:
                false
            }
        }
    }
}
