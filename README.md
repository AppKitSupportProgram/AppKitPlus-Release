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
| Platform | AppKitPlus: macOS 14.0 or later; UIKitPlus: iOS 17.0 or later, visionOS 1.0 or later |
| Architectures | macOS: `arm64`, `arm64e`, `x86_64`; iOS and visionOS: `arm64`, plus `x86_64` in the simulators |
| Xcode | 27.2 or later |
| Swift | 5 language mode (built with library evolution enabled) |
| Package manifest | swift-tools-version 5.9 (Xcode 15+) |

## Embedding

`AppKitPlus.framework` is a **dynamic** framework (`mh_dylib`). Swift Package Manager embeds and
signs it into an application target automatically. If you integrate the `.xcframework` by hand
instead, set it to **Embed & Sign** in your target's *Frameworks, Libraries, and Embedded Content*
— linking without embedding builds fine and then fails at launch.

## Agent Plugin

The `appkitplus` plugin gives Claude Code and Codex the `appkit-app-modernization` skill, which
writes and migrates AppKit code to use AppKitPlus. The plugin's version is the release it
describes.

Claude Code, in a session:

```
/plugin marketplace add AppKitSupportProgram/AppKitPlus-Release
/plugin install appkitplus@appkitplus
```

Codex:

```bash
codex plugin marketplace add AppKitSupportProgram/AppKitPlus-Release
codex plugin add appkitplus@appkitplus
```

To update after a release:

```bash
claude plugin marketplace update appkitplus && claude plugin update appkitplus@appkitplus
codex plugin marketplace upgrade appkitplus
```

## What's included

Ports of UIKit's content configurations, background configurations, cell accessories, button
configuration, trait collection, navigation controller and bars, view controller transitioning,
diffable data sources for `NSOutlineView`, drag and drop interactions, graphics renderers, focus
engine, document launch experience, and more.

## UIKitPlus

The package has a second product, **UIKitPlus**: the navigation popover, the pop-up path control, the
filter fields with the filter control bar, and the icons, built for UIKit — iOS 17 and visionOS 1 or
later; there is no Mac Catalyst slice. It is built from the same sources as AppKitPlus and released with
it, so both products always carry the same version. The classes have the same names on iOS —
`NSNavigationPopoverController`, `NSPopUpPathControl`, `NSFilterSearchField`, `NSFilterTokenField`,
`NSFilterControlBar`, `NSIcon` and `NSIconView`; each header says where a class differs on iOS.

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "UIKitPlus", package: "AppKitPlus-Release"),
])
```

```swift
import UIKitPlus
```

`UIKitPlus.framework` is a dynamic framework too; embed and sign it as described above. Swift Package
Manager downloads both frameworks when it resolves this package, whichever product a target uses.

## Releases

| Version | macOS | Swift | Built with |
|---------|-------|-------|------------|
| 0.1.0 | 12.0+ | 5 | Xcode 26.6 |
| 0.24.0 | 14.0+ | 5 | Xcode 27.2 |

A binary framework's `.swiftinterface` is not guaranteed to be readable by every future compiler,
so the Xcode version each release was built with is recorded here.

## License

AppKitPlus is released under the MIT License — see [LICENSE](LICENSE).

The framework statically incorporates third-party code under a different license. See
[NOTICE](NOTICE).
