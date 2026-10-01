import SwiftUI

// Modals from src/app/(dashboard)/welcome/page.tsx (rendered inside `.dashboard`: buttons use 4px radii).

/// `relative w-full max-w-* bg-white rounded-2xl flex flex-col max-h-[..vh] shadow-2xl overflow-hidden`
/// with a `px-6 py-4 border-b` header and a `px-6 py-4 border-t` footer.
struct ModalShell<Content: View, Footer: View>: View {
    let title: String
    var maxWidth: CGFloat = 512
    var maxHeightFraction: CGFloat = 0.9
    let onClose: () -> Void
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer()
                Button(action: onClose) { Icon("close", size: 20).foregroundStyle(Palette.gray400).padding(8) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .bottomBorder(Palette.gray100, width: 1)

            FittingScrollView { content.padding(.horizontal, 24).padding(.vertical, 20) }

            HStack(spacing: 12) { footer }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Palette.white)
                .topBorder(Palette.gray100, width: 1)
        }
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: TW.radius2xl))
        .twShadow(.x2l)
        .frame(maxWidth: maxWidth)
        .maxHeight(viewportFraction: maxHeightFraction)
    }
}

/// Footer buttons shared by the profile modals.
struct ModalCancelButton: View {
    let disabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Cancel").tw(.sm, .medium).foregroundStyle(Palette.gray600)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

struct ModalSaveButton: View {
    let title: String
    let saving: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if saving {
                    Spinner(size: 16)
                    Text("Saving…")
                } else {
                    Text(title)
                }
            }
            .tw(.sm, .semibold)
            .foregroundStyle(Palette.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).fill(Palette.navy))
        }
        .buttonStyle(.plain)
        .disabled(saving)
        .opacity(saving ? 0.5 : 1)
    }
}

/// `text-sm font-semibold text-gray-700` label above a control (`flex flex-col gap-1`).
struct LabeledField<Content: View>: View {
    let label: String
    var style: Style = .normal
    var required = false
    @ViewBuilder let content: Content

    enum Style { case normal, caps }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                switch style {
                case .normal:
                    Text(label).tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                case .caps:
                    (Text(label.uppercased()) + Text(required ? " *" : "").foregroundColor(Palette.red400))
                        .tw(.xs, .semibold, tracking: .wide)
                        .foregroundStyle(Palette.gray500)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `<select>` with a leading empty option (`appearance-none` → no arrow).
struct OptionSelect: View {
    let placeholder: String
    let options: [String]
    @Binding var selection: String
    var disabled: Bool = false

    var body: some View {
        WebSelect(options: [(placeholder, "")] + options.map { ($0, $0) }, selection: $selection, style: .modal, disabled: disabled)
    }
}

// MARK: - Edit Profile

struct EditProfileModal: View {
    let profile: UserProfile
    @Binding var isPresented: Bool
    let onSaved: (UserProfile) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.supabaseStorage) private var storage

    @State private var firstName: String
    @State private var lastName: String
    @State private var headline: String
    @State private var bio: String
    @State private var profilePic: String
    @State private var schoolName: String
    @State private var schoolEmail: String
    @State private var degreeLevel: String
    @State private var schoolYear: String
    @State private var graduationYear: String
    @State private var x: String
    @State private var facebook: String
    @State private var instagram: String
    @State private var linkedin: String
    @State private var majorValues: [String]
    @State private var saving = false
    @State private var saveError = ""
    @State private var avatarFile: PickedImage?
    @State private var avatarRemoved = false
    @State private var avatarError = ""
    @State private var suggestionsOpen = false
    @State private var suggestions: [CollegeSearchResponse.College] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var schoolFocused = false

