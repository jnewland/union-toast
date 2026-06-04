//
//  DynamicIslandToastItemModifier.swift
//  UnionToast
//

import SwiftUI

/// Item-based modifier that presents Dynamic Island toasts via ToastController.
///
/// When `item` becomes non-nil, the toast is shown through ``ToastController``.
/// When it dismisses (auto-timer, swipe-up, or external `ToastController.dismiss()`),
/// the binding is reset to nil and `onDismiss` fires.
struct DynamicIslandToastItemModifier<Item, ToastContent: View>: ViewModifier
where Item: Identifiable & Equatable {

    @Binding var item: Item?
    let dismissDelay: Duration?
    let onDismiss: (() -> Void)?

    private let toastContent: (Item) -> ToastContent
    @State private var activeToastID: Item.ID?

    init(
        item: Binding<Item?>,
        dismissDelay: Duration?,
        onDismiss: (() -> Void)?,
        @ViewBuilder toastContent: @escaping (Item) -> ToastContent
    ) {
        self._item = item
        self.dismissDelay = dismissDelay
        self.onDismiss = onDismiss
        self.toastContent = toastContent
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: item) { _, newValue in
                handleItemChange(newValue)
            }
    }

    // MARK: - Item Change Handling

    private func handleItemChange(_ newItem: Item?) {
        guard let newItem else {
            // Binding went nil externally — dismiss any active toast.
            ToastController.dismiss()
            return
        }

        // Skip if this is the same toast we already showed.
        guard activeToastID != newItem.id else { return }

        // Show via ToastController (item-based path handles replacement + duplicate suppression).
        activeToastID = newItem.id

        ToastController.show(
            style: .dynamicIsland,
            item: newItem,
            dismissDelay: dismissDelay,
            onDismiss: { [weak self] in
                guard let self else { return }

                // Only clear the binding if it still points to this item.
                DispatchQueue.main.async {
                    if self.item?.id == newItem.id {
                        self.item = nil
                    }

                    // Clear our tracker regardless.
                    if self.activeToastID == newItem.id {
                        self.activeToastID = nil
                    }

                    // Fire the user callback once.
                    if self.item == nil {
                        self.onDismiss?()
                    }
                }
            },
            content: toastContent
        )
    }
}
