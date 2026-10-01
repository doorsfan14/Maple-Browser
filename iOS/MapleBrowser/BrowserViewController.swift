import UIKit
import WebKit
import Foundation

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private let addressBar = UITextField()
    private let content = UIView()
    private let bottomBar = UIStackView()
    private let bottomChrome = UIStackView()
    private let chromeBar = UIView()
    private let downloadManager = MapleDownloadManager()
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

        bottomBar.axis = .horizontal
        bottomBar.alignment = .center
        bottomBar.distribution = .equalSpacing
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        [toolbarButton("chevron.left", #selector(goBack)), toolbarButton("chevron.right", #selector(goForward)),
         toolbarButton("plus", #selector(newTab)), toolbarButton("square.on.square", #selector(showTabs)),
         toolbarButton("ellipsis", #selector(showMenu))].forEach { bottomBar.addArrangedSubview($0) }

        bottomChrome.axis = .vertical
        bottomChrome.spacing = 7
        bottomChrome.translatesAutoresizingMaskIntoConstraints = false
        bottomChrome.addArrangedSubview(addressBar)
        bottomChrome.addArrangedSubview(bottomBar)

        content.translatesAutoresizingMaskIntoConstraints = false
        chromeBar.backgroundColor = .systemBackground
        chromeBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chromeBar)
        view.addSubview(content)
        view.addSubview(bottomChrome)

        NSLayoutConstraint.activate([
            chromeBar.topAnchor.constraint(equalTo: view.topAnchor),
            chromeBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeBar.bottomAnchor.constraint(equalTo: content.topAnchor),
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: bottomChrome.topAnchor, constant: -10),
            bottomChrome.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            bottomChrome.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            bottomChrome.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5),
            addressBar.heightAnchor.constraint(equalToConstant: 44),
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

    @available(iOS 13.0, *)
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType,
           let url = navigationResponse.response.url {
            if #available(iOS 14.5, *) {
                decisionHandler(.download)
                downloadManager.start(url: url)
            } else {
                decisionHandler(.cancel)
            }
            return
        }
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
        let controller = MapleTabsViewController(
            tabs: tabs,
            activeIndex: activeIndex,
            onSelect: { [weak self] index in
                self?.dismiss(animated: true) {
                    self?.switchTab(index)
                }
            },
            onNewTab: { [weak self] privateMode in
                self?.dismiss(animated: true) {
                    self?.addTab(privateMode: privateMode, url: nil)
                }
            },
            onClose: { [weak self] tab in
                self?.closeTab(tab: tab)
            }
        )
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = controller
        present(controller, animated: true)
    }

    private func switchTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        showActiveWebView()
    }

    private func closeCurrentTab() {
        closeTab(at: activeIndex)
    }

    private func closeTab(at index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        tabs[index].stopLoading()
        tabs[index].navigationDelegate = nil
        tabs[index].uiDelegate = nil
        tabs.remove(at: index)
        privateTabs.remove(at: index)
        if activeIndex >= tabs.count {
            activeIndex = tabs.count - 1
        } else if index < activeIndex {
            activeIndex -= 1
        } else if index == activeIndex {
            activeIndex = min(activeIndex, tabs.count - 1)
        }
        showActiveWebView()
    }

    private func closeTab(tab: WKWebView) {
        guard let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        closeTab(at: index)
    }

    @objc private func showMenu() {
        showActionPanel(title: "Maple Browser", actions: [
            ("Reload", { [weak self] in self?.reload() }),
            ("Add Bookmark", { [weak self] in self?.addBookmark() }),
            ("Bookmarks", { [weak self] in self?.showBookmarks() }),
            ("History", { [weak self] in self?.showHistory() }),
            ("Downloads", { [weak self] in self?.showDownloads() }),
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

    private func showDownloads() {
        let controller = DownloadsViewController(manager: downloadManager)
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    private func showSettings() {
        let controller = SettingsViewController(
            clearHistory: { [weak self] in self?.history.removeAll(); self?.saveData() },
            clearBookmarks: { [weak self] in self?.bookmarks.removeAll(); self?.saveData() },
            clearWebData: { [weak self] in
                for w in self?.tabs ?? [] {
                    w.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {}
                }
            },
            showDownloads: { [weak self] in self?.showDownloads() }
        )
        present(UINavigationController(rootViewController: controller), animated: true)
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


private final class MapleTabsViewController: UIViewController, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {
    private let tabs: [WKWebView]
    private var activeIndex: Int
    private let onSelect: (Int) -> Void
    private let onNewTab: (Bool) -> Void
    private let onClose: (WKWebView) -> Void

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var cardViews: [UIView] = []
    private var previewViews: [UIImageView] = []
    private var hasPlayedOpenAnimation = false
    private var isPresentingTransition = true

    init(tabs: [WKWebView], activeIndex: Int,
         onSelect: @escaping (Int) -> Void,
         onNewTab: @escaping (Bool) -> Void,
         onClose: @escaping (WKWebView) -> Void) {
        self.tabs = tabs
        self.activeIndex = activeIndex
        self.onSelect = onSelect
        self.onNewTab = onNewTab
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresentingTransition = true
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresentingTransition = false
        return self
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.46
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let duration = transitionDuration(using: transitionContext)

        if isPresentingTransition {
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            container.addSubview(toView)
            toView.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
            toView.alpha = 1

            // Start the entire switcher as the active website-sized surface.
            // The card itself is then animated down into its real app-switcher size.
            toView.layoutIfNeeded()

            let activeCard = cardViews.indices.contains(activeIndex) ? cardViews[activeIndex] : nil
            let activePreview = previewViews.indices.contains(activeIndex) ? previewViews[activeIndex] : nil

            let finalCardTransform = activeCard?.transform ?? .identity
            let finalPreviewTransform = activePreview?.transform ?? .identity

            activeCard?.transform = CGAffineTransform(scaleX: 1.32, y: 1.32)
            activeCard?.alpha = 0
            activePreview?.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)

            // Keep the surrounding UI quiet while the webpage shrinks into its card.
            for (index, card) in cardViews.enumerated() where index != activeIndex {
                card.alpha = 0
                card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            }

            let timing = UISpringTimingParameters(dampingRatio: 0.88, initialVelocity: CGVector(dx: 0, dy: 0))
            let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
            animator.addAnimations {
                activeCard?.transform = finalCardTransform
                activeCard?.alpha = 1
                activePreview?.transform = finalPreviewTransform

                for (index, card) in self.cardViews.enumerated() where index != self.activeIndex {
                    card.alpha = 0.72
                    card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                }
            }
            animator.addCompletion { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            animator.startAnimation()
        } else {
            guard let fromView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }

            UIViewPropertyAnimator.runningPropertyAnimator(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: 0.92,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .curveEaseIn],
                animations: {
                    fromView.alpha = 0
                    fromView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
                },
                completion: { _ in
                    fromView.transform = .identity
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let title = UILabel()
        title.text = "Tabs"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .label
        close.addTarget(self, action: #selector(dismissTabs), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false

        let privateButton = UIButton(type: .system)
        privateButton.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        privateButton.tintColor = .label
        privateButton.addTarget(self, action: #selector(newPrivateTab), for: .touchUpInside)
        privateButton.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(title)
        header.addSubview(privateButton)
        header.addSubview(close)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.decelerationRate = .fast
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = -150
        stack.translatesAutoresizingMaskIntoConstraints = false

        let newButton = UIButton(type: .system)
        newButton.setTitle("＋ New Tab", for: .normal)
        newButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        newButton.backgroundColor = .secondarySystemBackground
        newButton.setTitleColor(.label, for: .normal)
        newButton.layer.cornerRadius = 12
        newButton.addTarget(self, action: #selector(newTab), for: .touchUpInside)
        newButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newButton)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            header.heightAnchor.constraint(equalToConstant: 44),

            title.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            close.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 36),
            close.heightAnchor.constraint(equalToConstant: 36),

            privateButton.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),
            privateButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            privateButton.widthAnchor.constraint(equalToConstant: 36),
            privateButton.heightAnchor.constraint(equalToConstant: 36),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: newButton.topAnchor, constant: -16),

            newButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            newButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            newButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            newButton.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        for index in tabs.indices {
            addCard(for: index)
        }

        DispatchQueue.main.async { [weak self] in
            self?.scrollToActive(animated: false)
            self?.refreshSnapshots()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPlayedOpenAnimation else { return }
        hasPlayedOpenAnimation = true
    }

    private func addCard(for index: Int) {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = index

        let preview = UIImageView()
        preview.backgroundColor = .tertiarySystemBackground
        preview.contentMode = .scaleAspectFit
        preview.clipsToBounds = true
        preview.isUserInteractionEnabled = false
        preview.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(preview)

        let overlay = UIView()
        overlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.94)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(overlay)

        let label = UILabel()
        let title = tabs[index].title?.isEmpty == false ? tabs[index].title! : "New Tab"
        label.text = privateTabTitle(for: index) + title
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .secondaryLabel
        close.tag = index
        close.addTarget(self, action: #selector(closeCard(_:)), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(close)

        let tap = UITapGestureRecognizer(target: self, action: #selector(selectCard(_:)))
        card.addGestureRecognizer(tap)

        stack.addArrangedSubview(card)
        cardViews.append(card)
        previewViews.append(preview)

        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.72),
            card.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.66),

            preview.topAnchor.constraint(equalTo: card.topAnchor),
            preview.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            overlay.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            overlay.heightAnchor.constraint(equalToConstant: 48),

            label.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),

            close.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -10),
            close.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 32),
            close.heightAnchor.constraint(equalToConstant: 32)
        ])

        card.transform = index == activeIndex ? .identity : CGAffineTransform(scaleX: 0.92, y: 0.92)
        card.alpha = index == activeIndex ? 1 : 0.72
        // Avoid layer rasterization during scroll/transform animations; it can make
        // overlapping cards visibly snap between cached and uncached surfaces.
        card.layer.shouldRasterize = false
    }

    private func privateTabTitle(for index: Int) -> String { "" }

    private func refreshSnapshots() {
        for index in tabs.indices {
            guard index < previewViews.count else { continue }
            let webView = tabs[index]
            let imageView = previewViews[index]

            let configuration = WKSnapshotConfiguration()
            configuration.afterScreenUpdates = false

            webView.takeSnapshot(with: configuration) { [weak imageView] image, _ in
                guard let image else { return }
                DispatchQueue.main.async {
                    imageView?.image = image
                }
            }
        }
    }

    private func scrollToActive(animated: Bool) {
        guard activeIndex < cardViews.count else { return }
        let card = cardViews[activeIndex]
        let rect = card.convert(card.bounds, to: scrollView)
        let targetX = max(0, rect.midX - scrollView.bounds.width / 2)
        scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: animated)
    }

    @objc private func selectCard(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view, card.tag >= 0 else { return }
        onSelect(card.tag)
    }

    @objc private func closeCard(_ sender: UIButton) {
        let index = sender.tag
        guard index < cardViews.count else { return }
        let card = cardViews[index]
        let tab = tabs[index]

        let animator = UIViewPropertyAnimator(duration: 0.42, dampingRatio: 0.86) {
            card.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
                .translatedBy(x: 0, y: 18)
            card.alpha = 0
        }
        animator.addCompletion { [weak self, weak card] _ in
            card?.removeFromSuperview()
            self?.onClose(tab)
        }
        animator.startAnimation()
    }

    @objc private func dismissTabs() { dismiss(animated: true) }
    @objc private func newTab() { onNewTab(false) }
    @objc private func newPrivateTab() { onNewTab(true) }
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


