import Foundation
import Testing
@testable import PrePost

/// Built at runtime so no credential-shaped literal is committed.
private let sampleToken = "test-" + "token"

struct KeychainTokenStoreTests {
    /// A unique service per test so parallel tests never share an item.
    let store = KeychainTokenStore(service: "com.aurlaw.prepost.tests.\(UUID().uuidString)")

    @Test func roundTripSaveReadOverwriteDelete() throws {
        defer { try? store.delete() }
        #expect(try store.read() == nil)

        try store.save(sampleToken)
        #expect(try store.read() == sampleToken)

        try store.save(sampleToken + "-2")
        #expect(try store.read() == sampleToken + "-2")

        try store.delete()
        #expect(try store.read() == nil)
    }

    @Test func trimsWhitespaceAndNewlines() throws {
        defer { try? store.delete() }
        try store.save("  \n\(sampleToken)\n\t ")
        #expect(try store.read() == sampleToken)
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func rejectsEmpty(token: String) throws {
        defer { try? store.delete() }
        #expect(throws: TokenStoreError.empty) { try store.save(token) }
        #expect(try store.read() == nil)
    }

    @Test func deletingWhenAbsentSucceeds() throws {
        try store.delete()
    }

    @Test func separateServicesDoNotShareItems() throws {
        let other = KeychainTokenStore(service: "com.aurlaw.prepost.tests.\(UUID().uuidString)")
        defer {
            try? store.delete()
            try? other.delete()
        }
        try store.save(sampleToken)
        #expect(try other.read() == nil)
    }
}

struct InMemoryTokenStoreTests {
    @Test func roundTrip() throws {
        let store = InMemoryTokenStore()
        #expect(try store.read() == nil)
        try store.save(" \(sampleToken) ")
        #expect(try store.read() == sampleToken)
        try store.delete()
        #expect(try store.read() == nil)
    }

    @Test func rejectsEmpty() {
        let store = InMemoryTokenStore()
        #expect(throws: TokenStoreError.empty) { try store.save("  ") }
    }
}

struct TokenStoreErrorTests {
    @Test func descriptionsNeverContainTheToken() {
        for error in [TokenStoreError.empty, .keychain(-25300), .unexpectedData] {
            #expect(!(error.errorDescription ?? "").contains(sampleToken))
        }
    }
}
