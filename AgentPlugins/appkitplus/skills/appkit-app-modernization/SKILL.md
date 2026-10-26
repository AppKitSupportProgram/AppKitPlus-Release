---
name: appkit-app-modernization
description: Use when writing, reviewing or migrating AppKit UI code in a project that depends on AppKitPlus (`import AppKitPlus`, AppKitPlus-Release) — use its API instead of hand-rolling, and inventory legacy code for migration. Covers NSOutlineViewDiffableDataSource, NSTableViewDiffableReorderableDataSource, NSBrowserDiffableDataSource, cell registrations, NSListContentConfiguration, NSBackgroundConfiguration, NSViewAccessory, NSAction, control events, NSButton.Configuration, NSView.animate, NSTraitCollection, NSLayerBackedView, NSContentUnavailableConfiguration, NSTableViewController, NSHostingConfiguration, updateProperties, NSGraphicsImageRenderer, NSBezierPath/geometry helpers, NSEffectView, NSNavigationController, drag/drop interactions, NSCursorInteraction, NSHoverAppearanceInteraction, NSFindInteraction, NSScrollBehavior, NSScrollPagingInteraction, NSDeferredMenuItem, NSPopUpPathControl, NSNavigationPopoverController, NSFilterSearchField/TokenField/ControlBar, NSIcon, NSObjectGridGraph, NSPlaybackSlider.
---

# Modernising an AppKit App with AppKitPlus

AppKitPlus adds the APIs AppKit is missing — most of them UIKit's, spelled the AppKit way
(`UIListContentConfiguration` → `NSListContentConfiguration`, `UIView.animate` →
`NSView.animate`, `UICollectionView.CellRegistration` → `NSTableView.CellRegistration`).

**Treat every AppKitPlus type as part of AppKit.** Import it next to AppKit and use it exactly the
way you would use AppKit's own classes:

```swift
import AppKit
import AppKitPlus
```

## Step 0 — confirm the dependency and find its headers

```bash
rg -l 'AppKitPlus-Release|AppKitPlus\.xcframework|import AppKitPlus' \
   --glob 'Package.swift' --glob 'Package.resolved' --glob '*.pbxproj' --glob '*.swift'
```

A package may also reach it through a trait (`traits: ["AppKitPlus"]` on UIFoundation or RxAppKit).
The version is the `AppKitPlus-Release` pin in `Package.resolved`. New dependencies take the latest
release, which is the release this skill describes:

```swift
.package(url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release", from: "0.18.0")
// target dependency: .product(name: "AppKitPlus", package: "AppKitPlus-Release")
```

**The installed headers are the reference.** Every public declaration documents its contract in its
doc comment — defaults, call order, threading, availability — the way Apple's headers do. Read the
doc comment of an API before using it; where this skill and a header disagree, the header wins.

```
<artifacts>/appkitplus-release/AppKitPlus/AppKitPlus.xcframework/macos-arm64_arm64e_x86_64/AppKitPlus.framework/
├── Headers/                                   # one header per type
├── Modules/AppKitPlus.swiftmodule/*.swiftinterface   # the Swift overlay
└── Resources/Info.plist                       # CFBundleShortVersionString = installed version
```

`<artifacts>` is `<scratch path>/artifacts` for a SwiftPM build (`.build/` unless the project passes
`--scratch-path`) and `<DerivedData>/SourcePackages/artifacts` for an Xcode build.

To see a header the way Swift imports it — every public header is a submodule named after the
header, with `+` written as `_`:

```bash
FRAMEWORK_DIRECTORY=<artifacts>/appkitplus-release/AppKitPlus/AppKitPlus.xcframework/macos-arm64_arm64e_x86_64
xcrun swift-synthesize-interface -module-name AppKitPlus.NSView_Animation \
    -F "$FRAMEWORK_DIRECTORY" -target arm64-apple-macos14 -sdk "$(xcrun --sdk macosx --show-sdk-path)"
# -module-name AppKitPlus gives the Swift-only overlay (registrations, configuration structs, …)
```

This skill describes the newest release. An API marked with a version — **0.6.0+** — first shipped in
that release, and a project pinned to an older one does not have it; on an older pin, check the
installed headers before using anything here.

## How to work

