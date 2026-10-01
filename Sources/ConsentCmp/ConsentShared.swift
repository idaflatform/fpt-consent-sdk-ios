import Foundation

// MARK: - Doc cau hinh tu Info.plist

extension ConsentOptions {

    /// Khoa cau hinh trong Info.plist cua app.
    ///
    /// ```xml
    /// <key>CMPCodeConfig</key><string>cp_xxx::t_yyy</string>
    /// <key>CMPBaseUrl</key><string>https://uat-cmp.biznext.vn</string>   <!-- tuy chon, mac dinh PROD -->
    /// ```
    public enum InfoKey {
        public static let codeConfig = "CMPCodeConfig"
        public static let baseUrl = "CMPBaseUrl"
    }

    /// Dung options tu Info.plist; nil khi thieu hoac rong `CMPCodeConfig`.
    ///
    /// Thieu `CMPBaseUrl` thi dung `defaultBaseUrl` (PROD). Gia tri chua thay the (vd
    /// `$(CMP_BASE_URL)` khi quen khai bien xcconfig) cung bi coi la thieu.
    public static func fromBundle(_ bundle: Bundle = .main) -> ConsentOptions? {
        fromInfo(bundle.infoDictionary ?? [:])
    }

    static func fromInfo(_ info: [String: Any]) -> ConsentOptions? {
        func read(_ key: String) -> String? {
            guard let raw = (info[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
            return raw
        }
        guard let codeConfig = read(InfoKey.codeConfig) else { return nil }
        return ConsentOptions(codeConfig: codeConfig,
                              baseUrl: read(InfoKey.baseUrl) ?? ConsentOptions.defaultBaseUrl)
    }
}

// MARK: - Instance dung chung

extension ConsentCmp {

    private static let sharedLock = NSLock()
    private static var sharedInstance: ConsentCmp?

    /// Instance dung chung, tu doc Info.plist o lan truy cap dau tien.
    ///
    /// ```swift
    /// let config = try await ConsentCmp.shared.fetchConfig()
    /// ```
    ///
    /// - Precondition: Info.plist co `CMPCodeConfig`, hoac da goi `configure(_:)` truoc.
    ///   Thieu ca hai thi dung app voi thong bao ro rang — loi cau hinh phai lo ra ngay khi dev chay.
    public static var shared: ConsentCmp {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        if let instance = sharedInstance { return instance }
        guard let options = ConsentOptions.fromBundle() else {
            fatalError("ConsentCmp: thieu \(ConsentOptions.InfoKey.codeConfig) trong Info.plist. "
                + "Khai khoa nay hoac goi ConsentCmp.configure(_:) truoc khi dung ConsentCmp.shared.")
        }
        let instance = ConsentCmp(options: options)
        sharedInstance = instance
        return instance
    }

    /// Ghi de instance dung chung — goi truoc lan dung `shared` dau tien khi can options rieng
    /// (header, timeout, moi truong chon luc chay...). Goi lai se thay instance cu.
    public static func configure(_ options: ConsentOptions) {
        configure(ConsentCmp(options: options))
    }

    /// Ban nhan san instance — dung trong test de bom `HttpPort` / `StoragePort` gia.
    public static func configure(_ instance: ConsentCmp) {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        sharedInstance = instance
    }

    /// Bo instance dung chung; lan truy cap `shared` sau se doc lai Info.plist. Chu yeu cho test.
    static func resetShared() {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        sharedInstance = nil
    }
}
