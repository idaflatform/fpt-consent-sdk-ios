import XCTest
@testable import ConsentCmp

private final class AppearanceMemoryStorage: StoragePort {
    private var values: [String: String] = [:]
    func get(_ key: String) -> String? { values[key] }
    func set(_ key: String, _ value: String) { values[key] = value }
    func remove(_ key: String) { values.removeValue(forKey: key) }
}

private final class AppearanceHttp: HttpPort {
    private let lock = NSLock()
    private var count = 0
    var fails = false
    var calls: Int { lock.lock(); defer { lock.unlock() }; return count }
    var revision = "remote"
    var includesAppearance = true
    private(set) var paths: [String] = []
    private func response(_ request: HttpRequest) throws -> HttpResponse {
        lock.lock(); defer { lock.unlock() }; count += 1
        paths.append(URL(string: request.url)?.path ?? "")
        guard URL(string: request.url)?.path == "/api/v1/cmp/consent/config" else {
            return HttpResponse(status: 404, body: "{}")
        }
        if fails { throw ConsentError(message: "offline") }
        var data: [String: Any] = ["code": "cp-test", "status": "active", "fields": [], "config": ["items": []]]
        if includesAppearance {
            data["appearance"] = ["schemaVersion": 1, "revision": revision, "theme": [:], "typography": ["family": "system"]] as [String: Any]
        }
        let body = try JSONSerialization.data(withJSONObject: ["data": data])
        return HttpResponse(status: 200, body: String(decoding: body, as: UTF8.self))
    }
    func send(_ request: HttpRequest) async throws -> HttpResponse { try response(request) }
}

final class ConsentAppearanceTests: XCTestCase {
    func testPersistedAppearanceAvoidsNetworkAfterRepositoryRestart() async {
        let http = AppearanceHttp(), storage = AppearanceMemoryStorage()
        let options = ConsentOptions(codeConfig: "cp-test")
        let first = AppearanceRepository(options: options, http: http, storage: storage)
        let loaded = await first.get()
        XCTAssertEqual(loaded.revision, "remote")
        let reopened = AppearanceRepository(options: options, http: http, storage: storage)
        let cached = await reopened.get()
        XCTAssertEqual(cached.revision, "remote")
        XCTAssertEqual(http.calls, 1)
    }
    func testOfflineUsesDefaultOnceAndRetriesNextSession() async {
        let http = AppearanceHttp(), storage = AppearanceMemoryStorage()
        http.fails = true
        let options = ConsentOptions(codeConfig: "cp-test")
        let first = AppearanceRepository(options: options, http: http, storage: storage)
        let fallback = await first.get()
        _ = await first.get()
        XCTAssertEqual(fallback.revision, "default"); XCTAssertEqual(http.calls, 1)
        http.fails = false
        let second = AppearanceRepository(options: options, http: http, storage: storage)
        let retried = await second.get()
        XCTAssertEqual(retried.revision, "remote"); XCTAssertEqual(http.calls, 2)
    }
    func testConcurrentReadsShareRequestAndRefreshFailureKeepsCache() async {
        let http = AppearanceHttp()
        let repo = AppearanceRepository(options: ConsentOptions(codeConfig: "cp-test"), http: http, storage: AppearanceMemoryStorage())
        async let a = repo.get()
        async let b = repo.get()
        _ = await (a, b)
        XCTAssertEqual(http.calls, 1)
        http.fails = true
        let kept = await repo.refresh()
        XCTAssertEqual(kept.revision, "remote")
    }
    func testClearAndCollectionPointIsolation() async {
        let http = AppearanceHttp(), storage = AppearanceMemoryStorage()
        let first = AppearanceRepository(options: ConsentOptions(codeConfig: "one"), http: http, storage: storage)
        let second = AppearanceRepository(options: ConsentOptions(codeConfig: "two"), http: http, storage: storage)
        _ = await first.get(); _ = await second.get()
        XCTAssertEqual(http.calls, 2)
        await first.clear(); _ = await first.get()
        XCTAssertEqual(http.calls, 3)
    }
    func testFormUsesOneConfigRequestAndKeepsAppearanceUntilExplicitRefresh() async throws {
        let http = AppearanceHttp()
        let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp-test"), http: http,
                             storage: AppearanceMemoryStorage(), appearanceStorage: AppearanceMemoryStorage())
        _ = try await cmp.fetchConfig()
        XCTAssertEqual(cmp.appearance.revision, "remote"); XCTAssertEqual(http.calls, 1)
        http.revision = "changed"
        _ = try await cmp.fetchConfig()
        XCTAssertEqual(cmp.appearance.revision, "remote"); XCTAssertEqual(http.calls, 2)
        _ = await cmp.refreshAppearance()
        XCTAssertEqual(cmp.appearance.revision, "changed"); XCTAssertEqual(http.calls, 3)
        _ = await cmp.getAppearance()
        XCTAssertEqual(http.calls, 3)
        XCTAssertTrue(http.paths.allSatisfy { $0 == "/api/v1/cmp/consent/config" })
    }
    func testCachedContentRestoresAppearanceWithoutNetwork() async throws {
        let http = AppearanceHttp()
        let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp-test"), http: http,
                             storage: AppearanceMemoryStorage(), appearanceStorage: AppearanceMemoryStorage())
        _ = try await cmp.fetchConfig()
        await cmp.clearAppearanceCache()
        _ = try await cmp.fetchConfig(preferCache: true)
        XCTAssertEqual(cmp.appearance.revision, "remote"); XCTAssertEqual(http.calls, 1)
    }
    func testMissingAppearanceDoesNotFailContent() async throws {
        let http = AppearanceHttp(); http.includesAppearance = false
        let cmp = ConsentCmp(options: ConsentOptions(codeConfig: "cp-test"), http: http,
                             storage: AppearanceMemoryStorage(), appearanceStorage: AppearanceMemoryStorage())
        _ = try await cmp.fetchConfig()
        XCTAssertEqual(cmp.appearance.revision, "default"); XCTAssertEqual(http.calls, 1)
    }
    func testAppearanceLimitAppliesToTokensRatherThanWholeConfig() throws {
        let data: [String: Any] = ["description": String(repeating: "x", count: 40000),
                                  "appearance": ["schemaVersion": 1, "revision": "large-config", "theme": [:], "typography": [:]]]
        let raw = try JSONSerialization.data(withJSONObject: ["data": data])
        XCTAssertEqual(try ConsentAppearance.fromConfig(String(decoding: raw, as: UTF8.self)).revision, "large-config")
        XCTAssertThrowsError(try ConsentAppearance.fromConfig("{\"data\":{\"appearance\":{\"schemaVersion\":99}}}"))
    }

}
