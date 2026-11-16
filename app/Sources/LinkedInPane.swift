import SwiftUI
import WebKit

// LinkedIn inside the CRM window. One shared browser, so the sign-in, the open chat and the
// scroll position survive switching contacts. Nothing loads by itself: every page is opened by
// a click, because a profile visit shows up in that person's "Who viewed your profile".

@MainActor
final class LinkedInBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = LinkedInBrowser()
    static let inbox = URL(string: "https://www.linkedin.com/messaging/")!

    let web: WKWebView
    @Published var url: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var loading = false
    private var watchers: [NSKeyValueObservation] = []

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()          // keeps you signed in between launches
        web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        // Present as Safari so LinkedIn serves its normal desktop site
        web.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self
        watchers = [
            web.observe(\.url) { [weak self] w, _ in Task { @MainActor in self?.url = w.url } },
            web.observe(\.canGoBack) { [weak self] w, _ in Task { @MainActor in self?.canGoBack = w.canGoBack } },
            web.observe(\.canGoForward) { [weak self] w, _ in Task { @MainActor in self?.canGoForward = w.canGoForward } },
            web.observe(\.isLoading) { [weak self] w, _ in Task { @MainActor in self?.loading = w.isLoading } },
        ]
    }

    func open(_ u: URL) { web.load(URLRequest(url: u)) }
    func openIfBlank() { if web.url == nil { open(Self.inbox) } }

    static func isLinkedIn(_ u: URL?) -> Bool {
        guard let h = u?.host?.lowercased() else { return false }
        return h == "linkedin.com" || h.hasSuffix(".linkedin.com") || h.hasSuffix(".licdn.com")
    }

    /// "/in/sanne-de-vries" from any profile address, for matching against the CRM
    static func profileSlug(_ s: String) -> String? {
        guard let r = s.range(of: #"/in/[^/?#]+"#, options: .regularExpression) else { return nil }
        return s[r].lowercased().removingPercentEncoding ?? s[r].lowercased()
    }

    // Links to other sites (shared in a chat, say) open in your normal browser
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if a.navigationType == .linkActivated, let u = a.request.url, !Self.isLinkedIn(u), u.scheme?.hasPrefix("http") == true {
            NSWorkspace.shared.open(u); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url {
            if Self.isLinkedIn(u) { w.load(a.request) } else { NSWorkspace.shared.open(u) }
        }
        return nil
    }

    /// What to log: the text you selected, or else the last messages of the chat that is open.
    func capture() async -> String? {
        let js = """
        const sel = String(window.getSelection() || '').trim();
        if (sel) return sel;
        const items = [...document.querySelectorAll('li.msg-s-message-list__event')];
        let who = '', out = [];
        for (const li of items) {
          const n = li.querySelector('.msg-s-message-group__name');
          if (n) who = n.textContent.trim();
          for (const b of li.querySelectorAll('.msg-s-event-listitem__body')) {
            const t = b.textContent.replace(/\\s+/g, ' ').trim();
            if (t) out.push((who ? who + ': ' : '') + (t.length > 600 ? t.slice(0, 600) + '…' : t));
          }
        }
        return out.slice(-15).join('\\n');
        """
        let r = try? await web.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .defaultClient)
        let s = (r as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    /// Types text into the message box you clicked in. Sending stays your own click.
    func insert(_ text: String) async -> Bool {
        let js = """
        let el = document.activeElement;
        if (!el || !(el.isContentEditable || el.tagName === 'TEXTAREA')) {
          const boxes = [...document.querySelectorAll('.msg-form__contenteditable[contenteditable="true"]')];
          el = boxes[boxes.length - 1];
          if (el) el.focus();
        }
        if (!el) return false;
        document.execCommand('insertText', false, t);
        return true;
        """
        let r = try? await web.callAsyncJavaScript(js, arguments: ["t": text], in: nil, contentWorld: .defaultClient)
        return (r as? Bool) ?? false
    }
}

/// Hosts the shared web view; moves it into whichever pane is on screen.
struct WebViewHost: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> NSView {
        let box = NSView()
        attach(to: box)
        return box
    }
    func updateNSView(_ box: NSView, context: Context) {
        if web.superview !== box { attach(to: box) }
    }
    private func attach(to box: NSView) {
        web.removeFromSuperview()
        web.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: box.leadingAnchor), web.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            web.topAnchor.constraint(equalTo: box.topAnchor), web.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
    }
}

