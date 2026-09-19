import CoreGraphics

/// A normalized point in the source image that should remain visible while
/// edge-to-edge artwork is cropped to fill its hero.
public struct ImmersiveImageFocalPoint: Equatable, Sendable {
    public static let center = ImmersiveImageFocalPoint(x: 0.5, y: 0.5)
    public static let top = ImmersiveImageFocalPoint(x: 0.5, y: 0)
    public static let bottom = ImmersiveImageFocalPoint(x: 0.5, y: 1)

    /// Horizontal position from the source image's leading edge, in `0...1`.
    public let x: CGFloat
    /// Vertical position from the source image's top edge, in `0...1`.
    public let y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}

struct ImmersiveImagePlacement: Equatable {
    let size: CGSize
    let offset: CGSize

    static func filling(
        imageSize: CGSize,
        containerSize: CGSize,
        focalPoint: ImmersiveImageFocalPoint
    ) -> ImmersiveImagePlacement {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return ImmersiveImagePlacement(size: .zero, offset: .zero)
        }

        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let renderedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let horizontalOverflow = max(renderedSize.width - containerSize.width, 0)
        let verticalOverflow = max(renderedSize.height - containerSize.height, 0)

        return ImmersiveImagePlacement(
            size: renderedSize,
            offset: CGSize(
                width: clampedOffset(
                    renderedLength: renderedSize.width,
                    overflow: horizontalOverflow,
                    focalCoordinate: focalPoint.x
                ),
                height: clampedOffset(
                    renderedLength: renderedSize.height,
                    overflow: verticalOverflow,
                    focalCoordinate: focalPoint.y
                )
            )
        )
    }

    private static func clampedOffset(
        renderedLength: CGFloat,
        overflow: CGFloat,
        focalCoordinate: CGFloat
    ) -> CGFloat {
        let desiredOffset = renderedLength * (0.5 - focalCoordinate)
        let maximumOffset = overflow / 2
        return min(max(desiredOffset, -maximumOffset), maximumOffset)
    }
}