private final class MapleDownloadManager: NSObject, URLSessionDownloadDelegate {
    struct Item {
        var id: String
        var name: String
        var url: String
        var progress: Double
        var status: String
        var filePath: String?
        var resumeData: Data?
    }

    private(set) var items: [Item] = []
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
    }()

    override init() {
        super.init()
        load()
    }

    func start(url: URL) {
        let id = UUID().uuidString
        let name = url.lastPathComponent.isEmpty ? "Download" : url.lastPathComponent
        let item = Item(id: id, name: name, url: url.absoluteString, progress: 0, status: "Downloading", filePath: nil, resumeData: nil)
        items.insert(item, at: 0)
        save()
        let task = session.downloadTask(with: url)
        task.taskDescription = id
        task.resume()
    }

    func retry(_ item: Item) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = "Downloading"
        save()
        if let data = item.resumeData {
            let task = session.downloadTask(withResumeData: data)
            task.taskDescription = item.id
            items[index].resumeData = nil
            task.resume()
        } else if let url = URL(string: item.url) {
            let task = session.downloadTask(with: url)
            task.taskDescription = item.id
            task.resume()
        }
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func downloadItems() -> [Item] { items }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription,
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        if totalBytesExpectedToWrite > 0 {
            items[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
        items[index].status = "Downloading"
        save()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription,
              let index = items.firstIndex(where: { $0.id == id }) else { return }
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeName = items[index].name.replacingOccurrences(of: "/", with: "_")
        let destination = dir.appendingPathComponent(safeName)
        try? fm.removeItem(at: destination)
        do {
            try fm.moveItem(at: location, to: destination)
            items[index].progress = 1
            items[index].status = "Completed"
            items[index].filePath = destination.path
            items[index].resumeData = nil
        } catch {
            items[index].status = "Failed"
        }
        save()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let id = downloadTask.taskDescription,
              let index = items.firstIndex(where: { $0.id == id }),
              let error else { return }
        let nsError = error as NSError
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            items[index].resumeData = resumeData
            items[index].status = "Paused / failed — Resume available"
        } else {
            items[index].status = "Failed — Tap Retry"
        }
        save()
    }

    private func save() {
        let encoded = items.map { item -> [String: Any] in
            [
                "id": item.id, "name": item.name, "url": item.url,
                "progress": item.progress, "status": item.status,
                "filePath": item.filePath as Any,
                "resumeData": item.resumeData as Any
            ]
        }
        UserDefaults.standard.set(encoded, forKey: "maple.downloads")
    }

    private func load() {
        guard let raw = UserDefaults.standard.array(forKey: "maple.downloads") as? [[String: Any]] else { return }
        items = raw.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let url = dict["url"] as? String else { return nil }
            return Item(id: id, name: name, url: url,
                        progress: dict["progress"] as? Double ?? 0,
                        status: dict["status"] as? String ?? "Failed — Tap Retry",
                        filePath: dict["filePath"] as? String,
                        resumeData: dict["resumeData"] as? Data)
        }
    }
}

