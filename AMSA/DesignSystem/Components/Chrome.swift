import SwiftUI

// App chrome: the bottom tab bar, screen headers and per-tab top bars. Not ported from the
// web — the app's own navigation, modeled on floating pill bars.

enum Chrome {
    /// Height of every pill and circle in the tab bar and screen headers.
    static let navHeight: CGFloat = 44
    /// Height of every control in the tabs' top bars.
    static let toolbarHeight: CGFloat = 48
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
}

extension View {
    /// A floating chrome surface: Liquid Glass on iOS 26, white with a hairline and soft shadow before.
    @ViewBuilder
    func chromeSurface<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(shape.fill(Palette.white))
                .overlay(shape.stroke(Palette.gray200, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    /// Pins `bar` to the bottom edge, floating over the content, which scrolls underneath and fades out.
    func floatingBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            bar()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(alignment: .bottom) {
                    LinearGradient(stops: [.init(color: Palette.gray50.opacity(0), location: 0),
                                           .init(color: Palette.gray50.opacity(0.92), location: 0.55)],
                                   startPoint: .top, endPoint: .bottom)
                        .padding(.top, -16)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
        }
    }

    /// Pins `bar` to the top edge; content scrolls underneath and fades out below it.
    func pinnedTopBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            bar()
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(alignment: .top) {
                    VStack(spacing: 0) {
                        Palette.gray50
                        LinearGradient(colors: [Palette.gray50, Palette.gray50.opacity(0)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 16)
                    }
                    .padding(.bottom, -16)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }
        }
    }
}

/// A red count badge, `9+` past nine.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count > 9 ? "9+" : String(count))
            .font(.custom(TW.Weight.bold.fontName, fixedSize: 11))
            .foregroundStyle(Palette.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 18, minHeight: 18)
            .background(Capsule().fill(Palette.red500))
            .overlay(Capsule().stroke(Palette.gray50, lineWidth: 2))
    }
}

/// A round chrome button with an SF Symbol and an optional count badge.
struct ChromeCircleButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = Chrome.toolbarHeight
    var badge: Int = 0
    /// Navy fill, for a control whose filter or search is active.
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(active ? Palette.white : Palette.gray700)
                .frame(width: size, height: size)
                .background { if active { Circle().fill(Palette.navy) } }
                .chromeSurface(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(ChromePressStyle())
        .overlay(alignment: .topTrailing) {
            if badge > 0 { CountBadge(count: badge).offset(x: 4, y: -4).allowsHitTesting(false) }
        }
        .accessibilityLabel(label)
    }
}

/// Shrinks a control slightly while pressed.
struct ChromePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The capsule search field used in the tabs' top bars.
struct ChromeSearchField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.gray500)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Palette.gray400))
                .font(.custom(TW.Weight.normal.fontName, fixedSize: 16))
                .foregroundStyle(Palette.gray900)
                .focused(focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.gray400)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Chrome.toolbarHeight)
        .chromeSurface(Capsule())
        .contentShape(Capsule())
        .onTapGesture { focused.wrappedValue = true }
    }
}

/// Bottom sheet with a title, an optional Reset and a Done button.
struct ChromeSheet<Content: View>: View {
    let title: String
    var onReset: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(title).tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer(minLength: 0)
                if let onReset {
                    Button("Reset", action: onReset)
                        .font(.custom(TW.Weight.semibold.fontName, fixedSize: 15))
                        .foregroundStyle(Palette.gray500)
                }
                Button { dismiss() } label: {
                    Text("Done").tw(.sm, .semibold).foregroundStyle(Palette.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Palette.navy))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
        }
        .background(Palette.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Palette.white)
    }
}

/// An uppercase group label inside a `ChromeSheet`.
struct SheetSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
    }
}
