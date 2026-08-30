import SwiftUI

/// Behavior shared by ImmersiveKit's opt-in paginated containers.
///
/// Single-page containers do not use this configuration and remain the default
/// presentation. Pass a pagination configuration only to an
/// ``ImmersivePagedContainer``, ``ImmersivePagedImageBackground``, or
/// ``ImmersivePagedArtworkBackground``.
public struct ImmersivePaginationConfiguration: Sendable {
    public static let standard = ImmersivePaginationConfiguration()

    /// The animation used when the selection binding changes programmatically.
    ///
    /// Interactive swipes remain driven by the user's gesture. ImmersiveKit
    /// automatically disables this animation when Reduce Motion is enabled.
    public let programmaticSelectionAnimation: Animation

    public init(
        programmaticSelectionAnimation: Animation = .smooth(duration: 0.35)
    ) {
        self.programmaticSelectionAnimation = programmaticSelectionAnimation
    }
}