    init(profile: UserProfile, isPresented: Binding<Bool>, onSaved: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self._isPresented = isPresented
        self.onSaved = onSaved
        let majors = ProfileOptions.parseMajors(profile.major)
        _firstName = State(initialValue: profile.firstName ?? "")
        _lastName = State(initialValue: profile.lastName ?? "")
        _headline = State(initialValue: profile.headline ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _profilePic = State(initialValue: profile.profilePic ?? "")
        _schoolName = State(initialValue: profile.schoolName ?? "")
        _schoolEmail = State(initialValue: profile.schoolEmail ?? "")
        _degreeLevel = State(initialValue: profile.degreeLevel ?? "")
        _schoolYear = State(initialValue: profile.schoolYear ?? "")
        _graduationYear = State(initialValue: profile.graduationYear?.value ?? "")
        _x = State(initialValue: profile.x ?? "")
        _facebook = State(initialValue: profile.facebook ?? "")
        _instagram = State(initialValue: profile.instagram ?? "")
        _linkedin = State(initialValue: profile.linkedin ?? "")
        _majorValues = State(initialValue: majors.isEmpty ? [""] : majors)
    }

    var body: some View {
        ModalShell(title: "Edit Profile", maxWidth: 672, maxHeightFraction: 0.92, onClose: close) {
            VStack(alignment: .leading, spacing: 20) {
                photoSection
                basicInfo
                educationSection.zIndex(1)
                socialLinks
                Color.clear.frame(height: 8)
            }
        } footer: {
            if !saveError.isEmpty {
                Text(saveError).tw(.sm).foregroundStyle(Palette.red500).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            ModalCancelButton(disabled: saving, action: close)
            ModalSaveButton(title: "Save changes", saving: saving, action: save)
        }
    }

    private func close() { if !saving { isPresented = false } }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).tw(.base, .bold).foregroundStyle(Palette.gray900).padding(.bottom, 12)
    }

