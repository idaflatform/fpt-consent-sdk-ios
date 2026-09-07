import Foundation

/// Cac "port" ma app cung cap. Core khong biet gi ve `URLSession` hay `UserDefaults` —
/// nho vay test duoc va thay the duoc.

public struct HttpRequest {
    public let method: String
    public let url: String
    public let headers: [String: String]
    /// Body da serialize; chi co voi POST.
    public let body: Data?
    public let timeout: TimeInterval
}

public struct HttpResponse {
    public let status: Int
    /// Body dang text; rong neu khong co.
    public let body: String

    public init(status: Int, body: String) {
        self.status = status
        self.body = body
    }
}

/// Goi HTTP. Chi throw khi khong nhan duoc response (mat mang, timeout).
public protocol HttpPort {
    func send(_ request: HttpRequest) async throws -> HttpResponse
}

/// Luu tru key-value cuc bo.
public protocol StoragePort {
    func get(_ key: String) -> String?
    func set(_ key: String, _ value: String)
    func remove(_ key: String)
}

/// `URLSession` mac dinh, tat cache de cau hinh doi tren portal la thay ngay.
public struct URLSessionHttp: HttpPort {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HttpRequest) async throws -> HttpResponse {
        guard let url = URL(string: request.url) else {
            throw ConsentError(message: "URL khong hop le: \(request.url)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        // Khong cho URLCache hay proxy tra ban cu cua /config.
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        // Khong dung `session.data(for:)` vi API do chi co tu iOS 15 — SDK ho tro tu iOS 14.
        let (data, response) = try await Self.send(urlRequest, on: session)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HttpResponse(status: status, body: String(data: data, encoding: .utf8) ?? "")
    }

    /// Boc `dataTask` thanh async — thay cho `URLSession.data(for:)` (iOS 15+).
    private static func send(_ request: URLRequest,
                             on session: URLSession) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: ConsentError(message: "Response rong tu may chu"))
                }
            }
            task.resume()
        }
    }
}

/// Luu vao `UserDefaults` — du cho visitor ID, quyet dinh consent va cache `/config`.
public struct UserDefaultsStorage: StoragePort {

    private let defaults: UserDefaults
    private let prefix: String

    public init(defaults: UserDefaults = .standard, prefix: String = "vn.fpt.fis.cmp.") {
        self.defaults = defaults
        self.prefix = prefix
    }

    public func get(_ key: String) -> String? {
        defaults.string(forKey: prefix + key)
    }

    public func set(_ key: String, _ value: String) {
        defaults.set(value, forKey: prefix + key)
    }

    public func remove(_ key: String) {
        defaults.removeObject(forKey: prefix + key)
    }
}

/// Bo nho tam — dung trong unit test.
public final class MemoryStorage: StoragePort {

    private var map: [String: String] = [:]

    public init() {}

    public func get(_ key: String) -> String? { map[key] }
    public func set(_ key: String, _ value: String) { map[key] = value }
    public func remove(_ key: String) { map.removeValue(forKey: key) }
}