private final class DownloadsViewController: UITableViewController {
    private let manager: MapleDownloadManager
    private var items: [MapleDownloadManager.Item] = []

    init(manager: MapleDownloadManager) {
        self.manager = manager
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloads"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "download")
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    private func refresh() {
        items = manager.downloadItems()
        tableView.reloadData()
    }

    @objc private func close() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "download", for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.name
        let percent = Int(item.progress * 100)
        cell.detailTextLabel?.text = item.status == "Downloading" ? "Downloading · \(percent)%" : item.status
        cell.accessoryType = item.status == "Completed" ? .checkmark : .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        if item.status.contains("Failed") || item.status.contains("Paused") {
            manager.retry(item)
            refresh()
        } else if item.status == "Completed", let path = item.filePath {
            let url = URL(fileURLWithPath: path)
            let controller = UIDocumentInteractionController(url: url)
            controller.presentPreview(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            manager.remove(items[indexPath.row])
            refresh()
        }
    }
}

private final class SettingsViewController: UITableViewController {
    private let clearHistory: () -> Void
    private let clearBookmarks: () -> Void
    private let clearWebData: () -> Void
    private let showDownloads: () -> Void

    init(clearHistory: @escaping () -> Void, clearBookmarks: @escaping () -> Void,
         clearWebData: @escaping () -> Void, showDownloads: @escaping () -> Void) {
        self.clearHistory = clearHistory
        self.clearBookmarks = clearBookmarks
        self.clearWebData = clearWebData
        self.showDownloads = showDownloads
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : section == 1 ? 1 : 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Downloads", "Browsing Data", "About"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if indexPath.section == 0 {
            cell.textLabel?.text = "Downloads"
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 1 {
            let labels = ["Clear History", "Clear Bookmarks", "Clear Web Data"]
            cell.textLabel?.text = labels[indexPath.row]
            if indexPath.row == 2 { cell.textLabel?.textColor = .systemRed }
        } else {
            let labels = ["Maple Browser", "Version", "Search Engine"]
            let values = ["Team Celeste", "0.1.0", "Google"]
            cell.textLabel?.text = labels[indexPath.row]
            cell.detailTextLabel?.text = values[indexPath.row]
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 { showDownloads() }
        else if indexPath.section == 1 {
            if indexPath.row == 0 { clearHistory() }
            else if indexPath.row == 1 { clearBookmarks() }
            else { clearWebData() }
        }
    }

    @objc private func close() { dismiss(animated: true) }
}
