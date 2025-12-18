import AppKit
import Foundation

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let version: String
    let appPath: URL
    let appSize: Int64
    let icon: NSImage?
    var relatedFiles: [RelatedFile] = []
    var totalSize: Int64 {
        appSize + relatedFiles.reduce(0) { $0 + $1.size }
    }
    var lastUsedDate: Date?
    var isSystemApp: Bool = false
    var loginItems: [LoginItem] = []
    var source: AppSource = .user
    var installType: InstallType = .regular

    enum AppSource: String, CaseIterable {
        case system = "System Apps"
        case homebrew = "Homebrew"
        case appStore = "App Store"
        case user = "User Apps"

        var icon: String {
            switch self {
            case .system: return "applelogo"
            case .homebrew: return "terminal.fill"
            case .appStore: return "app.dashed"
            case .user: return "person.circle.fill"
            }
        }
    }

    enum InstallType {
        case regular  // .app files
        case homebrewFormula  // brew formula (python, go, etc)
        case homebrewCask  // brew cask (GUI apps)
        case prefPane  // Preference Panes
        case driver  // Audio/Hardware drivers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct RelatedFile: Identifiable, Hashable {
    let id = UUID()
    let path: URL
    let category: FileCategory
    let size: Int64

    enum FileCategory: String, CaseIterable {
        case applicationSupport = "Application Support"
        case preferences = "Preferences"
        case caches = "Caches"
        case logs = "Logs"
        case containers = "Containers"
        case savedState = "Saved Application State"
        case launchAgents = "Launch Agents"
        case launchDaemons = "Launch Daemons"

        var icon: String {
            switch self {
            case .applicationSupport: return "folder.fill"
            case .preferences: return "gearshape.fill"
            case .caches: return "tray.fill"
            case .logs: return "doc.text.fill"
            case .containers: return "shippingbox.fill"
            case .savedState: return "clock.arrow.circlepath"
            case .launchAgents, .launchDaemons: return "power"
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RelatedFile, rhs: RelatedFile) -> Bool {
        lhs.id == rhs.id
    }
}

struct LoginItem: Identifiable, Hashable {
    let id = UUID()
    let path: URL
    let type: LoginItemType
    let isEnabled: Bool

    enum LoginItemType: String {
        case launchAgent = "Launch Agent"
        case launchDaemon = "Launch Daemon"
        case loginItem = "Login Item"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LoginItem, rhs: LoginItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct OrphanedFiles: Identifiable {
    let id = UUID()
    let bundleIdentifier: String
    let appName: String
    let files: [RelatedFile]
    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}
