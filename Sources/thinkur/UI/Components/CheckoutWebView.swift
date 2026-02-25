import SwiftUI
import WebKit
import IOKit

struct CheckoutWebView: View {
    let url: URL
    let onLicenseKey: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(Spacing.sm)
            }

            CheckoutWebViewRepresentable(
                url: embeddedURL,
                onLicenseKey: onLicenseKey
            )
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 600, idealHeight: 700)
        .background(.background)
    }

    private var embeddedURL: URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "embed", value: "1"))
        queryItems.append(URLQueryItem(name: "dark", value: "1"))
        if let machineID = Self.machineID {
            queryItems.append(URLQueryItem(name: "checkout[custom][machine_id]", value: machineID))
        }
        components.queryItems = queryItems
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

    func makeCoordinator() -> Coordinator {
        Coordinator(onLicenseKey: onLicenseKey)
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
    private var hasExtractedKey = false

    init(onLicenseKey: @escaping (String) -> Void) {
        self.onLicenseKey = onLicenseKey
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

        // Check if we're on a receipt/confirmation page
        guard let url = webView.url?.absoluteString else { return }

        let isReceipt = url.contains("/receipt")
            || url.contains("order-confirmation")
            || url.contains("/thank")

        // Also try on any page after the initial checkout — LemonSqueezy may
        // redirect to a success page without "receipt" in the URL
        let isCheckoutBuy = url.contains("/checkout/buy/")
        guard isReceipt || !isCheckoutBuy else { return }

        extractLicenseKey(from: webView)
    }

    private func extractLicenseKey(from webView: WKWebView) {
        let js = """
        (function() {
            // Try data attribute first
            var el = document.querySelector('[data-testid="license-key"]');
            if (el && el.textContent.trim()) return el.textContent.trim();

            // Try class name
            el = document.querySelector('.license-key');
            if (el && el.textContent.trim()) return el.textContent.trim();

            // Regex fallback: XXXXX-XXXXX-XXXXX-XXXXX pattern
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
