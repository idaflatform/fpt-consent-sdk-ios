// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ConsentCmp",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    // Chi xuat thu vien: app khach hang chon package trong Xcode chi thay "ConsentCmp".
    products: [
        .library(name: "ConsentCmp", targets: ["ConsentCmp"])
    ],
    targets: [
        .target(name: "ConsentCmp"),
        // Chay noi bo: `swift run ConsentFixtureRunner` (SPM tu tao product cho root package).
        .executableTarget(name: "ConsentFixtureRunner", dependencies: ["ConsentCmp"])
        // Khong khai testTarget khi repo chua co thu muc Tests/ — SPM bao loi thieu source.
    ]
)
