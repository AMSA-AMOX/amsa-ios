import SwiftUI

/// Visual spec for a web `<input>`/`<textarea>`: padding, font, border, radius and focus ring.
struct InputStyle {
    var size: TW.Size = .sm
    var weight: TW.Weight = .normal
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 8
    var radius: CGFloat = TW.radiusLg
    var border: Color = Palette.gray200
    var borderWidth: CGFloat = 1
    var background: Color = Palette.white
    var textColor: Color = Palette.black
    /// Tailwind v4 preflight: placeholder = current text color at 50% (Safari 17+) unless overridden.
    var placeholderColor: Color? = nil
    var focusBorder: Color? = Palette.navy
    /// `focus:ring-2 focus:ring-[#001049]/20` — ring drawn outside the border.
    var focusRing: Color? = Palette.navy.opacity(0.2)
    var focusRingWidth: CGFloat = 2
    var focusBackground: Color? = nil
    var leadingInset: CGFloat = 0
    /// Extra right padding (e.g. `pr-12` for an inline send button).
    var trailingInset: CGFloat = 0
    /// `font-mono`
    var monospaced: Bool = false
    /// Tailwind v4 preflight sets `opacity: 1` on form controls, cancelling iOS WebKit's
    /// `input:disabled, textarea:disabled { opacity: 0.4 }`; only `disabled:opacity-*` changes it.
    var disabledOpacity: CGFloat = 1

    /// Edit-profile / modal inputs: `px-3 py-2 text-sm border border-gray-200 rounded-lg focus:ring-2
    /// focus:ring-[#001049]/20 focus:border-[#001049] bg-white`.
    static let modal = InputStyle()

    /// Auth `.input`: `w-full rounded-lg border border-gray-300 px-4 py-2 shadow-sm focus:ring-2 focus:ring-[#001A78]`.
    static let auth = InputStyle(size: .base, horizontalPadding: 16, verticalPadding: 8, border: Palette.gray300,
                                 focusBorder: nil, focusRing: Palette.navyFocus)

    var resolvedPlaceholder: Color { placeholderColor ?? textColor.opacity(0.5) }
}

private struct InputChrome: ViewModifier {
    let style: InputStyle
    let focused: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.radius)
        content
            .padding(.horizontal, style.horizontalPadding)
            .padding(.leading, style.leadingInset)
            .padding(.trailing, style.trailingInset)
            .padding(.vertical, style.verticalPadding)
            .background(shape.fill(focused ? (style.focusBackground ?? style.background) : style.background))
            .overlay(shape.strokeBorder(focused ? (style.focusBorder ?? style.border) : style.border,
                                        lineWidth: style.borderWidth))
            .overlay {
                if focused, let ring = style.focusRing {
                    shape.inset(by: -style.focusRingWidth / 2).stroke(ring, lineWidth: style.focusRingWidth)
                }
            }
    }
}

private struct InputFont: ViewModifier {
    let style: InputStyle
    func body(content: Content) -> some View {
        if style.monospaced { content.twMono(style.size) } else { content.tw(style.size, style.weight) }
    }
}

/// Single-line web `<input>`.
struct WebTextField: View {
    let placeholder: String
    @Binding var text: String
    var style: InputStyle = .modal
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var secure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disabled: Bool = false
    var maxLength: Int? = nil
    var submitLabel: SubmitLabel = .done
    var autoFocus: Bool = false
    var onFocusChange: ((Bool) -> Void)? = nil
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .modifier(InputFont(style: style))
                    .foregroundStyle(style.resolvedPlaceholder)
                    .lineLimit(1)
                    .allowsHitTesting(false)
            }
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .modifier(InputFont(style: style))
            .foregroundStyle(style.textColor)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(keyboard == .emailAddress || keyboard == .URL || secure)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .focused($focused)
            .disabled(disabled)
        }
        .modifier(InputChrome(style: style, focused: focused))
        .opacity(disabled ? style.disabledOpacity : 1)
        .onChange(of: text) { _, newValue in
            if let maxLength, newValue.utf16.count > maxLength { text = newValue.limitedUTF16(to: maxLength) }
        }
        .onChange(of: focused) { _, isFocused in onFocusChange?(isFocused) }
        .onAppear { if autoFocus { focused = true } }
    }
}

/// Web `<textarea rows={n}>` — grows from `rows` lines (auto-grow textareas pass `growing: true`).
struct WebTextArea: View {
    let placeholder: String
    @Binding var text: String
    var style: InputStyle = .modal
    var rows: Int = 3
    var maxLength: Int? = nil
    var disabled: Bool = false
    /// `true` for textareas that resize with content (composers); `false` keeps a fixed `rows` height with scrolling.
    var growing: Bool = false
    var autoFocus: Bool = false
    /// Enter submits (the web's `onKeyDown` Enter-without-Shift handler).
    var submitOnReturn: Bool = false
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .modifier(InputFont(style: style))
                    .foregroundStyle(style.resolvedPlaceholder)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text, axis: .vertical)
                .modifier(InputFont(style: style))
                .foregroundStyle(style.textColor)
                .lineLimit(rows...(growing ? 10_000 : rows))
                .focused($focused)
                .disabled(disabled)
                .onSubmit { onSubmit?() }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(InputChrome(style: style, focused: focused))
        .opacity(disabled ? style.disabledOpacity : 1)
        .onChange(of: text) { _, newValue in
            if submitOnReturn, newValue.contains("\n") {
                text = newValue.replacingOccurrences(of: "\n", with: "")
                onSubmit?()
                return
            }
            if let maxLength, newValue.utf16.count > maxLength { text = newValue.limitedUTF16(to: maxLength) }
        }
        .onAppear { if autoFocus { focused = true } }
    }
}

/// Web `<select>`: a box showing the selected option; tapping opens the native menu
/// (iOS Safari opens a native picker for `<select>` too).
struct WebSelect<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    var style: InputStyle = .modal
    var showsChevron: Bool = false
    var disabled: Bool = false

    var body: some View {
        Menu {
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(options.first(where: { $0.value == selection })?.label ?? "")
                    .tw(style.size, style.weight)
                    .foregroundStyle(style.textColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.gray500)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(InputChrome(style: style, focused: false))
            .contentShape(Rectangle())
        }
        .disabled(disabled)
        .opacity(disabled ? style.disabledOpacity : 1)
    }
}

/// iOS Safari's default `<input type="checkbox">` (no `accent-color`): a rounded square
/// filled with system blue when checked.
struct WebCheckbox: View {
    @Binding var isOn: Bool
    var size: CGFloat = 16
    var tint: Color = Color(uiColor: .systemBlue)
    var disabled: Bool = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(isOn ? tint : Palette.white)
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isOn ? tint : Palette.gray400, lineWidth: 1)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.65, weight: .bold))
                        .foregroundStyle(Palette.white)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}
