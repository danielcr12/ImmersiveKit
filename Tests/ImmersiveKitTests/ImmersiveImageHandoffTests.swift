import CoreGraphics
import SwiftUI
import XCTest
@testable import ImmersiveKit

@MainActor
final class ImmersiveImageHandoffTests: XCTestCase {
    func testUpgradeKeepsReadyArtworkUntilReplacementIsPrepared() throws {
        let image = try makeImage()
        let old = ImmersiveProcessedImage(image: image, extractedBackgroundColor: .red)
        let state = ImmersiveImageLoadState(requestID: request("thumbnail", image: image), result: old)
        let full = request("full", image: image)
        XCTAssertTrue(state.displayedResult(for: full, cachedResult: nil)?.image === image)

        let replacement = try makeImage()
        let prepared = ImmersiveProcessedImage(image: replacement, extractedBackgroundColor: .blue)
        XCTAssertTrue(state.displayedResult(for: full, cachedResult: prepared)?.image === replacement)
    }

    func testDeletionAndDifferentContentDoNotKeepPreviousArtwork() throws {
        let image = try makeImage()
        let old = ImmersiveProcessedImage(image: image, extractedBackgroundColor: .red)
        let state = ImmersiveImageLoadState(requestID: request("thumbnail", image: image), result: old)
        XCTAssertNil(state.displayedResult(for: request("deleted", image: nil), cachedResult: old))
        XCTAssertNil(state.displayedResult(for: request("full", contentID: "other-pet", image: image), cachedResult: nil))
    }

    func testDefaultIdentityDoesNotRetainAcrossUnrelatedSources() throws {
        let image = try makeImage()
        let state = ImmersiveImageLoadState(
            requestID: request("first", contentID: nil, image: image),
            result: ImmersiveProcessedImage(image: image, extractedBackgroundColor: nil)
        )
        XCTAssertNil(state.displayedResult(for: request("second", contentID: nil, image: image), cachedResult: nil))
    }

    private func request(_ revision: String, contentID: String? = "pet-photo", image: CGImage?) -> ImmersiveImageRequestID {
        ImmersiveImageRequestID(
            cacheKey: ImmersiveArtworkCacheKey(sourceID: revision, crop: .original),
            contentID: contentID,
            sourceImage: image,
            extractsBackgroundColor: true
        )
    }

    private func makeImage() throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try XCTUnwrap(context.makeImage())
    }
}
