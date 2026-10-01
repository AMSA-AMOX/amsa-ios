// Port of src/app/(dashboard)/dashboard/research/compare/page.tsx
import SwiftUI

struct CompareView: View {
    @Environment(CollegesStore.self) private var store
    @Environment(Router.self) private var router

    private static let maxCustomColumns = 6
    private static let statusOptions: [(value: String, label: String, dot: Color)] = [
        ("", "Select", Palette.gray300),
        ("researching", "Researching", Palette.blue400),
        ("applying", "Applying", Palette.amber400),
        ("applied", "Applied", Palette.purple400),
        ("admitted", "Admitted", Palette.green500),
        ("waitlisted", "Waitlisted", Palette.orange400),
        ("rejected", "Rejected", Palette.red400),
        ("enrolled", "Enrolled", Palette.emerald500),
    ]

    @State private var journal = JournalData()
    @State private var editingColumnId: String?
    @State private var savedAt: Date?
    @State private var confirmClear = false
    /// Per-row count of cells currently targeted by a drag (`dragOverIdx`), robust to enter/leave ordering.
    @State private var dropTargets: [Int: Int] = [:]

    private var rows: [College] { journal.rowOrder.compactMap { store.byId[$0] } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 24)
                if store.loading {
                    loadingBox
                } else if !store.error.isEmpty {
                    Text(store.error).tw(.sm).foregroundStyle(Palette.red600)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(21)
                        .background(Palette.red50)
                        .overlay(Rectangle().strokeBorder(Palette.red100, lineWidth: 1))
                } else if rows.isEmpty {
                    emptyState
                } else {
                    table
                    footer.padding(.top, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 32)
        }
        .onAppear {
            store.load()
            mergeCompareIds()
        }
        .alert("Clear your entire college journal? This cannot be undone.", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("OK") { clearAll() }
        }
    }

    // MARK: Header / states

    /// `flex flex-wrap items-start justify-between gap-4`
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                titleBlock
                Spacer(minLength: 16)
                addSchoolsLink
            }
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                addSchoolsLink
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("My College Journal").tw(.xl, .semibold).foregroundStyle(Palette.navy)
            subtitle.tw(.sm).foregroundStyle(Palette.gray400)
        }
    }

    private var subtitle: Text {
        let base = Text("Rank schools · track status · add notes")
        guard let savedAt else { return base }
        // `<span className="ml-2 text-xs">· Saved {time}</span>`
        return base + Text.inlineGap(8, fontSize: 12)
            + Text("· Saved \(Formatters.hourMinute(savedAt))").font(.custom(TW.Weight.normal.fontName, fixedSize: 12))
    }

    private var addSchoolsLink: some View {
        Button { router.navigate(to: .colleges) } label: {
            Text("+ Add Schools").tw(.sm, .medium).foregroundStyle(Palette.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: TW.radiusSm).fill(Palette.navy))
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    private var loadingBox: some View {
        VStack(spacing: 8) {
            SkeletonBar(fraction: 3 / 4, height: 14, centered: true)
            SkeletonBar(fraction: 1 / 2, height: 14, centered: true)
        }
        .frame(maxWidth: 448)
        .twPulse()
        .frame(maxWidth: .infinity)
        .padding(33)
        .background(Palette.white)
        .overlay(Rectangle().strokeBorder(Palette.gray200, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("Your journal is empty").tw(.sm, .semibold).foregroundStyle(Palette.navy).padding(.bottom, 4)
            (Text("Browse schools and click ")
                + Text("Compare").font(.custom(TW.Weight.bold.fontName, fixedSize: 14))
                + Text(" to add them here."))
                .tw(.sm)
                .foregroundStyle(Palette.gray400)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 384)
                .padding(.bottom, 24)
            Button { router.navigate(to: .colleges) } label: {
                Text("Browse Schools →").tw(.sm, .medium).foregroundStyle(Palette.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: TW.radiusSm).fill(Palette.navy))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(57)
        .background(Palette.white)
        .overlay(Rectangle().strokeBorder(Palette.gray200, lineWidth: 1))
    }

    // MARK: Table

    private var columnCount: Int { 11 + journal.customColumns.count }

    /// `overflow-x-auto border-2 rounded-lg border-gray-200 bg-white` around `table.w-full.text-sm.border-collapse`.
    private var table: some View {
        let rows = rows
        return ScrollView(.horizontal) {
            TableLayout(columns: columnCount) {
                headerCells
                ForEach(Array(rows.enumerated()), id: \.offset) { index, college in
                    rowCells(college, index: index, rows: rows)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg - 2))
        .padding(2)
        .background(RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.white))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 2))
    }

    @ViewBuilder
    private var headerCells: some View {
        headerCell(horizontalPadding: 12, alignment: .center) {
            Text("#").tw(.px(12, lineHeight: 20), .medium).foregroundStyle(Palette.gray400).frame(width: 24)
        }
        headerCell(minWidth: 220) { HeaderLabel(text: "School") }
        ForEach(["Rank", "Housing", "Tuition (yr)", "Net Cost (est.)", "Accept", "Aid Score", "Status"], id: \.self) { title in
            headerCell { HeaderLabel(text: title) }
        }
        ForEach(journal.customColumns) { column in
            headerCell(minWidth: 140) { customColumnHeader(column) }
        }
        headerCell(horizontalPadding: 12) {
            if journal.customColumns.count < Self.maxCustomColumns {
                Button(action: addColumn) {
                    Icon("compare-add-column", size: 16).foregroundStyle(Palette.gray400)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add column")
            } else {
                Text("Max").tw(.px(12, lineHeight: 20)).foregroundStyle(Palette.gray300)
            }
        }
        headerCell(horizontalPadding: 0, verticalPadding: 0, trailingBorder: false) {
            Color.clear.frame(width: 64, height: 0)
        }
    }

    private func customColumnHeader(_ column: JournalData.CustomColumn) -> some View {
        HStack(spacing: 6) {
            if editingColumnId == column.id {
                ColumnRenameField(initial: column.name) { name in
                    renameColumn(column.id, name)
                } finish: {
                    if editingColumnId == column.id { editingColumnId = nil }
                }
            } else {
                Button { editingColumnId = column.id } label: {
                    HeaderLabel(text: column.name)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Click to rename")
            }
            // Hover-only (`group-hover/col:opacity-100`) on the web; always visible on touch.
            Button { removeColumn(column.id) } label: {
                Icon("compare-remove-column", size: 12).foregroundStyle(Palette.gray300)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove column")
        }
    }

    @ViewBuilder
    private func rowCells(_ college: College, index: Int, rows: [College]) -> some View {
        let id = college.id
        let isLast = index == rows.count - 1
        let status = journal.statusData[String(id)] ?? ""
        let option = Self.statusOptions.first { $0.value == status } ?? Self.statusOptions[0]
        let score = college.financialAccessibilityScore

        // # / drag
        bodyCell(id, isLast: isLast, horizontalPadding: 12, alignment: .center) {
            VStack(spacing: 2) {
                // Hover-only on the web; always visible on touch.
                Icon("compare-grip", size: 12).foregroundStyle(Palette.gray300)
                Text("\(index + 1)").tw(.xs, leading: .leadingNone).foregroundStyle(Palette.gray400)
                moveButton("compare-up", hidden: index == 0) { moveRow(index, by: -1, rows: rows) }
                moveButton("compare-down", hidden: isLast) { moveRow(index, by: 1, rows: rows) }
            }
            .frame(width: 24)
        }
        .draggable(String(id))

        bodyCell(id, isLast: isLast) { SchoolCell(college: college) { router.navigate(to: .collegeDetail(id: id)) } }
        bodyCell(id, isLast: isLast) { numberText(college.nationalRank.map { "#\($0)" } ?? "—") }
        bodyCell(id, isLast: isLast) { numberText(Formatters.money(college.roomAndBoard)) }
        bodyCell(id, isLast: isLast) { numberText(Formatters.money(college.tuition)) }
        bodyCell(id, isLast: isLast) {
            if let net = college.estimatedNetCost {
                numberText(Formatters.money(net))
            } else {
                Text("—").tw(.sm).foregroundStyle(Palette.gray400)
            }
        }
        bodyCell(id, isLast: isLast) { numberText(college.overallAcceptanceRate.map { "\(Formatters.raw($0))%" } ?? "—") }
        bodyCell(id, isLast: isLast) {
            Text(Formatters.raw(score)).tw(.sm, .semibold).monospacedDigit()
                .foregroundStyle(score >= 75 ? Palette.green600 : score >= 55 ? Palette.amber600 : Palette.red500)
        }
        bodyCell(id, isLast: isLast) { statusMenu(collegeId: id, status: status, option: option) }
        ForEach(journal.customColumns) { column in
            bodyCell(id, isLast: isLast) {
                JournalCellField(text: Binding(
                    get: { journal.customData[column.id]?[String(id)] ?? "" },
                    set: { setCellValue(column.id, collegeId: id, value: $0) }
                ))
            }
        }
        bodyCell(id, isLast: isLast, horizontalPadding: 0, verticalPadding: 0) { Color.clear.frame(width: 0, height: 0) }
        // Remove — hover-only (`group-hover/row:opacity-100`) on the web; always visible on touch.
        bodyCell(id, isLast: isLast, horizontalPadding: 12, alignment: .trailing, trailingBorder: false) {
            Button { removeRow(id) } label: {
                Text("Remove").tw(.xs).foregroundStyle(Palette.gray300).fixedSize()
            }
            .buttonStyle(.plain)
        }
    }

    private func moveButton(_ icon: String, hidden: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(icon, size: 8).foregroundStyle(Palette.gray300).frame(width: 16, height: 12)
        }
        .buttonStyle(.plain)
        .opacity(hidden ? 0 : 1) // `disabled:opacity-0`
        .disabled(hidden)
    }

    private func numberText(_ text: String) -> some View {
        Text(text).tw(.sm).monospacedDigit().foregroundStyle(Palette.gray700)
    }

    /// `<select>` styled `text-xs bg-transparent appearance-none pr-3`; its width is the widest option's.
    private func statusMenu(collegeId: Int, status: String, option: (value: String, label: String, dot: Color)) -> some View {
        Menu {
            Picker("", selection: Binding(get: { status }, set: { setStatus(collegeId, $0) })) {
                ForEach(Self.statusOptions, id: \.value) { Text($0.label).tag($0.value) }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(option.dot).frame(width: 6, height: 6)
                ZStack(alignment: .leading) {
                    ForEach(Self.statusOptions, id: \.value) { Text($0.label).tw(.xs).hidden() }
                    Text(option.label).tw(.xs).foregroundStyle(status.isEmpty ? Palette.gray400 : Palette.gray700)
                }
                .padding(.trailing, 12)
                Icon("compare-down", size: 8).foregroundStyle(Palette.gray300)
            }
        }
    }

    /// `<th className="px-4 py-2.5 text-left border-r border-gray-200">` in `tr.bg-gray-50.border-b.border-gray-200`.
    /// The table's `text-sm` gives every header line a 20pt line box.
    private func headerCell<Content: View>(
        minWidth: CGFloat? = nil, horizontalPadding: CGFloat = 16, verticalPadding: CGFloat = 10,
        alignment: Alignment = .leading, trailingBorder: Bool = true, @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minWidth: minWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.trailing, trailingBorder ? 1 : 0)
            .padding(.bottom, 1)
            .background(Palette.gray50)
            .overlay(alignment: .trailing) { if trailingBorder { Palette.gray200.frame(width: 1) } }
            .overlay(alignment: .bottom) { Palette.gray200.frame(height: 1) }
    }

    /// `<td className="px-4 py-3 border-r border-gray-100">` in `tr.border-b.border-gray-100.last:border-b-0`.
    private func bodyCell<Content: View>(
        _ collegeId: Int, isLast: Bool, horizontalPadding: CGFloat = 16, verticalPadding: CGFloat = 12,
        alignment: Alignment = .leading, trailingBorder: Bool = true, @ViewBuilder _ content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.trailing, trailingBorder ? 1 : 0)
            .padding(.bottom, isLast ? 0 : 1)
            .background((dropTargets[collegeId] ?? 0) > 0 ? Palette.blue50.opacity(0.4) : Color.clear)
            .overlay(alignment: .trailing) { if trailingBorder { Palette.gray100.frame(width: 1) } }
            .overlay(alignment: .bottom) { if !isLast { Palette.gray100.frame(height: 1) } }
            .dropDestination(for: String.self) { items, _ in
                dropTargets[collegeId] = nil
                guard let raw = items.first, let fromId = Int(raw) else { return false }
                reorderRow(fromId: fromId, toId: collegeId)
                return true
            } isTargeted: { targeted in
                dropTargets[collegeId] = max(0, (dropTargets[collegeId] ?? 0) + (targeted ? 1 : -1))
            }
    }

    private var footer: some View {
        let rows = rows
        let statuses = rows.compactMap { journal.statusData[String($0.id)] }.filter { !$0.isEmpty }
        let applied = statuses.filter { ["applied", "admitted", "waitlisted", "enrolled"].contains($0) }.count
        return HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 16) {
                Text("\(rows.count) school\(rows.count != 1 ? "s" : "")")
                if applied > 0 { Text("\(applied) applied / in-progress") }
            }
            .tw(.xs)
            .foregroundStyle(Palette.gray400)
            Spacer(minLength: 0)
            Button { confirmClear = true } label: {
                Text("Clear journal").tw(.xs).foregroundStyle(Palette.gray300)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Journal mutations (same order of operations as the web)

    private func update(_ mutate: (inout JournalData) -> Void) {
        mutate(&journal)
        journal.persist()
        savedAt = Date()
    }

    /// Mount effect: merge `research_compare_ids` into `rowOrder` (the app has no `?ids=` URL).
    private func mergeCompareIds() {
        let stored = JournalData.load()
        let existing = Set(stored.rowOrder)
        var merged = stored
        merged.rowOrder += Preferences.compareIds.filter { !existing.contains($0) }
        journal = merged
        merged.persist()
    }

    private func moveRow(_ index: Int, by dir: Int, rows: [College]) {
        let target = index + dir
        guard target >= 0, target < rows.count else { return }
        let a = rows[index].id, b = rows[target].id
        update { j in
            guard let pa = j.rowOrder.firstIndex(of: a), let pb = j.rowOrder.firstIndex(of: b) else { return }
            j.rowOrder.swapAt(pa, pb)
        }
    }

    private func reorderRow(fromId: Int, toId: Int) {
        guard fromId != toId else { return }
        update { j in
            guard let from = j.rowOrder.firstIndex(of: fromId), let to = j.rowOrder.firstIndex(of: toId) else { return }
            j.rowOrder.remove(at: from)
            j.rowOrder.insert(fromId, at: to)
        }
    }

    private func removeRow(_ id: Int) {
        update { $0.rowOrder.removeAll { $0 == id } }
        if Preferences.hasCompareIds { Preferences.compareIds = Preferences.compareIds.filter { $0 != id } }
    }

    private func setStatus(_ id: Int, _ status: String) { update { $0.statusData[String(id)] = status } }

    private func setCellValue(_ columnId: String, collegeId: Int, value: String) {
        update { $0.customData[columnId, default: [:]][String(collegeId)] = value }
    }

    private func addColumn() {
        guard journal.customColumns.count < Self.maxCustomColumns else { return }
        let id = "col_\(UploadPath.millis(.now))"
        update { $0.customColumns.append(.init(id: id, name: "New Column")) }
        editingColumnId = id
    }

    private func renameColumn(_ id: String, _ name: String) {
        update { j in
            guard let i = j.customColumns.firstIndex(where: { $0.id == id }) else { return }
            j.customColumns[i].name = name.trimmed.nilIfEmpty ?? j.customColumns[i].name
        }
    }

    private func removeColumn(_ id: String) {
        update { j in
            j.customData[id] = nil
            j.customColumns.removeAll { $0.id == id }
        }
    }

    private func clearAll() {
        journal = JournalData()
        journal.persist()
        Preferences.removeCompareIds()
    }
}

