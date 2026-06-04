//
//  EnvironmentValues+Toast.swift
//  UnionToast
//

import SwiftUI

/// The resolved presentation style of the surrounding toast.
///
/// - `.regular` — standard overlay toast (follows app color scheme)
/// - `.dynamicIsland` — Dynamic Island presentation (forced dark environment for content legibility)
///
/// Use this to branch on the actual presentation style when your view needs different layout, copy, or icons
/// depending on how it's being rendered. The value reflects the *resolved* style — if you request
/// `.dynamicIsland` on a non-Dynamic-Island device, this will be `.regular`.
public extension EnvironmentValues {

    var toastPresentationStyle: ToastStyle {
        get { self[ToastPresentationStyleKey.self] }
        set { self[ToastPresentationStyleKey.self] = newValue }
    }
}

private struct ToastPresentationStyleKey: EnvironmentKey {
    static let defaultValue: ToastStyle = .regular
}
