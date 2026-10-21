import Foundation

nonisolated struct HealthResponse: Decodable, Equatable, Sendable {
    let status: String
}

/// One request to the Worker. Every endpoint goes through `APIClient.send`.
nonisolated struct APIRequest: Sendable {
    var method: String
    var path: String
    /// Public endpoints (only `GET /health`) are sent without the bearer token.
    var isPublic = false
    var body: Data?
    var contentType: String?
}

/// Client for the Pre Post Worker.
///
/// A `final class` rather than an `actor`: it holds only immutable, `Sendable`
/// state (base URL, token store, session), so there is nothing to protect, and
/// an actor would needlessly serialise concurrent requests such as parallel
/// photo uploads in A2.
///
/// Endpoints are added as extensions that build an `APIRequest` and call
/// `send` — A2 adds `uploadMedia` / `deleteMedia` that way.
nonisolated final class APIClient: Sendable {
    let baseURL: URL
    private let tokenStore: any TokenStore
    private let session: URLSession

    init(baseURL: URL, tokenStore: any TokenStore, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    /// Joins base and path with exactly one slash between them.
    static func url(base: URL, path: String) -> URL {
        var base = base.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        let path = path.drop { $0 == "/" }
        return URL(string: "\(base)/\(path)")!
    }

    /// Sends a request and decodes a 2xx JSON body.
    func send<Response: Decodable>(_ request: APIRequest, as _: Response.Type = Response.self) async throws(APIError) -> Response {
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    /// Sends a request whose success body is ignored (e.g. `204`).
    func send(_ request: APIRequest) async throws(APIError) {
        _ = try await perform(request)
    }

    private func perform(_ request: APIRequest) async throws(APIError) -> Data {
        var urlRequest = URLRequest(url: Self.url(base: baseURL, path: request.path))
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType = request.contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if !request.isPublic {
            urlRequest.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw .transport(error)
        } catch {
            throw .transport(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else { throw .invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw .unauthorized
        default:
            let code = (try? JSONDecoder().decode(APIError.Envelope.self, from: data))?.error ?? "unknown"
            throw .server(status: http.statusCode, code: code, body: data)
        }
    }

    private func bearerToken() throws(APIError) -> String {
        let token: String?
        do {
            token = try tokenStore.read()
        } catch let error as TokenStoreError {
            throw .tokenStore(error)
        } catch {
            throw .tokenStore(.unexpectedData)
        }
        guard let token, !token.isEmpty else { throw .missingToken }
        return token
    }
}

// MARK: - Endpoints

nonisolated extension APIClient {
    /// `GET /health` — public. Confirms the Worker is reachable, not that the token is valid.
    func health() async throws(APIError) -> HealthResponse {
        try await send(APIRequest(method: "GET", path: "/health", isPublic: true))
    }
}
