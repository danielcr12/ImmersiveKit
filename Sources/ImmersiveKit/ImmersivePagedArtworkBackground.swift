import SwiftUI

/// An opt-in horizontally paged collection of custom immersive artwork views.
///
/// Use this container when each page has a composed SwiftUI hero, such as a
/// weather illustration with live effects. Use ``ImmersiveArtworkBackground``
/// directly for the default single-page presentation.
@MainActor
public struct ImmersivePagedArtworkBackground<
    Pages: RandomAccessCollection,
    Artwork: View,
    Content: View
>: View where Pages.Element: Identifiable {
    private let pages: Pages
    @Binding private var selection: Pages.Element.ID
    private let pagination: ImmersivePaginationConfiguration
    private let configuration: (Pages.Element) -> ImmersiveArtworkPageConfiguration
    private let artwork: (Pages.Element) -> Artwork
    private let content: (Pages.Element) -> Content

    public init(
        pages: Pages,
        selection: Binding<Pages.Element.ID>,
        pagination: ImmersivePaginationConfiguration = .standard,
        configuration: @escaping (Pages.Element) -> ImmersiveArtworkPageConfiguration,
        @ViewBuilder artwork: @escaping (Pages.Element) -> Artwork,
        @ViewBuilder content: @escaping (Pages.Element) -> Content
    ) {
        self.pages = pages
        self._selection = selection
        self.pagination = pagination
        self.configuration = configuration
        self.artwork = artwork
        self.content = content
    }

    public var body: some View {
        ImmersivePagedContainer(
            pages: pages,
            selection: $selection,
            configuration: pagination
        ) { page in
            let pageConfiguration = configuration(page)

            ImmersiveArtworkBackground(
                backgroundColor: pageConfiguration.backgroundColor,
                title: pageConfiguration.title,
                subtitle: pageConfiguration.subtitle,
                titleColor: pageConfiguration.titleColor,
                backgroundTreatment: pageConfiguration.backgroundTreatment,
                layout: pageConfiguration.layout
            ) {
                artwork(page)
            } content: {
                content(page)
            }
        }
    }
}
