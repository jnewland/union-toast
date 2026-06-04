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

// MARK: - Island Guide

/// Describes the Dynamic Island cutout that occludes toast content, so custom views
/// can lay out around it. All zero / `hasPhysicalIsland == false` off the island.
public struct ToastIslandGuide: Equatable, Sendable {
    /// Whether a physical Dynamic Island is present (false on notch/fallback devices).
    public var hasPhysicalIsland: Bool
    /// The occluded cutout region, in the toast content's coordinate space.
    public var cutout: CGRect
    /// How far full-width content must move down to fully clear the cutout (0 when none).
    public var topClearance: CGFloat { hasPhysicalIsland ? cutout.maxY : 0 }

    public init(hasPhysicalIsland: Bool = false, cutout: CGRect = .zero) {
        self.hasPhysicalIsland = hasPhysicalIsland
        self.cutout = cutout
    }
}

public extension EnvironmentValues {
    var toastIslandGuide: ToastIslandGuide {
        get { self[ToastIslandGuideKey.self] }
        set { self[ToastIslandGuideKey.self] = newValue }
    }
}

private struct ToastPresentationStyleKey: EnvironmentKey {
    static let defaultValue: ToastStyle = .regular
}

private struct ToastIslandGuideKey: EnvironmentKey {
    static let defaultValue = ToastIslandGuide()
}
