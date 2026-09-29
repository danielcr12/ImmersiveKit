import PrismCoreBackgrounds
import SwiftUI

/// Determines how source artwork is cropped before presentation and color analysis.
public enum ImmersiveArtworkCrop: String, Sendable {
    /// Preserves the source image dimensions.
    case original
    /// Center-crops the source image to a square.
    case square
}

/// Determines whether a custom artwork background uses its exact color or a derived placeholder color.
public enum ImmersiveBackgroundTreatment: Sendable {
    /// Uses the supplied color exactly as the background.
    case exact
    /// Starts with the supplied source color and transitions into its adaptive
    /// light- or dark-mode Prism mesh below the artwork.
    case prismAdaptive
    /// Derives an OKLCH-adjusted palette and applies the standard Prism wash;
    /// ``key`` identifies the palette in the in-memory cache.
    case placeholderPalette(key: String)
    /// Uses the supplied color exactly and omits the artwork scrim.
    case solidPlaceholder
}

/// Determines how a missing image is rendered inside an image-backed hero.
public enum ImmersivePlaceholderArtworkStyle: Equatable, Sendable {
    /// Renders the supplied SwiftUI artwork across the hero without symbol
    /// sizing or tinting. Use for vector assets or other composed artwork.
    case artwork
    /// Uses the layered placeholder gradient and hero scrim.
    case gradient
    /// Uses a uniform placeholder tint and the supplied symbol color gradient.
    case solid
    /// Shows the placeholder symbol without painting a placeholder background.
    case transparent
}

/// Layout values shared by immersive artwork backgrounds.
public struct ImmersiveArtworkLayout: Sendable {
    public static let standard = ImmersiveArtworkLayout()

    public let heroHeightRatio: CGFloat
    public let minimumHeroHeight: CGFloat
    public let showsTitle: Bool
    public let showsSubtitle: Bool
    public let titleLineLimit: Int?
    public let subtitleLineLimit: Int?
    public let contentHorizontalPadding: CGFloat
    public let contentVerticalPadding: CGFloat

    public init(
        heroHeightRatio: CGFloat = 0.58,
        minimumHeroHeight: CGFloat = 440,
        showsTitle: Bool = true,
        showsSubtitle: Bool = true,
        titleLineLimit: Int? = 1,
        subtitleLineLimit: Int? = 1,
        contentHorizontalPadding: CGFloat = 16,
        contentVerticalPadding: CGFloat = 16
    ) {
        self.heroHeightRatio = heroHeightRatio
        self.minimumHeroHeight = minimumHeroHeight
        self.showsTitle = showsTitle
        self.showsSubtitle = showsSubtitle
        self.titleLineLimit = titleLineLimit
        self.subtitleLineLimit = subtitleLineLimit
        self.contentHorizontalPadding = contentHorizontalPadding
        self.contentVerticalPadding = contentVerticalPadding
    }
}

/// A scrolling immersive background whose hero can be any SwiftUI view.
@MainActor
public struct ImmersiveArtworkBackground<Artwork: View, Content: View>: View {
    private let backgroundColor: Color
    private let title: String
    private let subtitle: String
    private let titleColor: Color
    private let backgroundTreatment: ImmersiveBackgroundTreatment
    private let layout: ImmersiveArtworkLayout
    private let artwork: Artwork
    private let content: Content

    @State private var hidesTopScrollEdgeEffect = true
    @State private var adaptiveBackgroundState = ImmersiveAdaptiveBackgroundState()
    @Environment(\.colorScheme) private var colorScheme

    public init(
        backgroundColor: Color,
        title: String,
        subtitle: String,
        titleColor: Color = .primary,
        backgroundTreatment: ImmersiveBackgroundTreatment = .exact,
        layout: ImmersiveArtworkLayout = .standard,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.backgroundTreatment = backgroundTreatment
        self.layout = layout
        self.artwork = artwork()
        self.content = content()
    }