    // MARK: Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Profile Photo")
            HStack(spacing: 16) {
                ImagePickerButton(onPick: pickAvatar) {
                    // A `rounded-full` <button> inside `.dashboard` renders with 4px corners.
                    ZStack {
                        Palette.gold
                        if let avatarFile {
                            Image(uiImage: avatarFile.image).resizable().scaledToFill()
                        } else if !avatarRemoved, !profilePic.isEmpty {
                            RemoteImage(profilePic) { phase in
                                if let image = phase.image { Image(uiImage: image).resizable().scaledToFill() }
                            }
                        } else {
                            Text(session.user?.initials ?? "").tw(.xl, .bold).foregroundStyle(Palette.navy)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius))
                    .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius).strokeBorder(Palette.gray200, lineWidth: 2))
                }
                .accessibilityLabel("Change photo")

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ImagePickerButton(onPick: pickAvatar) {
                            Text(avatarFile != nil ? "Change photo" : "Upload photo")
                                .tw(.sm, .medium).foregroundStyle(Palette.navy)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                    .strokeBorder(Palette.navy.opacity(0.2), lineWidth: 1))
                        }
                        if avatarFile != nil || (!avatarRemoved && !profilePic.isEmpty) {
                            Button {
                                avatarFile = nil
                                avatarRemoved = true
                                avatarError = ""
                            } label: {
                                Text("Remove").tw(.sm, .medium).foregroundStyle(Palette.red500)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .overlay(RoundedRectangle(cornerRadius: TW.dashboardButtonRadius)
                                        .strokeBorder(Palette.red200, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let avatarFile {
                        Text("photo.jpg · \(Int((Double(avatarFile.byteCount) / 1024).rounded())) KB")
                            .tw(.xs).foregroundStyle(Palette.gray500).lineLimit(1)
                    } else if avatarRemoved {
                        Text("Photo will be removed on save").tw(.xs).foregroundStyle(Palette.red400)
                    } else {
                        Text("JPG, PNG — max 5 MB").tw(.xs).foregroundStyle(Palette.gray400)
                    }
                    if !avatarError.isEmpty { Text(avatarError).tw(.xs).foregroundStyle(Palette.red500) }
                }
            }
        }
    }

    private func pickAvatar(_ picked: PickedImage) {
        // welcome/page.tsx compresses to a 400px longest side, JPEG 0.8 before upload.
        guard let data = ImageEncoding.avatarJPEG(picked.image) else {
            avatarError = "Please select an image file."
            return
        }
        if picked.byteCount > 5 * 1024 * 1024, data.count > 5 * 1024 * 1024 {
            avatarError = "Image must be under 5 MB."
            return
        }
        avatarError = ""
        avatarFile = PickedImage(image: UIImage(data: data) ?? picked.image, data: data)
    }

    // MARK: Basic info

    private var basicInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Basic Info")
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "First Name") { WebTextField(placeholder: "First Name", text: $firstName, autocapitalization: .words) }
                    LabeledField(label: "Last Name") { WebTextField(placeholder: "Last Name", text: $lastName, autocapitalization: .words) }
                }
                LabeledField(label: "Custom Header") {
                    WebTextField(placeholder: "e.g. Computer Science @ UMD", text: $headline, maxLength: 140)
                }
                LabeledField(label: "About / Bio") {
                    WebTextArea(placeholder: "Tell the community about yourself…", text: $bio, rows: 3)
                }
            }
        }
    }

    // MARK: Education

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Education")
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("School Name").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                    WebTextField(placeholder: "Search your university…", text: $schoolName, autocapitalization: .words,
                                 onFocusChange: { schoolFocused = $0 })
                        .overlay(alignment: .topLeading) {
                            if suggestionsOpen, !suggestions.isEmpty { suggestionList.offset(y: 44) }
                        }
                        .zIndex(1)
                    Text("Live search across all universities.").tw(.px(11)).foregroundStyle(Palette.gray400)
                }
                .zIndex(1)

                // `grid grid-cols-2 gap-3`: Degree Level | (empty), Major(s) spans both, School Year | Graduation Year.
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Degree Level") {
                        OptionSelect(placeholder: "Select…", options: ProfileOptions.degreeLevels, selection: $degreeLevel)
                    }
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                }
                majorsField
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "School Year") {
                        OptionSelect(placeholder: "Select…", options: ProfileOptions.schoolYears, selection: $schoolYear)
                    }
                    LabeledField(label: "Graduation Year") { WebTextField(placeholder: "2026", text: $graduationYear) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    (Text("School Email ") + Text("(e.g. you@umd.edu)").font(.custom(TW.Weight.normal.fontName, fixedSize: 14))
                        .foregroundColor(Palette.gray400))
                        .tw(.sm, .semibold)
                        .foregroundStyle(Palette.gray700)
                    WebTextField(placeholder: "your.name@university.edu", text: $schoolEmail, keyboard: .emailAddress,
                                 autocapitalization: .never)
                    Text("Used to show the correct school logo. Not visible to other members.")
                        .tw(.px(11)).foregroundStyle(Palette.gray400)
                }
            }
        }
        .onChange(of: schoolName) { _, _ in
            scheduleSchoolSearch()
            if schoolFocused { suggestionsOpen = true }
        }
        .onChange(of: schoolFocused) { _, focused in
            if focused {
                suggestionsOpen = true
            } else {
                // `onBlur={() => setTimeout(() => setSchoolSuggestionsOpen(false), 120)}`
                Task {
                    try? await Task.sleep(for: .milliseconds(120))
                    suggestionsOpen = false
                }
            }
        }
    }

    private var majorsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Major(s)").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                Spacer()
                HStack(spacing: 8) {
                    if majorValues.count > 1 {
                        Button { majorValues.removeLast() } label: {
                            Text("Remove").tw(.xs, .medium).foregroundStyle(Palette.gray500)
                        }
                        .buttonStyle(.plain)
                    }
                    if majorValues.count < 3 {
                        Button { majorValues.append("") } label: {
                            Text("+ Add major").tw(.xs, .medium).foregroundStyle(Palette.navy)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ForEach(majorValues.indices, id: \.self) { index in
                WebTextField(placeholder: "Major \(index + 1)", text: Binding(
                    get: { index < majorValues.count ? majorValues[index] : "" },
                    set: { if index < majorValues.count { majorValues[index] = $0 } }
                ), autocapitalization: .words)
            }
        }
    }

    private var suggestionList: some View {
        FittingScrollView {
            VStack(spacing: 0) {
                ForEach(suggestions) { college in
                    Button {
                        schoolName = college.name
                        suggestionsOpen = false
                    } label: {
                        HStack(spacing: 10) {
                            SuggestionLogo(domain: college.domain, name: college.name)
                            Text(college.name).tw(.sm).foregroundStyle(Palette.gray700).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 256)
        .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radiusXl))
        .overlay(RoundedRectangle(cornerRadius: TW.radiusXl).strokeBorder(Palette.gray200, lineWidth: 1))
        .twShadow(.lg)
    }

    private func scheduleSchoolSearch() {
        searchTask?.cancel()
        let q = schoolName.trimmed
        guard q.count >= 2 else { suggestions = []; return }
        let api = session.api
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if let data = try? await api.send(ProfileAPI.searchColleges(q)), !Task.isCancelled {
                suggestions = data.colleges ?? []
            }
        }
    }

    // MARK: Social links

    private var socialLinks: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Social Links")
            VStack(spacing: 12) {
                socialRow(icon: "brand-x", color: Palette.black, placeholder: "https://x.com/…", text: $x)
                socialRow(icon: "brand-facebook", color: Palette.blue600, placeholder: "https://facebook.com/…", text: $facebook)
                socialRow(icon: "brand-instagram", color: Palette.pink500, placeholder: "https://instagram.com/…", text: $instagram)
                socialRow(icon: "brand-linkedin", color: Palette.blue700, placeholder: "https://linkedin.com/in/…", text: $linkedin)
            }
        }
    }

    private func socialRow(icon: String, color: Color, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Icon(icon, size: 20).foregroundStyle(color).frame(width: 24, alignment: .leading)
            WebTextField(placeholder: placeholder, text: text, keyboard: .URL, autocapitalization: .never)
        }
    }

    // MARK: Save

    private func save() {
        guard let user = session.user else { return }
        saving = true
        saveError = ""
        Task {
            do {
                var uploadedUrl = profilePic
                let oldUrl = profilePic
                if let avatarFile {
                    let path = UploadPath.avatar(userId: user.id)
                    do {
                        uploadedUrl = try await storage.upload(avatarFile.data, bucket: .avatars, path: path, contentType: "image/jpeg")
                    } catch {
                        throw SupabaseStorage.UploadError(message: "Photo upload failed: \(error.localizedDescription)")
                    }
                    if !oldUrl.isEmpty, let old = SupabaseStorage.avatarPath(fromPublicURL: oldUrl) {
                        await storage.remove(bucket: .avatars, paths: [old])
                    }
                } else if avatarRemoved {
                    uploadedUrl = ""
                    if !oldUrl.isEmpty, let old = SupabaseStorage.avatarPath(fromPublicURL: oldUrl) {
                        await storage.remove(bucket: .avatars, paths: [old])
                    }
                }
                let fields: [String: JSONValue] = [
                    "firstName": .string(firstName), "lastName": .string(lastName), "headline": .string(headline),
                    "bio": .string(bio), "profilePic": .string(uploadedUrl), "schoolName": .string(schoolName),
                    "schoolEmail": .string(schoolEmail), "degreeLevel": .string(degreeLevel),
                    "major": .string(ProfileOptions.serializeMajors(majorValues)), "schoolYear": .string(schoolYear),
                    "graduationYear": .string(graduationYear), "x": .string(x), "facebook": .string(facebook),
                    "instagram": .string(instagram), "linkedin": .string(linkedin),
                ]
                let data = try await session.api.send(UserAPI.updateProfile(fields))
                onSaved(data.user)
                session.updateUser { u in
                    u.firstName = data.user.firstName ?? u.firstName
                    u.lastName = data.user.lastName ?? u.lastName
                    u.bio = data.user.bio
                    u.profilePic = data.user.profilePic
                }
                isPresented = false
            } catch let e as SupabaseStorage.UploadError {
                saveError = e.message
            } catch let e {
                saveError = e.apiMessage ?? "Failed to save. Please try again."
            }
            saving = false
        }
    }
}

