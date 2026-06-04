//
//  View+DynamicIslandSafeArea.swift
//  UnionToast
//

import SwiftUI

public extension View {
    /// Pads content down to clear the Dynamic Island cutout. No-op off the island.
    ///
    /// Use this modifier on full-width custom toast content to prevent it from being
    /// occluded by the physical Dynamic Island cutout at top-center. When rendered on a
    /// non-Dynamic-Island device the modifier is a no-op (`topClearance == 0`).
    ///
    /// For finer control, read `@Environment(\.toastIslandGuide)` directly and lay out
    /// content around ``ToastIslandGuide/cutout``.
    func dynamicIslandSafeArea() -> some View {
        modifier(DynamicIslandSafeAreaModifier())
    }
}

private struct DynamicIslandSafeAreaModifier: ViewModifier {
    @Environment(\.toastIslandGuide) private var guide

    func body(content: Content) -> some View {
        content.padding(.top, guide.topClearance)
    }
}
