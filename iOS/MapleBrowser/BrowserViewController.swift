import UIKit
import WebKit
import MapleCore

final class BrowserViewController: UIViewController, WKNavigationDelegate, UISearchBarDelegate {
    private let webView: WKWebView
    private let searchBar = UISearchBar()
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let toolbar = UIStackView()
    private let contentView = UIView()

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        webView.navigationDelegate = self

        searchBar.placeholder = "Search or enter website"
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.returnKeyType = .go

        backButton.setTitle("‹", for: .normal)
        forwardButton.setTitle("›", for: .normal)
        reloadButton.setTitle("↻", for: .normal)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)

        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 8
        toolbar.addArrangedSubview(backButton)
        toolbar.addArrangedSubview(forwardButton)
        toolbar.addArrangedSubview(reloadButton)

        let top = UIStackView(arrangedSubviews: [searchBar, toolbar])
        top.axis = .horizontal
        top.spacing = 6
        top.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(top)
        view.addSubview(contentView)
        contentView.addSubview(webView)

        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                top.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                top.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                top.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                contentView.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 4),
                contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                webView.topAnchor.constraint(equalTo: contentView.topAnchor),
                webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }

        if let home = MapleURL.destination(for: "https://www.google.com") {
            webView.load(URLRequest(url: home))
        }
        updateButtons()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let url = MapleURL.destination(for: searchBar.text ?? "") else { return }
        searchBar.resignFirstResponder()
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        searchBar.text = webView.url?.absoluteString
        updateButtons()
    }

    private func updateButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    @objc private func goBack() { webView.goBack(); updateButtons() }
    @objc private func goForward() { webView.goForward(); updateButtons() }
    @objc private func reload() { webView.reload() }
}
