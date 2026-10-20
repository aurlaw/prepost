import Foundation
import Testing
@testable import PrePost

struct AppConfigTests {
    @Test(arguments: ["https://api.example.com", "http://localhost:8787", "  https://api.example.com/  "])
    func validURLParses(raw: String) throws {
        let url = try AppConfig.parseAPIBaseURL(raw)
        #expect(url.host() != nil)
    }

    @Test func parsedURLKeepsSchemeAndHost() throws {
        let url = try AppConfig.parseAPIBaseURL("https://api.example.com")
        #expect(url.scheme == "https")
        #expect(url.host() == "api.example.com")
    }

    @Test(arguments: [nil, "", "   ", 42] as [(any Sendable)?])
    func missingValueIsRejected(raw: (any Sendable)?) {
        #expect(throws: AppConfigError.missing) {
            try AppConfig.parseAPIBaseURL(raw)
        }
    }

    @Test(arguments: [
        "$(PREPOST_API_BASE_URL)",
        "https:/$()/api.example.com",
        "api.example.com",
        "not a url",
        "ftp://api.example.com",
        "https://",
    ])
    func invalidValueIsRejected(raw: String) {
        #expect {
            try AppConfig.parseAPIBaseURL(raw)
        } throws: { error in
            guard case .invalid = error as? AppConfigError else { return false }
            return true
        }
    }
}
