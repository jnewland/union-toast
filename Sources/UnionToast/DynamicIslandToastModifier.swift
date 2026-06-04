//
//  DynamicIslandToastModifier.swift
//  UnionToast
//

import SwiftUI

// MARK: - Device Detection (shared between modifier and presenter)

func hasDynamicIsland() -> Bool {
    guard let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first
    else { return false }

    let safeAreaTop = windowScene.windows.first?.safeAreaInsets.top ?? 0
    return safeAreaTop >= 59
}

// MARK: - Toast State Manager

@Observable
@MainActor
class DynamicIslandToastState {
    var isExpanded: Bool = false
    var dismissTask: Task<Void, Never>?

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
        dismissTask?.cancel()
        dismissTask = nil
    }

    func scheduleDismiss(after delay: Duration, action: @escaping () -> Void) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

// MARK: - Status Bar Hosting Controller

class StatusBarHostingController<Content: View>: UIHostingController<Content> {
    var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
}

// MARK: - Window Extractor

private struct WindowExtractor: UIViewRepresentable {
    var onWindowFound: (UIWindow) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            if let window = view.window {
                onWindowFound(window)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let window = uiView.window {
                onWindowFound(window)
            }
        }
    }
}

// MARK: - Internal Toast View Wrapper

private struct DynamicIslandToastWrapper<Content: View>: View {
    @Bindable var state: DynamicIslandToastState
    var onDismiss: () -> Void
    let content: () -> Content

    var body: some View {
        DynamicIslandToastView(
            isExpanded: $state.isExpanded,
            onDismiss: onDismiss,
            content: content
        )
    }
}

// MARK: - Dynamic Island Toast Modifier

struct DynamicIslandToastModifier<ToastContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dismissDelay: Duration
    let onDismiss: (() -> Void)?
    let toastContent: () -> ToastContent

    @State private var overlayWindow: PassThroughWindow?
    @State private var overlayController: StatusBarHostingController<DynamicIslandToastWrapper<ToastContent>>?
    @State private var toastState = DynamicIslandToastState()
    @State private var deviceHasDynamicIsland: Bool? = nil

    init(
        isPresented: Binding<Bool>,
        dismissDelay: Duration = .seconds(3),
        onDismiss: (() -> Void)? = nil,
        toastContent: @escaping () -> ToastContent
    ) {
        self._isPresented = isPresented
        self.dismissDelay = dismissDelay
        self.onDismiss = onDismiss
        self.toastContent = toastContent
    }

    func body(content: Content) -> some View {
        if deviceHasDynamicIsland == true {
            content
                .background(WindowExtractor { mainWindow in
                    createOverlayWindow(mainWindow)
                })
                .onChange(of: isPresented) { oldValue, newValue in
                    if newValue {
                        toastState.expand()
                        overlayController?.isStatusBarHidden = true
                        updateHittableRect(expanded: true)
                        toastState.scheduleDismiss(after: dismissDelay) { [self] in
                            isPresented = false
                            onDismiss?()
                        }
                    } else {
                        toastState.collapse()
                        overlayController?.isStatusBarHidden = false
                        updateHittableRect(expanded: false)
                    }
                }
        } else if deviceHasDynamicIsland == false {
            content
                .modifier(ToastModifier(
                    isPresented: $isPresented,
                    dismissDelay: dismissDelay,
                    onDismiss: onDismiss,
                    toastContent: toastContent
                ))
        } else {
            content
                .onAppear {
                    deviceHasDynamicIsland = hasDynamicIsland()
                }
        }
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard overlayWindow == nil,
              let windowScene = mainWindow.windowScene else { return }

        let passthroughWindow = PassThroughWindow(windowScene: windowScene)
        configurePassthroughWindow(passthroughWindow, mainWindow: mainWindow)

        let wrapperView = DynamicIslandToastWrapper(
            state: toastState,
            onDismiss: { [self] in
                toastState.collapse()
                overlayController?.isStatusBarHidden = false
                passthroughWindow.hittableRect = nil
                isPresented = false
                onDismiss?()
            },
            content: toastContent
        )

        let hosting = StatusBarHostingController(rootView: wrapperView)
        hosting.view.backgroundColor = .clear

        passthroughWindow.rootViewController = hosting
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()

        self.overlayWindow = passthroughWindow
        self.overlayController = hosting

        if isPresented {
            toastState.expand()
            hosting.isStatusBarHidden = true
            updateHittableRect(expanded: true)

            toastState.scheduleDismiss(after: dismissDelay) { [self] in
                isPresented = false
                onDismiss?()
            }
        }
    }

    private func configurePassthroughWindow(_ window: PassThroughWindow, mainWindow: UIWindow) {
        window.windowLevel = .alert + 10
        window.isHidden = false
        window.isUserInteractionEnabled = true
        window.backgroundColor = .clear

    }

    private func updateHittableRect(expanded: Bool) {
        guard let window = overlayWindow else { return }

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
