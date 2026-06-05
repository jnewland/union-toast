//
//  ToastController.swift
//  union-toast
//
//  Created by Ben Sage on 8/26/25.
//

import SwiftUI
import UIKit
import UnionHaptics

@MainActor
public final class ToastController: NSObject {
    public static let shared = ToastController()

    private var maxTrackedPresentations: Int = 10

    // MARK: - Regular overlay path
    private var sceneDelegate: ToastSceneDelegate?
    private var toastManager: ToastManager?

    // MARK: - Dynamic Island path
    private var dynamicIslandPresenter: DynamicIslandToastPresenter?

    // MARK: - Shared state
    private var currentStyle: ToastStyle? = nil
    private var lastContent: (() -> any View)?
    private var pendingShowTask: Task<Void, Never>?
    private var presentationDismissHandlers: [(id: UUID, handler: () -> Void)] = []

    private var lastPresentedItemEquality: ((Any) -> Bool)?
    private var lastPresentedTimestamps: [AnyHashable: Date] = [:]
    private let duplicateDebounceInterval: TimeInterval = 1.0

    private override init() {
        super.init()
    }

    private func setupToastOverlay() {
        let connectedScenes = UIApplication.shared.connectedScenes

        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
                return
            }

        let delegate = ToastSceneDelegate()
        delegate.configure(with: windowScene)

        self.sceneDelegate = delegate
    }

    /// Presents a toast view immediately (or queues it) using the controller instance.
    /// - Parameters:
    ///   - style: The presentation style (default: .regular).
    ///           On non-Dynamic Island devices, `.dynamicIsland` falls back to regular presentation.
    ///   - dismissDelay: Optional override for the auto-dismiss delay. Defaults to 6.5s (regular) or 3s (Dynamic Island).
    ///   - expandedHeight: Optional expanded height override for `.dynamicIsland` toasts (points). Ignored by `.regular`.
    ///   - content: View builder describing the toast UI.
    public func show<Content: View>(style: ToastStyle = .regular, dismissDelay: Duration? = nil, expandedHeight: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        let resolvedStyle = resolveStyle(style)

        switch resolvedStyle {
        case .regular:
            showRegular(dismissDelay: dismissDelay, content: content)
        case .dynamicIsland:
            showDynamicIsland(dismissDelay: dismissDelay, expandedHeight: expandedHeight, content: content)
        }
    }

    /// Presents a toast that is driven by an identifiable item. Replaces the current toast when a new item arrives.
    /// - Parameters:
    ///   - style: The presentation style (default: .regular).
    ///           On non-Dynamic Island devices, `.dynamicIsland` falls back to regular presentation.
    ///   - item: Identifiable, equatable payload that drives the toast content.
    ///   - dismissDelay: Optional override for the auto-dismiss timing. Defaults to 6.5s (regular) or 3s (Dynamic Island).
    ///   - expandedHeight: Optional expanded height override for `.dynamicIsland` toasts (points). Ignored by `.regular`.
    ///   - onDismiss: Callback invoked when the toast associated with `item` dismisses.
    ///   - content: View builder that renders the toast from the supplied item.
    public func show<Item: Identifiable & Equatable, ToastContent: View>(
        style: ToastStyle = .regular,
        item: Item,
        dismissDelay: Duration? = nil,
        expandedHeight: CGFloat? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        let resolvedStyle = resolveStyle(style)

        switch resolvedStyle {
        case .regular:
            showRegularItem(item: item, dismissDelay: dismissDelay, onDismiss: onDismiss, content: content)
        case .dynamicIsland:
            showDynamicIslandItem(item: item, dismissDelay: dismissDelay, expandedHeight: expandedHeight, onDismiss: onDismiss, content: content)
        }
    }

    /// Dismisses the currently visible toast, if any, without destroying the overlay.
    public func dismiss() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        flushPendingDismissHandlers(preserving: nil)
        clearLastPresentedItem()

        switch currentStyle {
        case .regular, nil:
            toastManager?.dismiss()
        case .dynamicIsland:
            dynamicIslandPresenter?.dismiss()
        }
    }

    /// Removes the overlay window and clears all pending toasts/handlers.
    public func remove() {
        pendingShowTask?.cancel()
        pendingShowTask = nil
        flushPendingDismissHandlers(preserving: nil)

        // Clean up both paths.
        sceneDelegate?.removeOverlay()
        toastManager = nil
        dynamicIslandPresenter?.remove()
        dynamicIslandPresenter = nil

        lastContent = nil
        presentationDismissHandlers.removeAll()
        currentStyle = nil
        clearLastPresentedItem()
        lastPresentedTimestamps.removeAll()
    }
}

