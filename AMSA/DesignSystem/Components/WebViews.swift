import SafariServices
import SwiftUI
import WebKit

/// Replaces `<iframe>` embeds (Guide flip-book, college map).
struct WebView: UIViewRepresentable {
    enum Source: Equatable {
        case url(URL)
        case html(String, baseURL: URL?)
    }

    let source: Source
    var scrollEnabled: Bool = true

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = scrollEnabled
        load(into: view)
        context.coordinator.loaded = source
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loaded != source else { return }
        context.coordinator.loaded = source
        load(into: view)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: Source?
    }

    private func load(into view: WKWebView) {
        switch source {
        case .url(let url): view.load(URLRequest(url: url))
        case .html(let html, let baseURL): view.loadHTMLString(html, baseURL: baseURL)
        }
    }
}

/// `target="_blank"` links open in an in-app Safari sheet.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Palette.navy)
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Opens `target="_blank"` links in SFSafariViewController, presented from the topmost
/// controller so it works from inside modals too.
@MainActor
@Observable
final class ExternalLinkPresenter {
    func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            // mailto:/tel: go to the system.
            UIApplication.shared.open(url)
            return
        }
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Palette.navy)
        Self.topViewController()?.present(controller, animated: true)
    }

    func open(_ string: String?) {
        guard let string, let url = URL(string: string) else { return }
        open(url)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
