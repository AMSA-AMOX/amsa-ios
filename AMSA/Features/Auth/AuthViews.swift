import SwiftUI

/// Login ↔ Signup ↔ Forgot password, navigated like the web's page links.
struct AuthFlowView: View {
    enum Screen { case login, signup, forgot }
    @State private var screen: Screen = .login

    var body: some View {
        Group {
            switch screen {
            case .login: LoginView(go: { screen = $0 })
            case .signup: SignupView(go: { screen = $0 })
            case .forgot: ForgotPasswordView(go: { screen = $0 })
            }
        }
        .background(Palette.white.ignoresSafeArea())
    }
}

// Port of src/app/(main)/login/page.tsx
struct LoginView: View {
    let go: (AuthFlowView.Screen) -> Void
    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error = ""
    @State private var loading = false
    @FocusState private var focus: AuthField.ID?

    var body: some View {
        AuthCard(title: "Welcome back", subtitle: "Sign in to your AMSA account") {
            VStack(alignment: .leading, spacing: 20) {
                if !error.isEmpty { AuthErrorBox(text: error) }
                else if session.endedByExpiry { AuthErrorBox(text: "Your session has expired. Please sign in again.") }

                AuthField(id: .email, label: "Email", placeholder: "your@email.com", text: $email, focus: $focus,
                          keyboard: .emailAddress, contentType: .username)

                VStack(alignment: .leading, spacing: 4) {
                    AuthPasswordField(label: "Password", placeholder: "••••••••", text: $password,
                                      show: $showPassword, focus: $focus, contentType: .password)
                    HStack {
                        Spacer()
                        Button("Forgot password?") { go(.forgot) }
                            .tw(.sm, .medium)
                            .foregroundStyle(Palette.navy)
                    }
                }

                AuthPrimaryButton(title: loading ? "Signing in…" : "Sign in", disabled: loading, action: submit)
                    .padding(.top, 8)

                AuthFooter(prompt: "Don't have an account?", link: "Register") { go(.signup) }
            }
        }
    }

    private func submit() {
        // `type=email` values are whitespace-trimmed by the browser before validation/submission.
        let email = self.email.trimmed
        // Native `required` / `type=email` validation (iOS Safari bubble copy).
        if let (field, message) = AuthValidation.check([(.email, email, true), (.password, password, false)]) {
            focus = field
            error = message
            return
        }
        error = ""
        loading = true
        Task {
            do {
                _ = try await session.login(email: email, password: password)
            } catch let e {
                let message = e.apiMessage ?? ""
                error = message.isEmpty ? "Login failed" : message
            }
            loading = false
        }
    }
}

// Port of src/app/(main)/signup/member/page.tsx
struct SignupView: View {
    let go: (AuthFlowView.Screen) -> Void
    @Environment(SessionStore.self) private var session

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var turnstileToken: String?
    @State private var turnstileReset = 0
    @State private var error = ""
    @State private var loading = false
    @FocusState private var focus: AuthField.ID?

    var body: some View {
        AuthCard(title: "Create an account", subtitle: "Join the AMSA community") {
            VStack(alignment: .leading, spacing: 20) {
                if !error.isEmpty { AuthErrorBox(text: error) }

                HStack(alignment: .top, spacing: 12) {
                    AuthField(id: .firstName, label: "First Name", placeholder: "First", text: $firstName, focus: $focus,
                              contentType: .givenName, autocapitalization: .words)
                    AuthField(id: .lastName, label: "Last Name", placeholder: "Last", text: $lastName, focus: $focus,
                              contentType: .familyName, autocapitalization: .words)
                }

                AuthField(id: .email, label: "Email", placeholder: "you@example.com", text: $email, focus: $focus,
                          keyboard: .emailAddress, contentType: .emailAddress)

                AuthPasswordField(label: "Password", placeholder: "password", text: $password, show: $showPassword,
                                  focus: $focus, contentType: .newPassword)

                // @marsidev/react-turnstile "normal" widget: 300×65.
                TurnstileView(
                    siteKey: AppConfig.current.turnstileSiteKey,
                    baseURL: AppConfig.current.apiBaseURL,
                    resetCount: turnstileReset,
                    onSuccess: { turnstileToken = $0 },
                    onExpire: { turnstileToken = nil },
                    onError: {
                        turnstileToken = nil
                        error = "Security check failed. Please refresh and try again."
                    }
                )
                .frame(width: 300, height: 65)

                AuthPrimaryButton(title: loading ? "Creating account…" : "Create Account",
                                  disabled: loading || turnstileToken == nil, action: submit)
                    .padding(.top, 8)

                AuthFooter(prompt: "Already have an account?", link: "Sign in") { go(.login) }
            }
        }
    }

    private func submit() {
        let email = self.email.trimmed
        if let (field, message) = AuthValidation.check(
            [(.firstName, firstName, false), (.lastName, lastName, false), (.email, email, true), (.password, password, false)])
        {
            focus = field
            error = message
            return
        }
        error = ""
        guard let token = turnstileToken else {
            error = "Please complete the security check."
            return
        }
        loading = true
        Task {
            do {
                _ = try await session.signup(email: email, password: password, firstName: firstName,
                                             lastName: lastName, turnstileToken: token)
            } catch let e {
                let message = e.apiMessage ?? ""
                error = message.isEmpty ? "Registration failed" : message
                // Reset widget so user can retry
                turnstileReset += 1
                turnstileToken = nil
            }
            loading = false
        }
    }
}

// Port of src/app/(main)/forgot-password/page.tsx
struct ForgotPasswordView: View {
    let go: (AuthFlowView.Screen) -> Void
    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var error = ""
    @State private var loading = false
    @State private var sent = false
    @FocusState private var focus: AuthField.ID?