// MARK: - Convenience Methods
public extension ToastController {
    /// Presents a toast using the shared controller instance.
    /// - Parameters:
    ///   - style: The presentation style (default: .regular).
    ///           On non-Dynamic Island devices, `.dynamicIsland` falls back to regular presentation.
    ///   - dismissDelay: Optional override for how long the toast remains visible before auto-dismiss.
    ///   - expandedHeight: Optional expanded height override for `.dynamicIsland` toasts (points). Ignored by `.regular`.
    ///   - content: View builder describing the toast's contents.
    static func show<Content: View>(style: ToastStyle = .regular, dismissDelay: Duration? = nil, expandedHeight: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        shared.show(style: style, dismissDelay: dismissDelay, expandedHeight: expandedHeight, content: content)
    }

    /// Presents a toast and plays the supplied haptic feedback before showing it.
    /// - Parameters:
    ///   - dismissDelay: Optional override for the auto-dismiss duration.
    ///   - haptic: Feedback type to play just before the toast appears.
    ///   - content: View builder describing the toast.
    static func showWithHaptic<Content: View>(dismissDelay: Duration? = nil, haptic: SensoryFeedback = .success, @ViewBuilder content: @escaping () -> Content) {
        Haptics.play(haptic)
        Self.show(dismissDelay: dismissDelay, content: content)
    }

    /// Presents a toast driven by an identifiable item. Calling with a new item replaces the existing toast.
    /// - Parameters:
    ///   - style: The presentation style (default: .regular).
    ///           On non-Dynamic Island devices, `.dynamicIsland` falls back to regular presentation.
    ///   - item: Identifiable, equatable value representing the toast payload.
    ///   - dismissDelay: Optional override for how long the toast stays visible.
    ///   - expandedHeight: Optional expanded height override for `.dynamicIsland` toasts (points). Ignored by `.regular`.
    ///   - onDismiss: Closure invoked after the toast tied to `item` dismisses.
    ///   - content: View builder that renders the toast for the supplied item.
    static func show<Item: Identifiable & Equatable, ToastContent: View>(
        style: ToastStyle = .regular,
        item: Item,
        dismissDelay: Duration? = nil,
        expandedHeight: CGFloat? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> ToastContent
    ) {
        shared.show(style: style, item: item, dismissDelay: dismissDelay, expandedHeight: expandedHeight, onDismiss: onDismiss, content: content)
    }

    /// Dismisses the currently presented toast, if any.
    static func dismiss() {
        shared.dismiss()
    }

    /// Removes the overlay window entirely, clearing any pending content and timers.
    static func remove() {
        shared.remove()
    }
}

// MARK: - Private helpers
private extension ToastController {
    func ensureManager(
        dismissDelay: Duration?,
        initialContent: @escaping () -> any View
    ) -> ToastManager? {
        if sceneDelegate == nil {
            setupToastOverlay()
        }

        guard let sceneDelegate = sceneDelegate else {
            return nil
        }

        if toastManager == nil {
            toastManager = sceneDelegate.addOverlay(
                dismissDelay: dismissDelay,
                onDismiss: { [weak self] presentationID in
                    self?.handleManagerDismiss(for: presentationID)
                },
                contentProvider: initialContent
            )
        }

        return toastManager
    }

