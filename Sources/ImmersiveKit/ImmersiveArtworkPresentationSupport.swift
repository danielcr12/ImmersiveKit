import Observation
import PrismCoreBackgrounds
import SwiftUI

@MainActor
@Observable
final class ImmersiveAdaptiveBackgroundState {
    private(set) var heroOverscroll: CGFloat = 0

    func updateHeroOverscroll(_ overscroll: CGFloat) {
        guard heroOverscroll != overscroll else { return }
        heroOverscroll = overscroll
    }
}

enum ImmersiveBackgroundGeometry {
    static func adaptiveMeshStartOffset(
        heroHeight: CGFloat,
        heroOverscroll: CGFloat,
        containerHeight: CGFloat
    ) -> CGFloat {
        guard containerHeight > 0 else { return 0 }
        return min(max(heroHeight + heroOverscroll, 0), containerHeight)
    }
}

@MainActor
struct ImmersiveBackgroundLayer: View {
    let backgroundColor: Color
    let sourceColor: Color
    let adaptivePalette: PrismAdaptiveBackgroundPalette?
    let heroHeight: CGFloat
    let containerHeight: CGFloat
    let adaptiveState: ImmersiveAdaptiveBackgroundState

    @ViewBuilder
    var body: some View {
        if let adaptivePalette {
            GeometryReader { geometry in
                PrismAdaptiveMeshBackground(
                    sourceColor: sourceColor,
                    palette: adaptivePalette,
                    transitionStart: transitionStart(in: geometry.size.height)
                )
            }
        } else {
            backgroundColor
        }
    }

    private func transitionStart(in containerHeight: CGFloat) -> CGFloat {
        guard containerHeight > 0 else { return 0 }
        let adaptiveMeshStartOffset = ImmersiveBackgroundGeometry.adaptiveMeshStartOffset(
            heroHeight: heroHeight,
            heroOverscroll: adaptiveState.heroOverscroll,
            containerHeight: self.containerHeight
        )
        return min(max(adaptiveMeshStartOffset / containerHeight, 0), 1)
    }
}

enum ImmersiveArtworkTuning {
    static let scrollEdgeRevealProgress: CGFloat = 0.85
    static let topBleed: CGFloat = 30
    /// Vertical spacing between the title and subtitle labels in the hero.
    static let titleSubtitleSpacing: CGFloat = 5
    /// Bottom inset of the title/subtitle stack from the hero's lower edge.
    static let heroLabelBottomPadding: CGFloat = 30
    /// Explicit visual shift toward the hero's lower edge.
    static let heroLabelVerticalOffset: CGFloat = 10
    /// Horizontal padding of the title/subtitle stack within the hero.
    static let heroLabelHorizontalPadding: CGFloat = 24
}

enum ImmersiveScrollSpace {
    static let name = "immersiveKit.artworkScroll"
}

/// A typed reference to the scroll coordinate space, avoiding raw-string call sites.
/// `nonisolated(unsafe)` is safe here because `NamedCoordinateSpace` is value-typed and
/// its `named(_:)` factory produces an immutable label — there is no mutable shared state.
extension NamedCoordinateSpace {
    nonisolated(unsafe) static let immersiveArtworkScroll: NamedCoordinateSpace =
        .named(ImmersiveScrollSpace.name)
}

struct ImmersiveHeroArtworkLayer<Artwork: View>: View {
    let artwork: Artwork
    let width: CGFloat
    let height: CGFloat
    let backgroundColor: Color
    let fadesIntoPrism: Bool

    @ViewBuilder
    var body: some View {
        if fadesIntoPrism {
            ImmersiveHeroArtworkSurface(
                artwork: artwork,
                width: width,
                height: height
            )
            .mask {
                ImmersiveHeroArtworkFadeMask()
            }
        } else {
            ZStack {
                ImmersiveHeroArtworkSurface(
                    artwork: artwork,
                    width: width,
                    height: height
                )

                ImmersiveArtworkOverlayLayer(
                    backgroundColor: backgroundColor,
                    height: height
                )
            }
        }
    }
}

struct ImmersiveHeroArtworkSurface<Artwork: View>: View {
    let artwork: Artwork
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        artwork
            .frame(
                width: width,
                height: height + ImmersiveArtworkTuning.topBleed
            )
            .clipped()
            .frame(width: width, height: height)
            .clipped()
    }
}

struct ImmersiveHeroArtworkFadeMask: View {
    var isEnabled = true

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.68),
                .init(color: .white.opacity(isEnabled ? 0.74 : 1), location: 0.80),
                .init(color: .white.opacity(isEnabled ? 0.10 : 1), location: 0.96),
                .init(color: .white.opacity(isEnabled ? 0 : 1), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
                    .init(color: backgroundColor, location: 1)
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

extension View {
    @ViewBuilder
    func immersiveTopScrollEdgeEffectHidden(_ hidden: Bool) -> some View {
#if os(iOS)
        scrollEdgeEffectHidden(hidden, for: .top)
#else
        self
#endif
    }

    @ViewBuilder
    func immersiveBottomScrollEdgeEffectVisible() -> some View {
#if os(iOS)
        scrollEdgeEffectHidden(false, for: .bottom)
#else
        self
#endif
    }

    @ViewBuilder
    func immersiveScrollGeometryProbe(
        heroHeight: CGFloat,
        onSample: @escaping (CGFloat) -> Void
    ) -> some View {
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
    }
}
