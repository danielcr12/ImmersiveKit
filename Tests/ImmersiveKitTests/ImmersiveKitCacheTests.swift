import CoreGraphics
import SwiftUI
import XCTest
@testable import ImmersiveKit

final class ImmersiveKitCacheTests: XCTestCase {
    @MainActor
    func testColorCacheStoreAndRetrieve() {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        let key = makeKey("colorCache")

        XCTAssertNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key),
            "Fresh key should have no cached color"
        )
        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .red,
            for: key
        )
        XCTAssertNotNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key),
            "Stored color should be retrievable"
        )
    }

    @MainActor
    func testColorCacheUpdateExistingKeyPreservesEntry() {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        let key = makeKey("colorUpdate")

        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .blue,
            for: key
        )
        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .green,
            for: key
        )

        XCTAssertNotNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key)
        )
    }

    @MainActor
    func testArtworkCacheStoreAndRetrieve() {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        guard let image = makeCGImage(width: 4, height: 4) else {
            return XCTFail("Could not create test CGImage")
        }
        let key = makeKey("artworkCache")

        XCTAssertNil(ImmersiveArtworkMemoryCache.artwork(for: key))
        ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        XCTAssertNotNil(ImmersiveArtworkMemoryCache.artwork(for: key))
    }

    @MainActor
    func testColorCacheUsesCropAsPartOfItsKey() {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        let sourceID = "unitTest-typedKey-\(UUID())"
        let squareKey = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: .square)
        let originalKey = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: .original)

        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .red,
            for: squareKey
        )
        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .blue,
            for: originalKey
        )

        XCTAssertEqual(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: squareKey),
            .red
        )
        XCTAssertEqual(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: originalKey),
            .blue
        )
    }

    @MainActor
    func testColorCacheEvictsLeastRecentlyUsedEntry() {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        let keys = (0..<50).map { index in
            ImmersiveArtworkCacheKey(
                sourceID: "unitTest-lru-\(UUID())-\(index)",
                crop: .square
            )
        }

        for key in keys {
            ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
                .red,
                for: key
            )
        }
        XCTAssertNotNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: keys[0])
        )

        let newKey = makeKey("lru-new")
        ImmersiveArtworkMemoryCache.storeExtractedBackgroundColor(
            .blue,
            for: newKey
        )

        XCTAssertNotNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: keys[0])
        )
        XCTAssertNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: keys[1])
        )
        XCTAssertNotNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: newKey)
        )
    }

    @MainActor
    func testPrewarmStoresArtworkWithoutCachingPresentationOverride() async {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        guard let source = makeCGImage(width: 120, height: 80) else {
            return XCTFail("Could not create test CGImage")
        }
        let sourceID = "unitTest-prewarm-\(UUID())"
        let key = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: .square)

        await ImmersiveImagePrewarmer.prewarm(
            sourceID: sourceID,
            sourceImage: source,
            preferredBackgroundColor: .green,
            crop: .square
        )

        XCTAssertNotNil(ImmersiveArtworkMemoryCache.artwork(for: key))
        XCTAssertNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key)
        )
    }

    @MainActor
    func testPrewarmDoesNotSharePreferredColorsBetweenPresentations() async {
        ImmersiveArtworkMemoryCache.removeAllForTesting()
        guard let source = makeCGImage(width: 40, height: 40) else {
            return XCTFail("Could not create test CGImage")
        }
        let sourceID = "unitTest-prewarm-reuse-\(UUID())"
        let key = ImmersiveArtworkCacheKey(sourceID: sourceID, crop: .original)

        await ImmersiveImagePrewarmer.prewarm(
            sourceID: sourceID,
            sourceImage: source,
            preferredBackgroundColor: .green
        )
        await ImmersiveImagePrewarmer.prewarm(
            sourceID: sourceID,
            sourceImage: source,
            preferredBackgroundColor: .red
        )

        XCTAssertNil(
            ImmersiveArtworkMemoryCache.extractedBackgroundColor(for: key)
        )
    }

    func testRequestIdentityChangesWhenAnImageFinishesLoading() {
        guard let image = makeCGImage(width: 40, height: 40) else {
            return XCTFail("Could not create test CGImage")
        }
        let key = makeKey("imageArrival")
        let waiting = ImmersiveImageRequestID(
            cacheKey: key,
            sourceImage: nil,
            extractsBackgroundColor: true
        )
        let loaded = ImmersiveImageRequestID(
            cacheKey: key,
            sourceImage: image,
            extractsBackgroundColor: true
        )

        XCTAssertNotEqual(waiting, loaded)
    }

    @MainActor
    func testPlaceholderPaletteCacheIncludesBaseColor() {
        ImmersivePlaceholderPaletteCache.removeAllForTesting()

        let redPalette = ImmersivePlaceholderPaletteCache.palette(
            for: "shared",
            baseColor: .red,
            colorScheme: .light
        )
        let bluePalette = ImmersivePlaceholderPaletteCache.palette(
            for: "shared",
            baseColor: .blue,
            colorScheme: .light
        )

        XCTAssertNotEqual(redPalette, bluePalette)
    }

    func testImagePageConfigurationDefaultsToGradientPlaceholder() {
        let configuration = ImmersiveImagePageConfiguration(
            sourceID: "unitTest-page",
            sourceImage: nil,
            fallbackBackgroundColor: .blue,
            placeholderPaletteKey: "unitTest-page",
            title: "Title",
            subtitle: "Subtitle"
        )

        XCTAssertEqual(configuration.placeholderArtworkStyle, .gradient)
    }

    func testImagePageConfigurationPreservesPlaceholderStyle() {
        let configuration = ImmersiveImagePageConfiguration(
            sourceID: "unitTest-page-style",
            sourceImage: nil,
            fallbackBackgroundColor: .blue,
            placeholderPaletteKey: "unitTest-page-style",
            placeholderArtworkStyle: .transparent,
            title: "Title",
            subtitle: "Subtitle"
        )

        XCTAssertEqual(configuration.placeholderArtworkStyle, .transparent)
    }

    func testImageSourceProvidesSimplePageConfigurationDefaults() {
        let source = ImmersiveImageSource(id: "unitTest-source", image: nil)
        let configuration = ImmersiveImagePageConfiguration(
            source: source,
            fallbackBackgroundColor: .blue,
            title: "Title"
        )

        XCTAssertEqual(configuration.sourceID, source.id)
        XCTAssertEqual(configuration.placeholderPaletteKey, source.id)
        XCTAssertEqual(configuration.subtitle, "")
    }

    private func makeKey(_ label: String) -> ImmersiveArtworkCacheKey {
        ImmersiveArtworkCacheKey(
            sourceID: "unitTest-\(label)-\(UUID())",
            crop: .square
        )
    }

    private func makeCGImage(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        return context.makeImage()
    }
}