    public var body: some View {
        GeometryReader { outerGeometry in
            let heroHeight = max(
                outerGeometry.size.height * layout.heroHeightRatio,
                layout.minimumHeroHeight
            )
            ZStack(alignment: .top) {
                ImmersiveBackgroundLayer(
                    backgroundColor: effectiveBackgroundColor,
                    sourceColor: backgroundColor,
                    adaptivePalette: effectiveAdaptivePalette,
                    heroHeight: heroHeight,
                    containerHeight: outerGeometry.size.height,
                    adaptiveState: adaptiveBackgroundState
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        stretchyHero(
                            outerGeometry: outerGeometry,
                            heroHeight: heroHeight
                        )

                        content
                            .padding(.horizontal, layout.contentHorizontalPadding)
                            .padding(.vertical, layout.contentVerticalPadding)
                    }
                }
                .ignoresSafeArea(edges: .top)
                .coordinateSpace(.immersiveArtworkScroll)
                .immersiveTopScrollEdgeEffectHidden(hidesTopScrollEdgeEffect)
                .immersiveBottomScrollEdgeEffectVisible()
                // Track only threshold crossings so scrolling does not invalidate
                // the full immersive hierarchy for every offset change.
                .immersiveScrollGeometryProbe(heroHeight: heroHeight) { offsetY in
                    updateScrollProgress(offsetY: offsetY, heroHeight: heroHeight)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func stretchyHero(
        outerGeometry: GeometryProxy,
        heroHeight: CGFloat
    ) -> some View {
        GeometryReader { heroProxy in
            let minY = heroProxy.frame(in: NamedCoordinateSpace.immersiveArtworkScroll).minY
            let overscroll = max(minY, 0)
            let displayHeight = heroHeight + overscroll

            ZStack(alignment: .bottom) {
                ImmersiveHeroArtworkLayer(
                    artwork: artwork,
                    width: outerGeometry.size.width,
                    height: displayHeight,
                    backgroundColor: effectiveOverlayColor,
                    fadesIntoPrism: usesAdaptivePrismBackground
                )
                .frame(width: outerGeometry.size.width, height: displayHeight)
                .allowsHitTesting(false)

                VStack(spacing: ImmersiveArtworkTuning.titleSubtitleSpacing) {
                    if layout.showsTitle {
                        Text(title)
                            .font(.title.bold())
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(layout.titleLineLimit)
                            .truncationMode(.tail)
                    }

                    if layout.showsSubtitle {
                        Text(subtitle)
                            .font(.subheadline.bold())
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(layout.subtitleLineLimit)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, ImmersiveArtworkTuning.heroLabelHorizontalPadding)
                .padding(.bottom, ImmersiveArtworkTuning.heroLabelBottomPadding)
                .offset(y: ImmersiveArtworkTuning.heroLabelVerticalOffset)
            }
            .frame(width: outerGeometry.size.width, height: displayHeight)
            .offset(y: -overscroll)
        }
        .frame(height: heroHeight)
        .onGeometryChange(for: CGFloat.self) { geometry in
            max(
                geometry.frame(in: NamedCoordinateSpace.immersiveArtworkScroll).minY,
                0
            )
        } action: { overscroll in
            adaptiveBackgroundState.updateHeroOverscroll(overscroll)
        }
    }

    private func updateScrollProgress(offsetY: CGFloat, heroHeight: CGFloat) {
        guard heroHeight > 0 else { return }
        // offsetY is always >= 0 from both scroll-tracking paths; a single upper clamp suffices.
        let progress = min(offsetY / heroHeight, 1)
        let shouldHide = progress < ImmersiveArtworkTuning.scrollEdgeRevealProgress
        guard shouldHide != hidesTopScrollEdgeEffect else { return }
        hidesTopScrollEdgeEffect = shouldHide
    }

    private var effectiveBackgroundColor: Color {
        switch backgroundTreatment {
        case .exact:
            return backgroundColor
        case .prismAdaptive:
            return PrismBackgroundConstruction.washedColor(
                backgroundColor,
                colorScheme: colorScheme
            )
        case .placeholderPalette(let key):
            let paletteColor = ImmersivePlaceholderPaletteCache.palette(
                for: key,
                baseColor: backgroundColor,
                colorScheme: colorScheme
            ).solidColor
            return PrismBackgroundConstruction.washedColor(
                paletteColor,
                colorScheme: colorScheme
            )
        case .solidPlaceholder:
            return backgroundColor
        }
    }

    private var effectiveAdaptivePalette: PrismAdaptiveBackgroundPalette? {
        guard case .prismAdaptive = backgroundTreatment else { return nil }
        return PrismAdaptiveBackgroundPalette(
            baseColor: backgroundColor,
            colorScheme: colorScheme
        )
    }

    private var effectiveOverlayColor: Color {
        switch backgroundTreatment {
        case .solidPlaceholder:
            return .clear
        case .exact, .prismAdaptive, .placeholderPalette:
            return effectiveBackgroundColor
        }
    }

    private var usesAdaptivePrismBackground: Bool {
        if case .prismAdaptive = backgroundTreatment {
            return true
        }
        return false
    }
}
