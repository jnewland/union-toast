//
//  DynamicIslandToastPresenter.swift
//  UnionToast
//

import SwiftUI

/// Type-erased wrapper for Dynamic Island toast content.
/// Used by ``DynamicIslandToastPresenter`` to swap arbitrary view types at runtime.
struct DynamicIslandToastContentWrapper: View {
    @ObservedObject var state: DynamicIslandToastStateObservable
    let onDismiss: () -> Void
    let contentProvider: () -> any View

    var body: some View {
        DynamicIslandToastView(
            isExpanded: $state.isExpanded,
            onDismiss: onDismiss,
            content: { AnyView(contentProvider()) }
        )
    }
}

/// ObservableObject wrapper around DynamicIslandToastState so the presenter's type-erased
/// content can bind to isExpanded for collapse animation.
@MainActor
class DynamicIslandToastStateObservable: ObservableObject {
    @Published var isExpanded: Bool = false
}

/// Manages the UIKit overlay window and presentation lifecycle for Dynamic Island toasts.
///
/// Used by ``ToastController`` when `style: .dynamicIsland` is requested.
/// Owns device detection, overlay window creation, status bar visibility,
/// hittable rect updates, and auto-dismiss scheduling.
@MainActor
final class DynamicIslandToastPresenter {

    private(set) var isPresenting: Bool = false
    private let state = DynamicIslandToastState()
    private var observableState: DynamicIslandToastStateObservable = .init()

    // MARK: - UIKit handles (managed internally)

    private var overlayWindow: PassThroughWindow?
    // Type-erased so we can swap content types at runtime.
    private var hostingController: StatusBarHostingController<DynamicIslandToastContentWrapper>?

    // MARK: - Public API

    /// Shows (or replaces) the Dynamic Island toast.
    func show(
        dismissDelay: Duration,
        onDismiss: @escaping () -> Void,
        content: @escaping () -> any View
    ) {
        if isPresenting {
            updateContent(dismissDelay: dismissDelay, onDismiss: onDismiss, content: content)
            return
        }

        createOverlayWindow(dismissDelay: dismissDelay, onDismiss: onDismiss, content: content)
    }

    /// Dismisses the toast (triggers collapse animation + onDismiss callback).
    func dismiss() {
        guard isPresenting else { return }

        state.collapse()
        observableState.isExpanded = false
        hostingController?.isStatusBarHidden = false
        overlayWindow?.hittableRect = nil

        isPresenting = false
    }

    /// Removes the overlay entirely, destroying all resources.
    func remove() {
        state.collapse()
        observableState.isExpanded = false

        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil

        isPresenting = false
    }

    // MARK: - Window Management

    private func createOverlayWindow(
        dismissDelay: Duration,
        onDismiss: @escaping () -> Void,
        content: @escaping () -> any View
    ) {
        guard let mainWindow = findMainWindow(),
              let windowScene = mainWindow.windowScene else { return }

        let passthroughWindow = PassThroughWindow(windowScene: windowScene)
        configurePassthroughWindow(passthroughWindow, mainWindow: mainWindow)

        let dismissHandler: () -> Void = { [weak self] in
            guard let self else { return }
            state.collapse()
            observableState.isExpanded = false
            passthroughWindow.hittableRect = nil
            isPresenting = false
        }

        let wrapperView = DynamicIslandToastContentWrapper(
            state: observableState,
            onDismiss: { dismissHandler(); onDismiss() },
            contentProvider: content
        )
        let hosting = StatusBarHostingController(rootView: wrapperView)
        hosting.view.backgroundColor = UIColor.clear

        passthroughWindow.rootViewController = hosting
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()

        self.overlayWindow = passthroughWindow
        self.hostingController = hosting

        // Expand immediately.
        isPresenting = true
        state.expand()
        observableState.isExpanded = true
        hosting.isStatusBarHidden = true
        updateHittableRect(window: passthroughWindow, expanded: true)

        // Schedule auto-dismiss.
        scheduleAutoDismiss(delay: dismissDelay, onDismiss: onDismiss)
    }

    private func configurePassthroughWindow(_ window: PassThroughWindow, mainWindow: UIWindow) {
        window.windowLevel = .alert + 10
        window.isHidden = false
        window.isUserInteractionEnabled = true
        window.backgroundColor = .clear

    }

    private func updateContent(
        dismissDelay: Duration,
        onDismiss: @escaping () -> Void,
        content: @escaping () -> any View
    ) {
        guard let hostingController, let overlayWindow else { return }

        // Cancel previous auto-dismiss.
        state.collapse()  // cancels the dismiss task

        let dismissHandler: () -> Void = { [weak self] in
            guard let self else { return }
            state.collapse()
            observableState.isExpanded = false
            hostingController.isStatusBarHidden = false
            overlayWindow.hittableRect = nil
            isPresenting = false
        }

        let wrapperView = DynamicIslandToastContentWrapper(
            state: observableState,
            onDismiss: { dismissHandler(); onDismiss() },
            contentProvider: content
        )
        hostingController.rootView = wrapperView
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        // Re-expand and restart timer.
        state.expand()
        observableState.isExpanded = true
        hostingController.isStatusBarHidden = true

        scheduleAutoDismiss(delay: dismissDelay, onDismiss: onDismiss)
    }

    private func scheduleAutoDismiss(delay: Duration, onDismiss: @escaping () -> Void) {
        state.scheduleDismiss(after: delay) { [weak self] in
            guard let self else { return }

            state.collapse()
            observableState.isExpanded = false
            hostingController?.isStatusBarHidden = false
            overlayWindow?.hittableRect = nil
            isPresenting = false

            onDismiss()
        }
    }

    // MARK: - Helpers

    private func findMainWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?.windows
            .first { $0.isKeyWindow }
        ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first { !$0.isHidden }
    }

    private func updateHittableRect(window: PassThroughWindow, expanded: Bool) {
        if expanded {
            let screenWidth = window.bounds.width
            let safeAreaTop = window.safeAreaInsets.top
            let topOffset: CGFloat = 11 + max((safeAreaTop - 59), 0)
            let expandedWidth = screenWidth - 20

            window.hittableRect = CGRect(
                x: 10,
                y: topOffset,
                width: expandedWidth,
                height: 90
            )
        } else {
            window.hittableRect = nil
        }
    }
}
