import Foundation
import ConsentCmp

/// Chay bo fixture trong consent-sdk-spec/fixtures tren core Swift.
///
///   swift run ConsentFixtureRunner                     # tu thu muc sdk-ios
///   swift run ConsentFixtureRunner <thu-muc-fixture>

let arguments = CommandLine.arguments
let fixtureDir = arguments.count > 1
    ? arguments[1]
    : FileManager.default.currentDirectoryPath + "/../consent-sdk-spec/fixtures"

let files = ((try? FileManager.default.contentsOfDirectory(atPath: fixtureDir)) ?? [])
    .filter { $0.hasSuffix(".json") }
    .sorted()

if files.isEmpty {
    FileHandle.standardError.write("Khong tim thay fixture trong \(fixtureDir)\n".data(using: .utf8)!)
    exit(2)
}

var passed = 0
var failures: [String] = []

for file in files {
    let path = fixtureDir + "/" + file
    guard let data = FileManager.default.contents(atPath: path),
          let fixture = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        failures.append("\(file)\n      khong doc duoc fixture")
        print("ERROR \(file)")
        continue
    }
    let id = (fixture["id"] as? String) ?? file
    let problems = FixtureCase.run(fixture)
    if problems.isEmpty {
        passed += 1
        print("PASS  \(id)")
    } else {
        failures.append("\(id)\n      " + problems.joined(separator: "\n      "))
        print("FAIL  \(id)")
    }
}

print("")
print("\(passed)/\(files.count) fixture pass")
if !failures.isEmpty {
    print("")
    for failure in failures { print("  \(failure)") }
    exit(1)
}
