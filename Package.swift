// swift-tools-version: 5.9
//
// AppKitPlus is in testing. No API or ABI stability is promised — any release may
// remove classes, change layouts, or change protocol requirements. Read the release
// notes before upgrading.

import PackageDescription

let version = "0.1.5"

let package = Package(
    name: "AppKitPlus",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "AppKitPlus", targets: ["AppKitPlus"]),
    ],
    targets: [
        .binaryTarget(
            name: "AppKitPlus",
            url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release/releases/download/\(version)/AppKitPlus.xcframework.zip",
            checksum: "d395361d40f8077e4d66756f28b086eff2ebfd857aee9fd726c378af2a5825e9"
        ),
    ]
)