private struct SuggestionLogo: View {
    let domain: String?
    let name: String
    @State private var failed = false

    var body: some View {
        if let domain, !failed, let url = LogoLookup.logoURL(domain: domain, token: AppConfig.current.logoDevToken) {
            RemoteImage(url: url) { phase in
                switch phase {
                case .success(let image): Image(uiImage: image).resizable().scaledToFit()
                case .failure: Color.clear.onAppear { failed = true }
                case .loading: Color.clear
                }
            }
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: TW.radiusSm).fill(Palette.white))
            .overlay(RoundedRectangle(cornerRadius: TW.radiusSm).strokeBorder(Palette.gray100, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: TW.radiusSm))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: TW.radiusSm).fill(Palette.navy.opacity(0.1))
                Icon("logo-school", size: 16).foregroundStyle(Palette.navy)
            }
            .frame(width: 28, height: 28)
        }
    }
}

// MARK: - Experience modal

struct ExperienceModalState: Identifiable {
    let id = UUID()
    let editing: Experience?
}

enum ProfileRowResult<T> {
    case saved(T)
    case deleted(Int)
}

struct ExperienceModal: View {
    let state: ExperienceModalState
    @Binding var isPresented: Bool
    let onResult: (ProfileRowResult<Experience>) -> Void

    @Environment(SessionStore.self) private var session

