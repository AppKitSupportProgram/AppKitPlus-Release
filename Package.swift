// swift-tools-version: 5.9
//
// AppKitPlus is in testing. No API or ABI stability is promised — any release may
// remove classes, change layouts, or change protocol requirements. Read the release
// notes before upgrading.

import PackageDescription

let version = "0.10.2"

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
            checksum: "341a3808f541f00b0d193c30afa90d94cc26233f6043a1cb6d70e9fb8a3a0aba"
        ),
    ]
)
