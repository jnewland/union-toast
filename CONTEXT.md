# UnionToast

A SwiftUI toast notification library with overlay window architecture, supporting both declarative modifiers and imperative controller APIs.

## Language

**Toast**:
A transient notification view presented above the app's UI via an overlay window. Auto-dismisses after a configurable delay or on user interaction (swipe-up).
_Avoid_: notification, alert, banner

**Presentation style**:
The visual presentation mode of a toast — either `.regular` (slides from top) or `.dynamicIsland` (animates from the Dynamic Island). The style is resolved at presentation time; on non-Dynamic-Island devices, `.dynamicIsland` falls back to `.regular`.
_Avoid_: theme, variant

**Overlay window**:
A `PassThroughWindow` (UIWindow subclass) created per scene, positioned above the main window. Passes touches through except within a defined hittable rect (used by Dynamic Island toasts).
_Avoid_: popup window, floating layer

**Controller**:
``ToastController`` — the imperative API for presenting toasts programmatically. Singleton (`shared`). Owns queueing, replacement choreography, duplicate suppression for item-based toasts, and dismiss callbacks.
_Avoid_: manager (that's ``ToastManager``, which is the timer/animation state machine inside one overlay)

**Modifier**:
A SwiftUI `ViewModifier` that presents toasts declaratively via `.toast(isPresented:)` or `.toast(item:)`. Each modifier instance manages its own overlay lifecycle independently of the controller.
_Avoid_: wrapper, decorator

**Item-based toast**:
A toast driven by an `Identifiable & Equatable` payload. New items replace the current toast with choreographed animation. Duplicate items within ~1 second are suppressed automatically.

**Resolved presentation style**:
The actual `ToastStyle` a view is being rendered as, available via `@Environment(\.toastPresentationStyle)`. Reflects the *resolved* style — if `.dynamicIsland` is requested on a non-DI device, this reports `.regular`. Dynamic Island content renders in a forced-dark environment (`colorScheme = .dark`) so semantic colors stay legible on the always-black background.

## Relationships

- A **Toast** is presented via either a **Modifier** (declarative) or the **Controller** (imperative).
- Each presentation path owns its own overlay window per scene.
- The **Controller** is a singleton — all imperative calls share the same instance and overlay state.
- Item-based **Modifier** instances are isolated per view hierarchy (each manages its own overlay).

## Flagged ambiguities

- "dismiss" was used for both user-initiated (swipe-up) and timer-driven dismissal — resolved: these are distinct triggers but share the same dismiss path.
- "style" was accepted by `toast(item:)` but silently ignored — resolved: now routes to the correct presentation path.
