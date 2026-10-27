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
    private func response() throws -> HttpResponse {
        lock.lock(); defer { lock.unlock() }; count += 1
        if fails { throw ConsentError(message: "offline") }
        return HttpResponse(status: 200, body: "{\"data\":{\"schemaVersion\":1,\"revision\":\"remote\",\"theme\":{},\"typography\":{\"family\":\"system\"}}}")
    }
    func send(_ request: HttpRequest) async throws -> HttpResponse { try response() }
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
}