    @State private var jobTitle: String
    @State private var company: String
    @State private var companyUrl: String
    @State private var employmentType: String
    @State private var startMonth: String
    @State private var startYear: String
    @State private var endMonth: String
    @State private var endYear: String
    @State private var currentlyWorking: Bool
    @State private var location: String
    @State private var description: String
    @State private var saving = false
    @State private var error = ""

    init(state: ExperienceModalState, isPresented: Binding<Bool>, onResult: @escaping (ProfileRowResult<Experience>) -> Void) {
        self.state = state
        self._isPresented = isPresented
        self.onResult = onResult
        let e = state.editing
        _jobTitle = State(initialValue: e?.jobTitle ?? "")
        _company = State(initialValue: e?.company ?? "")
        _companyUrl = State(initialValue: e?.companyUrl ?? "")
        _employmentType = State(initialValue: e?.employmentType ?? "")
        _startMonth = State(initialValue: e?.startMonth ?? "")
        _startYear = State(initialValue: e?.startYear?.value ?? "")
        _endMonth = State(initialValue: e?.endMonth ?? "")
        _endYear = State(initialValue: e?.endYear?.value ?? "")
        _currentlyWorking = State(initialValue: e?.currentlyWorking ?? false)
        _location = State(initialValue: e?.location ?? "")
        _description = State(initialValue: e?.description ?? "")
    }

