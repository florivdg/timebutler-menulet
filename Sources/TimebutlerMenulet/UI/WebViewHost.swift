import SwiftUI
import WebKit

struct WebViewHost: NSViewRepresentable {
    let url: URL
    let config: WKWebViewConfiguration
    var onCommit: ((URL) -> Void)?
    var onFinish: ((URL) -> Void)?
    var onReady: ((WKWebView) -> Void)?
    var allowsNavigation: ((URL) -> Bool)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let v = WKWebView(frame: .zero, configuration: config)
        v.navigationDelegate = context.coordinator
        v.allowsBackForwardNavigationGestures = true
        v.load(URLRequest(url: url))
        let cb = onReady
        DispatchQueue.main.async { cb?(v) }
        return v
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let cb = onReady
        DispatchQueue.main.async { cb?(nsView) }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewHost
        init(_ p: WebViewHost) { self.parent = p }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let u = webView.url { parent.onCommit?(u) }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let u = webView.url { parent.onFinish?(u) }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            guard isMainFrame, let allowsNavigation = parent.allowsNavigation else {
                decisionHandler(.allow)
                return
            }
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let policy: WKNavigationActionPolicy = allowsNavigation(url) ? .allow : .cancel
            decisionHandler(policy)
        }
    }
}
