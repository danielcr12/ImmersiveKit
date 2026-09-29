import PrismCoreBackgrounds
import Foundation
import SwiftUI

/// Composition layer that displays a processed `CGImage` hero or falls back to the
/// OKLCH placeholder artwork when the image is absent or still loading.
@MainActor
struct ImmersiveImageArtworkLayer<Placeholder: View>: View {
    let image: CGImage?
    let traceID: String
    let showsPlaceholder: Bool
    let fallbackBackgroundColor: Color
    let paletteKey: String
    let symbolColor: Color
    let placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle
    let focalPoint: ImmersiveImageFocalPoint
    let placeholder: Placeholder

    @Environment(\.colorScheme) private var colorScheme
    #if DEBUG
    @Environment(\.displayScale) private var displayScale
    #endif

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    let placement = ImmersiveImagePlacement.filling(
                        imageSize: CGSize(width: image.width, height: image.height),
                        containerSize: geometry.size,
                        focalPoint: focalPoint
                    )

                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(
                            width: placement.size.width,
                            height: placement.size.height
                        )
                        .offset(
                            x: placement.offset.width,
                            y: placement.offset.height
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        #if DEBUG
                        .onChange(
                            of: geometryTrace(image: image, geometry: geometry, placement: placement),
                            initial: true
                        ) { _, value in
                            print("[ImageTrace] t=\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime)) IMMERSIVE GEOMETRY content=\(traceID) \(value)")
                        }
                        #endif
                } else if showsPlaceholder {
                    ImmersivePlaceholderArtwork(
                        palette: ImmersivePlaceholderPaletteCache.palette(
                            for: paletteKey,
                            baseColor: fallbackBackgroundColor,
                            colorScheme: colorScheme
                        ),
                        symbolColor: symbolColor,
                        artworkStyle: placeholderArtworkStyle,
                        placeholder: placeholder
                    )
                } else {
                    Color.clear
                }
            }
        }
    }

    #if DEBUG
    private func geometryTrace(
        image: CGImage,
        geometry: GeometryProxy,
        placement: ImmersiveImagePlacement
    ) -> String {
        let frame = geometry.frame(in: .global)
        return String(
            format: "pixels=%ldx%ld container=%.3fx%.3f rendered=%.3fx%.3f cropOffset=%.3f,%.3f origin=%.3f,%.3f displayScale=%.1f safeTop=%.3f",
            image.width, image.height,
            geometry.size.width, geometry.size.height,
            placement.size.width, placement.size.height,
            placement.offset.width, placement.offset.height,
            frame.minX, frame.minY, displayScale, geometry.safeAreaInsets.top
        )
    }
    #endif
}

// MARK: - Placeholder tuning

private enum ImmersivePlaceholderTuning {
    /// Symbol size as a fraction of the smaller frame dimension.
    static let symbolSizeRatio: CGFloat = 0.56
    /// Minimum symbol size in points.
    static let symbolSizeMinimum: CGFloat = 180
    /// Maximum symbol size in points.
    static let symbolSizeMaximum: CGFloat = 420
    /// Upward nudge applied to the symbol, as a fraction of the frame height.
    static let symbolVerticalNudge: CGFloat = 0.05
}

@MainActor
private struct ImmersivePlaceholderArtwork<Placeholder: View>: View {
    let palette: PrismAdaptiveBackgroundPalette
    let symbolColor: Color
    let artworkStyle: ImmersivePlaceholderArtworkStyle
    let placeholder: Placeholder

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let symbolSize = min(
                max(
                    min(geometry.size.width, geometry.size.height) * ImmersivePlaceholderTuning.symbolSizeRatio,
                    ImmersivePlaceholderTuning.symbolSizeMinimum
                ),
                ImmersivePlaceholderTuning.symbolSizeMaximum
            )

            ZStack {
                placeholderBackground()
                placeholderSymbol(
                    size: symbolSize,
                    height: geometry.size.height
                )
            }
        }
    }

    @ViewBuilder
    private func placeholderSymbol(size: CGFloat, height: CGFloat) -> some View {
        switch artworkStyle {
        case .artwork:
            placeholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .gradient:
            placeholder
                .frame(width: size, height: size)
                .foregroundStyle(symbolColor)
                .offset(y: -height * ImmersivePlaceholderTuning.symbolVerticalNudge)
        case .solid:
            placeholder
                .frame(width: size, height: size)
                .foregroundStyle(symbolColor.gradient)
                .offset(y: -height * ImmersivePlaceholderTuning.symbolVerticalNudge)
        case .transparent:
            placeholder
                .frame(width: size, height: size)
                .foregroundStyle(symbolColor)
                .offset(y: -height * ImmersivePlaceholderTuning.symbolVerticalNudge)
        }
    }

    @ViewBuilder
    private func placeholderBackground() -> some View {
        switch artworkStyle {
        case .gradient:
            let transitionColor = PrismBackgroundConstruction.washedColor(
                palette.solidColor,
                colorScheme: colorScheme
            )
            ZStack {
                ImmersivePaletteGradient(
                    palette: palette
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.56),
                        .init(color: transitionColor.opacity(0.28), location: 0.78),
                        .init(color: transitionColor.opacity(0.74), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(colorScheme == .dark ? 0 : 1)
            }
        case .artwork, .solid, .transparent:
            Color.clear
        }
    }
}

@MainActor
struct ImmersivePaletteGradient: View {
    let palette: PrismAdaptiveBackgroundPalette

    var body: some View {
        PrismLayeredGradientBackground(
            colors: palette.layeredColors
        )
    }
}