**New code — AppKitPlus by default.** Before writing any pattern in the left column of the table
below, use the AppKitPlus API in the middle column.

**Existing code — inventory first, never rewrite on sight.**

1. Run the sweep below, then the detection searches of each area you care about (in the reference
   files).
2. Give the user a list grouped by area: `file:line`, the current pattern, the AppKitPlus
   replacement, and anything the user would see change.
3. Migrate only what the user picks, **one area per change**, keeping visible behaviour identical
   unless the user asked for the new behaviour. Do not touch neighbouring code that belongs to
   another area.
4. Build and run the project's tests after each area.

**The project also uses UIFoundation with its `AppKitPlus` trait?** UIFoundation's own types already
sit on AppKitPlus (`LayerBackedView` inherits `NSLayerBackedView`). Use those as the
`uifoundation-widgets` skill describes, and reach for AppKitPlus directly for everything UIFoundation
does not wrap.

### First sweep

```bash
rg -n -e 'NSOutlineViewDataSource|NSTableViewDataSource|NSBrowserDelegate|NSTreeController' \
      -e 'makeView\(withIdentifier:|makeItem\(withIdentifier:|makeViewWithIdentifier:|makeItemWithIdentifier:' \
      -e 'drawSelection\(in|drawBackground\(in|drawSelectionInRect:|drawBackgroundInRect:' \
      -e 'viewDidChangeEffectiveAppearance|accessibilityDisplayOptionsDidChange' \
      -e 'NSAnimationContext\.runAnimationGroup|\.animator\(\)|CA(Basic|Spring|Keyframe)Animation\(|CATransition\(\)' \
      -e 'lockFocus|NSBitmapImageRep\(bitmapDataPlanes|CGPDFContextCreate' \
      -e 'transition\(from:[^)]*to:[^)]*options:|NSPageController' \
      -e '\bNSDrawer\b|applicationShouldOpenUntitledFile' \
      -e 'registerForDraggedTypes|beginDraggingSession\(with|momentumPhase|menuNeedsUpdate' \
      -e 'addCursorRect|resetCursorRects|NSTrackingArea\(|updateTrackingAreas' \
      -e '\.action\s*=\s*#selector|\.bezelStyle\s*=|setButtonType\(' \
      -e 'documentView\s*=|NSScrollView\(\)|NSTableColumn\(identifier:|outlineTableColumn\s*='
```

## Instead of this, use that

