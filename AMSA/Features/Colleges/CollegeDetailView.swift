import SwiftUI

/// Flat `ScorecardProfile` (GET /api/colleges/{id}/scorecard) — only fields the page reads.
private struct ScorecardProfile: Decodable, Sendable {
    let satAvg: Double?
    let sat25Read: Double?
    let sat75Read: Double?
    let sat25Math: Double?
    let sat75Math: Double?
    let act25: Double?
    let actMid: Double?
    let act75: Double?
    let enrollment: Double?
    let gradStudents: Double?
    let gradRate: Double?
}

private struct SchoolStudent: Decodable, Sendable, Identifiable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let profilePic: String?
    let role: String?
    let major: String?
    let graduationYear: FlexibleString?
}

private struct CollegePost: Decodable, Sendable, Identifiable {
    struct Author: Decodable, Sendable { let id: Int; let firstName: String?; let lastName: String?; let profilePic: String? }
    let id: Int
    let body: String?
    let images: [String]?
    let createdAt: String?
    let appreciationCount: Int?
    let author: Author?
}

private enum CollegeDetailAPI {
    struct StudentsResponse: Decodable, Sendable { let students: [SchoolStudent]? }
    struct PostsResponse: Decodable, Sendable { let posts: [CollegePost]? }
    static func scorecard(_ id: Int) -> Endpoint<ScorecardProfile> {
        Endpoint(path: "/api/colleges/\(id)/scorecard", authenticated: false)
    }
    static func students(_ id: Int) -> Endpoint<StudentsResponse> {
        Endpoint(path: "/api/colleges/\(id)/students", authenticated: false)
    }
    static func posts(_ id: Int) -> Endpoint<PostsResponse> {
        Endpoint(path: "/api/colleges/\(id)/posts", authenticated: false)
    }
}

// Port of src/app/(dashboard)/dashboard/research/college/[id]/page.tsx (mobile: info stacked above Reviews).
struct CollegeDetailView: View {
    let collegeId: Int

    @Environment(CollegesStore.self) private var store
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @Environment(ExternalLinkPresenter.self) private var links

    @State private var profile: ScorecardProfile?
    @State private var students: [SchoolStudent] = []
    @State private var studentsLoading = true
    @State private var posts: [CollegePost] = []
    @State private var postsLoading = true
    @State private var lightbox: LightboxItem?

    private var college: College? { store.byId[collegeId] }

