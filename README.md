# AppKitPlus

Binary distribution of **AppKitPlus** — an Objective-C framework that ports modern UIKit APIs to
AppKit, so macOS code can use familiar UIKit patterns.

> [!WARNING]
> **AppKitPlus is in testing. No API or ABI stability is promised.**
> Any release may remove classes, change type layouts, or change protocol requirements, with no
> deprecation period. Pin an exact version and read the release notes before upgrading.

This repository contains **only** the Swift Package manifest. The framework's source lives in a
separate, private repository; each release here ships a prebuilt `AppKitPlus.xcframework`.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release", from: "0.1.0"),
]
```

Then add the product to your target:

```swift
.target(name: "YourTarget", dependencies: ["AppKitPlus"])
```

In Xcode: **File ▸ Add Package Dependencies…** and enter the repository URL.

```swift
import AppKitPlus
```

The module is named `AppKitPlus` — the `-Release` suffix belongs to the repository, not to the
package or the product.

## Requirements

| | |
|---|---|
| Platform | macOS 12.0 or later |
| Architectures | `arm64`, `arm64e`, `x86_64` |
| Swift | 5 language mode (built with library evolution enabled) |
| Package manifest | swift-tools-version 5.9 (Xcode 15+) |

## Embedding

`AppKitPlus.framework` is a **dynamic** framework (`mh_dylib`). Swift Package Manager embeds and
signs it into an application target automatically. If you integrate the `.xcframework` by hand
instead, set it to **Embed & Sign** in your target's *Frameworks, Libraries, and Embedded Content*
— linking without embedding builds fine and then fails at launch.

## What's included

Ports of UIKit's content configurations, background configurations, cell accessories, button
configuration, trait collection, navigation controller and bars, view controller transitioning,
diffable data sources for `NSOutlineView`, drag and drop interactions, graphics renderers, focus
engine, document launch experience, and more.

## Releases

| Version | macOS | Swift | Built with |
|---------|-------|-------|------------|
| 0.1.0 | 12.0+ | 5 | Xcode 26.6 |

A binary framework's `.swiftinterface` is not guaranteed to be readable by every future compiler,
so the Xcode version each release was built with is recorded here.

## License

AppKitPlus is released under the MIT License — see [LICENSE](LICENSE).

The framework statically incorporates third-party code under a different license. See
[NOTICE](NOTICE).