// MARK: - Cells

/// `SchoolCell`: logo (or initials) + name link + location, `min-w-[200px]`, text truncated at 200pt.
private struct SchoolCell: View {
    let college: College
    let open: () -> Void
    @State private var broken = false

    var body: some View {
        HStack(spacing: 10) {
            if let logo = college.logoUrl, !logo.isEmpty, !broken {
                RemoteImage(logo) { phase in
                    switch phase {
                    case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                    case .failure: Color.clear.onAppear { broken = true }
                    case .loading: Color.clear
                    }
                }
                .frame(width: 36, height: 36)
                .background(Palette.white)
                .clipShape(RoundedRectangle(cornerRadius: TW.radiusSm))
            } else {
                Text(String(college.name.prefix(2)).uppercased())
                    .tw(.px(10), .bold)
                    .foregroundStyle(Palette.gray500)
                    .frame(width: 28, height: 28)
                    .background(Palette.gray100)
            }
            VStack(alignment: .leading, spacing: 0) {
                Button(action: open) {
                    Text(college.name).tw(.sm, .medium, leading: .snug).foregroundStyle(Palette.navy).lineLimit(1)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 200, alignment: .leading)
                Text(college.location).tw(.xs).foregroundStyle(Palette.gray400).lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading)
            }
        }
        .frame(minWidth: 200, alignment: .leading)
    }
}

