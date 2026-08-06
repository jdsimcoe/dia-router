import AppKit
import SwiftUI

@MainActor
struct FaviconView: View {
    let pattern: String

    @StateObject private var loader = FaviconLoader()

    private var domain: String? {
        FaviconSource.domain(from: pattern)
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallback
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .clipped()
        .accessibilityLabel(domain.map { "Favicon for \($0)" } ?? "Rule icon")
        .task(id: FaviconSource.url(for: pattern)) {
            await loader.load(FaviconSource.url(for: pattern))
        }
    }

    private var fallback: some View {
        Image(systemName: "globe")
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
            .foregroundStyle(.secondary)
    }
}

@MainActor
private final class FaviconLoader: ObservableObject {
    @Published private(set) var image: NSImage?

    private static let cache = NSCache<NSURL, NSImage>()
    private var requestedURL: URL?

    func load(_ url: URL?) async {
        guard requestedURL != url else { return }
        requestedURL = url
        image = nil

        guard let url else { return }
        if let cachedImage = Self.cache.object(forKey: url as NSURL) {
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard requestedURL == url,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let loadedImage = NSImage(data: data) else { return }
            Self.cache.setObject(loadedImage, forKey: url as NSURL)
            image = loadedImage
        } catch {
            // The local globe remains visible when a favicon cannot be loaded.
        }
    }
}

enum FaviconSource {
    static func domain(from pattern: String) -> String? {
        let normalized = pattern
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\"#, with: "")

        guard !normalized.isEmpty,
              let expression = try? NSRegularExpression(
                pattern: #"(?i)(?:https?://)?(?:www\.)?([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+)"#
              ),
              let match = expression.firstMatch(
                in: normalized,
                range: NSRange(normalized.startIndex..., in: normalized)
              ),
              let domainRange = Range(match.range(at: 1), in: normalized) else {
            return nil
        }

        return String(normalized[domainRange]).lowercased()
    }

    static func url(for pattern: String) -> URL? {
        guard let domain = domain(from: pattern) else { return nil }

        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "domain_url", value: "https://\(domain)"),
            URLQueryItem(name: "sz", value: "64"),
        ]
        return components?.url
    }
}
