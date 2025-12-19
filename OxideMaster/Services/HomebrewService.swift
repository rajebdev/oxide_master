import AppKit
import Foundation

class HomebrewService: ObservableObject {
    static let shared = HomebrewService()

    private let apiBaseURL = "https://formulae.brew.sh/api"
    private let session = URLSession.shared

    // MARK: - Search Apps

    func searchApps(query: String) async throws -> [HomebrewApp] {
        var apps: [HomebrewApp] = []

        // Search in formulae
        let formulae = try await searchFormulae(query: query)
        apps.append(contentsOf: formulae)

        // Search in casks
        let casks = try await searchCasks(query: query)
        apps.append(contentsOf: casks)

        return apps
    }

    private func searchFormulae(query: String) async throws -> [HomebrewApp] {
        let urlString = "\(apiBaseURL)/formula.json"
        guard let url = URL(string: urlString) else {
            throw HomebrewError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let allFormulae = try JSONDecoder().decode([HomebrewFormula].self, from: data)

        // Filter by query
        let filtered = allFormulae.filter { formula in
            query.isEmpty || formula.name.localizedCaseInsensitiveContains(query)
                || (formula.desc?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Get installed formulas
        let installedFormulas = getInstalledFormulae()

        return filtered.prefix(50).map { formula in
            HomebrewApp(
                name: formula.name,
                token: formula.name,
                description: formula.desc,
                homepage: formula.homepage,
                version: formula.versions?.stable ?? "Unknown",
                isInstalled: installedFormulas.contains(formula.name),
                isCask: false,
                icon: nil,
                installSize: nil,
                dependencies: nil,
                analytics: nil,
                releaseDate: nil
            )
        }
    }

    private func searchCasks(query: String) async throws -> [HomebrewApp] {
        let urlString = "\(apiBaseURL)/cask.json"
        guard let url = URL(string: urlString) else {
            throw HomebrewError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let allCasks = try JSONDecoder().decode([HomebrewCask].self, from: data)

        // Filter by query
        let filtered = allCasks.filter { cask in
            query.isEmpty || cask.token.localizedCaseInsensitiveContains(query)
                || cask.name.first?.localizedCaseInsensitiveContains(query) ?? false
                || (cask.desc?.localizedCaseInsensitiveContains(query) ?? false)
        }

        // Get installed casks
        let installedCasks = getInstalledCasks()

        return filtered.prefix(50).map { cask in
            HomebrewApp(
                name: cask.name.first ?? cask.token,
                token: cask.token,
                description: cask.desc,
                homepage: cask.homepage,
                version: cask.version ?? "Unknown",
                isInstalled: installedCasks.contains(cask.token),
                isCask: true,
                icon: cask.iconURL,
                installSize: nil,
                dependencies: nil,
                analytics: nil,
                releaseDate: cask.generatedDate
            )
        }
    }

    // MARK: - Get Installed Apps

    func getInstalledApps() async throws -> [HomebrewApp] {
        var apps: [HomebrewApp] = []

        // Get installed formulae
        let formulae = getInstalledFormulae()
        for name in formulae {
            if let app = try? await getFormulaDetail(name: name) {
                apps.append(app)
            }
        }

        // Get installed casks
        let casks = getInstalledCasks()
        for token in casks {
            if let app = try? await getCaskDetail(token: token) {
                apps.append(app)
            }
        }

        return apps
    }

    private func getInstalledFormulae() -> [String] {
        let output = runBrewCommand(arguments: ["list", "--formula"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    private func getInstalledCasks() -> [String] {
        let output = runBrewCommand(arguments: ["list", "--cask"])
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    // MARK: - Get App Details

    func getFormulaDetail(name: String) async throws -> HomebrewApp {
        let urlString = "\(apiBaseURL)/formula/\(name).json"
        guard let url = URL(string: urlString) else {
            throw HomebrewError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let detail = try JSONDecoder().decode(HomebrewFormulaDetail.self, from: data)

        return HomebrewApp(
            name: detail.name,
            token: detail.name,
            description: detail.desc,
            homepage: detail.homepage,
            version: detail.versions.stable,
            isInstalled: detail.installed?.isEmpty == false,
            isCask: false,
            icon: nil,
            installSize: getFormulaSize(name: detail.name),
            dependencies: detail.dependencies,
            analytics: nil,
            releaseDate: nil
        )
    }

    func getCaskDetail(token: String) async throws -> HomebrewApp {
        let urlString = "\(apiBaseURL)/cask/\(token).json"
        guard let url = URL(string: urlString) else {
            throw HomebrewError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let detail = try JSONDecoder().decode(HomebrewCaskDetail.self, from: data)

        return HomebrewApp(
            name: detail.name.first ?? detail.token,
            token: detail.token,
            description: detail.desc,
            homepage: detail.homepage,
            version: detail.version,
            isInstalled: detail.installed != nil,
            isCask: true,
            icon: "https://formulae.brew.sh/images/cask/\(token).png",
            installSize: getCaskSize(token: detail.token),
            dependencies: nil,
            analytics: nil,
            releaseDate: detail.generatedDate
        )
    }

    // MARK: - Install / Uninstall

    func installApp(_ app: HomebrewApp, progress: @escaping (String) -> Void) async throws {
        progress("📥 Downloading \(app.name)...")

        let command = app.isCask ? "install --cask" : "install"
        try await runBrewCommandWithProgress(
            arguments: command.components(separatedBy: " ") + [app.token],
            progress: progress
        )

        progress("✓ Successfully installed \(app.name)")
    }

    func uninstallApp(_ app: HomebrewApp, progress: @escaping (String) -> Void) async throws {
        progress("🗑️ Removing \(app.name)...")

        let command = app.isCask ? "uninstall --cask" : "uninstall"
        try await runBrewCommandWithProgress(
            arguments: command.components(separatedBy: " ") + [app.token],
            progress: progress
        )

        progress("✓ Successfully uninstalled \(app.name)")
    }

    // MARK: - Homebrew Info

    func isHomebrewInstalled() -> Bool {
        let homebrewPaths = [
            "/opt/homebrew/bin/brew",  // Apple Silicon
            "/usr/local/bin/brew",  // Intel
        ]

        return homebrewPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    func getHomebrewVersion() -> String {
        let output = runBrewCommand(arguments: ["--version"])
        return output.components(separatedBy: .newlines).first ?? "Unknown"
    }

    // MARK: - Helper Methods

    private func getFormulaSize(name: String) -> Int64? {
        let output = runBrewCommand(arguments: ["info", "--json=v2", name])
        guard let data = output.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let formulae = json["formulae"] as? [[String: Any]],
            let formula = formulae.first,
            let bottle = formula["bottle"] as? [String: Any],
            let stable = bottle["stable"] as? [String: Any],
            let files = stable["files"] as? [String: Any],
            let firstFile = files.values.first as? [String: Any],
            let size = firstFile["size"] as? Int64
        else {
            return nil
        }
        return size
    }

    private func getCaskSize(token: String) -> Int64? {
        // Try to get size from installed cask
        let cellarPaths = [
            "/opt/homebrew/Caskroom/\(token)",
            "/usr/local/Caskroom/\(token)",
        ]

        for path in cellarPaths {
            if let size = try? FileManager.default.sizeOfDirectory(at: URL(fileURLWithPath: path)) {
                return size
            }
        }

        return nil
    }

    private func runBrewCommandWithProgress(
        arguments: [String],
        progress: @escaping (String) -> Void
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            // Find brew path
            let homebrewPaths = [
                "/opt/homebrew/bin/brew",  // Apple Silicon
                "/usr/local/bin/brew",  // Intel
            ]

            guard
                let brewPath = homebrewPaths.first(where: {
                    FileManager.default.fileExists(atPath: $0)
                })
            else {
                continuation.resume(throwing: HomebrewError.homebrewNotInstalled)
                return
            }

            task.launchPath = brewPath
            task.arguments = arguments
            task.standardOutput = outputPipe
            task.standardError = errorPipe

            // Use a thread-safe class to store data
            final class DataAccumulator: @unchecked Sendable {
                private let lock = NSLock()
                private var _data = Data()

                func append(_ data: Data) {
                    lock.lock()
                    defer { lock.unlock() }
                    _data.append(data)
                }

                func getData() -> Data {
                    lock.lock()
                    defer { lock.unlock() }
                    return _data
                }
            }

            let errorAccumulator = DataAccumulator()

            // Read output in real-time
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    {
                        if !line.isEmpty {
                            progress(line)
                        }
                    }
                }
            }

            // Read errors in real-time
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errorAccumulator.append(data)

                    if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    {
                        if !line.isEmpty && !line.contains("Warning") {
                            progress("⚠️ \(line)")
                        }
                    }
                }
            }

            task.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus != 0 {
                    let errorOutput =
                        String(data: errorAccumulator.getData(), encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: HomebrewError.commandFailed(errorOutput))
                } else {
                    continuation.resume()
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runBrewCommand(arguments: [String]) -> String {
        let task = Process()
        let pipe = Pipe()

        // Find brew path
        let homebrewPaths = [
            "/opt/homebrew/bin/brew",  // Apple Silicon
            "/usr/local/bin/brew",  // Intel
        ]

        guard
            let brewPath = homebrewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }
            )
        else {
            return "Error: Homebrew not found"
        }

        task.launchPath = brewPath
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    enum HomebrewError: LocalizedError {
        case invalidURL
        case homebrewNotInstalled
        case installationFailed(String)
        case uninstallationFailed(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .homebrewNotInstalled:
                return "Homebrew is not installed on this system"
            case .installationFailed(let message):
                return "Installation failed: \(message)"
            case .uninstallationFailed(let message):
                return "Uninstallation failed: \(message)"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            }
        }
    }
}

// Extension to calculate directory size
extension FileManager {
    func sizeOfDirectory(at url: URL) throws -> Int64 {
        var totalSize: Int64 = 0

        let contents = try contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []
        )

        for item in contents {
            let resourceValues = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])

            if resourceValues.isDirectory == true {
                totalSize += try sizeOfDirectory(at: item)
            } else {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }
}
