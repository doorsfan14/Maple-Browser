import UIKit
import WebKit
import Foundation

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
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
    private var homeView: MapleHomeView?
    private var showingHome = false

    private var webView: WKWebView { tabs[activeIndex] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        overrideUserInterfaceStyle = .unspecified
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
        config.allowsInlineMediaPlayback = true
        config.applicationNameForUserAgent = "Maple/0.1.0"
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
        showingHome = false
        homeView?.removeFromSuperview()
        homeView = nil

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
        updateButtons()
    }

    private func showHome() {
        webView.stopLoading()
        showingHome = true
        content.subviews.forEach { $0.removeFromSuperview() }

        let home = MapleHomeView { [weak self] query in
            self?.navigate(query)
        }
        home.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(home)
        NSLayoutConstraint.activate([
            home.topAnchor.constraint(equalTo: content.topAnchor),
            home.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            home.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            home.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        homeView = home
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
        if showingHome {
            showActiveWebView()
        }
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
        let sourceFrame = webView.convert(webView.bounds, to: view.window)
        webView.takeSnapshot(with: WKSnapshotConfiguration()) { [weak self] snapshot, _ in
            guard let self else { return }
            let controller = MapleTabsViewController(
                tabs: self.tabs,
                activeIndex: self.activeIndex,
                sourceSnapshot: snapshot,
                sourceFrame: sourceFrame,
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
                    guard let self else { return }
                    if self.tabs.count == 1 {
                        self.dismiss(animated: true) {
                            self.closeLastTabAndShowHome()
                        }
                    } else {
                        self.closeTab(tab: tab)
                    }
                }
            )
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = controller
            self.present(controller, animated: true)
        }
    }

    private func switchTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeIndex = index
        showActiveWebView()
    }

    private func closeCurrentTab() {
        if tabs.count == 1 {
            closeLastTabAndShowHome()
        } else {
            closeTab(at: activeIndex)
        }
    }

    private func closeLastTabAndShowHome() {
        guard !tabs.isEmpty else {
            addTab(privateMode: false, url: nil)
            return
        }

        tabs[0].stopLoading()
        tabs[0].navigationDelegate = nil
        tabs[0].uiDelegate = nil
        tabs.removeAll()
        privateTabs.removeAll()
        activeIndex = 0
        addTab(privateMode: false, url: nil)
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



private final class MapleHomeView: UIView {
    private let searchField = UITextField()
    private let logoView = UIImageView()
    private let wavesView = MapleWaveView()
    private let searchHandler: (String) -> Void

    init(searchHandler: @escaping (String) -> Void) {
        self.searchHandler = searchHandler
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        clipsToBounds = true
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        wavesView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wavesView)

        logoView.image = UIImage(named: "MapleLogo")
        logoView.contentMode = .scaleAspectFit
        logoView.clipsToBounds = false
        logoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoView)

        searchField.placeholder = "Search or enter a website"
        searchField.font = .systemFont(ofSize: 17, weight: .regular)
        searchField.textColor = .label
        searchField.tintColor = .label
        searchField.backgroundColor = .secondarySystemBackground
        searchField.layer.cornerRadius = 22
        searchField.layer.cornerCurve = .continuous
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
        searchField.layer.shadowColor = UIColor.black.cgColor
        searchField.layer.shadowOpacity = 0.12
        searchField.layer.shadowRadius = 18
        searchField.layer.shadowOffset = CGSize(width: 0, height: 8)
        searchField.returnKeyType = .go
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.clearButtonMode = .whileEditing
        searchField.addTarget(self, action: #selector(submitSearch), for: .editingDidEndOnExit)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        NSLayoutConstraint.activate([
            wavesView.topAnchor.constraint(equalTo: topAnchor),
            wavesView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wavesView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wavesView.bottomAnchor.constraint(equalTo: bottomAnchor),

            logoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -70),
            logoView.widthAnchor.constraint(equalToConstant: 190),
            logoView.heightAnchor.constraint(equalToConstant: 190),

            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            searchField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            searchField.heightAnchor.constraint(equalToConstant: 44)
        ])

        animateLogo()
    }

    @objc private func submitSearch() {
        let value = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return }
        searchField.resignFirstResponder()
        searchHandler(value)
    }

    private func animateLogo() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, -5, 0, 4, 0]
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.duration = 5.2
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        logoView.layer.add(animation, forKey: "maple.logo.float")
    }
}