/// Custom-column `<input placeholder="—" className="w-full text-xs text-gray-600 placeholder-gray-300
/// border-b border-transparent focus:border-gray-200 py-0.5 min-w-[120px]">`.
private struct JournalCellField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("—").tw(.xs).foregroundStyle(Palette.gray300).allowsHitTesting(false)
            }
            TextField("", text: $text)
                .tw(.xs)
                .foregroundStyle(Palette.gray600)
                .focused($focused)
                .submitLabel(.done)
        }
        .padding(.vertical, 2)
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) { (focused ? Palette.gray200 : Color.clear).frame(height: 1) }
        // A percentage-width input contributes only its `min-width` to the column.
        .frame(minWidth: 120, idealWidth: 120, maxWidth: .infinity, alignment: .leading)
    }
}

/// Column rename `<input autoFocus className="text-xs font-medium text-[#001049] bg-transparent border-b
/// border-[#001049]/40 max-w-[100px]">`. Blur or Enter commits (a tap elsewhere blurs, as on the web).
private struct ColumnRenameField: View {
    let commit: (String) -> Void
    let finish: () -> Void
    @State private var draft: String
    @State private var done = false
    @FocusState private var focused: Bool

    init(initial: String, commit: @escaping (String) -> Void, finish: @escaping () -> Void) {
        self.commit = commit
        self.finish = finish
        _draft = State(initialValue: initial)
    }

