import SwiftUI

/// The web's modal pattern: `fixed inset-0 z-50 flex items-center justify-center p-4` with a
/// dimmed backdrop and a centered panel. Presented over the whole app (like `z-50` over the
/// top bar) without a slide animation, as the web shows it instantly.
private struct WebModalModifier<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let backdropOpacity: Double
    let dismissOnBackdrop: () -> Bool
    let padding: CGFloat
    let panel: () -> Panel

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $shown) {
                ZStack {
                    Color.black.opacity(backdropOpacity)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { if dismissOnBackdrop() { isPresented = false } }
                    panel()
                        .padding(padding)
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { shown = newValue }
            }
            .onChange(of: shown) { _, newValue in
                if !newValue, isPresented { isPresented = false }
            }
    }
}

extension View {
    /// - Parameters:
    ///   - backdropOpacity: `bg-black/50` → 0.5, `/40` → 0.4, `/55` → 0.55.
    ///   - dismissOnBackdrop: evaluated at tap time (e.g. `{ !saving }`).
    func webModal<Panel: View>(
        isPresented: Binding<Bool>,
        backdropOpacity: Double = 0.5,
        padding: CGFloat = 16,
        dismissOnBackdrop: @escaping () -> Bool = { true },
        @ViewBuilder panel: @escaping () -> Panel
    ) -> some View {
        modifier(WebModalModifier(isPresented: isPresented, backdropOpacity: backdropOpacity,
                                  dismissOnBackdrop: dismissOnBackdrop, padding: padding, panel: panel))
    }

    /// Item-driven variant.
    func webModal<Item: Identifiable, Panel: View>(
        item: Binding<Item?>,
        backdropOpacity: Double = 0.5,
        padding: CGFloat = 16,
        dismissOnBackdrop: @escaping () -> Bool = { true },
        @ViewBuilder panel: @escaping (Item) -> Panel
    ) -> some View {
        let isPresented = Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
        return webModal(isPresented: isPresented, backdropOpacity: backdropOpacity, padding: padding,
                        dismissOnBackdrop: dismissOnBackdrop) {
            if let value = item.wrappedValue { panel(value) }
        }
    }
}

/// `max-h-[90vh]` for modal panels.
extension View {
    func maxHeight(viewportFraction fraction: CGFloat) -> some View {
        modifier(ViewportMaxHeight(fraction: fraction))
    }
}

private struct ViewportMaxHeight: ViewModifier {
    let fraction: CGFloat
    func body(content: Content) -> some View {
        content.frame(maxHeight: UIScreen.main.bounds.height * fraction)
    }
}
