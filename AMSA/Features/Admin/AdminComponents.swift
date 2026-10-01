// Shared pieces of src/app/(dashboard)/dashboard/admin/{verification,posts}/page.tsx
import SwiftUI

/// `"pending" | "approved" | "rejected" | "all"` filter shared by the verification and post queues.
enum ReviewFilter: String, CaseIterable, Identifiable {
    case pending, approved, rejected, all
    var id: String { rawValue }

    /// `tab === "all" ? "All" : tab[0].toUpperCase() + tab.slice(1)` plus ` (n)` on Pending.
    func label(pendingCount: Int) -> String {
        switch self {
        case .pending: "Pending (\(pendingCount))"
        case .approved: "Approved"
        case .rejected: "Rejected"
        case .all: "All"
        }
    }
}

/// `bg-white rounded-2xl border border-gray-100 shadow-sm` + padding.
struct AdminCard<Content: View>: View {
    var padding: CGFloat
    var border: Color = Palette.gray100
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding + 1)
            .twBox(background: Palette.white, radius: TW.radius2xl, border: border)
            .twShadow(.sm)
    }
}

/// The status tab card: `p-4 mb-5` around `flex flex-wrap gap-2` buttons
/// (`px-3 py-1.5 rounded-lg text-sm font-medium`; dashboard buttons render 4pt corners).
struct ReviewFilterTabs: View {
    @Binding var selection: ReviewFilter
    let pendingCount: Int

    var body: some View {
        AdminCard(padding: 16) {
            FlowLayout(spacing: 8) {
                ForEach(ReviewFilter.allCases) { tab in
                    Button { selection = tab } label: {
                        Text(tab.label(pendingCount: pendingCount))
                            .tw(.sm, .medium)
                            .foregroundStyle(selection == tab ? Palette.white : Palette.gray700)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                .fill(selection == tab ? Palette.navy : Palette.gray100))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// `px-2.5 py-1 rounded-full text-xs font-semibold` — green / red / yellow by review status.
struct ReviewStatusPill: View {
    let status: String

    var body: some View {
        let (bg, fg): (Color, Color) = switch status {
        case "approved": (Palette.green100, Palette.green700)
        case "rejected": (Palette.red100, Palette.red700)
        default: (Palette.yellow100, Palette.yellow700)
        }
        Text(status).tw(.xs, .semibold).foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .fixedSize()
    }
}

/// `mb-4 rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700`
struct AdminErrorBox: View {
    let message: String

    var body: some View {
        Text(message).tw(.sm).foregroundStyle(Palette.red700)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 17).padding(.vertical, 13)
            .twBox(background: Palette.red50, radius: TW.radiusXl, border: Palette.red100)
    }
}

/// `space-y-3 animate-pulse` of `h-N bg-white rounded-xl border border-gray-100` blocks.
struct AdminLoadingBlocks: View {
    var count = 2
    let height: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                Color.clear.frame(height: height)
                    .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray100)
            }
        }
        .twPulse()
    }
}

/// `bg-white rounded-2xl border border-gray-100 shadow-sm p-8 text-center text-sm text-gray-500`
struct AdminEmptyCard: View {
    let message: String

    var body: some View {
        AdminCard(padding: 32) {
            Text(message).tw(.sm).foregroundStyle(Palette.gray500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

/// `text-xs font-semibold text-gray-500 uppercase tracking-wide`
struct AdminFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray500)
    }
}

/// `px-4 py-2 rounded-lg text-sm font-semibold text-white disabled:opacity-50` (Approve / Reject).
struct AdminSolidButton: View {
    let title: String
    let color: Color
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).tw(.sm, .semibold).foregroundStyle(Palette.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(color))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

extension InputStyle {
    /// Admin note / review note `<textarea>`: `px-3 py-2 text-sm border border-gray-200 rounded-lg
    /// focus:ring-2 focus:ring-[#001049]/20` (no focus border color, transparent background on white).
    static let adminNote = InputStyle(focusBorder: nil)
}
