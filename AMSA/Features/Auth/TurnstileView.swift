import SwiftUI
import WebKit

/// Cloudflare Turnstile has no native SDK; the widget runs in a WKWebView whose document
/// origin is the website (`loadHTMLString(baseURL: https://www.amsa.mn)`), so the site key's
/// hostname allowlist accepts it. Mirrors `<Turnstile options={{ theme: "light" }}>`.
struct TurnstileView: UIViewRepresentable {
    let siteKey: String
    let baseURL: URL
    /// Increment to call `turnstile.reset()` (web: `turnstileRef.current?.reset()`).
    let resetCount: Int
    let onSuccess: (String) -> Void
    let onExpire: () -> Void
    let onError: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(WeakMessageHandler(context.coordinator), name: "turnstile")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.loadHTMLString(html, baseURL: baseURL)
        context.coordinator.webView = view
        context.coordinator.lastReset = resetCount
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastReset != resetCount {
            context.coordinator.lastReset = resetCount
            view.evaluateJavaScript("window.resetTurnstile && window.resetTurnstile()")
        }
    }

    private var html: String {
        let key = siteKey.replacingOccurrences(of: "'", with: "\\'")
        return """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:transparent;}</style>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=amsaTurnstileLoaded&render=explicit" async defer></script>
        </head><body>
        <div id="ts"></div>
        <script>
          function post(msg){ window.webkit.messageHandlers.turnstile.postMessage(msg); }
          var widgetId = null;
          function amsaTurnstileLoaded(){
            widgetId = turnstile.render('#ts', {
              sitekey: '\(key)',
              theme: 'light',
              callback: function(token){ post({type:'success', token: token}); },
              'expired-callback': function(){ post({type:'expire'}); },
              'error-callback': function(){ post({type:'error'}); }
            });
          }
          window.resetTurnstile = function(){ if (widgetId !== null) turnstile.reset(widgetId); };
        </script>
        </body></html>
        """
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: TurnstileView
        weak var webView: WKWebView?
        var lastReset = 0

        init(parent: TurnstileView) { self.parent = parent }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "success": if let token = body["token"] as? String { parent.onSuccess(token) }
            case "expire": parent.onExpire()
            default: parent.onError()
            }
        }
    }

    /// WKUserContentController retains its handlers; break the cycle.
    @MainActor
    private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?
        init(_ target: WKScriptMessageHandler) { self.target = target }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(controller, didReceive: message)
        }
    }
}