    var body: some View {
        AuthCard(title: "Forgot password", subtitle: "Enter your email and we'll send you a reset link") {
            if sent {
                VStack(alignment: .leading, spacing: 20) {
                    Text("If an account exists for that email, a password reset link is on its way. Check your inbox (and spam folder).")
                        .tw(.sm)
                        .foregroundStyle(Palette.green700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .twBox(background: Palette.green50, radius: TW.radiusLg, border: Palette.green200)
                    HStack {
                        Spacer()
                        Button("Back to sign in") { go(.login) }
                            .tw(.sm, .medium)
                            .foregroundStyle(Palette.navy)
                        Spacer()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if !error.isEmpty { AuthErrorBox(text: error) }
                    AuthField(id: .email, label: "Email", placeholder: "your@email.com", text: $email, focus: $focus,
                              keyboard: .emailAddress, contentType: .emailAddress)
                    AuthPrimaryButton(title: loading ? "Sending…" : "Send reset link", disabled: loading, action: submit)
                        .padding(.top, 8)
                    AuthFooter(prompt: "Remembered your password?", link: "Sign in") { go(.login) }
                }
            }
        }
    }

    private func submit() {
        let email = self.email.trimmed
        if let (field, message) = AuthValidation.check([(.email, email, true)]) {
            focus = field
            error = message
            return
        }
        error = ""
        loading = true
        Task {
            do {
                _ = try await session.api.send(AuthAPI.forgotPassword(email: email))
                sent = true
            } catch let e {
                let message = e.apiMessage ?? ""
                error = message.isEmpty ? "Something went wrong" : message
            }
            loading = false
        }
    }
}

// MARK: - Shared auth chrome

/// `min-h-[80vh] flex items-center justify-center px-4 py-16` › `w-full max-w-md bg-white shadow-xl rounded-2xl p-10`.
struct AuthCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Image("HeaderLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                            .padding(.bottom, 16)
                        Text(title)
                            .tw(.x3l, .bold)
                            .foregroundStyle(Palette.navy)
                        Text(subtitle)
                            .tw(.sm)
                            .foregroundStyle(Palette.gray400)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                    content
                }
                .padding(40)
                .frame(maxWidth: 448)
                .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
                .twShadow(.xl)
                .padding(.horizontal, 16)
                .padding(.vertical, 64)
                .frame(minHeight: proxy.size.height * 0.8)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct AuthField: View {
    enum ID: Hashable { case firstName, lastName, email, password }
    let id: ID
    let label: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<ID?>.Binding
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).tw(.sm, .medium).foregroundStyle(Palette.gray700)
            AuthInputBox(focused: focus.wrappedValue == id) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder).tw(.base).foregroundStyle(Palette.black.opacity(0.5)).lineLimit(1)
                    }
                    TextField("", text: $text)
                        .tw(.base)
                        .foregroundStyle(Palette.black)
                        .keyboardType(keyboard)
                        .textContentType(contentType)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                        .focused(focus, equals: id)
                }
            }
        }
    }
}

struct AuthPasswordField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @Binding var show: Bool
    var focus: FocusState<AuthField.ID?>.Binding
    var contentType: UITextContentType

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).tw(.sm, .medium).foregroundStyle(Palette.gray700)
            AuthInputBox(focused: focus.wrappedValue == .password, trailingPadding: 44) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder).tw(.base).foregroundStyle(Palette.black.opacity(0.5)).lineLimit(1)
                    }
                    Group {
                        if show { TextField("", text: $text) } else { SecureField("", text: $text) }
                    }
                    .tw(.base)
                    .foregroundStyle(Palette.black)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused(focus, equals: .password)
                }
            }
            .overlay(alignment: .trailing) {
                Button { show.toggle() } label: {
                    Icon(show ? "eye-slash" : "eye", size: 20).foregroundStyle(Palette.gray400)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .accessibilityLabel(show ? "Hide password" : "Show password")
            }
        }
    }
}

/// `.input`: `rounded-lg border border-gray-300 px-4 py-2 shadow-sm focus:ring-2 focus:ring-[#001A78]`.
struct AuthInputBox<Content: View>: View {
    let focused: Bool
    var trailingPadding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TW.radiusLg)
        content
            .padding(.leading, 16)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Palette.white).twShadow(.sm))
            .overlay(shape.strokeBorder(Palette.gray300, lineWidth: 1))
            .overlay {
                if focused { shape.inset(by: -1).stroke(Palette.navyFocus, lineWidth: 2) }
            }
    }
}

struct AuthErrorBox: View {
    let text: String
    var body: some View {
        Text(text)
            .tw(.sm)
            .foregroundStyle(Palette.red700)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .twBox(background: Palette.red50, radius: TW.radiusLg, border: Palette.red200)
    }
}

/// `w-full bg-[#001049] text-white py-3 rounded-xl font-medium disabled:opacity-50`.
struct AuthPrimaryButton: View {
    let title: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .tw(.base, .medium)
                .foregroundStyle(Palette.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.navy))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct AuthFooter: View {
    let prompt: String
    let link: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(prompt).tw(.sm).foregroundStyle(Palette.gray400)
            Button(action: action) {
                Text(link).tw(.sm, .medium).foregroundStyle(Palette.navy)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

/// HTML constraint validation as iOS Safari reports it.
enum AuthValidation {
    /// Fields in DOM order: (id, value, isEmail). Returns the first invalid field and its message.
    static func check(_ fields: [(AuthField.ID, String, Bool)]) -> (AuthField.ID, String)? {
        for (id, value, isEmail) in fields {
            if value.isEmpty { return (id, "Fill out this field") }
            if isEmail, !isValidEmail(value) { return (id, "Enter an email address") }
        }
        return nil
    }

    /// The WHATWG `type=email` pattern.
    static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
