import UIKit
import WebKit
import Foundation

final class BrowserViewController: UIViewController, WKNavigationDelegate, UISearchBarDelegate, WKUIDelegate {
    private let searchBar = UISearchBar()
    private let toolbar = UIStackView()
    private let webContainer = UIView()
    private var tabs: [WKWebView] = []
    private var privateTabs: [Bool] = []
    private var activeIndex = 0
    private var bookmarks: [[String: String]] = []
    private var history: [[String: String]] = []
    private var contentBlockingEnabled = true

    private var webView: WKWebView { tabs[activeIndex] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadData()
        buildUI()
        addTab(privateMode: false, url: URL(string: "https://www.google.com"))
    }

    private func buildUI() {
        searchBar.placeholder = "Search or enter website"
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .go

        let back = button("‹", #selector(goBack))
        let forward = button("›", #selector(goForward))
        let reload = button("↻", #selector(reload))
        let tabsButton = button("▢", #selector(showTabs))
        let menuButton = button("☰", #selector(showMenu))

        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 5
        [back, forward, reload, tabsButton, menuButton].forEach { toolbar.addArrangedSubview($0) }

        let top = UIStackView(arrangedSubviews: [searchBar, toolbar])
        top.axis = .horizontal
        top.spacing = 5
        top.translatesAutoresizingMaskIntoConstraints = false
        webContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        view.addSubview(webContainer)

        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            webContainer.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 4),
            webContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 21)
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func addTab(privateMode: Bool, url: URL?) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if privateMode {
            config.websiteDataStore = .nonPersistent()
        }
        let w = WKWebView(frame: .zero, configuration: config)
        w.navigationDelegate = self
        w.uiDelegate = self
        w.allowsBackForwardNavigationGestures = true
        tabs.append(w)
        privateTabs.append(privateMode)
        activeIndex = tabs.count - 1
        webContainer.subviews.forEach { $0.removeFromSuperview() }
        w.translatesAutoresizingMaskIntoConstraints = false
        webContainer.addSubview(w)
        NSLayoutConstraint.activate([
            w.topAnchor.constraint(equalTo: webContainer.topAnchor),
            w.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
            w.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
            w.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor)
        ])
        if let url { w.load(URLRequest(url: url)) }
        updateButtons()
    }

    private func switchTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        webContainer.subviews.forEach { $0.removeFromSuperview() }
        let w = tabs[index]
        w.translatesAutoresizingMaskIntoConstraints = false
        webContainer.addSubview(w)
        NSLayoutConstraint.activate([
            w.topAnchor.constraint(equalTo: webContainer.topAnchor),
            w.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
            w.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
            w.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor)
        ])
        searchBar.text = w.url?.absoluteString
        updateButtons()
    }

    private func loadData() {
        bookmarks = UserDefaults.standard.array(forKey: "maple.bookmarks") as? [[String: String]] ?? []
        history = UserDefaults.standard.array(forKey: "maple.history") as? [[String: String]] ?? []
    }

    private func saveData() {
        UserDefaults.standard.set(bookmarks, forKey: "maple.bookmarks")
        UserDefaults.standard.set(history, forKey: "maple.history")
    }

