import CoreGraphics
import XCTest
@testable import ImmersiveKit

final class ImmersiveKitTests: XCTestCase {

    // MARK: - ImmersiveArtworkLayout

    func testStandardLayoutMatchesDefaultHeroTuning() {
        XCTAssertEqual(ImmersiveArtworkLayout.standard.heroHeightRatio, 0.58)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.minimumHeroHeight, 440)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.titleLineLimit, 1)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.subtitleLineLimit, 1)
    }

    func testCustomLayoutInitRoundTrips() {
        let layout = ImmersiveArtworkLayout(
            heroHeightRatio: 0.5,
            minimumHeroHeight: 300,
            titleLineLimit: 2,
            subtitleLineLimit: 3,
            contentHorizontalPadding: 20,
            contentVerticalPadding: 12
        )
        XCTAssertEqual(layout.heroHeightRatio, 0.5)
        XCTAssertEqual(layout.minimumHeroHeight, 300)
        XCTAssertEqual(layout.titleLineLimit, 2)
        XCTAssertEqual(layout.subtitleLineLimit, 3)
        XCTAssertEqual(layout.contentHorizontalPadding, 20)
        XCTAssertEqual(layout.contentVerticalPadding, 12)
    }

    func testLayoutWithNilLineLimits() {
        let layout = ImmersiveArtworkLayout(titleLineLimit: nil, subtitleLineLimit: nil)
        XCTAssertNil(layout.titleLineLimit)
        XCTAssertNil(layout.subtitleLineLimit)
    }

    // MARK: - ImmersiveImageProcessing.cropSynchronously

    func testCropSynchronouslyNilImageReturnsNil() {
        let result = ImmersiveImageProcessing.cropSynchronously(nil, crop: .square)
        XCTAssertNil(result)
    }

    func testCropSynchronouslyOriginalReturnsSameDimensions() {
        guard let source = makeCGImage(width: 160, height: 90) else {
            return XCTFail("Could not create test CGImage")
        }
        let result = ImmersiveImageProcessing.cropSynchronously(source, crop: .original)
        XCTAssertEqual(result?.width, 160)
        XCTAssertEqual(result?.height, 90)
    }

    func testCropSynchronouslySquareCropsLandscape() {
        guard let source = makeCGImage(width: 200, height: 100) else {
            return XCTFail("Could not create test CGImage")
        }
        let result = ImmersiveImageProcessing.cropSynchronously(source, crop: .square)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    func testCropSynchronouslySquareCropsPortrait() {
        guard let source = makeCGImage(width: 80, height: 200) else {
            return XCTFail("Could not create test CGImage")
        }
        let result = ImmersiveImageProcessing.cropSynchronously(source, crop: .square)
        XCTAssertEqual(result?.width, 80)
        XCTAssertEqual(result?.height, 80)
    }

    func testCropSynchronouslySquareImageIsUnchanged() {
        guard let source = makeCGImage(width: 120, height: 120) else {
            return XCTFail("Could not create test CGImage")
        }
        let result = ImmersiveImageProcessing.cropSynchronously(source, crop: .square)
        XCTAssertEqual(result?.width, 120)
        XCTAssertEqual(result?.height, 120)
    }

    // MARK: - ImmersiveArtworkMemoryCache

    @MainActor
    func testColorCacheStoreAndRetrieve() {
        let key = "unitTest-colorCache-\(UUID())"
        XCTAssertNil(ImmersiveArtworkMemoryCache.backgroundColor(for: key),
                     "Fresh key should have no cached color")
        ImmersiveArtworkMemoryCache.store(.red, for: key)
        XCTAssertNotNil(ImmersiveArtworkMemoryCache.backgroundColor(for: key),
                        "Stored color should be retrievable")
    }

    @MainActor
    func testColorCacheUpdateExistingKeyPreservesEntry() {
        let key = "unitTest-colorUpdate-\(UUID())"
        ImmersiveArtworkMemoryCache.store(.blue, for: key)
        ImmersiveArtworkMemoryCache.store(.green, for: key)
        // After updating the same key the entry must still be present.
        XCTAssertNotNil(ImmersiveArtworkMemoryCache.backgroundColor(for: key))
    }

    @MainActor
    func testArtworkCacheStoreAndRetrieve() {
        guard let image = makeCGImage(width: 4, height: 4) else {
            return XCTFail("Could not create test CGImage")
        }
        let key = "unitTest-artworkCache-\(UUID())"
        XCTAssertNil(ImmersiveArtworkMemoryCache.artwork(for: key),
                     "Fresh key should have no cached artwork")
        ImmersiveArtworkMemoryCache.storeArtwork(image, for: key)
        XCTAssertNotNil(ImmersiveArtworkMemoryCache.artwork(for: key),
                        "Stored artwork should be retrievable")
    }

    // MARK: - Helpers

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
