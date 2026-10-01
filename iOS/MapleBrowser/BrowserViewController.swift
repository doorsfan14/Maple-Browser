import UIKit
import WebKit
import Foundation

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let addressBar = UITextField()
    private let content = UIView()
    private let bottomBar = UIStackView()
    private let chromeBar = UIView()
    private var tabs: [WKWebView] = []
    private var privateTabs: [Bool] = []
    private var activeIndex = 0
    private var bookmarks: [[String: String]] = []
    private var history: [[String: String]] = []
    private let homeURL = URL(string: "maple://home")!

    private var webView: WKWebView { tabs[activeIndex] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadData()
        buildUI()
        addTab(privateMode: false, url: nil)
    }

    private func buildUI() {
        addressBar.placeholder = "Search or enter website"
        addressBar.autocapitalizationType = .none
        addressBar.autocorrectionType = .no
        addressBar.returnKeyType = .go
        addressBar.borderStyle = .roundedRect
        addressBar.backgroundColor = .secondarySystemBackground
        addressBar.textColor = .label
        addressBar.tintColor = .systemBlue
        addressBar.clearButtonMode = .whileEditing
        addressBar.addTarget(self, action: #selector(addressSubmitted), for: .editingDidEndOnExit)

        let top = UIStackView(arrangedSubviews: [addressBar])
        top.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.axis = .horizontal
        bottomBar.alignment = .center
        bottomBar.distribution = .equalSpacing
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        [toolbarButton("chevron.left", #selector(goBack)), toolbarButton("chevron.right", #selector(goForward)),
         toolbarButton("plus", #selector(newTab)), toolbarButton("square.on.square", #selector(showTabs)),
         toolbarButton("ellipsis", #selector(showMenu))].forEach { bottomBar.addArrangedSubview($0) }

        content.translatesAutoresizingMaskIntoConstraints = false
        chromeBar.backgroundColor = .systemBackground
        chromeBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chromeBar)
        view.addSubview(top)
        view.addSubview(content)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            chromeBar.topAnchor.constraint(equalTo: view.topAnchor),
            chromeBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeBar.bottomAnchor.constraint(equalTo: top.bottomAnchor, constant: 8),
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            top.heightAnchor.constraint(equalToConstant: 44),
            content.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 4),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            bottomBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func toolbarButton(_ symbol: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.tintColor = .label
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 9
        b.widthAnchor.constraint(equalToConstant: 40).isActive = true
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func addTab(privateMode: Bool, url: URL?) {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "mapleSearch")
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        if privateMode { config.websiteDataStore = .nonPersistent() }

        let w = WKWebView(frame: .zero, configuration: config)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.allowsBackForwardNavigationGestures = true
        tabs.append(w)
        privateTabs.append(privateMode)
        activeIndex = tabs.count - 1
        showActiveWebView()

        if let url {
            w.load(URLRequest(url: url))
        } else {
            showHome()
        }
    }

    private func showActiveWebView() {
        content.subviews.forEach { $0.removeFromSuperview() }
        let w = webView
        w.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(w)
        NSLayoutConstraint.activate([
            w.topAnchor.constraint(equalTo: content.topAnchor),
            w.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            w.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            w.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        addressBar.text = w.url?.absoluteString == homeURL.absoluteString ? "" : w.url?.absoluteString
        updateButtons()
    }

    private func showHome() {
        webView.stopLoading()
        webView.loadHTMLString(homeHTML(), baseURL: nil)
        addressBar.text = ""
    }

    private func homeHTML() -> String {
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#f5f5f7}
        body{display:flex;align-items:center;justify-content:center;overflow:hidden;background:#101820}
        .bg{position:absolute;inset:0;background:linear-gradient(160deg,#101820 0%,#19333a 55%,#3a2924 100%)}
        .stripe{position:absolute;inset:auto -15% -22% -15%;height:45%;background:#223f46;transform:rotate(-7deg);opacity:.55}
        .leaf{position:absolute;font-size:190px;opacity:.055;bottom:-55px;right:-30px;transform:rotate(-18deg)}
        .card{position:relative;text-align:center;width:88%;max-width:520px}
        .mark{font-size:48px;margin-bottom:8px}.title{font-size:32px;font-weight:700;letter-spacing:-1px}.sub{color:#aeb8bc;font-size:15px;margin:7px 0 28px}
        form{background:#f2f2f2;border:1px solid #d0d0d0;border-radius:13px;padding:4px;display:flex;box-shadow:0 4px 16px rgba(0,0,0,.25)}
        input{flex:1;background:transparent;border:0;outline:0;color:#161616;font-size:17px;padding:11px 13px}input::placeholder{color:#777}
        button{border:0;background:#1677d2;color:white;border-radius:9px;padding:0 16px;font-size:16px;font-weight:600}
        </style></head><body><div class="bg"></div><div class="stripe"></div><div class="leaf">🍁</div>
        <main class="card"><div class="mark">🍁</div><div class="title">Maple Browser</div><div class="sub">Simple browsing, nothing in the way.</div>
        <form><input name="q" autocomplete="off" placeholder="Search or enter a website"><button>Search</button></form></main>
        <script>document.querySelector('form').onsubmit=function(e){e.preventDefault();window.webkit.messageHandlers.mapleSearch.postMessage(this.q.value)}</script>
        </body></html>
        """
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "mapleSearch", let q = message.body as? String {
            navigate(q)
        }
    }

    private func navigate(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let url: URL
        if let direct = URL(string: text), direct.scheme != nil {
            url = direct
        } else if text.contains(".") && !text.contains(" ") {
            url = URL(string: "https://" + text)!
        } else {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            url = URL(string: "https://www.google.com/search?q=" + encoded)!
        }
        addressBar.resignFirstResponder()
        webView.load(URLRequest(url: url))
    }

    @objc private func addressSubmitted() {
        navigate(addressBar.text ?? "")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.url?.absoluteString == homeURL.absoluteString { return }
        addressBar.text = webView.url?.absoluteString
        if !privateTabs[activeIndex], let url = webView.url?.absoluteString {
            history.insert(["title": webView.title ?? url, "url": url], at: 0)
            history = Array(history.prefix(100))
            saveData()
        }
        updateButtons()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    private func updateButtons() {
        guard !tabs.isEmpty else { return }
        (bottomBar.arrangedSubviews[0] as? UIButton)?.isEnabled = webView.canGoBack
        (bottomBar.arrangedSubviews[1] as? UIButton)?.isEnabled = webView.canGoForward
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }
    @objc private func reload() { webView.reload() }
    @objc private func newTab() { addTab(privateMode: false, url: nil) }

    @objc private func showTabs() {
        var actions: [(String, () -> Void)] = []
        for i in tabs.indices {
            actions.append(("\(i + 1) · \(tabs[i].title ?? "New Tab")", { [weak self] in self?.switchTab(i) }))
        }
        actions.append(("New Tab", { [weak self] in self?.addTab(privateMode: false, url: nil) }))
        actions.append(("New Private Tab", { [weak self] in self?.addTab(privateMode: true, url: nil) }))
        if tabs.count > 1 { actions.append(("Close Current Tab", { [weak self] in self?.closeCurrentTab() })) }
        showActionPanel(title: "Tabs · \(tabs.count)", actions: actions)
    }

    private func switchTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        showActiveWebView()
    }

    private func closeCurrentTab() {
        guard tabs.count > 1 else { return }
        tabs.remove(at: activeIndex)
        privateTabs.remove(at: activeIndex)
        activeIndex = min(activeIndex, tabs.count - 1)
        showActiveWebView()
    }

    @objc private func showMenu() {
        showActionPanel(title: "Maple Browser", actions: [
            ("Reload", { [weak self] in self?.reload() }),
            ("Add Bookmark", { [weak self] in self?.addBookmark() }),
            ("Bookmarks", { [weak self] in self?.showBookmarks() }),
            ("History", { [weak self] in self?.showHistory() }),
            ("Settings", { [weak self] in self?.showSettings() })
        ])
    }

    private func loadData() {
        bookmarks = UserDefaults.standard.array(forKey: "maple.bookmarks") as? [[String: String]] ?? []
        history = UserDefaults.standard.array(forKey: "maple.history") as? [[String: String]] ?? []
    }

    private func saveData() {
        UserDefaults.standard.set(bookmarks, forKey: "maple.bookmarks")
        UserDefaults.standard.set(history, forKey: "maple.history")
    }

    private func addBookmark() {
        guard let url = webView.url?.absoluteString, !url.isEmpty else { return }
        bookmarks.removeAll { $0["url"] == url }
        bookmarks.insert(["title": webView.title ?? url, "url": url], at: 0)
        saveData()
    }

    private func showBookmarks() {
        var actions: [(String, () -> Void)] = []
        for item in bookmarks {
            actions.append((item["title"] ?? item["url"] ?? "Bookmark", { [weak self] in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            }))
        }
        showActionPanel(title: "Bookmarks", actions: actions)
    }

    private func showHistory() {
        var actions: [(String, () -> Void)] = []
        for item in history.prefix(30) {
            actions.append((item["title"] ?? item["url"] ?? "Page", { [weak self] in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            }))
        }
        if !history.isEmpty { actions.append(("Clear History", { [weak self] in self?.history.removeAll(); self?.saveData() })) }
        showActionPanel(title: "History", actions: actions)
    }

    private func showSettings() {
        showActionPanel(title: "Settings", actions: [
            ("Clear History", { [weak self] in self?.history.removeAll(); self?.saveData() }),
            ("Clear Bookmarks", { [weak self] in self?.bookmarks.removeAll(); self?.saveData() }),
            ("Clear Web Data", { [weak self] in
                for w in self?.tabs ?? [] {
                    w.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {}
                }
            })
        ])
    }

    private func showActionPanel(title: String, actions: [(String, () -> Void)]) {
        let panel = ActionPanelViewController(title: title, actions: actions)
        panel.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = panel.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        present(panel, animated: true)
    }

}


private final class ActionPanelViewController: UIViewController {
    private let panelTitle: String
    private let actions: [(String, () -> Void)]
    private var actionHandlers: [() -> Void] = []

    init(title: String, actions: [(String, () -> Void)]) {
        self.panelTitle = title
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleActionButton(_ sender: UIButton) {
        guard let value = sender.accessibilityValue,
              let index = actions.firstIndex(where: { $0.0 == value }),
              actionHandlers.indices.contains(index) else { return }
        dismiss(animated: true, completion: actionHandlers[index])
    }

    @objc private func cancelPanel() {
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = panelTitle
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .label

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        for (text, action) in actions {
            let button = UIButton(type: .system)
            button.setTitle(text, for: .normal)
            button.setTitleColor(.systemBlue, for: .normal)
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 10
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            button.heightAnchor.constraint(equalToConstant: 48).isActive = true
            button.addTarget(self, action: #selector(handleActionButton(_:)), for: .touchUpInside)
            button.accessibilityIdentifier = "maple-action"
            button.accessibilityValue = text
            actionHandlers.append(action)
            stack.addArrangedSubview(button)
        }

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.systemBlue, for: .normal)
        cancel.backgroundColor = .secondarySystemBackground
        cancel.layer.cornerRadius = 10
        cancel.heightAnchor.constraint(equalToConstant: 48).isActive = true
        cancel.addTarget(self, action: #selector(cancelPanel), for: .touchUpInside)

        let root = UIStackView(arrangedSubviews: [title, stack, cancel])
        root.axis = .vertical
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}