| About to write | Use | Reference |
|---|---|---|
| `NSOutlineViewDataSource` walking a node tree; `reloadData` / `insertItems(at:inParent:)` after model changes; `NSTreeController` | `NSOutlineViewDiffableDataSource`, `NSOutlineViewDiffableSectionDataSource`, `NSDiffableDataSourceSectionSnapshot` | [lists-and-cells](references/lists-and-cells.md) |
| `NSTableViewDataSource` with hand-written drag reordering or `sortDescriptorsDidChange` | `NSTableViewDiffableReorderableDataSource` | lists-and-cells |
| `NSBrowserDelegate` with `NSBrowserCell` subclasses | `NSViewBasedBrowser` + `NSBrowserDiffableDataSource` | lists-and-cells |
| `makeView(withIdentifier:owner:) as? MyCell`, `register(_:forIdentifier:)`, `makeItem(withIdentifier:for:)` | `NSTableView.CellRegistration`, `NSOutlineView.CellRegistration`, `NSCollectionView.ItemRegistration` + `dequeueConfigured…` | lists-and-cells |
| a view controller that builds `NSScrollView` + `NSTableView` / `NSOutlineView` / `NSCollectionView` / `NSBrowser` in `loadView`, adds the column, wires `dataSource` / `delegate`, overrides `preferredFirstResponder` | `NSTableViewController`, `NSOutlineViewController`, `NSCollectionViewController`, `NSBrowserViewController` (0.7.0+) | lists-and-cells |
| an Auto Layout view (often an `NSStackView`) in an `NSScrollView` with hand-written width and height constraints, a flipped wrapper view or `NSClipView` subclass, `contentInsets` arithmetic | `NSScrollViewController(documentView:)` (0.7.0+) | lists-and-cells |
| `cell.textField?.stringValue = …`, `cell.imageView?.image = …`; cell subclasses laying out a title, subtitle and icon | `NSListContentConfiguration` through `contentConfiguration` | lists-and-cells |
| `drawSelection(in:)` / `drawBackground(in:)` overrides; restyling in `isSelected` / `backgroundStyle` overrides; hover tracking areas in cells | `NSBackgroundConfiguration`; `configurationUpdateHandler` / `updateConfiguration(using:)` with the configuration state | lists-and-cells |
| info buttons (and their popovers), checkmarks, count badges, pop-up chevrons, hover "…" buttons re-creating the row's context menu, built into cells | `accessories` (`NSViewAccessory`: `.detail(popover:)`, `.actionMenu`, …) | lists-and-cells |
| an `NSHostingView` embedded in a cell by hand | `NSHostingConfiguration` (macOS 13) | lists-and-cells |
| empty-state and loading overlays toggled with `isHidden` | `contentUnavailableConfiguration` on the view controller or on the view it covers (`NSContentUnavailableConfiguration`) | lists-and-cells |
| list icons drawn by hand — a coloured rounded square with a letter, Xcode style; an image swapped for a white version in selected rows or faded in a background window; a menu image redrawn for the highlighted item | `NSIcon` (Xcode's code symbol, language and stack frame icons, or an `NSGeneratedIconSpecification` of your own) shown in `NSIconView`; `NSMenuItem.icon` (0.15.0+) | lists-and-cells |
| `viewDidChangeEffectiveAppearance`; accessibility display, key/main window, screen and backing-scale notifications; walking up to the enclosing table for its style | `traitCollection` + `registerForTraitChanges` | [view-environment](references/view-environment.md) |
| environment values pushed down the view tree by hand | a custom `NSTraitDefinition` + `traitOverrides` | view-environment |
| `perform(_:with:afterDelay: 0)` coalescing, `withObservationTracking` loops, `didSet { updateUI() }` | `updateProperties()` + `setNeedsUpdateProperties()` | view-environment |
| `wantsLayer = true` boilerplate, first-layout / first-appear flags, per-container padding properties | `NSLayerBackedView`, `NSLayerBackedViewController`; `NSLayerBackedControl`, `NSLayerBackedTableCellView`, `NSLayerBackedCollectionViewItem` (0.9.0+); layout margins and the same hooks without the layer defaults through `NSPlusView` / `NSPlusViewController` (0.18.0+) | view-environment |
| centre arithmetic, `layer?.setAffineTransform`, `addSubview(_:positioned:relativeTo:)` | `center`, `transform`, `contentMode`, `bringSubview(toFront:)`, `insertSubview(_:aboveSubview:)` | view-environment |
| `NSVisualEffectView` / `NSGlassEffectView` behind `#available` branches | `NSEffectView` + `NSVisualEffect` / `NSGlassEffect` | view-environment |
| a container that swaps its own backdrop view per style; a backdrop no stock effect covers | an `NSEffect` subclass + `NSEffectHandler` (`import AppKitPlus.NSEffectSubclass`), shown through `NSEffectView` | view-environment |
| a sizing view plus a temporary width constraint to read `fittingSize` at a given width; KVC strings or bridging-header declarations reaching AppKit's private `NSView` members (`"ignoreHitTest"`) | `systemLayoutSizeFitting(_:withHorizontalFittingPriority:verticalFittingPriority:)`, `ignoreHitTest`, `mask`, … through `import AppKitPlus.SPI` (0.15.0+) | view-environment |
| global styling singletons applied in `awakeFromNib` | `appearance()` proxies | view-environment |
| `NSAnimationContext.runAnimationGroup` + `animator()`; hand-built `CABasicAnimation` / `CASpringAnimation` / `CATransition` on a view | the `NSView.animate` family | [animation-and-drawing](references/animation-and-drawing.md) |
| `NSImage.lockFocus`, `NSBitmapImageRep` + `NSGraphicsContext`, `CGPDFContextCreate` | `NSGraphicsImageRenderer`, `NSGraphicsPDFRenderer` | animation-and-drawing |
| a UIKit-compatibility `extension NSBezierPath` (`addLine(to:)`, `byRoundingCorners:`) | the AppKitPlus `NSBezierPath` construction API | animation-and-drawing |
| an app's own `CGRect.inset(by: NSEdgeInsets)`, `NSEdgeInsets: Equatable`, `NSStringFromCGRect` shims; `NSValue(bytes:objCType:)` for transforms | the `UIGeometry.h` helpers (0.6.0+) | animation-and-drawing |
| porting `UILabel` code; text that shrinks to fit | `NSLabel` | animation-and-drawing |
| a hand-rolled view-controller stack on `transition(from:to:options:)`; custom back buttons | `NSNavigationController` + `navigationItem` / `NSBarButtonItem` | [navigation-and-windows](references/navigation-and-windows.md) |
| pages on an `NSNavigationController` inset by hand for the navigation bar — `contentInsets` set from `topLayoutGuide.length`, content pinned to `topLayoutGuide` only to clear the bar | nothing: the bars are in the page's safe area, so `safeAreaLayoutGuide` and scroll views that adjust their insets clear them (0.7.0+) | navigation-and-windows |
| hand-written `NSViewControllerPresentationAnimator` slides | `NSNavigationParallaxTransition`, the transition controllers | navigation-and-windows |
| `NSDrawer` | `NSModernDrawer` | navigation-and-windows |
| a welcome window shown from `applicationDidFinishLaunching`; `applicationShouldOpenUntitledFile` tricks | `NSDocumentController.launchOptions` + `NSDocumentViewController` / `NSDocumentWindowController` | navigation-and-windows |
| `registerForDraggedTypes` + `NSDraggingDestination` overrides; `beginDraggingSession` from `mouseDragged` | `NSDropInteraction`, `NSDragInteraction`, `NSSpringLoadedInteraction` | [interactions-and-controls](references/interactions-and-controls.md) |
| `string(forType: .string)`, `readObjects(forClasses:)`, `clearContents()` + `writeObjects(_:)` for one value; `availableType(from:)` checks enabling Paste; a `UIPasteboard`-style `extension NSPasteboard` | `NSPasteboard.string` / `url` / `image` / `color`, their plurals, and `hasStrings` / `hasURLs` / `hasImages` / `hasColors` (0.7.0+) | interactions-and-controls |
| overlay chevron buttons paging a horizontal scroll view | `NSScrollPagingInteraction` | interactions-and-controls |
| `addCursorRect(_:cursor:)` in `resetCursorRects`; `NSCursor.set()` / `push()` from `mouseEntered` or `mouseMoved`; a `.cursorUpdate` tracking area | `NSCursorInteraction` (0.6.0+) | interactions-and-controls |
| hover highlights on a hand-made `NSTrackingArea` — `mouseEntered` / `mouseExited` plus `updateTrackingAreas` | `NSHoverAppearanceInteraction` (0.6.0+) | interactions-and-controls |
| snapping driven by `momentumPhase` or `didEndLiveScrollNotification` | `NSScrollBehaviorInteraction` + `NSScrollBehavior` | interactions-and-controls |
| async menu loading in `menuNeedsUpdate` with a "Loading…" item | `NSDeferredMenuItem` | interactions-and-controls |
| a search field put into an `NSMenu`, or key handling that hides menu items as the user types (`menuHasKeyEquivalent`, Carbon menu events, a `DVTFilteringMenu`-style subclass) | `NSMenu.filtersItemsWhileTyping` (0.16.0+) | interactions-and-controls |
| an `NSPathControl` with `pathStyle = .popUp` or a menu built per component; a breadcrumb of pop-up buttons rebuilt by hand when the selection changes | `NSPopUpPathControl` + `NSPopUpPathItem` on the model objects (0.8.0+); `navigationPresentationStyle = .popover` for searchable popovers instead of menus (0.18.0+) | interactions-and-controls |
| an `NSTableView` and a search field in an `NSPopover` built by hand to pick one of many items — a scheme, target or destination chooser; an `NSMenu` with an `NSSearchField` in a custom view; a pop-up button whose menu grew too long to scan | `NSNavigationPopoverController` + `NSNavigationPopoverItem` (0.18.0+) | interactions-and-controls |
| an `NSSearchField` with toggle buttons or a spinner laid over it; a hand-drawn "filter is on" background; a match count drawn next to the text | `NSFilterSearchField` (`addFilterButton(with:…)`, `progress`, `numberOfMatches`) (0.9.0+) | interactions-and-controls |
| an `NSTokenField` whose delegate parses `key:value` text into model objects, draws its own tokens, builds a completion popover, or saves recent filters; a search field meant to filter like Xcode's navigators (`loo*`, Begins With / Ends With) | `NSFilterTokenField` + `NSFilterToken` / `NSFilterTokenType` (0.9.0+); value marks and the delegate's token text for the navigators' text tokens (0.18.0+) | interactions-and-controls |
| a navigator-style bar under a list — a filter field with menu or action buttons beside it, laid out by hand; an `NSGlassEffectView` wrapped around a search field | `NSFilterControlBar` + `NSFilterControlBarItem` (0.10.0+); `NSFilterControlBarItemGroup` for buttons sharing one capsule (0.14.0+) | interactions-and-controls |
| a find field that builds an `NSRegularExpression` from typed text by hand; "digits" or "any word" offered as options beside the field; a find and replace pair where the user types `$1` | `NSFindPatternSearchField` + `NSFindPatternComponents` (0.13.0+) | interactions-and-controls |
| an `NSTextFinder` kept by hand; `performTextFinderAction(_:)` / `performFindPanelAction(_:)` overrides forwarding the sender's tag; an `NSTextFinderClient` with `stringAtIndex(_:effectiveRange:endsWithSearchBoundary:)`, `contentView(at:effectiveCharacterRange:)`, `rects(forCharacterRange:)` | `NSFindInteraction` + `NSTextProvidingFindSession` / `NSTextProviding`, or `NSTextSearchingFindSession` / `NSTextSearching` for content that searches itself (0.14.0+) | interactions-and-controls |
| an `NSSlider` subclass or custom `NSSliderCell` drawing a thin progress track; a knob drawn over or hidden by hand; a progress bar animated to grow on mouse down; a SwiftUI `Slider` hosted only for a media time bar; an `NSProgressIndicator` with a click recognizer standing in for a playback scrubber | `NSPlaybackSlider` (0.18.0+) | interactions-and-controls |
| `target = self` / `action = #selector(…)` per control; closure trampolines | `NSAction` (`addAction`, `primaryAction`) | interactions-and-controls |
| a graph of objects and their references drawn by hand — a custom view laying nodes out in columns with `CAShapeLayer` arrows; a web view running a JavaScript graph library | `NSObjectGridGraph`, the graph view of Xcode's Debug Memory Graph (0.15.0+) | interactions-and-controls |
| an `NSObjectGridGraph` whose scrolling is rewritten by a `scrollWheel` override or an event monitor; zoom commands sent to it from hidden menu items or a `keyDown` override | `NSObjectGridGraph.interactionConfiguration`, `zoomToFit()`, `returnToHomePivot()` (0.16.0+) | interactions-and-controls |
| a graph or dependency tree drawn top to bottom by hand — a rotated graph view, an org chart view | `NSObjectGridGraph` with `layoutOrientation = .vertical` (0.17.0+) | interactions-and-controls |
| an Expand All command for a graph written by hand — walking the model to expand each node in turn; an outline view standing in for a graph to get `expandItem(nil, expandChildren: true)` | `NSObjectGridGraph.expandAll(_:)`, `collapseAll(_:)` (0.17.0+) | interactions-and-controls |
| a second target or a block per control event — a hand-kept target list, a trampoline per `mouseDown` / `mouseUp` override | `NSControl.addAction(_:for:)` and the rest of `UIControl`'s event-handler API (0.7.0+) | interactions-and-controls |
| imperative button styling (`bezelStyle`, `setButtonType`, `bezelColor`, `NSButtonCell` subclasses) | `NSButton.Configuration` | interactions-and-controls |
| `NSDatePicker` in calendar style; hand-built day grids | `NSCalendarView` | interactions-and-controls |
| `sysctlbyname("hw.model")`, IOKit battery or serial-number queries | `NSDevice.current` | interactions-and-controls |
| `event.keyCode == 53`, `kVK_…` constants | `event.key?.keyCode` compared with `NSVirtualKey` | interactions-and-controls |

Each reference file lists, per area, what it replaces with the searches that find it, the
replacement in Swift with the Objective-C selectors, and the adoption steps — what to delete from the
old code once the new API is in.
