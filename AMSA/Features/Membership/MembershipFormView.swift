import SwiftUI

/// The application payload (src/lib/membership.ts `MembershipSubmissionPayload`).
struct MembershipForm: Equatable {
    var fullName = ""
    var pronouns = ""
    var enrolledUniversity = ""
    var yearInSchool = ""
    var state = ""
    var city = ""
    var major = ""
    var expectedGraduation = ""
    var email = ""
    var socialMedia = ""
    var phone = ""
    var careerInterests: [String] = []
    var careerInterestsOther = ""
    var amsaInterests: [String] = []
    var amsaInterestsOther = ""
    var mentorshipInterest = ""
    var eventIdeas = ""
    var heardAboutAmsa = ""
    var heardAboutAmsaOther = ""
    var agreesToEmails = false
}

private struct MembershipRecord: Decodable, Sendable {
    let fullName: String?
    let pronouns: String?
    let enrolledUniversity: String?
    let yearInSchool: String?
    let state: String?
    let city: String?
    let major: String?
    let expectedGraduation: String?
    let email: String?
    let socialMedia: String?
    let phone: String?
    let careerInterests: [String]?
    let careerInterestsOther: String?
    let amsaInterests: [String]?
    let amsaInterestsOther: String?
    let mentorshipInterest: String?
    let eventIdeas: String?
    let heardAboutAmsa: String?
    let heardAboutAmsaOther: String?
    let agreesToEmails: Bool?
    let reviewStatus: String?
}

private struct MembershipResponse: Decodable, Sendable { let membership: MembershipRecord? }

private struct EmailCheck: Decodable, Sendable, Equatable {
    struct College: Decodable, Sendable, Equatable { let id: Int; let name: String }
    let status: String
    let college: College?
}

private enum MembershipAPI {
    static func load() -> Endpoint<MembershipResponse> { Endpoint(path: "/api/user/verification") }
    static func submit(_ f: MembershipForm) -> Endpoint<MembershipResponse> {
        Endpoint(method: .post, path: "/api/user/verification", body: [
            "fullName": .string(f.fullName), "pronouns": .string(f.pronouns), "enrolledUniversity": .string(f.enrolledUniversity),
            "yearInSchool": .string(f.yearInSchool), "state": .string(f.state), "city": .string(f.city), "major": .string(f.major),
            "expectedGraduation": .string(f.expectedGraduation), "email": .string(f.email), "socialMedia": .string(f.socialMedia),
            "phone": .string(f.phone), "careerInterests": .strings(f.careerInterests),
            "careerInterestsOther": .string(f.careerInterestsOther), "amsaInterests": .strings(f.amsaInterests),
            "amsaInterestsOther": .string(f.amsaInterestsOther), "mentorshipInterest": .string(f.mentorshipInterest),
            "eventIdeas": .string(f.eventIdeas), "heardAboutAmsa": .string(f.heardAboutAmsa),
            "heardAboutAmsaOther": .string(f.heardAboutAmsaOther), "agreesToEmails": .bool(f.agreesToEmails),
        ])
    }
    static func match(email: String, name: String) -> Endpoint<EmailCheck> {
        Endpoint(path: "/api/colleges/match", query: [("email", email), ("name", name)])
    }
}

enum MembershipOptions {
    static let yearInSchool = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate Student", "Other"]
    static let mentorship = ["Yes", "Maybe", "Not at the moment"]
    static let careerInterests = [
        "Business / Finance", "Technology / Computer Science", "Engineering", "Medicine / Healthcare", "Law / Policy",
        "Research / Academia", "Entrepreneurship / Startups", "Design / Creative fields", "Nonprofit / Social Impact",
        "Environmental / Sustainability", "Other:",
    ]
    static let amsaInterests = [
        "Mentorship", "Networking", "Events", "Leadership Opportunities", "Advocacy", "Research", "Community Service", "Other",
    ]
    static let heardAbout = ["Instagram", "Friend", "School Club Fair", "AMSA Event", "Referral from Member", "Other"]