    var body: some View {
        ModalShell(title: state.editing != nil ? "Edit Experience" : "Add Experience", onClose: close) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Job Title", style: .caps, required: true) {
                        WebTextField(placeholder: "e.g. Software Engineer Intern", text: $jobTitle, autocapitalization: .words)
                    }
                    LabeledField(label: "Company", style: .caps, required: true) {
                        WebTextField(placeholder: "e.g. Google", text: $company, autocapitalization: .words)
                    }
                }
                LabeledField(label: "Company Website", style: .caps) {
                    WebTextField(placeholder: "e.g. google.com — used for the logo", text: $companyUrl, keyboard: .URL,
                                 autocapitalization: .never)
                }
                LabeledField(label: "Employment Type", style: .caps) {
                    OptionSelect(placeholder: "Select type…", options: ProfileOptions.employmentTypes, selection: $employmentType)
                }
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Start Month", style: .caps, required: true) {
                        OptionSelect(placeholder: "Month", options: ProfileOptions.months, selection: $startMonth)
                    }
                    LabeledField(label: "Start Year", style: .caps, required: true) {
                        OptionSelect(placeholder: "Year", options: ProfileOptions.years, selection: $startYear)
                    }
                }
                HStack(spacing: 10) {
                    WebCheckbox(isOn: Binding(get: { currentlyWorking }, set: {
                        currentlyWorking = $0
                        endMonth = ""
                        endYear = ""
                    }))
                    Text("I currently work here").tw(.sm).foregroundStyle(Palette.gray700)
                        .onTapGesture { currentlyWorking.toggle(); endMonth = ""; endYear = "" }
                }
                if !currentlyWorking {
                    HStack(alignment: .top, spacing: 12) {
                        LabeledField(label: "End Month", style: .caps) {
                            OptionSelect(placeholder: "Month", options: ProfileOptions.months, selection: $endMonth)
                        }
                        LabeledField(label: "End Year", style: .caps) {
                            OptionSelect(placeholder: "Year", options: ProfileOptions.years, selection: $endYear)
                        }
                    }
                }
                LabeledField(label: "Location", style: .caps) {
                    WebTextField(placeholder: "e.g. New York, NY · Remote", text: $location, autocapitalization: .words)
                }
                LabeledField(label: "Description", style: .caps) {
                    WebTextArea(placeholder: "Describe your role, responsibilities, and impact…", text: $description, rows: 4)
                }
                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red500) }
            }
        } footer: {
            if let editing = state.editing {
                Button {
                    delete(editing.id)
                    isPresented = false
                } label: { Text("Delete").tw(.sm, .medium).foregroundStyle(Palette.red500) }
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            ModalCancelButton(disabled: saving, action: close)
            ModalSaveButton(title: state.editing != nil ? "Save changes" : "Add experience", saving: saving, action: save)
        }
    }

    private func close() { if !saving { isPresented = false } }

    private func save() {
        guard !jobTitle.trimmed.isEmpty, !company.trimmed.isEmpty, !startMonth.isEmpty, !startYear.isEmpty else {
            error = "Job title, company, start month, and start year are required."
            return
        }
        saving = true
        error = ""
        let body: [String: JSONValue] = [
            "jobTitle": .string(jobTitle), "company": .string(company), "companyUrl": .string(companyUrl),
            "employmentType": .string(employmentType), "startMonth": .string(startMonth), "startYear": .string(startYear),
            "endMonth": .string(endMonth), "endYear": .string(endYear), "currentlyWorking": .bool(currentlyWorking),
            "location": .string(location), "description": .string(description),
        ]
        Task {
            do {
                let result: Experience
                if let editing = state.editing {
                    result = try await session.api.send(ProfileAPI.updateExperience(editing.id, body)).experience
                } else {
                    result = try await session.api.send(ProfileAPI.createExperience(body)).experience
                }
                onResult(.saved(result))
                isPresented = false
            } catch {
                self.error = "Failed to save. Please try again."
            }
            saving = false
        }
    }

    private func delete(_ id: Int) {
        let api = session.api
        Task {
            if (try? await api.send(ProfileAPI.deleteExperience(id))) != nil { onResult(.deleted(id)) }
        }
    }
}

// MARK: - Education modal

struct EducationModalState: Identifiable {
    let id = UUID()
    let editing: Education?
}

struct EducationModal: View {
    let state: EducationModalState
    @Binding var isPresented: Bool
    let onResult: (ProfileRowResult<Education>) -> Void

    @Environment(SessionStore.self) private var session

