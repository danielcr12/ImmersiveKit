import XCTest
@testable import ImmersiveKit

final class ImmersiveKitTests: XCTestCase {
    func testStandardLayoutMatchesDefaultHeroTuning() {
        XCTAssertEqual(ImmersiveArtworkLayout.standard.heroHeightRatio, 0.58)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.minimumHeroHeight, 440)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.titleLineLimit, 1)
        XCTAssertEqual(ImmersiveArtworkLayout.standard.subtitleLineLimit, 1)
    }
}
