import AppKit
import Foundation

actor IconLoaderService {
    static let shared = IconLoaderService()

    private let cache = NSCache<NSString, NSImage>()
    private let session: URLSession
    private var loadingTasks: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 100  // Cache max 100 icons
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    /// Load icon asynchronously for a Homebrew app
    func loadIcon(for app: HomebrewApp) async -> NSImage? {
        // Check cache first
        if let cached = cache.object(forKey: app.token as NSString) {
            return cached
        }

        // Check if already loading
        if let task = loadingTasks[app.token] {
            return await task.value
        }

        // Create new loading task
        let task = Task<NSImage?, Never> {
            // Try multiple sources in order
            if let icon = await self.tryLoadFromHomepage(app.homepage) {
                self.cache.setObject(icon, forKey: app.token as NSString)
                return icon
            }

            // Fallback to cask icon if available
            if app.isCask, let icon = await self.tryLoadFromCaskIcon(app.token) {
                self.cache.setObject(icon, forKey: app.token as NSString)
                return icon
            }

            return nil
        }

        loadingTasks[app.token] = task
        let result = await task.value
        loadingTasks.removeValue(forKey: app.token)
        return result
    }

    /// Try to load icon from homepage favicon
    private func tryLoadFromHomepage(_ homepage: String?) async -> NSImage? {
        guard let homepage = homepage else { return nil }

        // If it's a GitHub repo, get the homepage from repo info
        if homepage.contains("github.com") {
            return await tryLoadFromGitHub(homepage)
        }

        // Try to get favicon from the homepage
        return await tryLoadFavicon(from: homepage)
    }

    /// Load icon from GitHub repository
    private func tryLoadFromGitHub(_ repoURL: String) async -> NSImage? {
        // Extract owner and repo name
        guard let url = URL(string: repoURL),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let pathComponents = components.path.split(separator: "/").map(String.init)
                as [String]?,
            pathComponents.count >= 2
        else {
            return nil
        }

        let owner = pathComponents[0]
        let repo = pathComponents[1].replacingOccurrences(of: ".git", with: "")

        // Get repo info from GitHub API
        let apiURL = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: apiURL) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

            let (data, _) = try await session.data(for: request)

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let homepage = json["homepage"] as? String,
                !homepage.isEmpty
            {
                // Try to load favicon from the actual homepage
                return await tryLoadFavicon(from: homepage)
            }
        } catch {
            // Silently fail, will return nil
        }

        return nil
    }

    /// Try to load favicon from a URL
    private func tryLoadFavicon(from urlString: String) async -> NSImage? {
        guard let baseURL = URL(string: urlString) else { return nil }

        // Try multiple favicon paths
        let faviconPaths = [
            "/favicon.ico",
            "/favicon.png",
            "/apple-touch-icon.png",
            "/apple-touch-icon-precomposed.png",
        ]

        // Get the base domain
        guard let scheme = baseURL.scheme,
            let host = baseURL.host
        else { return nil }
        let baseURLString = "\(scheme)://\(host)"

        // Try each favicon path
        for path in faviconPaths {
            if let faviconURL = URL(string: baseURLString + path),
                let image = await downloadImage(from: faviconURL)
            {
                return image
            }
        }

        // Try Google's favicon service as fallback
        if let googleFaviconURL = URL(
            string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)"),
            let image = await downloadImage(from: googleFaviconURL)
        {
            return image
        }

        return nil
    }

    /// Load icon from Homebrew cask icon URL
    private func tryLoadFromCaskIcon(_ token: String) async -> NSImage? {
        let iconURLString = "https://formulae.brew.sh/images/cask/\(token).png"
        guard let url = URL(string: iconURLString) else { return nil }
        return await downloadImage(from: url)
    }

    /// Download image from URL
    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, response) = try await session.data(from: url)

            // Check if response is successful
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                return nil
            }

            // Try to create NSImage from data
            guard let image = NSImage(data: data) else {
                return nil
            }

            // Resize if too large
            return resizeImage(image, maxSize: 64)
        } catch {
            return nil
        }
    }

    /// Resize image to max size while maintaining aspect ratio
    private func resizeImage(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let size = image.size

        // If already small enough, return as is
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)

        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()

        return resizedImage
    }

    /// Clear cache
    func clearCache() {
        cache.removeAllObjects()
    }
}