    func scheduleShow(for manager: ToastManager, onDismiss: (() -> Void)?) {
        pendingShowTask?.cancel()
        pendingShowTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            manager.show()
            flushPendingDismissHandlers(preserving: manager.presentationID)

            if let onDismiss {
                presentationDismissHandlers.append((id: manager.presentationID, handler: onDismiss))
            }

            pendingShowTask = nil
        }
    }

    func handleManagerDismiss(for presentationID: UUID) {
        pendingShowTask?.cancel()
        pendingShowTask = nil

        if let index = presentationDismissHandlers.firstIndex(where: { $0.id == presentationID }) {
            let handler = presentationDismissHandlers.remove(at: index).handler
            handler()
        }

        if toastManager?.isShowing == false {
            lastContent = nil
            clearLastPresentedItem()
        }
    }

    func flushPendingDismissHandlers(preserving activeID: UUID?) {
        let handlersToFlush = presentationDismissHandlers.filter { entry in
            guard let activeID else { return true }
            return entry.id != activeID
        }

        for entry in handlersToFlush {
            entry.handler()
        }

        presentationDismissHandlers.removeAll { entry in
            guard let activeID else { return true }
            return entry.id != activeID
        }
    }

    private func cleanupOldPresentationsIfNeeded() {
        guard presentationDismissHandlers.count > maxTrackedPresentations else { return }

        let keepCount = maxTrackedPresentations / 2
        presentationDismissHandlers.removeFirst(presentationDismissHandlers.count - keepCount)
    }

    private func shouldSkip<Item: Identifiable & Equatable>(item: Item) -> Bool {
        if let equalityCheck = lastPresentedItemEquality, equalityCheck(item) {
            return true
        }

        guard let lastTimestamp = lastPresentedTimestamps[AnyHashable(item.id)] else {
            return false
        }

        if Date().timeIntervalSince(lastTimestamp) < duplicateDebounceInterval {
            return true
        }

        return false
    }

    private func updateLastPresentedItem<Item: Identifiable & Equatable>(_ item: Item) {
        lastPresentedItemEquality = { anyItem in
            guard let typedItem = anyItem as? Item else { return false }
            return typedItem == item
        }
        lastPresentedTimestamps[AnyHashable(item.id)] = Date()
    }

    private func clearLastPresentedItem() {
        lastPresentedItemEquality = nil
    }

    func performReplacement(
        using manager: ToastManager,
        content: @escaping () -> any View,
        onDismiss: (() -> Void)?
    ) {
        manager.enqueueReplacementAction { [weak self] in
            guard let self else { return }
            guard let replacementID = manager.beginReplacement() else {
                return
            }

            self.flushPendingDismissHandlers(preserving: replacementID)

            self.sceneDelegate?.updateOverlayWithPrevious(
                previousContent: self.lastContent ?? content,
                newContent: content,
                replacementID: replacementID
            )

            if let onDismiss {
                self.presentationDismissHandlers.append((id: replacementID, handler: onDismiss))
            }

            self.lastContent = content
        }
    }

    // MARK: - Style Resolution & Routing

    /// Resolves the requested style, falling back to .regular on non-DI devices.
    private func resolveStyle(_ requested: ToastStyle) -> ToastStyle {
        guard case .dynamicIsland = requested else { return requested }
        return hasDynamicIsland() ? .dynamicIsland : .regular
    }

    // MARK: - Regular Path (extracted from original show/show(item:) bodies)

    private func showRegular<Content: View>(dismissDelay: Duration?, content: @escaping () -> Content) {
        // Switch away from Dynamic Island if needed.
        switch currentStyle {
        case .dynamicIsland:
            dynamicIslandPresenter?.remove()
            dynamicIslandPresenter = nil
        default: break
        }
        currentStyle = .regular

        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = { content() }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else { return }

        if manager.isShowing {
            performReplacement(using: manager, content: wrappedContent, onDismiss: nil)
        } else {
            manager.enqueueShowAction { [weak self] in
                guard let self else { return }
                self.flushPendingDismissHandlers(preserving: nil)

                self.sceneDelegate?.updateOverlay(contentProvider: wrappedContent)
                self.lastContent = wrappedContent
                self.scheduleShow(for: manager, onDismiss: nil)
            }
        }
    }

    private func showRegularItem<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration?,
        onDismiss: (() -> Void)?,
        content: @escaping (Item) -> ToastContent
    ) {
        // Switch away from Dynamic Island if needed.
        switch currentStyle {
        case .dynamicIsland:
            dynamicIslandPresenter?.remove()
            dynamicIslandPresenter = nil
        default: break
        }
        currentStyle = .regular

        if shouldSkip(item: item) { return }

        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = { content(item) }

        guard let manager = ensureManager(
            dismissDelay: dismissDelay,
            initialContent: wrappedContent
        ) else { return }

        updateLastPresentedItem(item)

        if manager.isShowing {
            performReplacement(using: manager, content: wrappedContent, onDismiss: onDismiss)
        } else {
            manager.enqueueShowAction { [weak self] in
                guard let self else { return }
                self.flushPendingDismissHandlers(preserving: nil)

                self.sceneDelegate?.updateOverlay(contentProvider: wrappedContent)
                self.lastContent = wrappedContent
                self.scheduleShow(for: manager, onDismiss: onDismiss)
            }
        }
    }

    // MARK: - Dynamic Island Path

    private func showDynamicIsland<Content: View>(dismissDelay: Duration?, expandedHeight: CGFloat? = nil, content: @escaping () -> Content) {
        let delay = dismissDelay ?? .seconds(3)

        // Switch away from regular if needed.
        switch currentStyle {
        case .regular, nil:
            toastManager?.dismiss()
            sceneDelegate?.removeOverlay()
            toastManager = nil
        default: break
        }
        currentStyle = .dynamicIsland

        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = { content() }

        if dynamicIslandPresenter == nil {
            dynamicIslandPresenter = DynamicIslandToastPresenter()
        }

        guard let presenter = dynamicIslandPresenter else { return }

        lastContent = wrappedContent
        flushPendingDismissHandlers(preserving: nil)

        presenter.show(
            dismissDelay: delay,
            onDismiss: { [weak self] in
                guard let self else { return }
                handleDynamicIslandDismiss()
            },
            expandedHeight: expandedHeight,
            content: wrappedContent
        )
    }

    private func showDynamicIslandItem<Item: Identifiable & Equatable, ToastContent: View>(
        item: Item,
        dismissDelay: Duration?,
        expandedHeight: CGFloat? = nil,
        onDismiss: (() -> Void)?,
        content: @escaping (Item) -> ToastContent
    ) {
        let delay = dismissDelay ?? .seconds(3)

        // Switch away from regular if needed.
        switch currentStyle {
        case .regular, nil:
            toastManager?.dismiss()
            sceneDelegate?.removeOverlay()
            toastManager = nil
        default: break
        }
        currentStyle = .dynamicIsland

        if shouldSkip(item: item) { return }

        pendingShowTask?.cancel()
        cleanupOldPresentationsIfNeeded()

        let wrappedContent: () -> any View = { content(item) }

        if dynamicIslandPresenter == nil {
            dynamicIslandPresenter = DynamicIslandToastPresenter()
        }

        guard let presenter = dynamicIslandPresenter else { return }

        updateLastPresentedItem(item)
        lastContent = wrappedContent
        flushPendingDismissHandlers(preserving: nil)

        // Track onDismiss for item-based callback.
        if let onDismiss {
            presentationDismissHandlers.append((id: UUID(), handler: onDismiss))
        }

        presenter.show(
            dismissDelay: delay,
            onDismiss: { [weak self] in
                guard let self else { return }
                handleDynamicIslandDismiss(userCallback: onDismiss)
            },
            expandedHeight: expandedHeight,
            content: wrappedContent
        )
    }

    private func handleDynamicIslandDismiss(userCallback: (() -> Void)? = nil) {
        pendingShowTask?.cancel()
        pendingShowTask = nil

        // Flush all handlers (no active presentation ID to preserve).
        flushPendingDismissHandlers(preserving: nil)

        lastContent = nil
        clearLastPresentedItem()
    }
}