private final class MapleWaveView: UIView {
    private struct Wave {
        let shape: CAShapeLayer
        let gradient: CAGradientLayer
        let base: CGFloat
        let amplitude: CGFloat
        let phase: CGFloat
        let duration: CFTimeInterval
    }

    private var waves: [Wave] = []
    private var didAnimate = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .systemBackground
        createWaves()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func createWaves() {
        // Three broad, shallow layers: flowing ribbons rather than tall peaks.
        let palettes: [(UIColor, UIColor)] = [
            (UIColor(red: 1.00, green: 0.31, blue: 0.16, alpha: 1), UIColor(red: 0.84, green: 0.03, blue: 0.24, alpha: 1)),
            (UIColor(red: 1.00, green: 0.70, blue: 0.05, alpha: 1), UIColor(red: 1.00, green: 0.24, blue: 0.02, alpha: 1)),
            (UIColor(red: 0.47, green: 0.20, blue: 0.95, alpha: 1), UIColor(red: 0.00, green: 0.47, blue: 0.98, alpha: 1))
        ]
        let bases: [CGFloat] = [0.72, 0.82, 0.91]
        let amplitudes: [CGFloat] = [0.022, 0.018, 0.015]
        let durations: [CFTimeInterval] = [12, 15, 18]

        for index in 0..<3 {
            let shape = CAShapeLayer()
            let gradient = CAGradientLayer()
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.colors = [palettes[index].0.cgColor, palettes[index].1.cgColor]
            gradient.mask = shape
            layer.addSublayer(gradient)

            waves.append(Wave(
                shape: shape,
                gradient: gradient,
                base: bases[index],
                amplitude: amplitudes[index],
                phase: CGFloat(index) * 1.8,
                duration: durations[index]
            ))
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for wave in waves {
            wave.gradient.frame = bounds
            wave.shape.frame = bounds
            wave.shape.path = makePath(base: wave.base, amplitude: wave.amplitude, phase: wave.phase).cgPath
        }

        if !didAnimate && bounds.width > 0 && bounds.height > 0 {
            didAnimate = true
            startAnimations()
        }
    }

    private func makePath(base: CGFloat, amplitude: CGFloat, phase: CGFloat) -> UIBezierPath {
        let w = bounds.width
        let h = bounds.height
        let y = h * base
        let a = h * amplitude
        let path = UIBezierPath()

        // Long, smooth sine-like ribbon spanning the full screen.
        path.move(to: CGPoint(x: 0, y: y))
        let segments = 8
        let segmentWidth = w / CGFloat(segments)

        for i in 0..<segments {
            let x0 = CGFloat(i) * segmentWidth
            let x1 = CGFloat(i + 1) * segmentWidth
            let y0 = y + sin(phase + CGFloat(i) * 1.15) * a
            let y1 = y + sin(phase + CGFloat(i + 1) * 1.15) * a
            let c1 = CGPoint(x: x0 + segmentWidth * 0.33, y: y0)
            let c2 = CGPoint(x: x1 - segmentWidth * 0.33, y: y1)
            path.addCurve(to: CGPoint(x: x1, y: y1), controlPoint1: c1, controlPoint2: c2)
        }

        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.close()
        return path
    }

    private func startAnimations() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        for wave in waves {
            let current = wave.shape.path ?? makePath(base: wave.base, amplitude: wave.amplitude, phase: wave.phase).cgPath
            let target = makePath(base: wave.base, amplitude: wave.amplitude, phase: wave.phase + .pi).cgPath

            let morph = CABasicAnimation(keyPath: "path")
            morph.fromValue = current
            morph.toValue = target
            morph.duration = wave.duration
            morph.autoreverses = true
            morph.repeatCount = .infinity
            morph.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wave.shape.add(morph, forKey: "maple.wave.morph")

            let drift = CABasicAnimation(keyPath: "transform.translation.x")
            drift.fromValue = -bounds.width * 0.012
            drift.toValue = bounds.width * 0.012
            drift.duration = wave.duration * 1.4
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wave.gradient.add(drift, forKey: "maple.wave.drift")
        }
    }
}

private final class MapleTabsViewController: UIViewController, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning, UIScrollViewDelegate {
    private let tabs: [WKWebView]
    private var activeIndex: Int
    private let sourceSnapshot: UIImage?
    private let sourceFrame: CGRect
    private let onSelect: (Int) -> Void
    private let onNewTab: (Bool) -> Void
    private let onClose: (WKWebView) -> Void

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var cardViews: [UIView] = []
    private var previewViews: [UIImageView] = []
    private var isPresentingTransition = true

