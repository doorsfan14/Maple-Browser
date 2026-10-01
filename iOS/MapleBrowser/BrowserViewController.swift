import UIKit
import WebKit
import Foundation

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

        loadHome()
        updateButtons()

        if !UserDefaults.standard.bool(forKey: "maple.didShowCelesteAccountPrompt") {
            UserDefaults.standard.set(true, forKey: "maple.didShowCelesteAccountPrompt")
            DispatchQueue.main.async { [weak self] in
                self?.showCelesteAccountPrompt()
            }
        }
    }

    private func loadHome() {
        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }
    }

    private func destination(for input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://" + trimmed)
        }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://www.google.com/search?q=" + encoded)
    }

    private func showCelesteAccountPrompt() {
        let alert = UIAlertController(
            title: "Wanna connect your Celeste Account?",
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.showLocalDataMessage()
        })
        alert.addAction(UIAlertAction(title: "No", style: .cancel))

        present(alert, animated: true)
    }

    private func showLocalDataMessage() {
        let alert = UIAlertController(
            title: "Just kidding, dude.",
            message: "No need to connect accounts if you're gonna use this rarely lol, plus it's better if your data stays local rather than your save data (eg: browser history) stays on a server, enjoy the browser!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Enjoy Maple", style: .default))
        present(alert, animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let url = destination(for: searchBar.text ?? "") else { return }
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
