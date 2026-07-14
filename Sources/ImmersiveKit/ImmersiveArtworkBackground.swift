import CoreGraphics
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
    /// Derives an OKLCH-adjusted palette from the supplied color;
    /// ``key`` identifies the palette in the in-memory cache.
    case placeholderPalette(key: String)
}

/// Layout values shared by immersive artwork backgrounds.
public struct ImmersiveArtworkLayout: Sendable {
    public static let standard = ImmersiveArtworkLayout()

    public let heroHeightRatio: CGFloat
    public let minimumHeroHeight: CGFloat
    public let titleLineLimit: Int?
    public let subtitleLineLimit: Int?
    public let contentHorizontalPadding: CGFloat
    public let contentVerticalPadding: CGFloat

    public init(
        heroHeightRatio: CGFloat = 0.58,
        minimumHeroHeight: CGFloat = 440,
        titleLineLimit: Int? = 1,
        subtitleLineLimit: Int? = 1,
        contentHorizontalPadding: CGFloat = 16,
        contentVerticalPadding: CGFloat = 16
    ) {
        self.heroHeightRatio = heroHeightRatio
        self.minimumHeroHeight = minimumHeroHeight
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
    @Environment(\.colorScheme) private var colorScheme

    public init(
        backgroundColor: Color,
        title: String,
        subtitle: String,
        titleColor: Color = .white,
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
                effectiveBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .immersiveScrollOffsetFallbackProbe()

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
                // Scroll tracking: on iOS 18+, `immersiveScrollGeometryProbe` uses
                // `onScrollGeometryChange` for efficient threshold detection. The
                // fallback observer handles older OS versions and macOS via a
                // GeometryReader preference-key probe at the top of the scroll content.
                .immersiveScrollOffsetFallbackObserver { offsetY in
                    updateScrollProgress(offsetY: offsetY, heroHeight: heroHeight)
                }
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
                ZStack {
                    artwork
                        .frame(
                            width: outerGeometry.size.width,
                            height: displayHeight + ImmersiveArtworkTuning.topBleed
                        )
                        .clipped()

                    ImmersiveArtworkOverlayLayer(
                        backgroundColor: effectiveBackgroundColor,
                        height: displayHeight
                    )
                }
                .frame(width: outerGeometry.size.width, height: displayHeight)
                .clipShape(ImmersiveTopBleedClipShape())
                .allowsHitTesting(false)

                VStack(spacing: ImmersiveArtworkTuning.titleSubtitleSpacing) {
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(layout.titleLineLimit)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(titleColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(layout.subtitleLineLimit)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, ImmersiveArtworkTuning.heroLabelHorizontalPadding)
                .padding(.bottom, ImmersiveArtworkTuning.heroLabelBottomPadding)
            }
            .frame(width: outerGeometry.size.width, height: displayHeight)
            .clipShape(ImmersiveTopBleedClipShape())
            .offset(y: -overscroll)
        }
        .frame(height: heroHeight)
    }

    private func updateScrollProgress(offsetY: CGFloat, heroHeight: CGFloat) {
        guard heroHeight > 0 else { return }
        // offsetY is always ≥ 0 from both scroll-tracking paths; a single upper clamp suffices.
        let progress = min(offsetY / heroHeight, 1)
        let shouldHide = progress < ImmersiveArtworkTuning.scrollEdgeRevealProgress
        guard shouldHide != hidesTopScrollEdgeEffect else { return }
        hidesTopScrollEdgeEffect = shouldHide
    }

    private var effectiveBackgroundColor: Color {
        switch backgroundTreatment {
        case .exact:
            return backgroundColor
        case .placeholderPalette(let key):
            return ImmersivePlaceholderPaletteCache.palette(
                for: key,
                baseColor: backgroundColor,
                colorScheme: colorScheme
            ).solidColor
        }
    }
}

