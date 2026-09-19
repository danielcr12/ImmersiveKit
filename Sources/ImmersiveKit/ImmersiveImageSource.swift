import CoreGraphics
import SwiftUI

/// Image data and stable identity used by ImmersiveKit's processing pipeline.
///
/// Keep `id` stable while the image represents the same content. Change it when
/// the underlying image is replaced so cached artwork and colors remain correct.
public struct ImmersiveImageSource {
    public let id: String
    public let image: CGImage?
    public let preferredBackgroundColor: Color?

    public init(
        id: String,
        image: CGImage?,
        preferredBackgroundColor: Color? = nil
    ) {
        self.id = id
        self.image = image
        self.preferredBackgroundColor = preferredBackgroundColor
    }
}
