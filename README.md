# ImmersiveKit

ImmersiveKit is a Swift 6 SwiftUI package for image-led, edge-to-edge detail screens on iOS and macOS.

It provides:

- stretchy, overscrolling hero artwork;
- square or original-aspect image presentation;
- asynchronous prominent-color extraction across the image, weighted by opacity;
- bounded in-memory artwork and color caches;
- OKLCH-based placeholder palettes;
- light- and dark-mode Prism adaptive artwork backgrounds;
- optional horizontally paged image or custom-artwork backgrounds;
- smooth artwork-to-background scrims; and
- modern iOS scroll-edge handling with platform fallbacks.

ImmersiveKit uses the `PrismCoreBackgrounds` product from the
[PrismCore](https://github.com/danielcr12/PrismCore) package for shared adaptive
background construction and
[OKLCHKit](https://github.com/danielcr12/OKLCHKit) for perceptual color
rendering.

Application code supplies presentation values—a stable source identifier, optional `CGImage`, optional precomputed background color, placeholder artwork, text, and content. ImmersiveKit does not depend on an application's persistence or image-loading architecture.

## Requirements

- Swift 6.3+
- iOS 26+
- macOS 26+

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
    from: "1.1.0"
)
```

Then add the `ImmersiveKit` product to your target. Unreleased APIs in the local
checkout are not available through the remote dependency until they are included
in a new Git tag.

## Image-backed hero

```swift
import ImmersiveKit
import SwiftUI

let source = ImmersiveImageSource(
    id: photo.revisionID,
    image: photo.cgImage,
    preferredBackgroundColor: photo.savedBackgroundColor
)

ImmersiveImageBackground(
    source: source,
    fallbackBackgroundColor: .blue,
    crop: .original,
    focalPoint: .init(x: 0.5, y: 0.35),
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

The same `ImmersiveImageSource` can be passed to
`ImmersiveImagePrewarmer.prewarm(source:)` and to an
`ImmersiveImagePageConfiguration`. The source ID becomes the placeholder palette
identity unless a separate key is needed.

Image-backed heroes fill the hero edge to edge while preserving the source
aspect ratio. Use `focalPoint` to identify the pet or other subject that
should remain visible as the hero changes aspect ratio. Coordinates are
normalized from the source image's top-leading corner; `.center`, `.top`, and
`.bottom` are provided for common cases. Pass `crop: .square` only when the
source itself should be center-cropped before presentation.

`ImmersiveImageBackground` and `ImmersiveArtworkBackground` are always
single-page. They do not create paging state, gestures, indicators, or
instructional text. Use `ImmersiveArtworkBackground` when the hero is already a
SwiftUI view, such as a collage. Use `ImmersiveImagePrewarmer` when an upcoming
image-backed screen should have its crop and background color ready before
presentation.

## Asset, symbol, and emoji artwork

Use `ImmersiveArtwork` when the hero artwork comes from an image asset, SF
Symbol, or emoji. It keeps asset images in SwiftUI's image rendering path, so
vector assets are not rasterized into a `CGImage` before scaling. Asset and
image artwork fill the entire hero by default, preserving proportions and
cropping overflow just like photo heroes, regardless of intrinsic dimensions.
Symbols and emoji use a centered inset region. Pass `contentMode: .fit` for an
asset or image that should remain entirely visible within that inset region.

Asset and image artwork automatically fade at their lower edge into the hero
background, using the same gradient as photo heroes. Filled artwork fades at
the visible hero edge; fitted artwork fades at its own lower edge so
illustrations do not end in a hard horizontal edge.
Symbols and emoji remain fully visible by default. Pass `blending: .none` to
keep an illustration intact, or `blending: .bottomFade` to request the fade
explicitly for any source.

Pass `scale: 1.25` to enlarge the artwork by 25% within the hero, or
`scale: 0.85` to ease the zoom by 15%. Filled images keep the full hero viewport
while their artwork scales inside it. Smaller artwork can reveal the background
around its edges. Hero height and title placement stay unchanged; artwork
extending beyond the hero is clipped.

```swift
ImmersiveArtworkBackground(
    backgroundColor: .blue,
    title: "New in PawFolio",
    subtitle: "Version 1.0"
) {
    ImmersiveArtwork(asset: "pawfolio-unlimited")
} content: {
    ReleaseNotes()
}
```

Use `ImmersiveArtwork(symbol: "pawprint.fill")` for an SF Symbol or
`ImmersiveArtwork(emoji: "🐾")` for emoji. Use `ImmersiveArtwork(image:)` when
you already have a SwiftUI `Image`; use the existing artwork closure for other
composed SwiftUI views. An opaque `Image` does not reveal whether it came from
a vector or bitmap asset, so pass asset names through `ImmersiveArtwork(asset:)`
to preserve the source representation.

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
        source: ImmersiveImageSource(
            id: profile.photoRevision,
            image: profile.photo
        ),
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

The selection binding follows the settled page on iOS 26 and macOS 26.
Programmatic selection uses the animation from
`ImmersivePaginationConfiguration`, and Reduce Motion is respected
automatically. Image-backed pages should use a revision-aware `sourceID` when
their image can change without their model ID changing.

## License

ImmersiveKit is available under the MIT License.