    var body: some View {
        TextField("", text: $draft)
            .tw(.xs, .medium)
            .foregroundStyle(Palette.navy)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(end)
            .padding(.bottom, 1)
            .overlay(alignment: .bottom) { Palette.navy.opacity(0.4).frame(height: 1) }
            .frame(width: 100)
            .onAppear { focused = true }
            .onChange(of: focused) { _, isFocused in if !isFocused { end() } }
            // Tapping another column's name removes this field before it blurs; still commit.
            .onDisappear { if !done { done = true; commit(draft) } }
    }

    private func end() {
        guard !done else { return }
        done = true
        commit(draft)
        finish()
    }
}

/// A wrapping `<th>` label (`text-xs font-medium text-gray-500` on the table's 20pt line box).
/// Reports its CSS min-content width — the widest word — so the column can shrink to it, then
/// wraps within the width the column ends up with.
private struct HeaderLabel: View {
    let text: String

    var body: some View {
        MinContentLayout {
            label(text)
            ForEach(Array(text.split(separator: " ").enumerated()), id: \.offset) { _, word in
                label(String(word)).hidden()
            }
        }
    }

    private func label(_ string: String) -> some View {
        Text(string).tw(.px(12, lineHeight: 20), .medium).foregroundStyle(Palette.gray500)
    }
}

