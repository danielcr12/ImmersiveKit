import CoreGraphics
import SwiftUI
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

    // MARK: - Immersive image presentation

    func testFocalPointClampsToNormalizedCoordinates() {
        let focalPoint = ImmersiveImageFocalPoint(x: -0.5, y: 1.5)

        XCTAssertEqual(focalPoint.x, 0)
        XCTAssertEqual(focalPoint.y, 1)
    }

    func testFillPlacementPreservesImageAspectRatio() {
        let placement = ImmersiveImagePlacement.filling(
            imageSize: CGSize(width: 200, height: 100),
            containerSize: CGSize(width: 100, height: 100),
            focalPoint: .center
        )

        XCTAssertEqual(placement.size, CGSize(width: 200, height: 100))
        XCTAssertEqual(placement.offset, .zero)
    }

    func testLeadingFocalPointKeepsLeadingImageEdgeVisible() {
        let placement = ImmersiveImagePlacement.filling(
            imageSize: CGSize(width: 200, height: 100),
            containerSize: CGSize(width: 100, height: 100),
            focalPoint: ImmersiveImageFocalPoint(x: 0, y: 0.5)
        )

        XCTAssertEqual(placement.offset.width, 50)
        XCTAssertEqual(placement.offset.height, 0)
    }

    func testBottomFocalPointKeepsBottomImageEdgeVisible() {
        let placement = ImmersiveImagePlacement.filling(
            imageSize: CGSize(width: 100, height: 200),
            containerSize: CGSize(width: 100, height: 100),
            focalPoint: .bottom
        )

        XCTAssertEqual(placement.offset.width, 0)
        XCTAssertEqual(placement.offset.height, -50)
    }

    func testFillPlacementHandlesInvalidGeometry() {
        let placement = ImmersiveImagePlacement.filling(
            imageSize: .zero,
            containerSize: CGSize(width: 100, height: 100),
            focalPoint: .center
        )

        XCTAssertEqual(placement.size, .zero)
        XCTAssertEqual(placement.offset, .zero)
    }

    // MARK: - ImmersiveBackgroundGeometry

    func testAdaptiveMeshStartsAtHeroBoundary() {
        XCTAssertEqual(
            ImmersiveBackgroundGeometry.adaptiveMeshStartOffset(
                heroHeight: 440,
                heroOverscroll: 0,
                containerHeight: 800
            ),
            440
        )
    }

    func testAdaptiveMeshStartFollowsHeroOverscroll() {
        XCTAssertEqual(
            ImmersiveBackgroundGeometry.adaptiveMeshStartOffset(
                heroHeight: 440,
                heroOverscroll: 80,
                containerHeight: 800
            ),
            520
        )
    }

    func testAdaptiveMeshStartClampsToContainer() {
        XCTAssertEqual(
            ImmersiveBackgroundGeometry.adaptiveMeshStartOffset(
                heroHeight: 800,
                heroOverscroll: 80,
                containerHeight: 800
            ),
            800
        )
        XCTAssertEqual(
            ImmersiveBackgroundGeometry.adaptiveMeshStartOffset(
                heroHeight: 440,
                heroOverscroll: 0,
                containerHeight: 0
            ),
            0
        )
    }

    // MARK: - ImmersivePaginationSelection

    func testPaginationKeepsValidSelection() {
        let result = ImmersivePaginationSelection.resolved(
            selection: "b",
            visiblePageID: "a",
            pageIDs: ["a", "b", "c"]
        )
        XCTAssertEqual(result, "b")
    }

    func testPaginationRepairsInvalidSelectionToVisiblePage() {
        let result = ImmersivePaginationSelection.resolved(
            selection: "missing",
            visiblePageID: "b",
            pageIDs: ["a", "b", "c"]
        )
        XCTAssertEqual(result, "b")
    }

    func testPaginationRepairsInvalidSelectionToFirstPage() {
        let result = ImmersivePaginationSelection.resolved(
            selection: "missing",
            visiblePageID: nil,
            pageIDs: ["a", "b", "c"]
        )
        XCTAssertEqual(result, "a")
    }

    func testPaginationReturnsNilForEmptyPages() {
        let result = ImmersivePaginationSelection.resolved(
            selection: "missing",
            visiblePageID: nil,
            pageIDs: [String]()
        )
        XCTAssertNil(result)
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

    func testCropAsyncSquareCropsImageOffTheSynchronousPath() async {
        guard let source = makeCGImage(width: 200, height: 100) else {
            return XCTFail("Could not create test CGImage")
        }
        let result = await ImmersiveImageProcessing.crop(source, crop: .square)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    @MainActor
    func testCancelledCropDoesNotProduceAStaleResult() async {
        guard let source = makeCGImage(width: 200, height: 100) else {
            return XCTFail("Could not create test CGImage")
        }

        let task = Task { () -> CGImage? in
            await Task.yield()
            return await ImmersiveImageProcessing.crop(source, crop: .square)
        }
        task.cancel()

        let result = await task.value
        XCTAssertNil(result)
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