    private func destination(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), url.scheme != nil { return url }
        if text.contains(".") && !text.contains(" ") { return URL(string: "https://" + text) }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return URL(string: "https://www.google.com/search?q=" + encoded)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let url = destination(searchBar.text ?? "") else { return }
        searchBar.resignFirstResponder()
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        searchBar.text = webView.url?.absoluteString
        if !privateTabs[activeIndex], let url = webView.url?.absoluteString {
            history.insert(["title": webView.title ?? url, "url": url], at: 0)
            history = Array(history.prefix(100))
            saveData()
        }
        updateButtons()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel); return
        }
        if ["javascript", "data", "blob"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.allow); return
        }
        decisionHandler(.allow)
    }

    private func updateButtons() {
        guard !tabs.isEmpty else { return }
        if let b = toolbar.arrangedSubviews.first as? UIButton { b.isEnabled = webView.canGoBack }
        if toolbar.arrangedSubviews.count > 1, let f = toolbar.arrangedSubviews[1] as? UIButton { f.isEnabled = webView.canGoForward }
        searchBar.text = webView.url?.absoluteString
    }

    @objc private func goBack() { if webView.canGoBack { webView.goBack() } }
    @objc private func goForward() { if webView.canGoForward { webView.goForward() } }
    @objc private func reload() { webView.reload() }

    @objc private func showTabs() {
        let alert = UIAlertController(title: "Tabs ((tabs.count))", message: nil, preferredStyle: .actionSheet)
        for i in tabs.indices {
            let title = "\(i + 1). \(tabs[i].title ?? tabs[i].url?.host ?? "New Tab")"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in self?.switchTab(i) })
        }
        alert.addAction(UIAlertAction(title: "New Tab", style: .default) { [weak self] _ in
            self?.addTab(privateMode: false, url: URL(string: "https://www.google.com"))
        })
        alert.addAction(UIAlertAction(title: "New Private Tab", style: .default) { [weak self] _ in
            self?.addTab(privateMode: true, url: URL(string: "https://www.google.com"))
        })
        if tabs.count > 1 {
            alert.addAction(UIAlertAction(title: "Close Current Tab", style: .destructive) { [weak self] _ in self?.closeCurrentTab() })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1) }
        present(alert, animated: true)
    }

    private func closeCurrentTab() {
        guard tabs.count > 1 else { return }
        tabs.remove(at: activeIndex)
        privateTabs.remove(at: activeIndex)
        activeIndex = min(activeIndex, tabs.count - 1)
        switchTab(activeIndex)
    }

    @objc private func showMenu() {
        let alert = UIAlertController(title: "Maple Browser", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Add Bookmark", style: .default) { [weak self] _ in self?.addBookmark() })
        alert.addAction(UIAlertAction(title: "Bookmarks", style: .default) { [weak self] _ in self?.showBookmarks() })
        alert.addAction(UIAlertAction(title: "History", style: .default) { [weak self] _ in self?.showHistory() })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in self?.showSettings() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.maxX - 30, y: 60, width: 1, height: 1) }
        present(alert, animated: true)
    }

    private func addBookmark() {
        guard let url = webView.url?.absoluteString else { return }
        bookmarks.removeAll { $0["url"] == url }
        bookmarks.insert(["title": webView.title ?? url, "url": url], at: 0)
        saveData()
    }

    private func showBookmarks() {
        let alert = UIAlertController(title: "Bookmarks", message: nil, preferredStyle: .actionSheet)
        for item in bookmarks {
            let title = item["title"] ?? item["url"] ?? "Bookmark"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1) }
        present(alert, animated: true)
    }

    private func showHistory() {
        let alert = UIAlertController(title: "History", message: nil, preferredStyle: .actionSheet)
        for item in history.prefix(30) {
            let title = item["title"] ?? item["url"] ?? "Page"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                if let u = item["url"], let url = URL(string: u) { self?.webView.load(URLRequest(url: url)) }
            })
        }
        alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { [weak self] _ in
            self?.history.removeAll(); self?.saveData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1) }
        present(alert, animated: true)
    }

    private func showSettings() {
        let alert = UIAlertController(title: "Settings", message: "Content blocking: \(contentBlockingEnabled ? "On" : "Off")", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: contentBlockingEnabled ? "Turn Content Blocking Off" : "Turn Content Blocking On", style: .default) { [weak self] _ in
            self?.contentBlockingEnabled.toggle()
        })
        alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { [weak self] _ in
            self?.history.removeAll(); self?.saveData()
        })
        alert.addAction(UIAlertAction(title: "Clear Bookmarks", style: .destructive) { [weak self] _ in
            self?.bookmarks.removeAll(); self?.saveData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController { pop.sourceView = view; pop.sourceRect = CGRect(x: view.bounds.midX, y: 60, width: 1, height: 1) }
        present(alert, animated: true)
    }
}