    /// `normalizeInstagramHandle`
    static func instagramHandle(_ value: String?) -> String {
        var raw = (value ?? "").trimmed
        guard !raw.isEmpty else { return "" }
        if let range = raw.range(of: #"instagram\.com/([^/?#\s]+)"#, options: [.regularExpression, .caseInsensitive]) {
            let match = String(raw[range])
            raw = String(match[match.index(after: match.firstIndex(of: "/")!)...])
        }
        var handle = raw.replacingOccurrences(of: #"^@+"#, with: "", options: .regularExpression)
        handle = handle.replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression).trimmed
        return handle.isEmpty ? "" : "@\(handle)"
    }
}

// Port of src/app/(dashboard)/verification/page.tsx
struct MembershipFormView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ShellStore.self) private var shell

    private enum Field: Hashable {
        case fullName, enrolledUniversity, yearInSchool, state, city, major, expectedGraduation, email, phone
        case careerOther, amsaOther, mentorship, heardAbout, heardOther
    }

    @State private var form = MembershipForm()
    @State private var reviewStatus = "pending"
    @State private var loadingForm = true
    @State private var submitting = false
    @State private var error = ""
    @State private var success = ""
    @State private var emailCheck: EmailCheck?
    @State private var checkingEmail = false
    @State private var checkTask: Task<Void, Never>?
    @State private var invalid: (field: Field, message: String)?

    private var isLocked: Bool { reviewStatus == "approved" }
    private var requiresCareerOther: Bool { form.careerInterests.contains("Other:") }
    private var requiresAmsaOther: Bool { form.amsaInterests.contains("Other") }
    private var requiresHeardOther: Bool { form.heardAboutAmsa == "Other" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    intro.padding(.bottom, 32)
                    aboutAmsa.padding(.bottom, 32)
                    TWDivider().padding(.bottom, 32)
                    if loadingForm {
                        VStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.gray200).frame(height: 48)
                            RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.gray200).frame(height: 48)
                            RoundedRectangle(cornerRadius: TW.radiusLg).fill(Palette.gray200).frame(height: 128)
                        }
                        .twPulse()
                    } else {
                        formBody(proxy)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task { await load() }
        .onChange(of: form.email) { _, _ in scheduleEmailCheck() }
        .onChange(of: form.enrolledUniversity) { _, _ in scheduleEmailCheck() }
        .onChange(of: form) { _, _ in invalid = nil }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.role == Role.boardMember
                 ? "All board members are required to complete this US Member application. Submitting it will not change your board member role."
                 : "Use this form to apply for US Member status. Your submission is linked to your account and reviewed by admins.")
                .tw(.base).foregroundStyle(Palette.gray500)
            Text("The school, major, graduation, location and contact details you enter here are saved to your profile as well.")
                .tw(.sm).foregroundStyle(Palette.gray400)
            if reviewStatus == "approved" {
                Text("Your application has been approved.").tw(.base, .semibold).foregroundStyle(Palette.green700)
            }
        }
    }

    private var aboutAmsa: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("About AMSA")
            Text("The Association of Mongolian Students in America (AMSA), founded in 2011, connects Mongolian students pursuing higher education in the United States. As a non-profit organization, AMSA has built a strong network of over 12,000 students and alumni, led by 8 board members.")
                .tw(.base, leading: .relaxed).foregroundStyle(Palette.gray700)
            Text("AMSA includes 1,100+ active members across the U.S. and organizes key programs such as:")
                .tw(.base, leading: .relaxed).foregroundStyle(Palette.gray700)
            VStack(alignment: .leading, spacing: 6) {
                bullet("Change Your Future (CYF) — introducing high school students to U.S. study opportunities")
                bullet("Best University Opportunity Program (BUOP) — preparing students for college applications and scholarships")
                bullet("Annual General Meeting (AGM) — bringing students together for networking and community")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("•").frame(width: 20, alignment: .center)
            Text(text)
        }
        .tw(.base)
        .foregroundStyle(Palette.gray700)
    }

    private func sectionTitle(_ text: String, required: Bool = false) -> some View {
        (Text(text.uppercased()) + Text(required ? " *" : "").foregroundColor(Palette.red500))
            .tw(.sm, .semibold, tracking: .wide)
            .foregroundStyle(Palette.gray400)
    }

    // MARK: Form

    private func formBody(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Personal Info")
                textField(.fullName, "Full Name", $form.fullName, required: true, placeholder: "Enter your full name", caps: .words)
                textField(nil, "Pronouns", $form.pronouns, placeholder: "e.g., she/her, he/him, they/them")
                textField(.enrolledUniversity, "Enrolled University", $form.enrolledUniversity, required: true,
                          placeholder: "Enter your university name", caps: .words)
                selectField(.yearInSchool, "Year in School", $form.yearInSchool, MembershipOptions.yearInSchool)
                textField(.state, "State", $form.state, required: true, placeholder: "Enter your state", caps: .words)
                textField(.city, "City", $form.city, required: true, placeholder: "Enter your city", caps: .words)
                textField(.major, "Major", $form.major, required: true, placeholder: "Enter your major", caps: .words)
                textField(.expectedGraduation, "Expected Graduation", $form.expectedGraduation, required: true,
                          placeholder: "e.g., June 2029")
                VStack(alignment: .leading, spacing: 6) {
                    textField(.email, "School Email (.edu)", $form.email, required: true, placeholder: "you@university.edu",
                              hint: isLocked ? nil : "Must end in .edu — must belong to the university above",
                              keyboard: .emailAddress, caps: .never)
                    if !isLocked, checkingEmail || emailCheck != nil { emailStatus }
                }
                textField(.phone, "Phone", $form.phone, required: true, placeholder: "Enter your phone number", keyboard: .phonePad)
                textField(nil, "Instagram Handle", $form.socialMedia, placeholder: "@username",
                          hint: isLocked ? nil : "Optional — your Instagram @handle so we can find and tag you", caps: .never)
            }

            TWDivider()

            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Career Interests", required: true)
                multiSelect(MembershipOptions.careerInterests, $form.careerInterests)
                if requiresCareerOther {
                    textField(.careerOther, "Other Career Interest", $form.careerInterestsOther, required: true,
                              placeholder: "Please specify")
                }
            }

            TWDivider()

            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("AMSA Interests")
                multiSelect(MembershipOptions.amsaInterests, $form.amsaInterests)
                if requiresAmsaOther {
                    textField(.amsaOther, "Other AMSA Interest", $form.amsaInterestsOther, required: true, placeholder: "Please specify")
                }
            }

            TWDivider()

            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Additional Questions")
                selectField(.mentorship, "Mentorship Interest", $form.mentorshipInterest, MembershipOptions.mentorship)
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Event Ideas", required: false)
                    WebTextArea(placeholder: "Share any event ideas you want AMSA to organize", text: $form.eventIdeas,
                                style: fieldStyle, rows: 5, disabled: isLocked)
                }
                selectField(.heardAbout, "How did you hear about AMSA?", $form.heardAboutAmsa, MembershipOptions.heardAbout)
                if requiresHeardOther {
                    textField(.heardOther, "How did you hear about AMSA? (Other)", $form.heardAboutAmsaOther, required: true,
                              placeholder: "Please specify")
                }
            }

            TWDivider()

            HStack(alignment: .top, spacing: 12) {
                WebCheckbox(isOn: $form.agreesToEmails, disabled: isLocked).padding(.top, 2)
                Text("I agree to receive AMSA emails and updates.").tw(.sm).foregroundStyle(Palette.gray700)
                    .onTapGesture { if !isLocked { form.agreesToEmails.toggle() } }
            }

            VStack(alignment: .leading, spacing: 12) {
                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red600) }
                if !success.isEmpty { Text(success).tw(.sm).foregroundStyle(Palette.green700) }
                Button { submit(proxy) } label: {
                    Text(submitting ? "Submitting..." : "Submit Application")
                        .tw(.base, .semibold)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
                }
                .buttonStyle(.plain)
                .disabled(submitting || isLocked)
                .opacity(submitting || isLocked ? 0.5 : 1)
            }
        }
    }

    private var fieldStyle: InputStyle {
        InputStyle(size: .base, horizontalPadding: 16, verticalPadding: 12, radius: TW.radiusLg,
                   textColor: isLocked ? Palette.gray400 : Palette.black)
    }

    private func fieldLabel(_ label: String, required: Bool) -> some View {
        (Text(label.uppercased()) + Text(required ? " *" : "").foregroundColor(Palette.red500))
            .tw(.xs, .semibold, tracking: .wide)
            .foregroundStyle(Palette.gray500)
    }

    private func textField(_ field: Field?, _ label: String, _ text: Binding<String>, required: Bool = false,
                           placeholder: String, hint: String? = nil, keyboard: UIKeyboardType = .default,
                           caps: TextInputAutocapitalization = .sentences) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: required)
            WebTextField(placeholder: placeholder, text: text,
                         style: InputStyle(size: .base, horizontalPadding: 16, verticalPadding: 12, radius: TW.radiusLg,
                                           background: isLocked ? Palette.gray50 : Palette.white,
                                           textColor: isLocked ? Palette.gray400 : Palette.black),
                         keyboard: keyboard, autocapitalization: caps, disabled: isLocked)
            if let hint { Text(hint).tw(.xs).foregroundStyle(Palette.gray400) }
            validationMessage(field)
        }
        .id(field)
    }

    private func selectField(_ field: Field, _ label: String, _ selection: Binding<String>, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: true)
            WebSelect(options: [("Select an option", "")] + options.map { ($0, $0) }, selection: selection,
                      style: InputStyle(size: .base, horizontalPadding: 16, verticalPadding: 12, radius: TW.radiusLg,
                                        background: isLocked ? Palette.gray50 : Palette.white),
                      showsChevron: true, disabled: isLocked)
            validationMessage(field)
        }
        .id(field)
    }

    @ViewBuilder
    private func validationMessage(_ field: Field?) -> some View {
        if let field, let invalid, invalid.field == field {
            Text(invalid.message).tw(.xs).foregroundStyle(Palette.red600)
        }
    }

    private func multiSelect(_ options: [String], _ values: Binding<[String]>) -> some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                let checked = values.wrappedValue.contains(option)
                let toggle = {
                    if checked { values.wrappedValue.removeAll { $0 == option } } else { values.wrappedValue.append(option) }
                }
                HStack(spacing: 12) {
                    WebCheckbox(isOn: Binding(get: { checked }, set: { _ in toggle() }), disabled: isLocked)
                    Text(option).tw(.base).foregroundStyle(Palette.gray700)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: TW.radiusLg).strokeBorder(Palette.gray200, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { if !isLocked { toggle() } }
            }
        }
    }

    private var emailStatus: some View {
        let (text, color): (String, Color) = {
            if checkingEmail { return ("Checking school email…", Palette.gray400) }
            switch emailCheck?.status {
            case "match": return ("✓ Email verified for \(emailCheck?.college?.name ?? "")", Palette.green700)
            case "mismatch": return ("✗ This email belongs to \(emailCheck?.college?.name ?? ""), not \"\(form.enrolledUniversity)\"", Palette.red600)
            default: return ("We couldn't match this email domain to a college — an admin will verify it manually.", Palette.gray400)
            }
        }()
        return Text(text).tw(.xs).foregroundStyle(color)
    }

    // MARK: Data

    private func load() async {
        loadingForm = true
        error = ""
        let api = session.api
        do {
            async let membershipCall = api.send(MembershipAPI.load())
            let profile = try? await api.send(AuthAPI.me()).user
            let membership = try await membershipCall.membership
            if let m = membership {
                form = MembershipForm(
                    fullName: m.fullName ?? "", pronouns: m.pronouns ?? "", enrolledUniversity: m.enrolledUniversity ?? "",
                    yearInSchool: m.yearInSchool ?? "", state: m.state ?? "", city: m.city ?? "", major: m.major ?? "",
                    expectedGraduation: m.expectedGraduation ?? "", email: m.email ?? profile?.schoolEmail ?? "",
                    socialMedia: m.socialMedia ?? "", phone: m.phone ?? "", careerInterests: m.careerInterests ?? [],
                    careerInterestsOther: m.careerInterestsOther ?? "", amsaInterests: m.amsaInterests ?? [],
                    amsaInterestsOther: m.amsaInterestsOther ?? "", mentorshipInterest: m.mentorshipInterest ?? "",
                    eventIdeas: m.eventIdeas ?? "", heardAboutAmsa: m.heardAboutAmsa ?? "",
                    heardAboutAmsaOther: m.heardAboutAmsaOther ?? "", agreesToEmails: m.agreesToEmails ?? false)
                reviewStatus = m.reviewStatus ?? "pending"
            } else {
                // First-time applicant: pre-fill from the profile.
                let user = session.user
                form.fullName = "\(user?.firstName ?? "") \(user?.lastName ?? "")".trimmed
                form.enrolledUniversity = profile?.schoolName ?? ""
                form.yearInSchool = MembershipOptions.yearInSchool.contains(profile?.schoolYear ?? "") ? (profile?.schoolYear ?? "") : ""
                form.major = profile?.major ?? ""
                form.expectedGraduation = profile?.graduationYear?.value ?? ""
                form.state = profile?.state ?? ""
                form.city = profile?.city ?? ""
                form.email = profile?.schoolEmail ?? ""
                form.phone = profile?.phoneNumber ?? ""
                form.socialMedia = MembershipOptions.instagramHandle(profile?.instagram)
            }
        } catch let e {
            error = e.apiMessage ?? "Failed to load US Member application."
        }
        loadingForm = false
    }

    private func scheduleEmailCheck() {
        guard !isLocked, !loadingForm else { return }
        checkTask?.cancel()
        let email = form.email.trimmed.lowercased()
        guard email.contains("@"), email.hasSuffix(".edu") else {
            emailCheck = nil
            checkingEmail = false
            return
        }
        checkingEmail = true
        let name = form.enrolledUniversity.trimmed
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let result = try? await session.api.send(MembershipAPI.match(email: email, name: name))
            guard !Task.isCancelled else { return }
            emailCheck = result
            checkingEmail = false
        }
    }

    /// Browser constraint validation, in DOM order (Safari's wording).
    private func firstInvalid() -> (Field, String)? {
        let required: [(Field, String)] = [
            (.fullName, form.fullName), (.enrolledUniversity, form.enrolledUniversity), (.yearInSchool, form.yearInSchool),
            (.state, form.state), (.city, form.city), (.major, form.major), (.expectedGraduation, form.expectedGraduation),
            (.email, form.email), (.phone, form.phone),
        ] + (requiresCareerOther ? [(.careerOther, form.careerInterestsOther)] : [])
          + (requiresAmsaOther ? [(.amsaOther, form.amsaInterestsOther)] : [])
          + [(.mentorship, form.mentorshipInterest), (.heardAbout, form.heardAboutAmsa)]
          + (requiresHeardOther ? [(.heardOther, form.heardAboutAmsaOther)] : [])
        let selects: Set<Field> = [.yearInSchool, .mentorship, .heardAbout]
        for (field, value) in required {
            if value.isEmpty { return (field, selects.contains(field) ? "Select an item in the list." : "Fill out this field") }
            if field == .email, !AuthValidation.isValidEmail(value.trimmed) { return (field, "Enter an email address") }
        }
        return nil
    }

    private func submit(_ proxy: ScrollViewProxy) {
        guard !isLocked else { return }
        if let (field, message) = firstInvalid() {
            invalid = (field, message)
            withAnimation { proxy.scrollTo(field, anchor: .center) }
            return
        }
        if !form.email.lowercased().hasSuffix(".edu") {
            error = "Please enter a valid school email address ending in .edu"
            return
        }
        if emailCheck?.status == "mismatch", let college = emailCheck?.college {
            error = "Your school email belongs to \(college.name), but you entered \"\(form.enrolledUniversity)\". Please use an email from that university or correct the university name."
            return
        }
        submitting = true
        error = ""
        success = ""
        var payload = form
        if !requiresCareerOther { payload.careerInterestsOther = "" }
        if !requiresAmsaOther { payload.amsaInterestsOther = "" }
        if !requiresHeardOther { payload.heardAboutAmsaOther = "" }
        Task {
            do {
                let data = try await session.api.send(MembershipAPI.submit(payload))
                reviewStatus = data.membership?.reviewStatus ?? "pending"
                if let university = data.membership?.enrolledUniversity, !university.isEmpty {
                    form.enrolledUniversity = university
                }
                shell.invalidate()
                success = "US Member application submitted. Admins can now review your application."
            } catch let e {
                error = e.apiMessage ?? "Failed to submit US Member application."
            }
            submitting = false
        }
    }
}
