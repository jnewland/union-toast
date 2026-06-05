//
//  _ToastExample.swift
//  UnionToast
//
//  Created by Union on 1/8/26.
//

import SwiftUI

/// A comprehensive example view demonstrating all UnionToast features.
///
/// Use this view to test and explore the toast notification system including:
/// - Boolean-based toast presentation
/// - Item-based toast presentation with automatic replacement
/// - Imperative ToastController API
/// - Custom backgrounds and styling
/// - Haptic feedback integration
public struct _ToastExample: View {
    // MARK: - Boolean-based toast state
    @State private var showBasicToast = false
    @State private var showCustomDelayToast = false

    // MARK: - Item-based toast state
    @State private var activeToast: ExampleToast?

    // MARK: - Background examples
    @State private var showTintedToast = false
    @State private var showCustomBackgroundToast = false

    // MARK: - Dynamic Island toast state
    @State private var showDynamicIslandToast = false

    // MARK: - Item-based Dynamic Island state (modifier-driven)
    @State private var activeDIToast: ExampleToast?

    // MARK: - Controller-driven item-based DI state
    @State private var diItemToast = ExampleDIToast(id: UUID(), title: "", icon: "")

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                booleanBasedSection
                itemBasedSection
                controllerSection
                backgroundSection
                dynamicIslandSection
            }
            .navigationTitle("Toast Examples")
        }
        .toast(isPresented: $showBasicToast) {
            Label("Basic Toast", systemImage: "bell.fill")
        }
        .toast(isPresented: $showCustomDelayToast, dismissDelay: .seconds(2)) {
            Label("Quick Toast (2s)", systemImage: "hare.fill")
        }
        .toast(item: $activeToast) { toast in
            Label(toast.title, systemImage: toast.icon)
                .foregroundStyle(toast.color)
        }
        // Item-based modifier with Dynamic Island style (separate binding to avoid conflicts)
        .toast(item: $activeDIToast, style: .dynamicIsland) { toast in
            Label(toast.title, systemImage: toast.icon)
        }
        .toast(isPresented: $showTintedToast) {
            Label("Tinted Background", systemImage: "paintpalette.fill")
                .toastBackground(.blue)
        }
        .toast(isPresented: $showCustomBackgroundToast) {
            Label("Custom Background", systemImage: "square.fill")
                .toastBackground {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.linearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
        }
        .toast(isPresented: $showDynamicIslandToast, style: .dynamicIsland) {
            Label("Dynamic Island Toast!", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
        }
    }

    // MARK: - Sections

    private var booleanBasedSection: some View {
        Section {
            Button("Show Basic Toast") {
                showBasicToast = true
            }

            Button("Show Quick Toast (2s delay)") {
                showCustomDelayToast = true
            }
        } header: {
            Text("Boolean-Based Presentation")
        } footer: {
            Text("Uses .toast(isPresented:) modifier with a binding.")
        }
    }

    private var itemBasedSection: some View {
        Section {
            Button("Success Toast") {
                activeToast = ExampleToast(
                    title: "Success!",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }

            Button("Error Toast") {
                activeToast = ExampleToast(
                    title: "Error occurred",
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }

            Button("Warning Toast") {
                activeToast = ExampleToast(
                    title: "Warning",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )
            }

            Button("Info Toast") {
                activeToast = ExampleToast(
                    title: "Information",
                    icon: "info.circle.fill",
                    color: .blue
                )
            }
        } header: {
            Text("Item-Based Presentation")
        } footer: {
            Text("Uses .toast(item:) modifier. New items automatically replace the current toast with choreographed animation.")
        }
    }

    private var controllerSection: some View {
        Section {
            Button("Show via Controller") {
                ToastController.show {
                    Label("Controller Toast", systemImage: "gearshape.fill")
                }
            }

            Button("Show with Haptic (Success)") {
                ToastController.showWithHaptic(haptic: .success) {
                    Label("Success with Haptic", systemImage: "hand.thumbsup.fill")
                }
            }

            Button("Show with Haptic (Warning)") {
                ToastController.showWithHaptic(haptic: .warning) {
                    Label("Warning with Haptic", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Button("Show with Haptic (Error)") {
                ToastController.showWithHaptic(haptic: .error) {
                    Label("Error with Haptic", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }

            Button("Show Long Duration (10s)") {
                ToastController.show(dismissDelay: .seconds(10)) {
                    Label("Long Toast (10s)", systemImage: "clock.fill")
                }
            }

            Button("Dismiss Current Toast", role: .destructive) {
                ToastController.dismiss()
            }
        } header: {
            Text("ToastController (Imperative)")
        } footer: {
            Text("Use ToastController.show() for programmatic toast presentation from anywhere in your app.")
        }
    }

    private var backgroundSection: some View {
        Section {
            Button("Tinted Background (Blue)") {
                showTintedToast = true
            }

            Button("Custom Gradient Background") {
                showCustomBackgroundToast = true
            }

            Button("Material Background via Controller") {
                ToastController.show {
                    Label("Thin Material", systemImage: "rectangle.fill")
                        .toastBackground(.thinMaterial)
                }
            }
        } header: {
            Text("Custom Backgrounds")
        } footer: {
            Text("Customize toast appearance with .toastBackground() modifier.")
        }
    }

    // MARK: - Dynamic Island Examples

    private var dynamicIslandSection: some View {
        Section {
            // MARK: Modifier-driven
            Button("Modifier (Boolean Binding)") {
                showDynamicIslandToast = true
            }

            Button("Modifier (Item-Based, DI Style)") {
                activeDIToast = ExampleToast(
                    title: "Item + Dynamic Island",
                    icon: "star.fill",
                    color: .yellow
                )
            }

            Divider()

            // MARK: Controller-driven — basic content
            Button("Controller (Default, 3s)") {
                ToastController.show(style: .dynamicIsland) {
                    Label("Copied to clipboard", systemImage: "doc.on.doc.fill")
                }
            }

            Button("Controller (Custom Delay, 8s)") {
                ToastController.show(style: .dynamicIsland, dismissDelay: .seconds(8)) {
                    Label("Long-running task", systemImage: "hourglass")
                }
            }

            // MARK: Custom view — semantic colors + explicit style branching
            Button("Controller (Custom View, Semantic Colors)") {
                ToastController.show(style: .dynamicIsland) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Upload complete")
                                .fontWeight(.semibold)
                        }
                        Text("3 files synced to cloud")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Controller (Reads toastPresentationStyle)") {
                ToastController.show(style: .dynamicIsland) {
                    AdaptiveToastContent(title: "Adaptive Toast", icon: "lightbulb.fill")
                }
            }

            // MARK: Custom view — island cutout avoidance
            Button("Controller (Custom View + .dynamicIslandSafeArea())") {
                ToastController.show(style: .dynamicIsland) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.cyan)
                            Text("Photos uploaded")
                                .fontWeight(.semibold)
                        }
                        Text("12 photos added to shared album")
                            .foregroundStyle(.secondary)
                        ProgressView(value: 1.0)
                    }
                    .dynamicIslandSafeArea()
                }
            }

            Button("Controller (Split Around Cutout)") {
                ToastController.show(style: .dynamicIsland) {
                    SplitAroundCutoutView()
                }
            }

            Button("Controller (Tall, expandedHeight: 160)") {
                ToastController.show(style: .dynamicIsland, expandedHeight: 160) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.orange)
                            Text("Build finished")
                                .fontWeight(.semibold)
                        }
                        .dynamicIslandSafeArea()
                        Text("UnionToast compiled for iOS Simulator with 0 errors and 2 warnings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ProgressView(value: 1.0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                }
            }

            Divider()

            // MARK: Controller-driven — item-based (replacement + duplicate suppression)
            Button("Controller Item #1") {
                ToastController.show(style: .dynamicIsland, item: diItemToast) { toast in
                    Label(toast.title, systemImage: toast.icon)
                }
            }

            Button("Controller Item #2 (replaces #1)") {
                diItemToast = ExampleDIToast(id: UUID(), title: "Replaced!", icon: "arrow.triangle.2.circlepath")
                ToastController.show(style: .dynamicIsland, item: diItemToast) { toast in
                    Label(toast.title, systemImage: toast.icon)
                }
            }

            Button("Rapid Fire (3 replacements in 1s)") {
                let items = [
                    ExampleDIToast(id: UUID(), title: "One", icon: "1.circle.fill"),
                    ExampleDIToast(id: UUID(), title: "Two", icon: "2.circle.fill"),
                    ExampleDIToast(id: UUID(), title: "Three", icon: "3.circle.fill"),
                ]

                for (index, item) in items.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.35) {
                        ToastController.show(style: .dynamicIsland, item: item) { toast in
                            Label(toast.title, systemImage: toast.icon)
                        }
                    }
                }
            }

            Divider()

            // MARK: Lifecycle controls
            Button("Dismiss Current Toast", role: .destructive) {
                ToastController.dismiss()
            }

            Button("Remove Overlay Entirely", role: .destructive) {
                ToastController.remove()
            }
        } header: {
            Text("Dynamic Island")
        } footer: {
            Text(
                "Controller-driven DI toasts use ToastController.show(style:.dynamicIsland). "
            )
        }
    }
}

