// swift-tools-version: 5.9
//
// AppKitPlus is in testing. No API or ABI stability is promised — any release may
// remove classes, change layouts, or change protocol requirements. Read the release
// notes before upgrading.

import PackageDescription

let version = "0.19.0"

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
            checksum: "bee50aafe904d695655cc51353e305cbb76f2042f0e068d060c26e39ca1cd4e9"
        ),
    ]
)
