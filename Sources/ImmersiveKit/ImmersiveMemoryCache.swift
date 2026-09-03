import CoreGraphics
import PrismBackgroundFoundation
import SwiftUI

struct ImmersiveArtworkCacheKey: Hashable, Sendable {
    let sourceID: String
    let crop: ImmersiveArtworkCrop

    var storageKey: String {
        "\(sourceID.count)#\(sourceID)#\(crop.rawValue)"
    }
}

private struct ImmersiveLRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var values: [Key: Value] = [:]
    private var accessOrder: [Key] = []

    init(capacity: Int) {
        self.capacity = max(capacity, 1)
    }

    mutating func value(for key: Key) -> Value? {
        guard let value = values[key] else { return nil }
        touch(key)
        return value
    }

    mutating func insert(_ value: Value, for key: Key) {
        if values[key] == nil, values.count >= capacity {
            let oldest = accessOrder.removeFirst()
            values.removeValue(forKey: oldest)
        }

        values[key] = value
        touch(key)
    }

    mutating func removeAll() {
        values.removeAll(keepingCapacity: true)
        accessOrder.removeAll(keepingCapacity: true)
    }

    private mutating func touch(_ key: Key) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }
}

@MainActor
enum ImmersiveArtworkMemoryCache {
    private final class CGImageBox {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private static var colors = ImmersiveLRUCache<ImmersiveArtworkCacheKey, Color>(
        capacity: 50
    )
    private static let artworkCache: NSCache<NSString, CGImageBox> = {
        let cache = NSCache<NSString, CGImageBox>()
        cache.countLimit = 16
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func backgroundColor(for key: ImmersiveArtworkCacheKey) -> Color? {
        colors.value(for: key)
    }

    static func store(_ color: Color, for key: ImmersiveArtworkCacheKey) {
        colors.insert(color, for: key)
    }

    static func artwork(for key: ImmersiveArtworkCacheKey) -> CGImage? {
        artworkCache.object(forKey: key.storageKey as NSString)?.image
    }

    static func storeArtwork(_ image: CGImage, for key: ImmersiveArtworkCacheKey) {
        artworkCache.setObject(
            CGImageBox(image),
            forKey: key.storageKey as NSString,
            cost: image.bytesPerRow * image.height
        )
    }

    static func removeAllForTesting() {
        colors.removeAll()
        artworkCache.removeAllObjects()
    }
}

/// An LRU-bounded in-memory cache for derived Prism adaptive palettes.
/// Separate entries are stored per color scheme to avoid cross-appearance bleed.
@MainActor
enum ImmersivePlaceholderPaletteCache {
    private static var palettes = ImmersiveLRUCache<String, PrismAdaptiveBackgroundPalette>(
        capacity: 80
    )

    static func palette(
        for key: String,
        baseColor: Color,
        colorScheme: ColorScheme
    ) -> PrismAdaptiveBackgroundPalette {
        let cacheKey = "\(colorScheme == .dark ? "dark" : "light")-\(key)"
        if let palette = palettes.value(for: cacheKey) {
            return palette
        }

        let palette = PrismAdaptiveBackgroundPalette(
            baseColor: baseColor,
            colorScheme: colorScheme
        )
        palettes.insert(palette, for: cacheKey)
        return palette
    }

    static func removeAllForTesting() {
        palettes.removeAll()
    }
}
