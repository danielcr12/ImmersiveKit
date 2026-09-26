# Changelog

All notable changes to ImmersiveKit are documented in this file.

## Unreleased

- `ImmersiveImageBackground` accepts an optional stable `contentID` to retain
  ready artwork and its extracted color while another rendition is processed.
  Source IDs remain revision-specific cache keys. Deletion and changing content
  identity still clear the old artwork.
- Source changes use already-prewarmed artwork immediately without resetting
  the scrolling container or its content state.

## 1.1.0 - 2026-09-20

### Added

- Added `ImmersiveImageSource` as a shared input for single-page rendering,
  paged rendering, and prewarming.
- Added focal-point-aware edge-to-edge image placement without changing source
  image dimensions.

### Changed

- Consolidated shared adaptive background rendering under PrismCore's
  `PrismCoreBackgrounds` product and removed the separate
  `PrismBackgroundFoundation` dependency.
- Set the package baseline to iOS 26 and macOS 26 and removed compatibility
  branches for older scrolling and mesh APIs.

### Fixed

- Image processing now restarts when an asynchronously loaded image becomes
  available under the same stable source ID.
- Preferred presentation colors no longer pollute extracted-color cache entries.
- Placeholder palette caching now includes the base color as well as appearance.

## 1.0.1 - 2026-09-03

### Fixed

- ImmersiveKit now resolves `PrismBackgroundFoundation` from its versioned
  GitHub package so stable Swift Package Manager releases can be consumed
  directly.

## 1.0.0 - 2026-09-03

### Added
- Added Prism adaptive backgrounds that derive light- and dark-mode palettes
  from the preferred or extracted artwork color.
- Added `ImmersiveBackgroundTreatment.prismAdaptive` for artwork-to-mesh
  transitions aligned with PrismCore.
- Added shared hero-boundary geometry so adaptive mesh transitions follow
  stretchy pull-down overscroll.

### Changed
- ImmersiveKit now uses the shared `PrismBackgroundFoundation` rendering and
  palette APIs.
- Refactored image processing, cache keys, cancellation, and background state
  into focused components with expanded test coverage.

## 0.3.0 - 2026-08-30

### Added
- Added explicit, opt-in pagination while keeping `ImmersiveImageBackground` and `ImmersiveArtworkBackground` single-page by default.
- Added `ImmersivePaginationConfiguration` for shared paginated-container behavior.
- Added `ImmersivePagedContainer` for collections whose models already produce complete immersive pages.
- Added `ImmersivePagedImageBackground` for identifiable image-backed pages such as profiles.
- Added `ImmersivePagedArtworkBackground` for identifiable custom SwiftUI artwork pages such as weather cities.
- Added `ImmersiveImagePageConfiguration` to supply each page's artwork, colors, labels, crop, and layout.
- Added `ImmersiveArtworkPageConfiguration` to supply each custom-artwork page's colors, labels, treatment, and layout.
- Programmatic page changes use a configurable animation and respect Reduce Motion.

### Fixed
- Paginated containers now retain every supplied page while presented, preventing processed artwork and local page state from being destroyed during a swipe.
- Interactive selection now commits after paging settles on iOS 18+ and macOS 15+, instead of changing while the user is still scrolling.
- Invalid selections now reconcile to the visible page or the first available page.
- Updated `ImmersiveKit.version` and the tagged-package installation example to
  `0.3.0`.

## 0.2.0 - 2026-07-14

### Changed
- `ImmersiveBackgroundTreatment.placeholderPalette(cacheKey:)` has been renamed to `.placeholderPalette(key:)` to hide caching implementation details from the public API.

### Fixed
- Fixed a prewarm bug where `ImmersiveImagePrewarmer` returned early if any background color was cached, even if the artwork had been evicted. Artwork and color caches are now checked independently.
- Fixed an issue on the AppKit path where `NSColor.getRed` was incorrectly guarded for a `Bool` return value, which caused a compilation error.
- Addressed a redundant double-clamp on `offsetY` scroll tracking.
- Wrapped the raw `ImmersiveScrollSpace` string into a `nonisolated(unsafe) NamedCoordinateSpace` extension, enabling safe typed usage for iOS 17+/macOS 14+ coordinate spaces.

### Refactored
- Extracted magic numbers into dedicated `ImmersiveArtworkTuning` and `ImmersivePlaceholderTuning` enumerations.
- Added comprehensive documentation comments and safety rationales (e.g., `@unchecked Sendable` for `CGImage`).
- Test suite expanded from 1 to 11 tests with full coverage of layouts, cropping, and caching.

## 0.1.0 - 2026-07-14

### Added

- Image-backed immersive SwiftUI backgrounds with square and original-aspect cropping.
- Custom SwiftUI artwork backgrounds for collages and other composed heroes.
- Stretchy overscroll presentation and adaptive scroll-edge behavior.
- Background color extraction, prewarming, and bounded in-memory caching.
- OKLCH-based placeholder palettes.
- Swift 6 strict-concurrency support for iOS 18+ and macOS 14+.
