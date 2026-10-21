import Foundation

nonisolated enum APIError: Error, Equatable, LocalizedError {
    /// No token saved. Thrown before any network call.
    case missingToken
    /// The token store itself failed (e.g. a Keychain error).
    case tokenStore(TokenStoreError)
    /// HTTP 401 — the Worker rejected the token.
    case unauthorized
    /// Any other non-2xx. `code` is the Worker's `error` field, or "unknown" if the body
    /// wasn't the envelope. Codes stay strings so new Worker codes never break decoding.
    /// `body` is kept so callers can decode extra fields (e.g. `width`, `maxWidth`).
    case server(status: Int, code: String, body: Data)
    case transport(URLError)
    /// Not an HTTP response.
    case invalidResponse
    /// 2xx body didn't match the expected type.
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: "No API token saved. Add it in Settings."
        case .tokenStore(let error): error.errorDescription
        case .unauthorized: "Token rejected — update it in Settings."
        case .server(let status, let code, _): "Server error \(status) (\(code))."
        case .transport(let error): "Can't reach the server. \(error.localizedDescription)"
        case .invalidResponse: "Unexpected response from the server."
        case .decoding: "Couldn't read the server's response."
        }
    }

    /// The Worker's error envelope: `{"error": "<code>", …}`.
    struct Envelope: Decodable {
        let error: String
    }
}
