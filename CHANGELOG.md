# Changelog

All notable changes to ImmersiveKit are documented in this file.

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
