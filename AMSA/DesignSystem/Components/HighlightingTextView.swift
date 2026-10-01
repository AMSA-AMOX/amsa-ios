import SwiftUI
import UIKit

/// A growing text view that styles ranges of its own text — replaces the web's
/// "transparent textarea + mirror div" trick (PostComposer hashtag bolding) and exposes the
/// caret so emoji/hashtag insertion can happen at the cursor like `selectionStart`.
struct HighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    /// Caret/selection in UTF-16 offsets (JS string indices).
    @Binding var selection: NSRange
    var placeholder: String
    var fontName: String
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var textColor: UIColor
    var placeholderColor: UIColor
    var caretColor: UIColor
    var minHeight: CGFloat
    var isEditable: Bool = true
    var maxLength: Int? = nil
    /// Ranges (UTF-16) to render with `highlightFontName`.
    var highlights: (String) -> [NSRange] = { _ in [] }
    var highlightFontName: String? = nil
    /// Set true to focus once.
    var focusTrigger: Int = 0
    var onChange: ((String, NSRange) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.delegate = context.coordinator
        view.tintColor = caretColor
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let label = UILabel()
        label.numberOfLines = 0
        label.tag = 999
        view.addSubview(label)
        context.coordinator.placeholderLabel = label
        apply(to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = isEditable
        view.tintColor = caretColor
        if view.text != text { apply(to: view, coordinator: context.coordinator) }
        if view.selectedRange != selection, selection.location <= (view.text as NSString).length {
            view.selectedRange = selection
        }
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
        layoutPlaceholder(in: view, coordinator: context.coordinator)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(minHeight, ceil(fitting.height)))
    }

    private var paragraph: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = lineHeight
        p.maximumLineHeight = lineHeight
        p.lineBreakMode = .byWordWrapping
        return p
    }

    private func baseAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
            // Center glyphs in the CSS line box (UIKit otherwise bottom-aligns them).
            .baselineOffset: (lineHeight - font.lineHeight) / 4,
        ]
    }

    fileprivate func attributed(_ text: String) -> NSAttributedString {
        let font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes(font: font))
        if let highlightFontName, let bold = UIFont(name: highlightFontName, size: fontSize) {
            for range in highlights(text) where NSMaxRange(range) <= result.length {
                result.addAttribute(.font, value: bold, range: range)
            }
        }
        return result
    }

    fileprivate func apply(to view: UITextView, coordinator: Coordinator) {
        let selected = view.selectedRange
        view.attributedText = attributed(text)
        let font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        view.typingAttributes = baseAttributes(font: font)
        let length = (text as NSString).length
        view.selectedRange = selection.location <= length ? selection : NSRange(location: min(selected.location, length), length: 0)
        layoutPlaceholder(in: view, coordinator: coordinator)
    }

    fileprivate func layoutPlaceholder(in view: UITextView, coordinator: Coordinator) {
        guard let label = coordinator.placeholderLabel else { return }
        let font = UIFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        label.attributedText = NSAttributedString(string: placeholder, attributes: [
            .font: font, .foregroundColor: placeholderColor, .paragraphStyle: paragraph,
            .baselineOffset: (lineHeight - font.lineHeight) / 4,
        ])
        label.isHidden = !text.isEmpty
        let width = max(view.bounds.width, 1)
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightingTextView
        weak var placeholderLabel: UILabel?
        var lastFocusTrigger = 0

        init(_ parent: HighlightingTextView) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let max = parent.maxLength else { return true }
            let current = (textView.text as NSString).length
            // `maxLength` counts UTF-16 units, like the DOM.
            return current - range.length + (text as NSString).length <= max
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            let selection = textView.selectedRange
            parent.text = newText
            parent.selection = selection
            // Re-style in place, preserving the caret.
            let attributed = parent.attributed(newText)
            if textView.markedTextRange == nil {
                textView.attributedText = attributed
                textView.selectedRange = selection
            }
            parent.layoutPlaceholder(in: textView, coordinator: self)
            parent.onChange?(newText, selection)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if parent.selection != textView.selectedRange { parent.selection = textView.selectedRange }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.layoutPlaceholder(in: textView, coordinator: self)
        }
    }
}
