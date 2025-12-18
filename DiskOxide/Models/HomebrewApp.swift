import AppKit
import Foundation

struct HomebrewApp: Identifiable, Codable, Hashable {
    let id = UUID()
    let name: String
    let token: String  // homebrew formula/cask name
    let description: String?
    let homepage: String?
    let version: String
    let isInstalled: Bool
    let isCask: Bool  // true = GUI app (cask), false = CLI tool (formula)
    var icon: String?  // URL string for icon
    var installSize: Int64?
    var dependencies: [String]?
    var analytics: HomebrewAnalytics?
    var releaseDate: String?  // Release/generated date

    enum CodingKeys: String, CodingKey {
        case name, token
        case description = "desc"
        case homepage, version
        case isInstalled, isCask, icon, installSize, dependencies, analytics, releaseDate
    }

    var displayName: String {
        name.split(separator: "/").last.map(String.init) ?? name
    }

    var formattedSize: String {
        guard let size = installSize else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedReleaseDate: String? {
        guard let releaseDate = releaseDate else { return nil }

        // Parse ISO8601 date format
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: releaseDate) else { return releaseDate }

        // Format to readable format
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: date)
    }

    var category: AppCategory {
        if isCask {
            return .application
        } else {
            // Categorize based on common formula names
            let lowerName = name.lowercased()
            if lowerName.contains("python") || lowerName.contains("node")
                || lowerName.contains("ruby")
                || lowerName.contains("go") || lowerName.contains("rust")
            {
                return .development
            } else if lowerName.contains("git") || lowerName.contains("svn") {
                return .versionControl
            } else if lowerName.contains("mysql") || lowerName.contains("postgres")
                || lowerName.contains("redis") || lowerName.contains("mongodb")
            {
                return .database
            } else if lowerName.contains("nginx") || lowerName.contains("apache") {
                return .server
            }
            return .utility
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: HomebrewApp, rhs: HomebrewApp) -> Bool {
        lhs.id == rhs.id
    }
}

enum AppCategory: String, CaseIterable {
    case all = "All"
    case application = "Applications"
    case development = "Development"
    case utility = "Utilities"
    case versionControl = "Version Control"
    case database = "Databases"
    case server = "Servers"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .application: return "app.dashed"
        case .development: return "hammer"
        case .utility: return "wrench.and.screwdriver"
        case .versionControl: return "arrow.triangle.branch"
        case .database: return "cylinder"
        case .server: return "server.rack"
        }
    }
}

struct HomebrewAnalytics: Codable, Hashable {
    let install30Days: Int?
    let install90Days: Int?
    let install365Days: Int?

    enum CodingKeys: String, CodingKey {
        case install30Days = "install_on_request"
        case install90Days = "install_on_request_90d"
        case install365Days = "install_on_request_365d"
    }
}

// Response models for Homebrew API
struct HomebrewSearchResponse: Codable {
    let formulae: [HomebrewFormula]
    let casks: [HomebrewCask]
}

struct HomebrewFormula: Codable {
    let name: String
    let desc: String?
    let homepage: String?
    let versions: VersionInfo?
    let installed: [InstalledInfo]?

    struct VersionInfo: Codable {
        let stable: String?
    }

    struct InstalledInfo: Codable {
        let version: String
    }
}

struct HomebrewCask: Codable {
    let token: String
    let name: [String]
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: String?
    let url: String?
    let generatedDate: String?

    enum CodingKeys: String, CodingKey {
        case token, name, desc, homepage, version, installed, url
        case generatedDate = "generated_date"
    }

    var iconURL: String? {
        // Try to get icon from caskroom.org or other sources
        return "https://formulae.brew.sh/images/cask/\(token).png"
    }
}