// MARK: - Example Toast Model

private struct ExampleToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

// MARK: - Example DI Toast Model (for controller item-based examples)

private struct ExampleDIToast: Identifiable, Equatable {
    let id: UUID
    let title: String
    let icon: String
}

// MARK: - Adaptive Toast Content (demonstrates toastPresentationStyle env)

/// A view that adapts its layout based on the surrounding toast presentation style.
private struct AdaptiveToastContent: View {
    let title: String
    let icon: String

    @Environment(\.toastPresentationStyle) private var presentationStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)

                // Branch on presentation style for different subtitle copy.
                Text(
presentationStyle == .dynamicIsland
                    ? "Dynamic Island"
                    : "Regular overlay"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Split Around Cutout View (demonstrates toastIslandGuide env)

/// A view that splits content left and right of the Dynamic Island cutout.
private struct SplitAroundCutoutView: View {
    @Environment(\.toastIslandGuide) private var guide

    var body: some View {
        GeometryReader { geo in
            let cutout = guide.cutout
            let size = geo.size

            // Left gutter: from leading edge to cutout.x
            let leftWidth = max(cutout.origin.x, 0)
            // Right gutter: from cutout.maxX to trailing edge
            let rightWidth = max(size.width - cutout.maxX, 0)

            ZStack(alignment: .topLeading) {
                // Left side content
                if leftWidth > 20 {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "gauge.low")
                            .foregroundStyle(.green)
                        Text("CPU 12%")
                            .font(.caption2)
                    }
                    .frame(width: leftWidth, height: cutout.height > 0 ? cutout.height : size.height)
                    .padding(.horizontal, 8)
                }

                // Right side content (anchored to trailing edge of cutout)
                if rightWidth > 20 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("2.1 GB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "memorychip")
                            .foregroundStyle(.purple)
                    }
                    .frame(width: rightWidth, height: cutout.height > 0 ? cutout.height : size.height)
                    .offset(x: max(cutout.maxX, 0))
                    .padding(.horizontal, 8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    _ToastExample()
}
