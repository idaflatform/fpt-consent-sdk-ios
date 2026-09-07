// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ConsentCmp",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "ConsentCmp", targets: ["ConsentCmp"]),
        .executable(name: "ConsentFixtureRunner", targets: ["ConsentFixtureRunner"])
    ],
    targets: [
        .target(name: "ConsentCmp"),
        .executableTarget(name: "ConsentFixtureRunner", dependencies: ["ConsentCmp"]),
        .testTarget(name: "ConsentCmpTests", dependencies: ["ConsentCmp"])
    ]
)