    @State private var schoolName: String
    @State private var degreeLevel: String
    @State private var major: String
    @State private var schoolYear: String
    @State private var graduationYear: String
    @State private var currentlyEnrolled: Bool
    @State private var saving = false
    @State private var error = ""

    init(state: EducationModalState, isPresented: Binding<Bool>, onResult: @escaping (ProfileRowResult<Education>) -> Void) {
        self.state = state
        self._isPresented = isPresented
        self.onResult = onResult
        let e = state.editing
        _schoolName = State(initialValue: e?.schoolName ?? "")
        _degreeLevel = State(initialValue: e?.degreeLevel ?? "")
        _major = State(initialValue: e?.major ?? "")
        _schoolYear = State(initialValue: e?.schoolYear ?? "")
        _graduationYear = State(initialValue: e?.graduationYear?.value ?? "")
        _currentlyEnrolled = State(initialValue: e?.currentlyEnrolled ?? false)
    }

    var body: some View {
        ModalShell(title: state.editing != nil ? "Edit Education" : "Add Education", onClose: close) {
            VStack(alignment: .leading, spacing: 16) {
                LabeledField(label: "School Name", style: .caps, required: true) {
                    WebTextField(placeholder: "e.g. University of Minnesota", text: $schoolName, autocapitalization: .words)
                }
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Degree", style: .caps) {
                        OptionSelect(placeholder: "Select…", options: ProfileOptions.educationDegrees, selection: $degreeLevel)
                    }
                    LabeledField(label: "Major / Field", style: .caps) {
                        WebTextField(placeholder: "e.g. Computer Science", text: $major, autocapitalization: .words)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Year", style: .caps) {
                        OptionSelect(placeholder: "Select…", options: ProfileOptions.educationYears, selection: $schoolYear)
                    }
                    LabeledField(label: "Graduation Year", style: .caps) {
                        OptionSelect(placeholder: "Year", options: ProfileOptions.years, selection: $graduationYear,
                                     disabled: currentlyEnrolled)
                    }
                }
                HStack(spacing: 10) {
                    WebCheckbox(isOn: Binding(get: { currentlyEnrolled }, set: {
                        currentlyEnrolled = $0
                        graduationYear = ""
                    }))
                    Text("I currently study here").tw(.sm).foregroundStyle(Palette.gray700)
                        .onTapGesture { currentlyEnrolled.toggle(); graduationYear = "" }
                }
                if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red500) }
            }
        } footer: {
            if let editing = state.editing {
                Button {
                    delete(editing.id)
                    isPresented = false
                } label: { Text("Delete").tw(.sm, .medium).foregroundStyle(Palette.red500) }
                    .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            ModalCancelButton(disabled: saving, action: close)
            ModalSaveButton(title: state.editing != nil ? "Save changes" : "Add education", saving: saving, action: save)
        }
    }

    private func close() { if !saving { isPresented = false } }

    private func save() {
        guard !schoolName.trimmed.isEmpty else { error = "School name is required."; return }
        saving = true
        error = ""
        let body: [String: JSONValue] = [
            "schoolName": .string(schoolName), "degreeLevel": .string(degreeLevel), "major": .string(major),
            "schoolYear": .string(schoolYear), "graduationYear": .string(graduationYear),
            "currentlyEnrolled": .bool(currentlyEnrolled),
        ]
        Task {
            do {
                let result: Education
                if let editing = state.editing {
                    result = try await session.api.send(ProfileAPI.updateEducation(editing.id, body)).education
                } else {
                    result = try await session.api.send(ProfileAPI.createEducation(body)).education
                }
                onResult(.saved(result))
                isPresented = false
            } catch {
                self.error = "Failed to save. Please try again."
            }
            saving = false
        }
    }

    private func delete(_ id: Int) {
        let api = session.api
        Task {
            if (try? await api.send(ProfileAPI.deleteEducation(id))) != nil { onResult(.deleted(id)) }
        }
    }
}
