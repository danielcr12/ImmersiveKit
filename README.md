# ImmersiveKit

ImmersiveKit is a Swift 6 SwiftUI package for image-led, edge-to-edge detail screens on iOS and macOS.

It provides:

- stretchy, overscrolling hero artwork;
- square or original-aspect image presentation;
- asynchronous bottom-edge color extraction;
- bounded in-memory artwork and color caches;
- OKLCH-based placeholder palettes;
- smooth artwork-to-background scrims; and
- modern iOS scroll-edge handling with platform fallbacks.

Application code supplies presentation values—a stable source identifier, optional `CGImage`, optional precomputed background color, placeholder artwork, text, and content. ImmersiveKit does not depend on an application's persistence or image-loading architecture.

## Requirements

- Swift 6.3+
- iOS 18+
- macOS 14+

## Installation

Add ImmersiveKit in Xcode using:

```text
https://github.com/danielcr12/ImmersiveKit.git
```

Or add it to a package manifest:

```swift
.package(
    url: "https://github.com/danielcr12/ImmersiveKit.git",
    from: "0.1.0"
)
```

Then add the `ImmersiveKit` product to your target.

## Image-backed hero

```swift
import ImmersiveKit
import SwiftUI

ImmersiveImageBackground(
    sourceID: photo.revisionID,
    sourceImage: photo.cgImage,
    preferredBackgroundColor: photo.savedBackgroundColor,
    fallbackBackgroundColor: .blue,
    placeholderPaletteKey: "profile",
    title: "Milo",
    subtitle: "Dog"
) {
    Image(systemName: "pawprint.fill")
        .resizable()
        .scaledToFit()
} content: {
    DetailContent()
}
```

Use `ImmersiveArtworkBackground` when the hero is already a SwiftUI view, such as a collage. Use `ImmersiveImagePrewarmer` when an upcoming image-backed screen should have its crop and background color ready before presentation.

## License

ImmersiveKit is available under the MIT License.
