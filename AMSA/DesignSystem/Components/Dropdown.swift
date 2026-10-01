import SwiftUI

/// Web dropdowns (`absolute … z-30` cards under a trigger that close on an outside
/// mousedown). A host view renders the open dropdown above its content, positioned from the
/// trigger's anchor, with a transparent full-size layer that closes it on an outside tap.
@MainActor
@Observable
final class DropdownController {
    enum Placement {
        /// `absolute right-0 top-N` — right edges aligned, top at trigger.minY + offset.
        case belowTrailing(offset: CGFloat)
        /// `absolute left-0 top-N`
        case belowLeading(offset: CGFloat)
        /// `absolute left-0 bottom-N` — bottom at trigger.maxY − offset.
        case aboveLeading(offset: CGFloat)
    }

    struct Active {
        let id: AnyHashable
        let placement: Placement
        let content: AnyView
    }

    private(set) var active: Active?

    func isOpen(_ id: AnyHashable) -> Bool { active?.id == id }

    func toggle<Content: View>(_ id: AnyHashable, placement: Placement, @ViewBuilder content: () -> Content) {
        if active?.id == id { active = nil; return }
        active = Active(id: id, placement: placement, content: AnyView(content()))
    }

    func open<Content: View>(_ id: AnyHashable, placement: Placement, @ViewBuilder content: () -> Content) {
        active = Active(id: id, placement: placement, content: AnyView(content()))
    }

    func close() { active = nil }
}

struct DropdownAnchorKey: PreferenceKey {
    static var defaultValue: [AnyHashable: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [AnyHashable: Anchor<CGRect>], nextValue: () -> [AnyHashable: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Marks the positioning box (`relative` wrapper) of a dropdown trigger.
    func dropdownAnchor(_ id: AnyHashable) -> some View {
        anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { [id: $0] }
    }

    /// Renders the controller's open dropdown over this view.
    func dropdownHost(_ controller: DropdownController) -> some View {
        overlayPreferenceValue(DropdownAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let active = controller.active, let anchor = anchors[active.id] {
                    let rect = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { controller.close() }
                        positioned(active, rect: rect)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func positioned(_ active: DropdownController.Active, rect: CGRect) -> some View {
        switch active.placement {
        case .belowTrailing(let offset):
            active.content.fixedSize()
                .frame(width: max(rect.maxX, 0), alignment: .trailing)
                .offset(y: rect.minY + offset)
        case .belowLeading(let offset):
            active.content.fixedSize()
                .offset(x: rect.minX, y: rect.minY + offset)
        case .aboveLeading(let offset):
            active.content.fixedSize()
                .frame(height: max(rect.maxY - offset, 0), alignment: .bottom)
                .offset(x: rect.minX)
        }
    }
}

/// The white menu card used by PostCard / ThreadCard: `bg-white border border-gray-200 rounded-xl shadow-lg p-1`.
struct DropdownCard<Content: View>: View {
    var width: CGFloat = 144
    var radius: CGFloat = TW.radiusXl
    var padding: CGFloat = 4
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(width: width, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(Palette.white))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Palette.gray200, lineWidth: 1))
            .twShadow(.lg)
    }
}
