# ImmersiveKit

ImmersiveKit is a Swift 6 SwiftUI package for image-led, edge-to-edge detail screens on iOS and macOS.

It provides:

- stretchy, overscrolling hero artwork;
- square or original-aspect image presentation;
- asynchronous bottom-edge color extraction;
- bounded in-memory artwork and color caches;
- OKLCH-based placeholder palettes;
- light- and dark-mode Prism adaptive artwork backgrounds;
- optional horizontally paged image or custom-artwork backgrounds;
- smooth artwork-to-background scrims; and
- modern iOS scroll-edge handling with platform fallbacks.

ImmersiveKit uses the versioned
[PrismBackgroundFoundation](https://github.com/danielcr12/PrismBackgroundFoundation)
package for shared adaptive background construction and
[OKLCHKit](https://github.com/danielcr12/OKLCHKit) for perceptual color
rendering.

Application code supplies presentation values—a stable source identifier, optional `CGImage`, optional precomputed background color, placeholder artwork, text, and content. ImmersiveKit does not depend on an application's persistence or image-loading architecture.

## Requirements

- Swift 6.3+
- iOS 18+
- macOS 14+

## Installation

### Local development

Harmony Weather currently adds ImmersiveKit as a local package at
`../immersiveKit`. Xcode compiles the source in this checkout directly, so local
ImmersiveKit changes are available to the app on its next compilation. A Git tag,
package version bump, or package-cache reset is not required for local package
changes.

In Xcode, use **File > Add Package Dependencies > Add Local** and select the
`immersiveKit` folder. In a project file, the equivalent reference is:

```text
../immersiveKit
```

### Tagged releases

For a tagged release, add ImmersiveKit in Xcode using:

```text
https://github.com/danielcr12/ImmersiveKit.git
```

Or add it to a package manifest:

```swift
.package(
    url: "https://github.com/danielcr12/ImmersiveKit.git",
    from: "1.0.1"
)
```

Then add the `ImmersiveKit` product to your target. Unreleased APIs in the local
checkout are not available through the remote dependency until they are included
in a new Git tag.

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

`ImmersiveImageBackground` and `ImmersiveArtworkBackground` are always
single-page. They do not create paging state, gestures, indicators, or
instructional text. Use `ImmersiveArtworkBackground` when the hero is already a
SwiftUI view, such as a collage. Use `ImmersiveImagePrewarmer` when an upcoming
image-backed screen should have its crop and background color ready before
presentation.

## Opt-in pagination

Pagination is a separate, explicit presentation for identifiable collections.
Use `ImmersivePagedImageBackground` for image-backed pages such as profiles, or
`ImmersivePagedArtworkBackground` for composed SwiftUI heroes such as Harmony
Weather's city artwork. If each model already creates a complete immersive page,
use `ImmersivePagedContainer`. All three use
`ImmersivePaginationConfiguration`; none adds page dots, duplicate labels, or
swipe-instruction UI.

Paginated containers intentionally keep their supplied pages alive while
presented. This preserves processed artwork, local scroll position, and other
page state during an interactive transition instead of recreating a placeholder
as a page moves on or off screen.

> The pagination API is available in the `0.3.0` tagged release.

### Image-backed profile pages

```swift
@State private var selectedProfileID = profiles[0].id

ImmersivePagedImageBackground(
    pages: profiles,
    selection: $selectedProfileID,
    pagination: .init(
        programmaticSelectionAnimation: .smooth(duration: 0.35)
    )
) { profile in
    ImmersiveImagePageConfiguration(
        sourceID: profile.photoRevision,
        sourceImage: profile.photo,
        fallbackBackgroundColor: profile.themeColor,
        placeholderPaletteKey: "profile-\(profile.id)",
        title: profile.name,
        subtitle: profile.subtitle
    )
} placeholder: { profile in
    Image(systemName: profile.placeholderSymbol)
        .resizable()
        .scaledToFit()
} content: { profile in
    ProfileDetails(profile: profile)
}
```

### Harmony Weather city pages

```swift
@State private var selectedCityID = cities[0].id

ImmersivePagedContainer(
    pages: cities,
    selection: $selectedCityID
) { city in
    CityImmersivePage(city: city)
}
```

The selection binding follows the settled page on iOS 18+ and macOS 15+.
macOS 14 uses the current visible page because settled scroll-phase observation
is not available there. Programmatic selection uses the animation from
`ImmersivePaginationConfiguration`, and Reduce Motion is respected
automatically. Image-backed pages should use a revision-aware `sourceID` when
their image can change without their model ID changing.

## License

ImmersiveKit is available under the MIT License.