struct LinkedInPane: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var b = LinkedInBrowser.shared
    let contactID: String?
    @State private var message: String?

    private var c: Contact? { store.contact(contactID) }
    private var firstName: String { c.map { String($0.name.split(separator: " ").first ?? "") } ?? "" }

    /// The CRM contact whose profile is on screen, when it isn't the one selected
    private var shownContact: Contact? {
        guard let slug = b.url.flatMap({ LinkedInBrowser.profileSlug($0.absoluteString) }) else { return nil }
        return store.contacts.first { LinkedInBrowser.profileSlug($0.linkedin) == slug && $0.id != contactID }
    }

    var body: some View {
        VStack(spacing: 0) {
            bar
            if let m = message {
                Text(m).font(Theme.body(12)).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 7).background(Theme.quiet)
            }
            Divider()
            WebViewHost(web: b.web)
        }
        .onAppear { b.openIfBlank() }
        .onChange(of: contactID) { message = nil }
    }

    private var bar: some View {
        HStack(spacing: 8) {
            Button { b.web.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!b.canGoBack).help("Back")
            Button { b.web.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!b.canGoForward).help("Forward")
            Button { if b.loading { b.web.stopLoading() } else { b.web.reload() } } label: {
                Image(systemName: b.loading ? "xmark" : "arrow.clockwise")
            }.help(b.loading ? "Stop" : "Reload")
            Button("Messages") { b.open(LinkedInBrowser.inbox) }.help("Your LinkedIn inbox")
            if let c, let u = URL(string: c.linkedin), !c.linkedin.isEmpty {
                Button("\(firstName)'s profile") { b.open(u) }
                    .help("Opens their profile. They will see you in “Who viewed your profile”.")
            }
            if let o = shownContact {
                Button("Show \(o.name)") { NotificationCenter.default.post(name: .openContact, object: o.id) }
                    .help("This profile is in your CRM")
            }
            Spacer(minLength: 4)
            if let c, let n = c.net {
                let lines = n.lines.keys.sorted().compactMap { k in n.lines[k].flatMap { $0.isEmpty ? nil : (k.uppercased(), $0) } }
                if !lines.isEmpty {
                    Menu("Insert opener") {
                        ForEach(lines, id: \.0) { (lang, text) in
                            Button("\(lang): \(text.prefix(50))…") { insert(text) }
                        }
                    }
                    .fixedSize()
                    .help("Click in the message box first. You still press Send yourself.")
                }
            }
            if c != nil {
                Button { log() } label: { Label("Log to \(firstName)", systemImage: "square.and.arrow.down") }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .help("Adds the selected text, or the open chat, to this contact's touchpoint form")
            }
        }
        .font(Theme.body(12))
        .controlSize(.small)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.paper)
    }

    private func insert(_ text: String) {
        Task {
            message = await b.insert(text) ? nil : "Click in the LinkedIn message box first, then choose the opener again."
        }
    }

    private func log() {
        guard let id = contactID else { return }
        Task {
            if let text = await b.capture() {
                NotificationCenter.default.post(name: .logFromLinkedIn, object: id, userInfo: ["text": text])
                message = "Added to the touchpoint form. Check it, then press Log touchpoint."
            } else {
                message = "Nothing to log yet. Open the chat with \(firstName), or select the messages you want, then try again."
            }
        }
    }
}