/// A scrolling immersive background backed by an optional `CGImage` and placeholder view.
@MainActor
public struct ImmersiveImageBackground<Placeholder: View, Content: View>: View {
    private let sourceID: String
    private let sourceImage: CGImage?
    private let preferredBackgroundColor: Color?
    private let fallbackBackgroundColor: Color
    private let placeholderPaletteKey: String
    private let placeholderSymbolColor: Color
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
        placeholderSymbolColor: Color = .white.opacity(0.78),
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
        self.showsPlaceholder = showsPlaceholder
        self.crop = crop
        self.title = title
        self.subtitle = subtitle
        self.layout = layout
        self.placeholder = placeholder()
        self.content = content()

        let cacheKey = Self.cacheKey(sourceID: sourceID, crop: crop)
        self._processedImage = State(
            initialValue: ImmersiveArtworkMemoryCache.artwork(for: cacheKey)
                ?? ImmersiveImageProcessing.cropSynchronously(sourceImage, crop: crop)
        )
        self._extractedBackgroundColor = State(
            initialValue: ImmersiveArtworkMemoryCache.backgroundColor(for: cacheKey)
        )
    }

    public var body: some View {
        ImmersiveArtworkBackground(
            backgroundColor: effectiveBackgroundColor,
            title: title,
            subtitle: subtitle,
            layout: layout
        ) {
            ImmersiveImageArtworkLayer(
                image: processedImage,
                showsPlaceholder: showsPlaceholder,
                fallbackBackgroundColor: fallbackBackgroundColor,
                paletteKey: placeholderPaletteKey,
                symbolColor: placeholderSymbolColor,
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
        preferredBackgroundColor
            ?? extractedBackgroundColor
            ?? ImmersivePlaceholderPaletteCache.palette(
                for: placeholderPaletteKey,
                baseColor: fallbackBackgroundColor,
                colorScheme: colorScheme
            ).solidColor
    }

    private var processingID: String {
        Self.cacheKey(sourceID: sourceID, crop: crop)
    }

    private func processImage() async {
        let key = processingID

        if let cachedImage = ImmersiveArtworkMemoryCache.artwork(for: key) {
            processedImage = cachedImage
        } else if let image = await ImmersiveImageProcessing.crop(sourceImage, crop: crop) {
            guard !Task.isCancelled else { return }
            processedImage = image
            ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        } else {
            processedImage = nil
            extractedBackgroundColor = nil
            return
        }

        if let preferredBackgroundColor {
            extractedBackgroundColor = preferredBackgroundColor
            ImmersiveArtworkMemoryCache.store(preferredBackgroundColor, for: key)
            return
        }

        if let cachedColor = ImmersiveArtworkMemoryCache.backgroundColor(for: key) {
            extractedBackgroundColor = cachedColor
            return
        }

        guard let processedImage else { return }
        guard let color = try? await ImmersiveImageProcessing.extractBackgroundColor(
            from: processedImage
        ) else { return }
        guard !Task.isCancelled else { return }

        extractedBackgroundColor = color
        ImmersiveArtworkMemoryCache.store(color, for: key)
    }

    private static func cacheKey(
        sourceID: String,
        crop: ImmersiveArtworkCrop
    ) -> String {
        "\(sourceID)-\(crop.rawValue)"
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
        let key = "\(sourceID)-\(crop.rawValue)"

        // --- Artwork ---
        // Re-crop if artwork was evicted from NSCache or was never stored.
        let needsArtwork = ImmersiveArtworkMemoryCache.artwork(for: key) == nil
        if needsArtwork {
            guard let image = await ImmersiveImageProcessing.crop(sourceImage, crop: crop) else {
                return
            }
            ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        }

        // --- Background color ---
        guard ImmersiveArtworkMemoryCache.backgroundColor(for: key) == nil else { return }

        if let preferredBackgroundColor {
            ImmersiveArtworkMemoryCache.store(preferredBackgroundColor, for: key)
            return
        }

        guard let artwork = ImmersiveArtworkMemoryCache.artwork(for: key) else { return }
        guard let color = try? await ImmersiveImageProcessing.extractBackgroundColor(
            from: artwork
        ) else { return }
        ImmersiveArtworkMemoryCache.store(color, for: key)
    }
}

private enum ImmersiveArtworkTuning {
    static let scrollEdgeRevealProgress: CGFloat = 0.85
    static let topBleed: CGFloat = 30
    /// Distance by which the hero clip rect extends upward to prevent status-bar clipping artefacts.
    static let clipBleed: CGFloat = 800
    /// Vertical spacing between the title and subtitle labels in the hero.
    static let titleSubtitleSpacing: CGFloat = 5
    /// Bottom inset of the title/subtitle stack from the hero's lower edge.
    static let heroLabelBottomPadding: CGFloat = 30
    /// Horizontal padding of the title/subtitle stack within the hero.
    static let heroLabelHorizontalPadding: CGFloat = 24
}

private enum ImmersiveScrollSpace {
    static let name = "immersiveKit.artworkScroll"
}

/// A typed reference to the scroll coordinate space, avoiding raw-string call sites.
/// `nonisolated(unsafe)` is safe here because `NamedCoordinateSpace` is value-typed and
/// its `named(_:)` factory produces an immutable label — there is no mutable shared state.
private extension NamedCoordinateSpace {
    nonisolated(unsafe) static let immersiveArtworkScroll: NamedCoordinateSpace =
        .named(ImmersiveScrollSpace.name)
}

private struct ImmersiveTopBleedClipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(
            CGRect(
                x: rect.minX,
                y: rect.minY - ImmersiveArtworkTuning.clipBleed,
                width: rect.width,
                height: rect.height + ImmersiveArtworkTuning.clipBleed
            )
        )
        return path
    }
}