/// First subview: the text. Remaining subviews: its words, measured for the min-content width.
private struct MinContentLayout: Layout {
    private func minContent(_ subviews: Subviews) -> CGFloat {
        (subviews.dropFirst().map { $0.sizeThatFits(.unspecified).width }.max() ?? 0).rounded(.up)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }
        let floor = minContent(subviews)
        let width = proposal.width.map { max($0, floor) } ?? floor
        return text.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }
        text.place(at: bounds.origin, proposal: ProposedViewSize(width: max(bounds.width, minContent(subviews)), height: nil))
        for word in subviews.dropFirst() { word.place(at: bounds.origin, proposal: .unspecified) }
    }
}

/// CSS automatic table layout for a table wider than its scroll container (always the case on a
/// phone): every column takes its widest cell's min-content width and every row its tallest cell.
/// Subviews are cells in row-major order, `columns` per row.
private struct TableLayout: Layout {
    let columns: Int

    private struct Metrics {
        var widths: [CGFloat] = []
        var heights: [CGFloat] = []
    }

    // Measured on every pass (no cache): cell contents change without the subview list changing.
    private func measure(_ subviews: Subviews) -> Metrics {
        guard columns > 0 else { return Metrics() }
        var widths = Array(repeating: CGFloat(0), count: columns)
        for (i, cell) in subviews.enumerated() {
            widths[i % columns] = max(widths[i % columns], cell.sizeThatFits(.unspecified).width)
        }
        var heights = Array(repeating: CGFloat(0), count: (subviews.count + columns - 1) / columns)
        for (i, cell) in subviews.enumerated() {
            let height = cell.sizeThatFits(ProposedViewSize(width: widths[i % columns], height: nil)).height
            heights[i / columns] = max(heights[i / columns], height)
        }
        return Metrics(widths: widths, heights: heights)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let metrics = measure(subviews)
        return CGSize(width: metrics.widths.reduce(0, +), height: metrics.heights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = measure(subviews)
        var y = bounds.minY
        for (row, height) in metrics.heights.enumerated() {
            var x = bounds.minX
            for (column, width) in metrics.widths.enumerated() {
                let i = row * columns + column
                guard i < subviews.count else { break }
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: height))
                x += width
            }
            y += height
        }
    }
}
