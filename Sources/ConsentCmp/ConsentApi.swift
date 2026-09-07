import Foundation

/// Hai API consent cua backend fis-cmp:
///   GET  {baseUrl}/api/v1/cmp/consent/config?code_config=...
///   POST {baseUrl}/api/v1/cmp/consent/sendData
///
/// Ca hai la public (khong JWT). Header `X-Consent-Integration` mang gia tri `codeConfig`.
/// Khong gui tenant id — backend tu suy ra tenant tu integration key.

public struct ConsentOptions {

    /// Dia chi CMP mac dinh (moi truong PROD). App khong truyen `baseUrl` thi dung gia tri nay;
    /// muon tro sang UAT hay moi truong rieng thi truyen tham so `baseUrl`.
    public static let defaultBaseUrl = "https://cmp.biznext.vn"
    public static let defaultApiPath = "/api/v1/cmp/consent"
    public static let defaultStatus = "ACTIVE"

    /// Vd `https://uat-cmp.biznext.vn` — khong kem path.
    public let baseUrl: String
    /// Integration key cua Collection Point.
    public let codeConfig: String
    public let apiPath: String
    /// Trang thai ghi vao ban ghi consent.
    public let status: String
    /// Nguon gui ban ghi; nil = SDK tu suy ra tu Bundle (ten app + bundle id + version).
    public let source: String?
    public let headers: [String: String]
    public let timeout: TimeInterval
    /// Cache `/config` lam phuong an du phong khi mat mang.
    public let cacheConfig: Bool
    /// Chi anh huong khi app chu dong goi `fetchConfig(preferCache: true)`.
    public let configTtlMs: Double

    /// - Parameter baseUrl: chi truyen khi khong dung PROD; mac dinh `defaultBaseUrl`.
    public init(codeConfig: String,
                baseUrl: String = ConsentOptions.defaultBaseUrl,
                apiPath: String = ConsentOptions.defaultApiPath,
                status: String = ConsentOptions.defaultStatus,
                source: String? = nil,
                headers: [String: String] = [:],
                timeout: TimeInterval = 15,
                cacheConfig: Bool = true,
                configTtlMs: Double = 15 * 60 * 1000) {
        precondition(!baseUrl.isEmpty, "baseUrl is required")
        precondition(!codeConfig.isEmpty, "codeConfig is required")
        self.baseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        self.codeConfig = codeConfig
        self.apiPath = apiPath.hasSuffix("/") ? String(apiPath.dropLast()) : apiPath
        self.status = status
        self.source = source
        self.headers = headers
        self.timeout = timeout
        self.cacheConfig = cacheConfig
        self.configTtlMs = configTtlMs
    }
}

/// Loi cua SDK: mang, HTTP, hoac nghiep vu do backend tra ve.
public struct ConsentError: Error, LocalizedError {
    public let message: String
    /// 0 khi loi xay ra truoc khi co response (mat mang, timeout, parse).
    public let httpStatus: Int
    /// Ma loi nghiep vu trong `BaseResponse.code`; nil neu khong co.
    public let errorCode: String?

    public init(message: String, httpStatus: Int = 0, errorCode: String? = nil) {
        self.message = message
        self.httpStatus = httpStatus
        self.errorCode = errorCode
    }

    public var errorDescription: String? { message }
    public var isClientError: Bool { httpStatus >= 400 && httpStatus < 500 }
}

public struct ConsentApi {

    public static let headerIntegration = "X-Consent-Integration"

    private let options: ConsentOptions
    private let http: HttpPort

    public init(options: ConsentOptions, http: HttpPort) {
        self.options = options
        self.http = http
    }

    public var configUrl: String {
        let encoded = options.codeConfig
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? options.codeConfig
        return "\(options.baseUrl)\(options.apiPath)/config?code_config=\(encoded)"
    }

    public var sendDataUrl: String {
        "\(options.baseUrl)\(options.apiPath)/sendData"
    }

    /// Tra ve ca config da parse va JSON tho (de caller cache lai nguyen ban).
    public func fetchConfig() async throws -> (config: ConsentConfig, raw: String) {
        let response = try await request(method: "GET", url: configUrl, body: nil)
        return (ConsentParser.parseConfig(response.json), response.raw)
    }

    public func sendData(body: [String: Any]) async throws -> SendConsentResult {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw ConsentError(message: "Khong dung duoc body sendData")
        }
        let response = try await request(method: "POST", url: sendDataUrl, body: data)
        return ConsentParser.parseSendResult(response.json)
    }

    private func request(method: String, url: String,
                         body: Data?) async throws -> (json: [String: Any], raw: String) {
        var headers: [String: String] = [
            "Accept": "application/json",
            ConsentApi.headerIntegration: options.codeConfig,
            // Cau hinh doi tren portal la phai thay ngay.
            "Cache-Control": "no-cache, no-store",
            "Pragma": "no-cache",
        ]
        if body != nil {
            headers["Content-Type"] = "application/json; charset=utf-8"
        }
        // Header do app khai bao dat sau cung nen ghi de duoc mac dinh o tren.
        for (name, value) in options.headers {
            headers[name] = value
        }

        let response: HttpResponse
        do {
            response = try await http.send(HttpRequest(method: method, url: url, headers: headers,
                                                       body: body, timeout: options.timeout))
        } catch let error as ConsentError {
            throw error
        } catch {
            throw ConsentError(message: "Khong ket noi duoc toi may chu consent: \(error.localizedDescription)")
        }

        if response.status >= 400 {
            throw ConsentApi.toError(status: response.status, body: response.body)
        }
        let trimmed = response.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ([:], "{}")
        }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConsentError(message: "Response khong phai JSON hop le")
        }
        return (json, trimmed)
    }

    /// Doc `BaseResponse.code/message` tu body loi de bao dung nguyen nhan nghiep vu.
    static func toError(status: Int, body: String) -> ConsentError {
        var message = "HTTP \(status)"
        var code: String?
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            code = json["code"] as? String
            if let serverMessage = json["message"] as? String, !serverMessage.isEmpty {
                message = serverMessage
            }
        }
        return ConsentError(message: message, httpStatus: status, errorCode: code)
    }
}

/// `dateCreated` dang ISO-8601 co offset — kieu `OffsetDateTime` ma backend mong doi.
public enum Iso8601 {

    public static func format(_ date: Date = Date(), timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter.string(from: date)
    }
}