// For detailed info API
struct HomebrewFormulaDetail: Codable {
    let name: String
    let fullName: String
    let tap: String
    let oldnames: [String]
    let aliases: [String]
    let versionedFormulae: [String]
    let desc: String?
    let license: String?
    let homepage: String?
    let versions: Versions
    let urls: URLs
    let revision: Int
    let versionScheme: Int
    let bottle: Bottle?
    let kegOnly: Bool
    let kegOnlyReason: KegOnlyReason?
    let options: [String]
    let buildDependencies: [String]
    let dependencies: [String]
    let testDependencies: [String]
    let recommendedDependencies: [String]
    let optionalDependencies: [String]
    let usesFromMacos: [UsesFromMacos]
    let usesFromMacosBounds: [[String: String]]
    let requirements: [String]
    let conflictsWith: [String]
    let conflictsWithReasons: [String]
    let linkOverwrite: [String]
    let caveats: String?
    let installed: [InstalledVersion]?
    let linkedKeg: String?
    let pinned: Bool
    let outdated: Bool
    let deprecated: Bool
    let deprecationDate: String?
    let deprecationReason: String?
    let disabled: Bool
    let disableDate: String?
    let disableReason: String?
    let postInstallDefined: Bool
    let service: ServiceInfo?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap, oldnames, aliases
        case versionedFormulae = "versioned_formulae"
        case desc, license, homepage, versions, urls, revision
        case versionScheme = "version_scheme"
        case bottle
        case kegOnly = "keg_only"
        case kegOnlyReason = "keg_only_reason"
        case options
        case buildDependencies = "build_dependencies"
        case dependencies
        case testDependencies = "test_dependencies"
        case recommendedDependencies = "recommended_dependencies"
        case optionalDependencies = "optional_dependencies"
        case usesFromMacos = "uses_from_macos"
        case usesFromMacosBounds = "uses_from_macos_bounds"
        case requirements
        case conflictsWith = "conflicts_with"
        case conflictsWithReasons = "conflicts_with_reasons"
        case linkOverwrite = "link_overwrite"
        case caveats, installed
        case linkedKeg = "linked_keg"
        case pinned, outdated, deprecated
        case deprecationDate = "deprecation_date"
        case deprecationReason = "deprecation_reason"
        case disabled
        case disableDate = "disable_date"
        case disableReason = "disable_reason"
        case postInstallDefined = "post_install_defined"
        case service
    }

    struct Versions: Codable {
        let stable: String
        let head: String?
        let bottle: Bool
    }

    struct URLs: Codable {
        let stable: URLInfo?
        let head: HeadURLInfo?

        struct URLInfo: Codable {
            let url: String
            let tag: String?
            let revision: String?
            let using: String?
            let checksum: String?
        }

        struct HeadURLInfo: Codable {
            let url: String
            let branch: String?
            let using: String?
        }
    }

    struct Bottle: Codable {
        let stable: StableBottle

        struct StableBottle: Codable {
            let rebuild: Int
            let rootUrl: String
            let files: [String: BottleFile]

            enum CodingKeys: String, CodingKey {
                case rebuild
                case rootUrl = "root_url"
                case files
            }
        }

        struct BottleFile: Codable {
            let cellar: String
            let url: String
            let sha256: String
        }
    }

    struct KegOnlyReason: Codable {
        let reason: String?
        let explanation: String?
    }

    enum UsesFromMacos: Codable {
        case string(String)
        case dictionary([String: String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let dict = try? container.decode([String: String].self) {
                self = .dictionary(dict)
            } else {
                throw DecodingError.typeMismatch(
                    UsesFromMacos.self,
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Expected String or Dictionary"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .dictionary(let value):
                try container.encode(value)
            }
        }

        var stringValue: String {
            switch self {
            case .string(let value):
                return value
            case .dictionary(let dict):
                return dict.keys.first ?? ""
            }
        }
    }

    struct InstalledVersion: Codable {
        let version: String
        let usedOptions: [String]
        let builtAsBottle: Bool
        let pouredFromBottle: Bool
        let time: Int
        let runtimeDependencies: [RuntimeDependency]
        let installedAsDependency: Bool
        let installedOnRequest: Bool

        enum CodingKeys: String, CodingKey {
            case version
            case usedOptions = "used_options"
            case builtAsBottle = "built_as_bottle"
            case pouredFromBottle = "poured_from_bottle"
            case time
            case runtimeDependencies = "runtime_dependencies"
            case installedAsDependency = "installed_as_dependency"
            case installedOnRequest = "installed_on_request"
        }

        struct RuntimeDependency: Codable {
            let fullName: String
            let version: String
            let revision: Int
            let pkgVersion: String
            let declaredDirectly: Bool

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case version, revision
                case pkgVersion = "pkg_version"
                case declaredDirectly = "declared_directly"
            }
        }
    }

    struct ServiceInfo: Codable {
        let name: String?
        let run: [String]?
        let runType: String?
        let workingDir: String?
        let keepAlive: Bool?

        enum CodingKeys: String, CodingKey {
            case name, run
            case runType = "run_type"
            case workingDir = "working_dir"
            case keepAlive = "keep_alive"
        }
    }
}

