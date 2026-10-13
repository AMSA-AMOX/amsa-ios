import SwiftUI

/// GET /api/auth/me, reading only whether the member has agreed to the Terms. A server that predates
/// Terms acceptance omits the key, so members are only asked once the website supports it.
private struct TermsStatus: Decodable, Sendable {
    /// `.some(nil)` = not accepted yet; `nil` = the server doesn't track it.
    let acceptedAt: String??

    private enum RootKey: String, CodingKey { case user }
    private enum UserKey: String, CodingKey { case termsAcceptedAt }

    init(from decoder: Decoder) throws {
        let user = try decoder.container(keyedBy: RootKey.self).nestedContainer(keyedBy: UserKey.self, forKey: .user)
        acceptedAt = user.contains(.termsAcceptedAt)
            ? .some(try user.decodeIfPresent(String.self, forKey: .termsAcceptedAt))
            : nil
    }
}

extension View {
    /// Asks members who signed up before the signup checkbox existed to agree to the Terms, once.
    func termsGate() -> some View { modifier(TermsGateModifier()) }
}

private struct TermsGateModifier: ViewModifier {
    @Environment(SessionStore.self) private var session
    @State private var needsTerms = false

    func body(content: Content) -> some View {
        content
            .task(id: session.user?.id) { await check() }
            .fullScreenCover(isPresented: $needsTerms) {
                TermsGateView { needsTerms = false }
            }
    }

    private func check() async {
        guard let user = session.user, user.termsAcceptedAt == nil else { return }
        let endpoint = Endpoint<TermsStatus>(path: "/api/auth/me")
        guard let status = try? await session.api.send(endpoint) else { return }
        switch status.acceptedAt {
        case .some(.some(let acceptedAt)): session.updateUser { $0.termsAcceptedAt = acceptedAt }
        case .some(.none): needsTerms = true
        case .none: break
        }
    }
}

private struct TermsGateView: View {
    let onAccepted: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(ExternalLinkPresenter.self) private var links
    @State private var saving = false
    @State private var error = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Palette.navy)
            Text("Before you continue").tw(.x2l, .bold).foregroundStyle(Palette.navy)
            Text("AMSA is a community for students. To keep it safe, please agree to our Terms of Use. There is no tolerance for objectionable content or abusive members: you can report anything that breaks the rules, block members, and moderators act on reports within 24 hours.")
                .tw(.base, leading: .relaxed).foregroundStyle(Palette.gray700)
            VStack(alignment: .leading, spacing: 10) {
                linkRow("Terms of Use", url: AppConfig.current.termsURL)
                linkRow("Privacy Policy", url: AppConfig.current.privacyPolicyURL)
            }
            if !error.isEmpty { Text(error).tw(.sm).foregroundStyle(Palette.red600) }
            Spacer(minLength: 0)
            Button(action: accept) {
                Text(saving ? "Saving…" : "I agree").tw(.base, .semibold).foregroundStyle(Palette.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Palette.navy))
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .opacity(saving ? 0.6 : 1)
            Button { session.logout() } label: {
                Text("Sign out").tw(.sm, .semibold).foregroundStyle(Palette.gray500).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(saving)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.gray50)
        .interactiveDismissDisabled()
    }

    private func linkRow(_ title: String, url: URL) -> some View {
        Button { links.open(url) } label: {
            HStack(spacing: 6) {
                Text(title).tw(.base, .semibold)
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Palette.navy)
        }
        .buttonStyle(.plain)
    }

    private func accept() {
        saving = true
        error = ""
        Task {
            do {
                let response = try await session.api.send(SafetyAPI.acceptTerms())
                session.updateUser { $0.termsAcceptedAt = response.termsAcceptedAt ?? ISODate.string(from: .now) }
                onAccepted()
            } catch let e {
                error = e.apiMessage ?? "Couldn't save. Please try again."
            }
            saving = false
        }
    }
}
