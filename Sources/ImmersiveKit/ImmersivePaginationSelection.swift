enum ImmersivePaginationSelection {
    static func resolved<ID: Hashable>(
        selection: ID,
        visiblePageID: ID?,
        pageIDs: [ID]
    ) -> ID? {
        guard let firstPageID = pageIDs.first else { return nil }

        if pageIDs.contains(selection) {
            return selection
        }

        if let visiblePageID, pageIDs.contains(visiblePageID) {
            return visiblePageID
        }

        return firstPageID
    }
}
