import Foundation
import Synchronization
import Testing
@testable import PrePost

private let sampleToken = "test-" + "token"

/// Intercepts every request made through a session configured with it.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)

    private static let state = Mutex<(handler: Handler?, requests: [URLRequest])>((nil, []))

    static func install(_ handler: @escaping Handler) {
        state.withLock { $0 = (handler, []) }
    }

    static var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.state.withLock { state in
            state.requests.append(request)
            return state.handler
        }
        do {
            guard let handler else { throw URLError(.unknown) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private struct Echo: Decodable, Equatable {
    let value: Int
}

/// Serialized: the stub's handler is shared state.
@Suite(.serialized)
struct APIClientTests {
    private func client(base: String = "https://api.example.com", token: String? = sampleToken) -> APIClient {
        APIClient(
            baseURL: URL(string: base)!,
            tokenStore: InMemoryTokenStore(token: token),
            session: StubURLProtocol.makeSession()
        )
    }

    private func json(_ string: String) -> Data { Data(string.utf8) }

    @Test(arguments: [
        ("https://api.example.com", "/health"),
        ("https://api.example.com/", "/health"),
        ("https://api.example.com//", "health"),
        ("https://api.example.com/", "health"),
    ])
    func urlJoining(base: String, path: String) {
        #expect(APIClient.url(base: URL(string: base)!, path: path).absoluteString == "https://api.example.com/health")
    }

    @Test func urlJoiningKeepsBasePathPrefix() {
        #expect(APIClient.url(base: URL(string: "https://api.example.com/v1/")!, path: "/media").absoluteString
            == "https://api.example.com/v1/media")
    }

    @Test func healthIsPublicAndDecodes() async throws {
        StubURLProtocol.install { _ in (200, Data(#"{"status":"ok"}"#.utf8)) }
        let health = try await client().health()
        #expect(health == HealthResponse(status: "ok"))
        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.url?.absoluteString == "https://api.example.com/health")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func healthWorksWithoutAToken() async throws {
        StubURLProtocol.install { _ in (200, Data(#"{"status":"ok"}"#.utf8)) }
        _ = try await client(token: nil).health()
    }

    @Test func privateRequestCarriesBearerToken() async throws {
        StubURLProtocol.install { _ in (200, Data(#"{"value":7}"#.utf8)) }
        let echo: Echo = try await client().send(APIRequest(method: "POST", path: "/things", body: Data([1, 2]), contentType: "image/jpeg"))
        #expect(echo == Echo(value: 7))
        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(sampleToken)")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(request.httpMethod == "POST")
    }

    @Test func missingTokenThrowsBeforeAnyRequest() async {
        StubURLProtocol.install { _ in (200, Data()) }
        await #expect(throws: APIError.missingToken) {
            try await client(token: nil).send(APIRequest(method: "DELETE", path: "/things/1"))
        }
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test func noContentReturnsNothing() async throws {
        StubURLProtocol.install { _ in (204, Data()) }
        try await client().send(APIRequest(method: "DELETE", path: "/things/1"))
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test func errorEnvelopeMapsToServerErrorWithBodyRetained() async throws {
        let body = Data(#"{"error":"too_wide","width":1600,"maxWidth":1440}"#.utf8)
        StubURLProtocol.install { _ in (422, body) }
        do {
            try await client().send(APIRequest(method: "POST", path: "/media"))
            Issue.record("Expected an error")
        } catch {
            #expect(error == .server(status: 422, code: "too_wide", body: body))
            if case .server(_, _, let retained) = error {
                struct Extra: Decodable { let width: Int; let maxWidth: Int }
                let extra = try JSONDecoder().decode(Extra.self, from: retained)
                #expect(extra.width == 1600 && extra.maxWidth == 1440)
            }
        }
    }

    @Test func unauthorizedMapsTo401Case() async {
        StubURLProtocol.install { _ in (401, Data(#"{"error":"unauthorized"}"#.utf8)) }
        await #expect(throws: APIError.unauthorized) {
            try await client().send(APIRequest(method: "DELETE", path: "/things/1"))
        }
    }

    @Test func nonJSONErrorBodyHasUnknownCode() async throws {
        let body = Data("<html>Bad gateway</html>".utf8)
        StubURLProtocol.install { _ in (502, body) }
        await #expect(throws: APIError.server(status: 502, code: "unknown", body: body)) {
            try await client().health()
        }
    }

    @Test func transportFailureMapsToTransport() async {
        StubURLProtocol.install { _ in throw URLError(.notConnectedToInternet) }
        await #expect {
            try await client().health()
        } throws: { error in
            guard case .transport(let urlError) = error as? APIError else { return false }
            return urlError.code == .notConnectedToInternet
        }
    }

    @Test func undecodableSuccessBodyIsDecodingError() async {
        StubURLProtocol.install { _ in (200, Data("not json".utf8)) }
        await #expect {
            try await client().health()
        } throws: { error in
            guard case .decoding = error as? APIError else { return false }
            return true
        }
    }

    @Test func errorMessagesAreUserFacingAndNeverContainTheToken() {
        let errors: [APIError] = [
            .missingToken, .unauthorized, .invalidResponse, .decoding("x"),
            .server(status: 500, code: "internal_error", body: Data()),
            .transport(URLError(.timedOut)), .tokenStore(.keychain(-1)),
        ]
        for error in errors {
            let message = error.errorDescription ?? ""
            #expect(!message.isEmpty)
            #expect(!message.contains(sampleToken))
        }
        #expect(APIError.unauthorized.errorDescription == "Token rejected — update it in Settings.")
    }
}