@MainActor
private struct ImmersiveArtworkOverlayLayer: View {
    let backgroundColor: Color
    let height: CGFloat

    private static let scrimStopValues: [(progress: Double, opacityMultiplier: Double)] =
        (0..<10).map { index in
            let progress = Double(index) / 9
            return (progress, UnitCurve.easeOut.value(at: progress))
        }

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.68),
                    .init(color: backgroundColor.opacity(0.26), location: 0.80),
                    .init(color: backgroundColor.opacity(0.9), location: 0.96),
                    .init(color: backgroundColor, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        stops: Self.scrimStopValues.map { stop in
                            Gradient.Stop(
                                color: backgroundColor.opacity(stop.opacityMultiplier * 0.55),
                                location: stop.progress
                            )
                        },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: height * 0.28)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

private struct ImmersiveScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    @ViewBuilder
    func immersiveTopScrollEdgeEffectHidden(_ hidden: Bool) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .top)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func immersiveBottomScrollEdgeEffectVisible() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(false, for: .bottom)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func immersiveScrollGeometryProbe(
        heroHeight: CGFloat,
        onSample: @escaping (CGFloat) -> Void
    ) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: Bool.self) { geometry in
                let height = max(heroHeight, 1)
                let progress = min(max(geometry.contentOffset.y / height, 0), 1)
                return progress < ImmersiveArtworkTuning.scrollEdgeRevealProgress
            } action: { _, hidesTopScrollEdgeEffect in
                let progress = hidesTopScrollEdgeEffect
                    ? CGFloat.zero
                    : ImmersiveArtworkTuning.scrollEdgeRevealProgress
                onSample(progress * max(heroHeight, 1))
            }
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func immersiveScrollOffsetFallbackObserver(
        onSample: @escaping (CGFloat) -> Void
    ) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self
        } else {
            onPreferenceChange(ImmersiveScrollOffsetPreferenceKey.self) { offsetY in
                onSample(offsetY)
            }
        }
        #else
        onPreferenceChange(ImmersiveScrollOffsetPreferenceKey.self) { offsetY in
            onSample(offsetY)
        }
        #endif
    }

    @ViewBuilder
    func immersiveScrollOffsetFallbackProbe() -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self
        } else {
            immersiveScrollOffsetPreference()
        }
        #else
        immersiveScrollOffsetPreference()
        #endif
    }

    private func immersiveScrollOffsetPreference() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ImmersiveScrollOffsetPreferenceKey.self,
                    value: max(
                        0,
                        -geometry.frame(in: NamedCoordinateSpace.immersiveArtworkScroll).minY
                    )
                )
            }
        }
    }
}
