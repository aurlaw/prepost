import Foundation

enum AppConfigError: Error, Equatable {
    case missing
    case invalid(String)
}

/// Build-time configuration read from the app's Info.plist.
///
/// Values originate in `Configs/Base.xcconfig` (optionally overridden by the
/// gitignored `Local.xcconfig`) and reach the bundle through Info.plist keys.
nonisolated struct AppConfig: Sendable {
    static let apiBaseURLKey = "PrePostAPIBaseURL"

    let apiBaseURL: URL

    init(bundle: Bundle) throws(AppConfigError) {
        apiBaseURL = try Self.parseAPIBaseURL(bundle.object(forInfoDictionaryKey: Self.apiBaseURLKey))
    }

    /// Validates a raw Info.plist value as the API base URL.
    ///
    /// Accepts an absolute `http`/`https` URL with a host. Rejects a missing or
    /// empty value and an unresolved `$(...)` build-setting reference.
    static func parseAPIBaseURL(_ raw: Any?) throws(AppConfigError) -> URL {
        guard let string = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty
        else {
            throw .missing
        }
        guard !string.contains("$(") else {
            throw .invalid("unresolved build setting: \(string)")
        }
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host(), !host.isEmpty
        else {
            throw .invalid("not an absolute http(s) URL: \(string)")
        }
        return url
    }
}