    init(tabs: [WKWebView], activeIndex: Int, sourceSnapshot: UIImage?, sourceFrame: CGRect,
         onSelect: @escaping (Int) -> Void,
         onNewTab: @escaping (Bool) -> Void,
         onClose: @escaping (WKWebView) -> Void) {
        self.tabs = tabs
        self.activeIndex = activeIndex
        self.sourceSnapshot = sourceSnapshot
        self.sourceFrame = sourceFrame
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

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.52 }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView

        if isPresentingTransition {
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }

            container.addSubview(toView)
            toView.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
            toView.layoutIfNeeded()
            updateCardDepth()

            let activeCard = cardViews.indices.contains(activeIndex) ? cardViews[activeIndex] : nil
            let activePreview = previewViews.indices.contains(activeIndex) ? previewViews[activeIndex] : nil

            if let snapshot = sourceSnapshot, let activePreview {
                let overlay = UIImageView(image: snapshot)
                overlay.contentMode = .scaleAspectFit
                overlay.clipsToBounds = true
                overlay.backgroundColor = .systemBackground
                overlay.frame = sourceFrame
                container.addSubview(overlay)

                activePreview.alpha = 0
                let previewBounds = activePreview.convert(activePreview.bounds, to: container)
                let targetRect = aspectFitRect(imageSize: snapshot.size, in: previewBounds)

                let animator = UIViewPropertyAnimator(
                    duration: transitionDuration(using: transitionContext),
                    timingParameters: UISpringTimingParameters(
                        dampingRatio: 0.9,
                        initialVelocity: CGVector(dx: 0, dy: 0.15)
                    )
                )
                animator.addAnimations {
                    overlay.frame = targetRect
                    overlay.layer.cornerRadius = 18
                    activePreview.alpha = 1
                }
                animator.addCompletion { _ in
                    overlay.removeFromSuperview()
                    self.refreshSnapshots()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
                animator.startAnimation()
            } else {
                transitionContext.completeTransition(true)
            }
        } else {
            guard let fromView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }

            let animator = UIViewPropertyAnimator(
                duration: transitionDuration(using: transitionContext),
                timingParameters: UISpringTimingParameters(dampingRatio: 0.92)
            )
            animator.addAnimations {
                fromView.alpha = 0
                fromView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
            animator.addCompletion { _ in
                fromView.transform = .identity
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            animator.startAnimation()
        }
    }

    private func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
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
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = -155
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

        view.layoutIfNeeded()
        scrollToActive(animated: false)
        updateCardDepth()
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
        overlay.backgroundColor = .systemBackground
        overlay.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(overlay)

        let label = UILabel()
        let title = tabs[index].title?.isEmpty == false ? tabs[index].title! : "New Tab"
        label.text = title
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

        card.transform = .identity
        card.alpha = 1
        card.layer.shouldRasterize = false
    }

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

    private func updateCardDepth() {
        guard !cardViews.isEmpty else { return }
        let centerX = scrollView.bounds.midX

        for card in cardViews {
            let rect = card.convert(card.bounds, to: scrollView)
            let distance = abs(rect.midX - centerX) / max(card.bounds.width, 1)
            let scale = max(0.70, 1.0 - min(distance, 3.0) * 0.09)
            card.transform = CGAffineTransform(scaleX: scale, y: scale)
            card.alpha = 1
            card.layer.zPosition = CGFloat(1000 - distance * 100)
        }

        if let topCard = cardViews.min(by: {
            abs($0.convert($0.bounds, to: self.scrollView).midX - centerX) <
            abs($1.convert($1.bounds, to: self.scrollView).midX - centerX)
        }) {
            topCard.layer.zPosition = 2000
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCardDepth()
    }

    private func scrollToActive(animated: Bool) {
        guard activeIndex < cardViews.count else { return }
        let card = cardViews[activeIndex]
        let rect = card.convert(card.bounds, to: scrollView)
        let targetX = max(-scrollView.adjustedContentInset.left,
                          min(rect.midX - scrollView.bounds.width / 2,
                              scrollView.contentSize.width - scrollView.bounds.width))
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

        let animator = UIViewPropertyAnimator(duration: 0.38, dampingRatio: 0.9) {
            card.transform = CGAffineTransform(scaleX: 0.78, y: 0.78).translatedBy(x: 0, y: 18)
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
