// swift-tools-version: 5.9
//
// AppKitPlus and UIKitPlus are in testing. No API or ABI stability is promised — any
// release may remove classes, change layouts, or change protocol requirements. Read the
// release notes before upgrading.
//
// Written by the source repository's Scripts/publish-release.sh on every release.

import PackageDescription

let version = "0.24.0"

let package = Package(
    name: "AppKitPlus",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "AppKitPlus", targets: ["AppKitPlus"]),
        .library(name: "UIKitPlus", targets: ["UIKitPlus"]),
    ],
    targets: [
        .binaryTarget(
            name: "AppKitPlus",
            url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release/releases/download/\(version)/AppKitPlus.xcframework.zip",
            checksum: "a7f18f88bae98ae29e34f8f307004d7ff9cb25fa002579702a8fc943883d7b6b"
        ),
        .binaryTarget(
            name: "UIKitPlus",
            url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release/releases/download/\(version)/UIKitPlus.xcframework.zip",
            checksum: "9cf9242ca3b63371774613bb1f671c70a00e445ec4605f5be75954d18edb6428"
        ),
    ]
)