    var body: some View {
        ScrollView {
            if store.loading {
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in RoundedRectangle(cornerRadius: TW.radiusSm).fill(Palette.gray100).frame(height: 112) }
                }
                .twPulse()
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            } else if let college {
                VStack(alignment: .leading, spacing: 0) {
                    info(college).padding(24)
                    ReviewsColumn(config: .college(id: college.id, name: college.name))
                }
            } else {
                // The web renders `error ?? "College not found."` where error is "" — the fallback never showed.
                VStack(spacing: 16) {
                    Text(store.error.isEmpty ? "College not found." : store.error).tw(.sm).foregroundStyle(Palette.gray400)
                    Button { router.back(to: .colleges) } label: {
                        Text("← Back").tw(.sm, .semibold).underline().foregroundStyle(Palette.navy)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { store.load() }
        .task(id: collegeId) { await loadExtras() }
        .lightbox($lightbox, backdropOpacity: 0.8)
    }

    // MARK: Info column

    @ViewBuilder
    private func info(_ c: College) -> some View {
        let meta = [
            c.type == "public" ? "Public" : c.type == "liberal_arts" ? "Liberal Arts" : "Private",
            c.nationalRank.map { "\(c.type == "liberal_arts" ? "LAC" : "Nat'l") Rank #\($0)" },
            c.stemOptEligible ? "STEM OPT eligible" : nil,
            c.meetsFullDemonstratedNeed ? "Meets full need" : nil,
            c.noLoanPolicy ? "No loans" : nil,
        ].compactMap { $0 }

        VStack(alignment: .leading, spacing: 0) {
            Button { router.back(to: .colleges) } label: {
                HStack(spacing: 6) {
                    Icon("chevron-left-thick", size: 16)
                    Text("Back to research").tw(.sm)
                }
                .foregroundStyle(Palette.gray500)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 16) {
                DetailLogo(college: c)
                VStack(alignment: .leading, spacing: 0) {
                    Text(c.name).tw(.x2l, .bold, leading: .tight).foregroundStyle(Palette.navy)
                    HStack(spacing: 4) {
                        Icon("feather-map-pin", size: 13).opacity(0.6)
                        Text(c.location).tw(.sm)
                    }
                    .foregroundStyle(Palette.gray500)
                    .padding(.top, 2)
                    Text(meta.joined(separator: " · ")).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 4)
                }
            }
            .padding(.bottom, 20)

            // "Campus photo" — the web embeds Google Maps in an iframe.
            WebView(source: .url(mapURL(c)))
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
                .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
                .padding(.bottom, 24)

            statGrid([
                ("Tuition", Formatters.money(c.tuition), c.type == "public" ? "OOS rate" : "per year"),
                (c.estimatedNetCost != nil ? "Est. Net Cost" : "Total COA", Formatters.money(c.estimatedNetCost ?? c.totalCostOfAttendance),
                 c.estimatedNetCost != nil ? "after avg aid" : "full price"),
                ("Acceptance Rate", c.overallAcceptanceRate.map(Formatters.percent) ?? "N/A",
                 (c.overallAcceptanceRate ?? 100) < 10 ? "Highly selective" : "Overall"),
                ("Int'l Students", c.internationalPercent.map { Formatters.raw($0) + "%" } ?? "N/A",
                 c.intlStudentsEstimate.map { "≈ \(Formatters.localeNumber($0)) students" } ?? "of enrollment"),
            ])
            .padding(.bottom, 20)

            studentsSection
            postsSection
            atAGlance(c)
            studentProfile(c)
            tipsSection(c)
            internationalSection(c)
            aidSection(c)
            costSection(c)
            moreInfo(c)

            Text("Data sourced from 2024 College Scorecard, Common Data Set, and IPEDS. Figures such as tuition, aid, and acceptance rates may change year to year — verify with each school's official website.")
                .tw(.xs, leading: .relaxed)
                .foregroundStyle(Palette.gray400)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .topBorder(Palette.gray300, width: 2)
        }
    }

    private func mapURL(_ c: College) -> URL {
        let q = "\(c.name), \(c.location)".addingPercentEncoding(withAllowedCharacters: .jsURIComponent) ?? ""
        return URL(string: "https://maps.google.com/maps?q=\(q)&output=embed")!
    }

    private func statGrid(_ stats: [(String, String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16, alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                  alignment: .leading, spacing: 20) {
            ForEach(stats, id: \.0) { stat in
                VStack(alignment: .leading, spacing: 0) {
                    Text(stat.0).tw(.xs, .medium).foregroundStyle(Palette.gray400).padding(.bottom, 4)
                    Text(stat.1).tw(.base, .bold, leading: .snug).foregroundStyle(Palette.navy)
                    Text(stat.2).tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 2)
                }
            }
        }
    }

    private func bigStats(_ stats: [(String, String)], columns: Int = 2) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .topLeading), count: columns),
                  alignment: .leading, spacing: 20) {
            ForEach(stats, id: \.1) { stat in
                VStack(alignment: .leading, spacing: 4) {
                    Text(stat.0).tw(.x2l, .black, leading: .leadingNone).foregroundStyle(Palette.navy)
                    Text(stat.1).tw(.xs, leading: .tight).foregroundStyle(Palette.gray500)
                }
            }
        }
    }

    // MARK: Sections

    private var studentsSection: some View {
        InfoSection(label: studentsLoading ? "AMSA Members at This School"
                    : "\(students.count) AMSA \(students.count == 1 ? "Member" : "Members") at This School",
                    icon: "feather-users") {
            if studentsLoading {
                VStack(spacing: 12) { ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 40) } }.twPulse()
            } else if students.isEmpty {
                Text("No AMSA members have linked this school to their profile yet.").tw(.sm).foregroundStyle(Palette.gray400)
            } else {
                VStack(spacing: 12) {
                    ForEach(students) { s in
                        Button { router.navigate(to: .memberProfile(id: s.id)) } label: {
                            HStack(spacing: 12) {
                                Avatar(imageURL: s.profilePic, initials: .initials(s.firstName, s.lastName), size: 36, fontSize: .xs,
                                       background: Palette.gray100, foreground: Palette.gray500, fontWeight: .semibold)
                                VStack(alignment: .leading, spacing: 0) {
                                    (Text("\(s.firstName ?? "") \(s.lastName ?? "")")
                                        + Text(s.role == Role.ambassador ? "  Ambassador" : "")
                                        .font(.custom(TW.Weight.medium.fontName, fixedSize: 12)).foregroundColor(Palette.gray400))
                                        .tw(.sm, .semibold).foregroundStyle(Palette.gray900).lineLimit(1)
                                    let sub = [s.major?.nilIfEmpty, s.graduationYear?.value.nilIfEmpty].compactMap { $0 }
                                    if !sub.isEmpty {
                                        Text(sub.joined(separator: " · ")).tw(.xs).foregroundStyle(Palette.gray400).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray200, borderWidth: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var postsSection: some View {
        InfoSection(label: postsLoading ? "Posts From This School"
                    : "\(posts.count) \(posts.count == 1 ? "Post" : "Posts") From This School",
                    icon: "feather-file-text") {
            if postsLoading {
                VStack(spacing: 16) { ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 80) } }.twPulse()
            } else if posts.isEmpty {
                Text("No posts from this school yet. Be the first to share your experience.").tw(.sm).foregroundStyle(Palette.gray400)
            } else {
                VStack(spacing: 12) { ForEach(posts) { postRow($0) } }
            }
        }
    }

    private func postRow(_ post: CollegePost) -> some View {
        let initials = String.initials(post.author?.firstName, post.author?.lastName).nilIfEmpty ?? "U"
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Avatar(imageURL: post.author?.profilePic, initials: initials, size: 28, fontSize: .xs,
                       background: Palette.gray100, foreground: Palette.gray500, fontWeight: .semibold)
                Text(post.author.map { "\($0.firstName ?? "") \($0.lastName ?? "")" } ?? "AMSA Member")
                    .tw(.xs, .semibold).foregroundStyle(Palette.gray700)
                Text("·").foregroundStyle(Palette.gray300)
                Text(RelativeTime.agoMonth.format(post.createdAt)).tw(.xs).foregroundStyle(Palette.gray400)
            }
            .padding(.bottom, 8)
            if let body = post.body, !body.isEmpty {
                Text(body).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray600).lineLimit(4)
            }
            if let images = post.images, !images.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { _, url in
                        Button { lightbox = LightboxItem(url: url) } label: {
                            RemoteImage(url) { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() } else { Palette.gray100 }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusLg))
                            .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
            }
            if let count = post.appreciationCount, count > 0 {
                Text("\(count) appreciations").tw(.xs).foregroundStyle(Palette.gray400).padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .twBox(background: Palette.white, radius: TW.radiusXl, border: Palette.gray200, borderWidth: 2)
        .contentShape(Rectangle())
        .onTapGesture { if let author = post.author { router.navigate(to: .memberProfile(id: author.id)) } }
    }

    private func atAGlance(_ c: College) -> some View {
        var stats: [(String, String)] = [("\(JSNumber.string(c.financialAccessibilityScore))/100", "Aid score (financial access)")]
        if let rate = c.completionRate4yr ?? profile?.gradRate {
            stats.append((Formatters.percent(Formatters.jsRound(rate * 100)), "Grad rate (4-yr)"))
        }
        stats.append((c.internationalPercent.map { Formatters.raw($0) + "%" } ?? "N/A", "Int'l share of campus"))
        return InfoSection(label: "At a Glance", icon: "feather-bar-chart") { bigStats(stats) }
    }

    private func studentProfile(_ c: College) -> some View {
        var stats: [(String, String)] = [
            (c.overallAcceptanceRate.map(Formatters.percent) ?? "—", "Overall accept rate"),
            ((c.internationalAcceptanceRate ?? c.overallAcceptanceRate).map(Formatters.percent) ?? "—", "Int'l accept rate"),
        ]
        if let ugds = c.ugds ?? profile?.enrollment { stats.append((Formatters.localeNumber(ugds), "Undergrads")) }
        if let grad = c.gradStudents ?? profile?.gradStudents { stats.append((Formatters.localeNumber(grad), "Grad students")) }

        let satAvg = c.satAvg ?? profile?.satAvg
        let sat25M = c.satMath25 ?? profile?.sat25Math
        let sat75M = c.satMath75 ?? profile?.sat75Math
        let sat25R = c.satRead25 ?? profile?.sat25Read
        let sat75R = c.satRead75 ?? profile?.sat75Read
        let actMid = c.actMid ?? profile?.actMid
        let act25 = c.act25 ?? profile?.act25
        let act75 = c.act75 ?? profile?.act75
        // `satAvg ?? sat25M ?? act25` truthiness
        let hasData = (satAvg ?? sat25M ?? act25).map { $0 != 0 } ?? false

        return InfoSection(label: "Average Student Profile", icon: "feather-grad-cap") {
            bigStats(stats).padding(.bottom, 20)
            if hasData {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TEST SCORE RANGES (25TH–75TH PERCENTILE)").tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
                    VStack(alignment: .leading, spacing: 0) {
                        if let satAvg {
                            scoreRow("SAT Average", JSNumber.string(Formatters.jsRound(satAvg)))
                        }
                        ScoreRange(label: "SAT Math", lo: sat25M, hi: sat75M, min: 200, max: 800)
                        ScoreRange(label: "SAT Reading", lo: sat25R, hi: sat75R, min: 200, max: 800)
                        if let actMid { scoreRow("ACT Midpoint", JSNumber.string(actMid)) }
                        ScoreRange(label: "ACT Composite", lo: act25, hi: act75, min: 1, max: 36)
                    }
                }
            }
        }
    }

    private func scoreRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).tw(.sm, .medium).foregroundStyle(Palette.gray600)
            Spacer()
            Text(value).tw(.base, .bold).foregroundStyle(Palette.navy)
        }
        .padding(.vertical, 10)
        .bottomBorder(Palette.gray100, width: 1)
    }

    private func tips(_ c: College) -> [String] {
        var t: [String] = []
        if c.noLoanPolicy { t.append("No-loan policy — all aid is grants, zero institutional debt.") }
        if c.meetsFullDemonstratedNeed { t.append("Meets 100% of demonstrated need for every admitted student.") }
        if c.stemOptEligible { t.append("STEM OPT eligible — 36 months work auth vs. standard 12.") }
        if c.type == "public" { t.append("Public school: internationals pay out-of-state tuition with minimal aid.") }
        if let i = c.internationalAcceptanceRate, let o = c.overallAcceptanceRate, i < o * 0.6 {
            t.append("International acceptance (\(Formatters.raw(i))%) is much lower than overall (\(Formatters.raw(o))%).")
        }
        if c.healthInsurance > 4000 { t.append("F-1 health insurance is \(Formatters.money(c.healthInsurance))/yr — mandatory.") }
        return t
    }

    @ViewBuilder
    private func tipsSection(_ c: College) -> some View {
        let items = tips(c)
        if !items.isEmpty {
            InfoSection(label: "Tips for International Applicants", icon: "feather-lightbulb") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Icon("feather-check", size: 15).foregroundStyle(Palette.navy).opacity(0.5).padding(.top, 2)
                            Text(tip).tw(.sm, leading: .relaxed).foregroundStyle(Palette.gray700)
                        }
                    }
                }
            }
        }
    }

    private func internationalSection(_ c: College) -> some View {
        var stats: [(String, String)] = [(c.internationalPercent.map { Formatters.raw($0) + "%" } ?? "N/A", "Of undergrads")]
        if let n = c.intlStudentsEstimate, n > 0 { stats.append(("~" + Formatters.localeNumber(n), "Est. intl enrollment")) }
        if let n = c.countriesRepresented { stats.append((Formatters.raw(n), "Countries represented")) }
        if let n = c.internationalAcceptanceRate { stats.append((Formatters.percent(n), "Intl accept rate")) }
        let checks: [(String, Bool)] = [
            ("Meets full demonstrated need", c.meetsFullDemonstratedNeed),
            ("No-loan policy", c.noLoanPolicy),
            ("STEM OPT eligible (36 mo)", c.stemOptEligible),
            ("Aid is renewable", c.aidIsRenewable),
            ("Actively recruits international students", c.activelyRecruitsUnderrepresented),
        ]
        return InfoSection(label: "International Students", icon: "feather-globe") {
            bigStats(stats).padding(.bottom, 20)
            VStack(spacing: 0) {
                ForEach(checks, id: \.0) { label, active in
                    HStack(spacing: 8) {
                        Icon(active ? "feather-check" : "feather-x-circle", size: 15).foregroundStyle(Palette.navy).opacity(0.5)
                        Text(label).tw(.sm).foregroundStyle(active ? Palette.gray700 : Palette.gray400)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                    .bottomBorder(Palette.gray100, width: 1)
                }
            }
        }
    }

    private func aidSection(_ c: College) -> some View {
        InfoSection(label: "Financial Aid for Internationals", icon: "feather-dollar") {
            if !c.offersAidToInternationals {
                HStack(alignment: .top, spacing: 10) {
                    Icon("feather-x-circle", size: 18).foregroundStyle(Palette.navy).opacity(0.5).padding(.top, 2)
                    Text("No institutional aid for international undergrads — expect full cost of attendance.")
                        .tw(.sm).foregroundStyle(Palette.gray700)
                }
            } else {
                let stats = [
                    c.averageAidPackage.map { (Formatters.money($0), "Avg aid package / yr") },
                    c.percentReceivingAid.map { (Formatters.raw($0) + "%", "Receiving aid") },
                    c.estimatedNetCost.map { (Formatters.money($0), "Est. net cost after aid") },
                ].compactMap { $0 }
                if !stats.isEmpty { bigStats(stats).padding(.bottom, 20) }
                if let renewal = c.renewalConditions, !renewal.isEmpty {
                    (Text("Renewal: ").font(.custom(TW.Weight.semibold.fontName, fixedSize: 14)).foregroundColor(Palette.navy)
                        + Text(renewal))
                        .tw(.sm, leading: .relaxed)
                        .foregroundStyle(Palette.gray600)
                        .padding(.bottom, 16)
                }
                if !c.meritScholarships.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MERIT SCHOLARSHIPS").tw(.xs, .semibold, tracking: .wide).foregroundStyle(Palette.gray400)
                        VStack(spacing: 0) {
                            ForEach(Array(c.meritScholarships.enumerated()), id: \.offset) { index, s in
                                if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                                HStack {
                                    Text(s.name ?? "").tw(.sm).foregroundStyle(Palette.gray700)
                                    Spacer()
                                    if let amount = s.amount {
                                        Text("\(Formatters.money(amount))/yr").tw(.sm, .semibold).foregroundStyle(Palette.navy)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private func costSection(_ c: College) -> some View {
        var rows: [(label: String, value: Double, note: String?, bold: Bool)] = [
            ("Tuition", c.tuition, c.type == "public" ? "OOS rate" : nil, false),
            ("Room & Board", c.roomAndBoard, nil, false),
            ("Books & Supplies", c.booksAndSupplies, nil, false),
            ("Personal Expenses", c.personalExpenses, nil, false),
            ("Health Insurance (F-1 mandatory)", c.healthInsurance, nil, false),
            ("Total Cost of Attendance", c.totalCostOfAttendance, nil, true),
        ]
        if let net = c.estimatedNetCost { rows.append(("Est. Net Cost after Avg Aid", net, nil, true)) }
        return InfoSection(label: "Full Cost Breakdown (Annual)", icon: "feather-receipt") {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                    HStack {
                        (Text(row.label) + Text(row.note.map { "  (\($0))" } ?? "")
                            .font(.custom(TW.Weight.normal.fontName, fixedSize: 12)).foregroundColor(Palette.gray400))
                            .tw(.sm, row.bold ? .bold : .normal)
                            .foregroundStyle(row.bold ? Palette.navy : Palette.gray600)
                        Spacer()
                        Text(Formatters.money(row.value)).tw(.sm, row.bold ? .bold : .medium)
                            .foregroundStyle(row.bold ? Palette.navy : Palette.gray800)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func moreInfo(_ c: College) -> some View {
        func slugify(_ s: String) -> String {
            s.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .replacingOccurrences(of: "(^-|-$)", with: "", options: .regularExpression)
        }
        let name = c.name.addingPercentEncoding(withAllowedCharacters: .jsURIComponent) ?? c.name
        var items: [(label: String, desc: String, domain: String, href: String)] = [
            ("Niche", "Student reviews, demographics, rankings & grades", "niche.com",
             "https://www.niche.com/colleges/\(c.nicheSlug ?? slugify(c.name))/"),
            ("U.S. News & World Report", "Official rankings & full profile", "usnews.com",
             "https://www.usnews.com/best-colleges/\(c.usNewsSlug ?? slugify(c.name))-\(c.id)"),
            ("The Princeton Review", "Campus culture & best-of lists", "princetonreview.com",
             "https://www.princetonreview.com/college-search?name=\(name)"),
            ("College Factual", "Major outcomes & earnings data", "collegefactual.com",
             "https://www.collegefactual.com/colleges/\(slugify(c.name))/"),
        ]
        if let website = c.website, !website.isEmpty {
            let href = website.hasPrefix("http") ? website : "https://\(website)"
            items.append(("Official website", "Admissions, programs & contact", URL(string: href)?.host ?? website, href))
        }
        return InfoSection(label: "More Information", icon: "feather-globe") {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { TWDivider(color: Palette.gray100, width: 1) }
                    Button { links.open(item.href) } label: {
                        HStack(spacing: 12) {
                            RemoteImage("https://www.google.com/s2/favicons?domain=\(item.domain)&sz=32") { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFit() }
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: TW.radiusSm))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.label).tw(.sm, .semibold).foregroundStyle(Palette.gray900)
                                Text(item.desc).tw(.xs).foregroundStyle(Palette.gray400)
                            }
                            Spacer(minLength: 0)
                            Icon("feather-external", size: 15).foregroundStyle(Palette.gray300)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Data

    private func loadExtras() async {
        let api = session.api
        let id = collegeId
        let tasks: [Task<Void, Never>] = [
            Task { profile = try? await api.send(CollegeDetailAPI.scorecard(id)) },
            Task {
                students = (try? await api.send(CollegeDetailAPI.students(id)))?.students ?? []
                studentsLoading = false
            },
            Task {
                posts = (try? await api.send(CollegeDetailAPI.posts(id)))?.posts ?? []
                postsLoading = false
            },
        ]
        for task in tasks { await task.value }
    }
}

private struct DetailLogo: View {
    let college: College
    @State private var failed = false

    var body: some View {
        if let logo = college.logoUrl, !failed {
            RemoteImage(logo) { phase in
                switch phase {
                case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                case .failure: Color.clear.onAppear { failed = true }
                case .loading: Color.clear
                }
            }
            .padding(6)
            .frame(width: 56, height: 56)
            .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.white))
            .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray100, lineWidth: 1))
        } else {
            Text(String(college.name.prefix(2)).uppercased())
                .tw(.xl, .bold)
                .foregroundStyle(Palette.gray500)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.gray100))
        }
    }
}

/// `ScoreRange` — monochrome 25th–75th bar.
private struct ScoreRange: View {
    let label: String
    let lo: Double?
    let hi: Double?
    let min: Double
    let max: Double

    var body: some View {
        // `!lo && !hi` — zero counts as missing.
        let loValue = (lo ?? 0) != 0 ? lo : nil
        let hiValue = (hi ?? 0) != 0 ? hi : nil
        if loValue == nil, hiValue == nil {
            HStack {
                Text(label).tw(.sm).foregroundStyle(Palette.gray500)
                Spacer()
                Text("N/A").tw(.sm).foregroundStyle(Palette.gray300)
            }
            .padding(.vertical, 10)
        } else {
            let range = max - min
            let loX = loValue.map { ($0 - min) / range } ?? 0
            let hiX = hiValue.map { ($0 - min) / range } ?? 1
            VStack(spacing: 0) {
                HStack {
                    Text(label).tw(.sm, .medium).foregroundStyle(Palette.gray600)
                    Spacer()
                    Text("\(loValue.map(JSNumber.string) ?? "?") – \(hiValue.map(JSNumber.string) ?? "?")")
                        .tw(.sm, .bold).foregroundStyle(Palette.navy)
                }
                .padding(.bottom, 8)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.gray100)
                        Capsule().fill(Palette.navy)
                            .frame(width: Swift.max(0, proxy.size.width * (hiX - loX)))
                            .offset(x: proxy.size.width * loX)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text(JSNumber.string(min))
                    Spacer()
                    Text(JSNumber.string(max))
                }
                .tw(.px(10))
                .foregroundStyle(Palette.gray300)
                .padding(.top, 4)
            }
            .padding(.vertical, 10)
        }
    }
}
