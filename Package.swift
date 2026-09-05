// swift-tools-version: 5.9
//
// AppKitPlus is in testing. No API or ABI stability is promised — any release may
// remove classes, change layouts, or change protocol requirements. Read the release
// notes before upgrading.

import PackageDescription

let version = "0.3.1"

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
            checksum: "779b34e858b4e098019ba378a7f541a2c8a63c2f3d81b4c895ad55130ddbdaeb"
        ),
    ]
)
