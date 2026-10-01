import SwiftUI

enum FeedbackAPI {
    static func send(category: String, message: String, page: String) -> Endpoint<Empty> {
        Endpoint(method: .post, path: "/api/feedback",
                 body: ["category": .string(category), "message": .string(message), "page": .string(page)])
    }
}

// Port of src/components/FeedbackButton.tsx (the portaled dialog — outside `.dashboard`,
// so buttons keep their class radii).
struct FeedbackDialog: View {
    @Binding var isPresented: Bool
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router

    private static let categories = ["Bug", "Idea", "Question", "Other"]
    private static let maxLength = 2000

    @State private var category = "Idea"
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Send feedback").tw(.lg, .bold).foregroundStyle(Palette.gray900)
                Spacer()
                Button(action: close) {
                    Icon("close", size: 20).foregroundStyle(Palette.gray400).padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .bottomBorder(Palette.gray100, width: 1)

            if sent {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Palette.green100)
                        Icon("check-bold", size: 24).foregroundStyle(Palette.green700)
                    }
                    .frame(width: 48, height: 48)
                    Text("Thanks — we got it.").tw(.base, .semibold).foregroundStyle(Palette.gray900)
                    Text("The AMSA team will reply to your account email if needed.")
                        .tw(.sm).foregroundStyle(Palette.gray500).multilineTextAlignment(.center)
                    Button(action: close) {
                        Text("Done").tw(.sm, .semibold).foregroundStyle(Palette.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.navy))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            } else {
                FittingScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Found a bug, have an idea, or need help? This goes straight to the AMSA admins.")
                            .tw(.sm).foregroundStyle(Palette.gray500)

                        FlowLayout(spacing: 8) {
                            ForEach(Self.categories, id: \.self) { c in
                                let selected = category == c
                                Button { category = c } label: {
                                    Text(c).tw(.sm, .medium)
                                        .foregroundStyle(selected ? Palette.white : Palette.gray700)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Capsule().fill(selected ? Palette.navy : Palette.white))
                                        .overlay(Capsule().strokeBorder(selected ? Palette.navy : Palette.gray300, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message").tw(.sm, .semibold).foregroundStyle(Palette.gray700)
                            WebTextArea(placeholder: "What happened, or what would you like to see?", text: $message,
                                        style: .modal, rows: 6, maxLength: Self.maxLength, autoFocus: true)
                            Text("\(message.count)/\(Self.maxLength)")
                                .tw(.xs).foregroundStyle(Palette.gray400)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if !error.isEmpty {
                            Text(error).tw(.sm).foregroundStyle(Palette.red600)
                        }

                        HStack(spacing: 8) {
                            Spacer()
                            Button(action: close) {
                                Text("Cancel").tw(.sm, .semibold).foregroundStyle(Palette.gray600)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .disabled(sending)
                            .opacity(sending ? 0.5 : 1)
                            let disabled = sending || message.trimmed.count < 10
                            Button(action: submit) {
                                Text(sending ? "Sending…" : "Send").tw(.sm, .semibold).foregroundStyle(Palette.white)
                                    .padding(.horizontal, 20).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: TW.radiusXl).fill(Palette.navy))
                            }
                            .buttonStyle(.plain)
                            .disabled(disabled)
                            .opacity(disabled ? 0.5 : 1)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: 512)
        .maxHeight(viewportFraction: 0.9)
        .background(RoundedRectangle(cornerRadius: TW.radius2xl).fill(Palette.white))
        .clipShape(RoundedRectangle(cornerRadius: TW.radius2xl))
        .twShadow(.x2l)
    }

    private func close() {
        if sending { return }
        isPresented = false
    }

    private func submit() {
        sending = true
        error = ""
        let page = router.current.webPath
        Task {
            do {
                _ = try await session.api.send(FeedbackAPI.send(category: category, message: message.trimmed, page: page))
                sent = true
                message = ""
            } catch let e {
                error = e.apiMessage ?? "Something went wrong. Please try again."
            }
            sending = false
        }
    }
}
