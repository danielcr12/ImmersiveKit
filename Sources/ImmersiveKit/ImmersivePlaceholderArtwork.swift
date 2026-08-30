import OKLCHKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Composition layer that displays a processed `CGImage` hero or falls back to the
/// OKLCH placeholder artwork when the image is absent or still loading.
@MainActor
struct ImmersiveImageArtworkLayer<Placeholder: View>: View {
    let image: CGImage?
    let showsPlaceholder: Bool
    let fallbackBackgroundColor: Color
    let paletteKey: String
    let symbolColor: Color
    let placeholderArtworkStyle: ImmersivePlaceholderArtworkStyle
    let placeholder: Placeholder

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
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
    let palette: ImmersivePlaceholderPalette
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
                placeholderBackground(size: geometry.size)
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
    private func placeholderBackground(size: CGSize) -> some View {
        switch artworkStyle {
        case .gradient:
            ZStack {
                ImmersivePaletteGradient(
                    palette: palette,
                    size: size
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.56),
                        .init(color: palette.solidColor.opacity(0.28), location: 0.78),
                        .init(color: palette.solidColor.opacity(0.74), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(colorScheme == .dark ? 0 : 1)
            }
        case .solid:
            Color.clear
        case .transparent:
            Color.clear
        }
    }
}

@MainActor
struct ImmersivePaletteGradient: View {
    let palette: ImmersivePlaceholderPalette
    let size: CGSize

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: palette.topColor, location: 0),
                        .init(color: palette.middleColor, location: 0.48),
                        .init(color: palette.bottomColor, location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RadialGradient(
                    colors: [
                        palette.highlightColor,
                        palette.highlightColor.opacity(0.38),
                        .clear,
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.82
                )
            }
            .overlay {
                RadialGradient(
                    colors: [palette.glowColor.opacity(0.82), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.64
                )
            }
    }
}

/// An LRU-bounded in-memory cache for derived ``ImmersivePlaceholderPalette`` values.
/// Separate entries are stored per color scheme to avoid cross-appearance bleed.
@MainActor
enum ImmersivePlaceholderPaletteCache {
    private static var palettes: [String: ImmersivePlaceholderPalette] = [:]
    private static var accessOrder: [String] = []
    private static let maxEntries = 80

    static func palette(
        for key: String,
        baseColor: Color,
        colorScheme: ColorScheme
    ) -> ImmersivePlaceholderPalette {
        let cacheKey = "\(colorScheme == .dark ? "dark" : "light")-\(key)"
        if let palette = palettes[cacheKey] {
            if let index = accessOrder.firstIndex(of: cacheKey) {
                accessOrder.append(accessOrder.remove(at: index))
            }
            return palette
        }

        let palette = ImmersivePlaceholderPalette(
            baseColor: baseColor,
            colorScheme: colorScheme
        )
        if palettes.count >= maxEntries, let oldest = accessOrder.first {
            palettes.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        palettes[cacheKey] = palette
        accessOrder.append(cacheKey)
        return palette
    }
}

@MainActor
struct ImmersivePlaceholderPalette {
    let topColor: Color
    let middleColor: Color
    let bottomColor: Color
    let solidColor: Color
    let highlightColor: Color
    let glowColor: Color

    init(baseColor: Color, colorScheme: ColorScheme) {
        let baseOKLCH = Self.resolvedOKLCH(from: baseColor, colorScheme: colorScheme)
        let targets = Self.targets(for: colorScheme)

        topColor = Self.adjustedColor(
            from: baseOKLCH,
            lightness: targets.topLightness,
            chromaScale: targets.topChromaScale
        )
        middleColor = Self.adjustedColor(
            from: baseOKLCH,
            lightness: targets.middleLightness,
            chromaScale: targets.middleChromaScale
        )
        bottomColor = Self.adjustedColor(
            from: baseOKLCH,
            lightness: targets.bottomLightness,
            chromaScale: targets.bottomChromaScale
        )
        solidColor = Self.adjustedColor(
            from: baseOKLCH,
            lightness: targets.solidLightness,
            chromaScale: targets.solidChromaScale
        )
        highlightColor = colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.34)
        glowColor = Self.adjustedColor(
            from: baseOKLCH,
            lightness: targets.glowLightness,
            chromaScale: targets.glowChromaScale
        )
    }

    private struct Targets {
        let topLightness: Double
        let middleLightness: Double
        let bottomLightness: Double
        let solidLightness: Double
        let glowLightness: Double
        let topChromaScale: Double
        let middleChromaScale: Double
        let bottomChromaScale: Double
        let solidChromaScale: Double
        let glowChromaScale: Double
    }

    private static func targets(for colorScheme: ColorScheme) -> Targets {
        if colorScheme == .dark {
            return Targets(
                topLightness: 0.43,
                middleLightness: 0.32,
                bottomLightness: 0.38,
                solidLightness: 0.34,
                glowLightness: 0.46,
                topChromaScale: 1.10,
                middleChromaScale: 1.16,
                bottomChromaScale: 1.08,
                solidChromaScale: 1.12,
                glowChromaScale: 1.02
            )
        }

        return Targets(
            topLightness: 0.86,
            middleLightness: 0.74,
            bottomLightness: 0.80,
            solidLightness: 0.78,
            glowLightness: 0.88,
            topChromaScale: 0.72,
            middleChromaScale: 0.84,
            bottomChromaScale: 0.78,
            solidChromaScale: 0.78,
            glowChromaScale: 0.60
        )
    }

    private static func adjustedColor(
        from color: OKLCH,
        lightness: Double,
        chromaScale: Double
    ) -> Color {
        Color(
            oklch: OKLCH(
                l: lightness,
                c: min(color.c * chromaScale, 0.32),
                h: color.h,
                alpha: color.alpha
            )
        )
    }

    private static func resolvedOKLCH(
        from color: Color,
        colorScheme: ColorScheme
    ) -> OKLCH {
        guard let components = resolvedComponents(from: color, colorScheme: colorScheme) else {
            return colorScheme == .dark
                ? OKLCH(l: 0.34, c: 0.16, h: 250)
                : OKLCH(l: 0.78, c: 0.14, h: 250)
        }

        return ColorConversion.srgbToOKLCH(
            SRGB(
                r: components.red,
                g: components.green,
                b: components.blue,
                alpha: components.opacity
            )
        )
    }

    private static func resolvedComponents(
        from color: Color,
        colorScheme: ColorScheme
    ) -> (red: Double, green: Double, blue: Double, opacity: Double)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0

        #if canImport(UIKit)
        let traits = UITraitCollection(
            userInterfaceStyle: colorScheme == .dark ? .dark : .light
        )
        let resolvedColor = UIColor(color).resolvedColor(with: traits)
        guard resolvedColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity) else {
            return nil
        }
        #elseif canImport(AppKit)
        let appearanceName: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        guard let appearance = NSAppearance(named: appearanceName) else {
            return nil
        }
        var rgbColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            rgbColor = NSColor(color).usingColorSpace(.sRGB)
        }
        guard let rgbColor else { return nil }
        // NSColor.getRed returns Void (unlike UIColor which returns Bool); call it directly.
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        #else
        return nil
        #endif

        return (
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(opacity)
        )
    }
}
