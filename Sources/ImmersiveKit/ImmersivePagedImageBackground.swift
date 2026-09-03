import SwiftUI

/// An opt-in horizontally paged collection of immersive image backgrounds.
///
/// Use this container for image-backed collections such as profiles. Use
/// ``ImmersiveImageBackground`` directly for the default single-page
/// presentation.
@MainActor
public struct ImmersivePagedImageBackground<
    Pages: RandomAccessCollection,
    Placeholder: View,
    Content: View
>: View where Pages.Element: Identifiable {
    private let pages: Pages
    @Binding private var selection: Pages.Element.ID
    private let pagination: ImmersivePaginationConfiguration
    private let configuration: (Pages.Element) -> ImmersiveImagePageConfiguration
    private let placeholder: (Pages.Element) -> Placeholder
    private let content: (Pages.Element) -> Content

    public init(
        pages: Pages,
        selection: Binding<Pages.Element.ID>,
        pagination: ImmersivePaginationConfiguration = .standard,
        configuration: @escaping (Pages.Element) -> ImmersiveImagePageConfiguration,
        @ViewBuilder placeholder: @escaping (Pages.Element) -> Placeholder,
        @ViewBuilder content: @escaping (Pages.Element) -> Content
    ) {
        self.pages = pages
        self._selection = selection
        self.pagination = pagination
        self.configuration = configuration
        self.placeholder = placeholder
        self.content = content
    }

    public var body: some View {
        ImmersivePagedContainer(
            pages: pages,
            selection: $selection,
            configuration: pagination
        ) { page in
            let pageConfiguration = configuration(page)

            ImmersiveImageBackground(
                sourceID: pageConfiguration.sourceID,
                sourceImage: pageConfiguration.sourceImage,
                preferredBackgroundColor: pageConfiguration.preferredBackgroundColor,
                fallbackBackgroundColor: pageConfiguration.fallbackBackgroundColor,
                placeholderPaletteKey: pageConfiguration.placeholderPaletteKey,
                placeholderSymbolColor: pageConfiguration.placeholderSymbolColor,
                placeholderArtworkStyle: pageConfiguration.placeholderArtworkStyle,
                showsPlaceholder: pageConfiguration.showsPlaceholder,
                crop: pageConfiguration.crop,
                title: pageConfiguration.title,
                subtitle: pageConfiguration.subtitle,
                layout: pageConfiguration.layout
            ) {
                placeholder(page)
            } content: {
                content(page)
            }
        }
    }
}
