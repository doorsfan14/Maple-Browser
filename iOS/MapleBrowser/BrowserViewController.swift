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
            content.bottomAnchor.constraint(equalTo: bottomChrome.topAnchor),
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
        var config = cell.defaultContentConfiguration()
        config.text = item.name
        let percent = Int(item.progress * 100)
        config.secondaryText = item.status == "Downloading" ? "Downloading · \(percent)%" : item.status
        cell.contentConfiguration = config
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
