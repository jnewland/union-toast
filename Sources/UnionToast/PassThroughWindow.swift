//
//  PassThroughWindow.swift
//  UnionToast
//
//  Created by Ben Sage on 8/24/25.
//

import UIKit
import SwiftUI

class PassThroughWindow: UIWindow {
    /// Optional rect where hits should be intercepted instead of passed through.
    /// Used by Dynamic Island toasts to define the interactive area.
    var hittableRect: CGRect?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        // If we have a defined hittable rect, only intercept hits inside it.
        // Taps outside the toast area must pass through to windows below (toolbar, nav bar).
        if let rect = hittableRect {
            return rect.contains(point) ? hitView : nil
        }

        // No hittable rect — if something other than the bare root view was hit, return it.
        // This preserves normal behaviour when no toast is active (e.g. compact Dynamic Island capsule).
        if hitView !== rootView {
            return hitView
        }

        // Fallback: check subviews explicitly (for edge cases where super.hitTest returns root)
        for subview in rootView.subviews.reversed() {
            let pointInSubview = subview.convert(point, from: rootView)
            if subview.hitTest(pointInSubview, with: event) != nil {
                return hitView
            }
        }
        return nil
    }
}


