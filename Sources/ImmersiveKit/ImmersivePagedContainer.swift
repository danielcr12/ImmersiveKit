import SwiftUI

/// An opt-in pager that keeps every supplied page alive while the collection is
/// presented.
///
/// Use this container when each model already produces a complete immersive
/// page. Keeping the pages in a non-lazy stack preserves their local image and
/// scroll state while an interactive swipe moves between them.
@MainActor
public struct ImmersivePagedContainer<
    Pages: RandomAccessCollection,
    Page: View
>: View where Pages.Element: Identifiable {
    private let pages: Pages
    @Binding private var selection: Pages.Element.ID
    private let configuration: ImmersivePaginationConfiguration
    private let page: (Pages.Element) -> Page

    @State private var scrollPosition: Pages.Element.ID?
    @State private var pendingInteractiveSelection: Pages.Element.ID?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    public init(
        pages: Pages,
        selection: Binding<Pages.Element.ID>,
        configuration: ImmersivePaginationConfiguration = .standard,
        @ViewBuilder page: @escaping (Pages.Element) -> Page
    ) {
        self.pages = pages
        self._selection = selection
        self.configuration = configuration
        self.page = page
        self._scrollPosition = State(initialValue: selection.wrappedValue)
    }

    public var body: some View {
        phaseTrackedScrollView
    }

    private var phaseTrackedScrollView: some View {
        pagingScrollView
            .onScrollPhaseChange { _, newPhase in
                guard newPhase == .idle else { return }
                commitPendingInteractiveSelection()
            }
    }

    private var pagingScrollView: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(pages) { pageModel in
                    page(pageModel)
                        .containerRelativeFrame(.horizontal)
                        .id(pageModel.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition)
        .onChange(of: selection) { _, newSelection in
            handleSelectionChange(newSelection)
        }
        .onChange(of: scrollPosition) { _, newScrollPosition in
            handleScrollPositionChange(newScrollPosition)
        }
        .onChange(of: pageIDs, initial: true) { _, newPageIDs in
            reconcileSelection(with: newPageIDs)
        }
    }

    private var pageIDs: [Pages.Element.ID] {
        pages.map(\.id)
    }

    private func handleSelectionChange(_ newSelection: Pages.Element.ID) {
        guard pageIDs.contains(newSelection) else {
            reconcileSelection(with: pageIDs)
            return
        }

        updateScrollPosition(to: newSelection)
    }

    private func handleScrollPositionChange(
        _ newScrollPosition: Pages.Element.ID?
    ) {
        pendingInteractiveSelection = newScrollPosition
    }

    private func commitPendingInteractiveSelection() {
        guard
            let pendingInteractiveSelection,
            pageIDs.contains(pendingInteractiveSelection)
        else {
            self.pendingInteractiveSelection = nil
            return
        }

        self.pendingInteractiveSelection = nil

        guard pendingInteractiveSelection != selection else { return }
        selection = pendingInteractiveSelection
    }

    private func reconcileSelection(with pageIDs: [Pages.Element.ID]) {
        guard let resolvedSelection = ImmersivePaginationSelection.resolved(
            selection: selection,
            visiblePageID: scrollPosition,
            pageIDs: pageIDs
        ) else {
            pendingInteractiveSelection = nil
            scrollPosition = nil
            return
        }

        if selection != resolvedSelection {
            selection = resolvedSelection
        }

        updateScrollPosition(to: resolvedSelection)
    }

    private func updateScrollPosition(to pageID: Pages.Element.ID) {
        guard scrollPosition != pageID else { return }

        if accessibilityReduceMotion {
            scrollPosition = pageID
        } else {
            withAnimation(configuration.programmaticSelectionAnimation) {
                scrollPosition = pageID
            }
        }
    }
}