struct HomebrewCaskDetail: Codable {
    let token: String
    let fullToken: String?
    let oldTokens: [String]?
    let tap: String?
    let name: [String]
    let desc: String?
    let homepage: String?
    let url: String?
    let urlSpecs: [String: String]?
    let version: String
    let autobump: Bool?
    let noAutobumpMessage: String?
    let skipLivecheck: Bool?
    let installed: String?
    let installedTime: Int?
    let bundleVersion: String?
    let bundleShortVersion: String?
    let outdated: Bool?
    let sha256: String?
    let artifacts: [[String: AnyCodable]]?
    let caveats: String?
    let dependsOn: DependsOn?
    let conflictsWith: ConflictsWith?
    let container: String?
    let rename: [String]?
    let autoUpdates: Bool?
    let deprecated: Bool?
    let deprecationDate: String?
    let deprecationReason: String?
    let deprecationReplacementFormula: String?
    let deprecationReplacementCask: String?
    let disabled: Bool?
    let disableDate: String?
    let disableReason: String?
    let disableReplacementFormula: String?
    let disableReplacementCask: String?
    let tapGitHead: String?
    let languages: [String]?
    let rubySourcePath: String?
    let rubySourceChecksum: Checksum?
    let variations: [String: Variation]?
    let generatedDate: String?

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case oldTokens = "old_tokens"
        case tap, name, desc, homepage, url
        case urlSpecs = "url_specs"
        case version, autobump
        case noAutobumpMessage = "no_autobump_message"
        case skipLivecheck = "skip_livecheck"
        case installed
        case installedTime = "installed_time"
        case bundleVersion = "bundle_version"
        case bundleShortVersion = "bundle_short_version"
        case outdated, sha256, artifacts, caveats
        case dependsOn = "depends_on"
        case conflictsWith = "conflicts_with"
        case container, rename
        case autoUpdates = "auto_updates"
        case deprecated
        case deprecationDate = "deprecation_date"
        case deprecationReason = "deprecation_reason"
        case deprecationReplacementFormula = "deprecation_replacement_formula"
        case deprecationReplacementCask = "deprecation_replacement_cask"
        case disabled
        case disableDate = "disable_date"
        case disableReason = "disable_reason"
        case disableReplacementFormula = "disable_replacement_formula"
        case disableReplacementCask = "disable_replacement_cask"
        case tapGitHead = "tap_git_head"
        case languages
        case rubySourcePath = "ruby_source_path"
        case rubySourceChecksum = "ruby_source_checksum"
        case variations
        case generatedDate = "generated_date"
    }

    struct Variation: Codable {
        let url: String?
        let version: String?
        let sha256: String?
        let skipLivecheck: Bool?

        enum CodingKeys: String, CodingKey {
            case url, version, sha256
            case skipLivecheck = "skip_livecheck"
        }
    }

    struct DependsOn: Codable {
        let macos: MacOSRequirement?
        let formula: [String]?
        let cask: [String]?

        struct MacOSRequirement: Codable {
            let greaterThanOrEqual: [String]?
            let lessThanOrEqual: [String]?

            enum CodingKeys: String, CodingKey {
                case greaterThanOrEqual = ">="
                case lessThanOrEqual = "<="
            }
        }
    }

    struct ConflictsWith: Codable {
        let formula: [String]?
        let cask: [String]?
    }

    struct Checksum: Codable {
        let sha256: String
    }
}

// Helper for decoding any type
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}
