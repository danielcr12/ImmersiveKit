import SwiftUI

/// Presentation values for one page in an
/// ``ImmersivePagedArtworkBackground``.
public struct ImmersiveArtworkPageConfiguration {
    public let backgroundColor: Color
    public let title: String
    public let subtitle: String
    public let titleColor: Color
    public let backgroundTreatment: ImmersiveBackgroundTreatment
    public let layout: ImmersiveArtworkLayout

    public init(
        backgroundColor: Color,
        title: String,
        subtitle: String,
        titleColor: Color = .primary,
        backgroundTreatment: ImmersiveBackgroundTreatment = .exact,
        layout: ImmersiveArtworkLayout = .standard
    ) {
        self.backgroundColor = backgroundColor
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.backgroundTreatment = backgroundTreatment
        self.layout = layout
    }
}
