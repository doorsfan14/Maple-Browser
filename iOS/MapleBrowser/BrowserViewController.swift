import UIKit
import WebKit
import Foundation

final class BrowserViewController: UIViewController, WKNavigationDelegate, UISearchBarDelegate, WKUIDelegate {
    private let addressBar = UISearchBar()
    private let content = UIView()
    private let bottomBar = UIStackView()
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
        addressBar.delegate = self
        addressBar.autocapitalizationType = .none
        addressBar.autocorrectionType = .no
        addressBar.returnKeyType = .go
        addressBar.searchBarStyle = .minimal
        addressBar.backgroundImage = UIImage()
        addressBar.layer.cornerRadius = 12
        addressBar.clipsToBounds = true

        let top = UIStackView(arrangedSubviews: [addressBar])
        top.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.axis = .horizontal
        bottomBar.alignment = .center
        bottomBar.distribution = .equalSpacing
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        [toolbarButton("‹", #selector(goBack)), toolbarButton("›", #selector(goForward)),
         toolbarButton("＋", #selector(newTab)), toolbarButton("▢", #selector(showTabs)),
         toolbarButton("☰", #selector(showMenu))].forEach { bottomBar.addArrangedSubview($0) }

        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        view.addSubview(content)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
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
            bottomBar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func toolbarButton(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func addTab(privateMode: Bool, url: URL?) {
        let config = WKWebViewConfiguration()\n        let contentController = WKUserContentController()\n        contentController.add(self, name: "mapleSearch")\n        config.userContentController = contentController
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
        *{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:white}
        body{display:flex;align-items:center;justify-content:center;overflow:hidden;background:linear-gradient(145deg,#0b1728 0%,#163b45 48%,#6b3f2b 100%)}
        .glow{position:absolute;width:420px;height:420px;border-radius:50%;background:rgba(255,196,111,.13);filter:blur(50px);top:-130px;right:-100px}
        .leaf{position:absolute;font-size:180px;opacity:.07;transform:rotate(-18deg);bottom:-45px;left:-25px}
        .card{position:relative;text-align:center;width:88%;max-width:560px}
        .mark{font-size:58px;margin-bottom:4px}.title{font-size:38px;font-weight:700;letter-spacing:-1.5px}.sub{opacity:.68;font-size:15px;margin:8px 0 26px}
        form{background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.2);backdrop-filter:blur(20px);border-radius:18px;padding:6px;display:flex}
        input{flex:1;background:transparent;border:0;outline:0;color:white;font-size:17px;padding:12px 14px}input::placeholder{color:rgba(255,255,255,.65)}
        button{border:0;border-radius:13px;padding:0 17px;font-size:17px;font-weight:600}
        </style></head><body><div class="glow"></div><div class="leaf">🍁</div>
        <main class="card"><div class="mark">🍁</div><div class="title">Maple Browser</div><div class="sub">A simple, fast place to browse.</div>
        <form><input name="q" autocomplete="off" placeholder="Search or enter a website"></form></main>
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

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        navigate(searchBar.text ?? "")
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
        let alert = UIAlertController(title: "Tabs  ·  \(tabs.count)", message: nil, preferredStyle: .actionSheet)
        for i in tabs.indices {
            alert.addAction(UIAlertAction(title: "\(i + 1)  ·  \(tabs[i].title ?? "New Tab")", style: .default) { [weak self] _ in self?.switchTab(i) })
        }
        alert.addAction(UIAlertAction(title: "New Tab", style: .default) { [weak self] _ in self?.addTab(privateMode: false, url: nil) })
        alert.addAction(UIAlertAction(title: "New Private Tab", style: .default) { [weak self] _ in self?.addTab(privateMode: true, url: nil) })
        if tabs.count > 1 { alert.addAction(UIAlertAction(title: "Close Current Tab", style: .destructive) { [weak self] _ in self?.closeCurrentTab() }) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
        let alert = UIAlertController(title: "Maple Browser", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Reload", style: .default) { [weak self] _ in self?.reload() })
        alert.addAction(UIAlertAction(title: "Add Bookmark", style: .default) { [weak self] _ in self?.addBookmark() })
        alert.addAction(UIAlertAction(title: "Bookmarks", style: .default) { [weak self] _ in self?.showBookmarks() })
        alert.addAction(UIAlertAction(title: "History", style: .default) { [weak self] _ in self?.showHistory() })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in self?.showSettings() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
        let alert = UIAlertController(title: "Bookmarks", message: nil, preferredStyle: .actionSheet)
        for item in bookmarks {
            alert.addAction(UIAlertAction(title: item["title"] ?? item["url"] ?? "Bookmark", style: .default) { [weak self] _ in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showHistory() {
        let alert = UIAlertController(title: "History", message: nil, preferredStyle: .actionSheet)
        for item in history.prefix(30) {
            alert.addAction(UIAlertAction(title: item["title"] ?? item["url"] ?? "Page", style: .default) { [weak self] _ in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            })
        }
        alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { [weak self] _ in self?.history.removeAll(); self?.saveData() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showSettings() {
        let alert = UIAlertController(title: "Settings", message: "Maple Browser", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { [weak self] _ in self?.history.removeAll(); self?.saveData() })
        alert.addAction(UIAlertAction(title: "Clear Bookmarks", style: .destructive) { [weak self] _ in self?.bookmarks.removeAll(); self?.saveData() })
        alert.addAction(UIAlertAction(title: "Clear Web Data", style: .destructive) { [weak self] _ in
            for w in self?.tabs ?? [] { w.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {} }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
