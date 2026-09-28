// swift-tools-version: 5.9
//
// AppKitPlus is in testing. No API or ABI stability is promised — any release may
// remove classes, change layouts, or change protocol requirements. Read the release
// notes before upgrading.

import PackageDescription

let version = "0.5.0"

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
            checksum: "1dd80ea5a9742b2c52104ed3553ae3511c956d6a14edc0b14b13224bc5d8f5b5"
        ),
    ]
)
