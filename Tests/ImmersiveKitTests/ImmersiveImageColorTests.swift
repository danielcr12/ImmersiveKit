import CoreGraphics
import SwiftUI
import XCTest
@testable import ImmersiveKit

@MainActor
final class ImmersiveImageColorTests: XCTestCase {
    func testSolidColorPreservesSRGBComponents() async throws {
        let image = try makeImage(width: 1, height: 1) { context in
            context.setFillColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        let color = try await extract(image)
        assertColor(color, red: 0.8, green: 0.3, blue: 0.1)
    }

    func testMajorityColorWinsOverDifferentBottomEdge() async throws {
        let image = try makeImage { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 30))
        }

        let color = try await extract(image)
        assertColor(color, red: 1, green: 0, blue: 0)
    }

    func testDistinctColorsAreNotMixedIntoAnAbsentHue() async throws {
        let image = try makeImage { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 100))
            context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 100))
        }

        let color = try await extract(image)
        XCTAssertTrue(
            (color.red > 0.99 && color.blue < 0.01)
                || (color.blue > 0.99 && color.red < 0.01),
            "Choose an existing color instead of a purple average."
        )
        XCTAssertEqual(color.green, 0, accuracy: 0.01)
        XCTAssertEqual(color.opacity, 1)
    }

    func testTransparentPaddingDoesNotDarkenTranslucentArtwork() async throws {
        let image = try makeImage(width: 640, height: 320) { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 0.5)
            context.fill(CGRect(x: 240, y: 80, width: 160, height: 160))
        }

        let color = try await extract(image)
        assertColor(color, red: 1, green: 0, blue: 0)
    }

    func testFaintPixelsDoNotOutweighOpaqueSubject() async throws {
        let image = try makeImage { context in
            context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 100))
            context.setFillColor(red: 0, green: 0, blue: 1, alpha: 0.1)
            context.fill(CGRect(x: 20, y: 0, width: 80, height: 100))
        }

        let color = try await extract(image)
        assertColor(color, red: 1, green: 0, blue: 0)
    }

    func testNeutralArtworkStaysNeutral() async throws {
        let image = try makeImage { context in
            context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        let color = try await extract(image)
        assertColor(color, red: 0.5, green: 0.5, blue: 0.5)
    }

    func testFullyTransparentImageFailsExtraction() async throws {
        let image = try makeImage { _ in }
        do {
            _ = try await extract(image)
            XCTFail("No visible pixels should leave the caller's fallback in use.")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
    }

    func testCancelledExtractionDoesNotReturnAColor() async throws {
        let image = try makeImage { _ in }
        let task = Task {
            try await ImmersiveImageProcessing.extractBackgroundColor(from: image)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Cancelled extraction should throw.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    private func extract(_ image: CGImage) async throws -> Color.Resolved {
        let color = try await ImmersiveImageProcessing.extractBackgroundColor(from: image)
        return color.resolve(in: EnvironmentValues())
    }

    private func assertColor(
        _ color: Color.Resolved,
        red: Float,
        green: Float,
        blue: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(color.red, red, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.green, green, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.blue, blue, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.opacity, 1, file: file, line: line)
    }

    private func makeImage(
        width: Int = 100,
        height: Int = 100,
        draw: (CGContext) -> Void
    ) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        draw(context)
        return try XCTUnwrap(context.makeImage())
    }
}
