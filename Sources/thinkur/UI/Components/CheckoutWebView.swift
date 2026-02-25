import SwiftUI
import WebKit
import IOKit

struct CheckoutWebView: View {
    let url: URL
    let onLicenseKey: (String) -> Void
    let onDismiss: () -> Void
    let onReachedReceipt: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Close button header
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(Spacing.sm)
            }

            CheckoutWebViewRepresentable(
                url: checkoutURL,
                onLicenseKey: onLicenseKey,
                onReachedReceipt: onReachedReceipt
            )
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 700, idealHeight: 780)
        .background(Color.white)
    }

    /// Build the checkout URL with machine ID but WITHOUT embed=1,
    /// so LemonSqueezy renders a full-page checkout (no overlay chrome / broken X).
    private var checkoutURL: URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        if let machineID = Self.machineID {
            queryItems.append(URLQueryItem(name: "checkout[custom][machine_id]", value: machineID))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url ?? url
    }

    private static var machineID: String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }

        guard platformExpert != 0,
              let uuid = IORegistryEntryCreateCFProperty(
                  platformExpert,
                  "IOPlatformUUID" as CFString,
                  kCFAllocatorDefault,
                  0
              )?.takeRetainedValue() as? String else {
            return nil
        }
        return uuid
    }
}

// MARK: - WKWebView Wrapper

private struct CheckoutWebViewRepresentable: NSViewRepresentable {
    let url: URL
    let onLicenseKey: (String) -> Void
    let onReachedReceipt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLicenseKey: onLicenseKey, onReachedReceipt: onReachedReceipt)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Navigation Delegate

private final class Coordinator: NSObject, WKNavigationDelegate {
    let onLicenseKey: (String) -> Void
    let onReachedReceipt: () -> Void
    private var hasExtractedKey = false

    init(onLicenseKey: @escaping (String) -> Void, onReachedReceipt: @escaping () -> Void) {
        self.onLicenseKey = onLicenseKey
        self.onReachedReceipt = onReachedReceipt
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasExtractedKey else { return }

        guard let url = webView.url?.absoluteString else { return }

        let isReceipt = url.contains("/receipt")
            || url.contains("order-confirmation")
            || url.contains("/thank")

        if isReceipt {
            Task { @MainActor in onReachedReceipt() }
        }

        let isCheckoutBuy = url.contains("/checkout/buy/")
        guard isReceipt || !isCheckoutBuy else { return }

        extractLicenseKey(from: webView)
    }

    private func extractLicenseKey(from webView: WKWebView) {
        let js = """
        (function() {
            var el = document.querySelector('[data-testid="license-key"]');
            if (el && el.textContent.trim()) return el.textContent.trim();

            el = document.querySelector('.license-key');
            if (el && el.textContent.trim()) return el.textContent.trim();

            var match = document.body.innerText.match(/[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}/);
            if (match) return match[0];

            return null;
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self, !self.hasExtractedKey else { return }
            if let key = result as? String, !key.isEmpty {
                self.hasExtractedKey = true
                Task { @MainActor in
                    self.onLicenseKey(key)
                }
            }
        }
    }
}
