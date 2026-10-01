import Foundation

public enum MapleURL {
    public static let defaultSearchURL = URL(string: "https://www.google.com/search?q=")!

    public static func destination(for input: String) -> URL? {
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
}
