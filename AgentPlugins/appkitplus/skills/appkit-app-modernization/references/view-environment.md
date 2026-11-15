# View Environment

Traits, the properties pass, the layer-backed base classes, view geometry, effects and appearance
proxies.

## Traits — `traitCollection`, `registerForTraitChanges`, `traitOverrides`

The environment a view lives in — appearance, accessibility settings, window and display state, the
kind of list it sits in — resolved down the chain `NSApplication → NSScreen → NSWindowController →
NSWindow → NSViewController → NSView`, with change callbacks for exactly the traits you name.

**Replaces**

| Legacy code | Trait |
|---|---|
| `viewDidChangeEffectiveAppearance()`, KVO on `effectiveAppearance`, dark-mode checks | `appearance`, `effectiveAppearance` |
| `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` + `accessibilityDisplayShould…` | `reduceMotion`, `reduceTransparency`, `accessibilityContrast`, `differentiateWithoutColor`, `invertColors` |
| `NSWindow.didBecomeKey/ResignKey/BecomeMain/ResignMainNotification`, `isKeyWindow` checks in drawing | `activeAppearance` |
| `viewDidChangeBackingProperties`, `didChangeScreenNotification`, `maximumFramesPerSecond`, `canRepresent(.p3)`, notch checks | `displayScale`, `displayMaximumFramesPerSecond`, `displayGamut`, `displayHasNotch`, `displayKind`, `displayPointDensity`, `imageDynamicRange` |
| `didEnterFullScreen` / `didExitFullScreen` notifications, `styleMask.contains(.fullScreen)` | `windowPresentationMode` |
| `didChangeOcclusionStateNotification` | `windowOcclusionState` |
| walking up `superview` to the enclosing table for `style` / `rowSizeStyle`; `backgroundStyle` / `isEmphasized` overrides in cells and rows | `tableViewStyle`, `tableViewRowSizeStyle`, `tableViewSelectionHighlightStyle`, `backgroundStyle`, `emphasized`, `groupRowStyle` |
| `userInterfaceLayoutDirection` reads | `layoutDirection` |
| an "environment" property pushed down a view tree by hand (`isInSidebar`, a density setting) | a custom `NSTraitDefinition` + `traitOverrides` |

```bash
rg -n -e 'viewDidChangeEffectiveAppearance|effectiveAppearance' -e 'accessibilityDisplayOptionsDidChange|accessibilityDisplayShould' \
      -e 'did(Become|Resign)(Key|Main)Notification|isKeyWindow|isMainWindow' \
      -e 'viewDidChangeBackingProperties|didChangeScreen(Parameters)?Notification|maximumFramesPerSecond' \
      -e 'did(Enter|Exit)FullScreen|didChangeOcclusionState' -e 'effectiveStyle|effectiveRowSizeStyle'
```

```swift
// Reading. On/off traits are three-state; compare against .on.
let reducesMotion = view.traitCollection.reduceMotion == .on
let isActive = view.traitCollection.activeAppearance == .active
let isDark = view.traitCollection.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

// Observing. The handler receives the environment itself, so it captures nothing.
registerForTraitChanges([NSTraitAppearance.self, NSTraitActiveAppearance.self, NSTraitReduceMotion.self]) {
    (viewController: InspectorViewController, previousTraitCollection) in
    viewController.refreshChrome()
}

// Overriding for a subtree.
window.traitOverrides.tableViewStyle = .sourceList
detailViewController.traitOverrides.reduceMotion = .off

// A trait of your own.
struct SidebarDensityTrait: NSTraitDefinition {
    static let defaultValue: CGFloat = 1.0
    static let identifier = "com.example.sidebar-density"
}
containerView.traitOverrides[SidebarDensityTrait.self] = 1.5
let density = cellView.traitCollection[SidebarDensityTrait.self]

// Building collections.
let sidebarTraits = NSTraitCollection(mutations: { $0.tableViewStyle = .sourceList })
let darkSidebarTraits = sidebarTraits.modifyingTraits { $0.appearance = NSAppearance(named: .darkAqua) }
```

Also: `registerForTraitChanges(_:target:action:)`, `registerForTraitChanges(_:action:)`,
`unregisterForTraitChanges(_:)`, `NSTraitCollection.current`,
`performAsCurrent(_:)`; `NSCell` has a read-only `traitCollection`. To draw with dynamic colours for a
trait collection, use `traitCollection.effectiveAppearance.performAsCurrentDrawingAppearance { … }`.

SwiftUI: content inside an `NSHostingConfiguration` reads the host's traits through
`EnvironmentValues.hostTraitCollection` or an `EnvironmentKey` conforming to
`NSTraitBridgedEnvironmentKey`. In an `NSViewRepresentable`, pass SwiftUI's environment down with
`nsView.traitOverrides.apply(context.environment.resolvedTraitCollection)`.

Objective-C: `traitCollection`, `traitOverrides`, `-registerForTraitChanges:withHandler:`,
`-registerForTraitChanges:withTarget:action:`, `-unregisterForTraitChanges:`,
`+traitCollectionWithTraits:`, `-traitCollectionByModifyingTraits:`; trait classes are passed as
`NSTraitAppearance.class` and so on, and on/off values compare against
`NSTraitEnvironmentStateValueOn`.

**Adopting**

- Register once, on the view controller (in `viewDidLoad`) or the window, and update what depends on
  the traits from there. Cells that use content or background configurations re-resolve by
  themselves and need no registration.
- Delete the notification observers, the appearance overrides and the superview walks they replace.

## The properties pass — `updateProperties()`

A per-view and per-view-controller pass that runs before layout, coalesces every request made in
the same turn, and on macOS 14 and later re-runs by itself when an `@Observable` property it read
changes.

**Replaces**: UI refresh done in `layout()` / `viewDidLayout()`; coalescing with
`perform(_:with:afterDelay: 0)` + `cancelPreviousPerformRequests` or `DispatchQueue.main.async`;
hand-written `withObservationTracking` loops; Combine sinks and `didSet { updateUI() }` whose only
job is refreshing views.

```bash
rg -n -e 'withObservationTracking' -e 'cancelPreviousPerformRequests' -e 'afterDelay:\s*0' \
      -e 'func (updateUI|refreshUI|reloadUI|configureUI|updateViews)\('
```

```swift
final class CounterViewController: NSViewController {
    let model = CounterModel()                        // @Observable
    var badgeCount = 0 { didSet { if badgeCount != oldValue { setNeedsUpdateProperties() } } }

    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsUpdateProperties()                    // schedules the first pass
    }

    override func updateProperties() {
        super.updateProperties()
        countLabel.stringValue = "\(model.count)"     // tracked on macOS 14+
        badgeLabel.stringValue = "\(badgeCount)"
    }
}
```

`updatePropertiesIfNeeded()` runs a pending pass right away (before measuring, for example). The same
three members exist on `NSView`. Objective-C: `-setNeedsUpdateProperties`, `-updateProperties`,
`-updatePropertiesIfNeeded`.

**Adopting**: move the refresh code into `updateProperties()`, call `setNeedsUpdateProperties()`
wherever a non-observable input changes, and delete the coalescing and tracking machinery. On macOS
12 and 13, call `setNeedsUpdateProperties()` for observable inputs too.

## View base classes — `NSPlusView`, `NSPlusViewController`, the layer-backed pair and their variants

A view with writable layout margins and `isUserInteractionEnabled` (`NSPlusView`, next release); a view
controller with first-layout and first-appearance hooks (`NSPlusViewController`, next release); the
same two already set up for layer-backed drawing (`NSLayerBackedView`, `NSLayerBackedViewController`,
which inherit from them) — plus the same members on the system classes that cannot inherit from them:
`NSLayerBackedControl`, `NSLayerBackedTableCellView` and `NSLayerBackedCollectionViewItem`.

**Replaces**: `wantsLayer = true` + `layerContentsRedrawPolicy = .onSetNeedsDisplay` in every
initialiser, a control's or a table cell view's included; `didLayoutOnce` / `hasAppeared` flags, an
item's included; `loadView() { view = NSView(); view.wantsLayer = true }`; per-container
`contentInsets` / `padding` properties used as constraint constants — on a view that draws in
`draw(_:)` too, through `NSPlusView`.

```bash
rg -n -e 'wantsLayer\s*=\s*true' -e 'layerContentsRedrawPolicy' \
      -e '(didLayout|hasLaidOut|firstLayout|hasAppeared|didAppearOnce)\w*\s*[:=]' \
      -e 'var (contentInsets|padding|edgeInsets)\s*:\s*NSEdgeInsets'
```

```swift
final class CardView: NSLayerBackedView {
    override func updateLayer() {                     // draw here
        super.updateLayer()
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
}

final class DetailViewController: NSLayerBackedViewController {
    override class var viewClass: any NSLayerBackedViewProtocol.Type { CardView.self }
    override func viewDidFirstLayout() { super.viewDidFirstLayout(); selectInitialRow() }
    override func viewDidFirstAppear() { super.viewDidFirstAppear(); startInitialFetch() }
}

// Writable layout margins that drive layoutMarginsGuide.
cardView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
titleLabel.leadingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.leadingAnchor).isActive = true

// The same margins and hooks for a view that keeps drawing in draw(_:) and wants no layer defaults.
final class BadgeView: NSPlusView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
    }
}

final class BadgeViewController: NSPlusViewController {
    override class var viewClass: any NSPlusViewProtocol.Type { BadgeView.self }
    override func viewDidFirstAppear() { super.viewDidFirstAppear(); startInitialFetch() }
}

// A control: NSControl + its cell as before, with the same members as NSLayerBackedView.
final class RatingControl: NSLayerBackedControl {
    override class var cellClass: AnyClass? { get { RatingCell.self } set {} }
}

// A collection view item: the same hooks as NSLayerBackedViewController.
final class PhotoItem: NSLayerBackedCollectionViewItem {
    override func viewDidFirstLayout() { super.viewDidFirstLayout(); configureThumbnailSize() }
}
```

`NSPlusView` (0.18.0+): `isUserInteractionEnabled` (`userInteractionEnabled` in Swift through
0.17.0), `sizeThatFits(_:)`,
`layoutMargins`, `directionalLayoutMargins`, `preservesSuperviewLayoutMargins`,
`insetsLayoutMarginsFromSafeArea`, `layoutMarginsDidChange()` — and no layer: `wantsLayer`,
`wantsUpdateLayer` and the redraw policy stay AppKit's, so `draw(_:)` is called as on any `NSView`.
`NSLayerBackedView`: all of those, inherited from `NSPlusView` (0.18.0+; earlier releases declare
them on `NSLayerBackedView` itself, with the same behaviour), plus `layerClass`. `NSIconView` and
`NSObjectGridGraph` are `NSPlusView`s too (0.18.0+).
`NSLayerBackedControl` (0.9.0+) and `NSLayerBackedTableCellView` (0.9.0+): the same members
on an `NSControl` and an `NSTableCellView`. `NSPlusViewController` (0.18.0+): `viewClass`
(`any NSPlusViewProtocol.Type`, `NSPlusView` by default), `viewWillFirstLayout` / `viewDidFirstLayout`,
`viewWillFirstAppear` / `viewDidFirstAppear`, `viewSafeAreaInsetsDidChange`, `menu(for:)`.
`NSLayerBackedViewController`: all of those, inherited from `NSPlusViewController` (0.18.0+), plus
`layerBackedView` and `viewUpdateLayer()`; its `viewClass` is typed `any NSLayerBackedViewProtocol.Type`
(0.8.0+; up to 0.7.0 it is `AnyClass`). The same members on an `NSCollectionViewItem` through
`NSLayerBackedCollectionViewItem` (0.9.0+).

**Adopting**: change the superclass, move drawing into `updateLayer()`, and delete the layer setup and
the once-flags. A view that must keep drawing in `draw(_:)` derives from `NSPlusView` instead, and its
controller from `NSPlusViewController` (0.18.0+) — `NSLayerBackedView` never calls `draw(_:)` unless
`wantsUpdateLayer` is overridden to return `false`, which is the way on releases before `NSPlusView`. A control changes `NSControl` to `NSLayerBackedControl` and keeps drawing through its cell —
nothing to override. A table cell view changes `NSTableCellView` to `NSLayerBackedTableCellView`; its
`directionalLayoutMargins` keep laying out content configuration as before. An item changes
`NSCollectionViewItem` to `NSLayerBackedCollectionViewItem` and drops its own `loadView()` when that
only built a container view.

## Geometry and hierarchy on `NSView`

**Replaces**: centre arithmetic on `frame.origin`; `layer?.setAffineTransform(…)` and
`frameCenterRotation`; `layer?.contentsGravity`; `addSubview(_:positioned:relativeTo:)`; app-local
`extension NSView { var center … }`.

```bash
rg -n -e 'layer\??\.(setAffineTransform|transform\s*=|contentsGravity\s*=)' -e 'frameCenterRotation|rotate\(byDegrees' \
      -e 'positioned:\s*\.(above|below)' -e 'extension NSView\b'
```

```swift
badgeView.center = CGPoint(x: bounds.midX, y: bounds.midY)
cardView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
thumbnailView.contentMode = .scaleAspectFill
containerView.bringSubview(toFront: overlayView)
containerView.insertSubview(shadowView, belowSubview: cardView)
```

Objective-C: `center`, `transform`, `contentMode`, `-bringSubviewToFront:`, `-sendSubviewToBack:`,
`-insertSubview:aboveSubview:`, `-insertSubview:belowSubview:`.

**Adopting**: delete the app's own `NSView` extensions that declare these names. Views placed by Auto
Layout keep being moved through their constraints; `transform` is for visual effects.

## Structured layout — `NSStructuredLayoutView` (0.23.0+)

Frames set in code, in a pass AppKit runs after its own layout: each structured view gives its subviews the room
they have, every subview lays itself out and settles its size, then the view places them and settles its own. A
label's height for a width reaches its row, and the row's reaches the list, in the same pass — the layout Xcode's
navigators, jump bar and tab bar are built with.

**Replaces**: frame arithmetic in `layout()` or `resizeSubviews(withOldSize:)`; a parent that measures its labels with
`sizeThatFits` or `preferredMaxLayoutWidth` after every change to work out its own size; constraints torn down and
rebuilt to fit an icon, a wrapping title and trailing badges into a row.

```swift
final class IssueRowView: NSStructuredLayoutView {
    let iconView = NSStructuredLayoutImageView()
    let titleField = NSStructuredLayoutTextField(wrappingLabelWithString: "")
    @NSView.Invalidating(.structuredLayout) var spacing: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(iconView)
        addSubview(titleField)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // Before the subviews lay themselves out: the room each one has.
    override func configureSubviewsBeforeSubviewLayout() {
        titleField.maximumAlignmentWidth = bounds.width - iconView.frame.width - spacing
    }

    // After: they have their sizes, so place them and settle this view's own.
    override func positionSubviewsAndSizeSelfAfterSubviewLayout() {
        iconView.setFrameOrigin(.zero)
        titleField.setFrameOrigin(NSPoint(x: iconView.frame.maxX + spacing, y: 0))
        setFrameSize(NSSize(width: bounds.width, height: max(iconView.frame.height, titleField.frame.height)))
    }
}
```

- **Invalidate** with `structuredLayoutState.invalidateLayout()`, or declare the property
  `@NSView.Invalidating(.structuredLayout)`. A change of the view's frame size or bounds invalidates it by itself; a
  parent follows a subview that sizes itself with `structuredLayoutState.invalidateLayout(onFrameChangesOf: subview)`.
- **Order and interleave**: `subviewsOrderedForStructuredLayout()` lays out the subviews whose sizes are needed first,
  and `willLayoutSubview(_:at:)` / `didLayoutSubview(_:at:)` run around each one — give the title the room the
  badges left just before the title's turn. `didCompleteStructuredLayout()` runs once the whole tree is done.
- **Text**: `NSStructuredLayoutTextField` wraps up to `maximumAlignmentWidth`, keeps exactly `fixedAlignmentWidth`, or
  takes its text on one line; `fixedFrameHeight` overrides the height, and `explicitExpansionText` is what its
  expansion tool tip shows over a truncated title. `NSStructuredLayoutImageView` sizes itself to its image.
- **Any other view** — a table cell or row view, a control — adopts `NSStructuredLayoutViewProtocol`:
  `lazy var structuredLayoutState = NSStructuredLayoutViewState(hostView: self)`, read once in `init`.
- **With Auto Layout**: a structured view placed by constraints reports the height it needs as its
  `intrinsicContentSize` and lays out only its subviews; a view laid out by constraints goes inside one through
  `NSStructuredLayoutAutolayoutWrapperView(wrappedView:fixedWidth:fixedHeight:constraintPriority:)`.
- **Now, not in the next pass** — to measure a view before showing it, or to settle a container before focusing
  or snapshotting it: `structuredLayoutState.layoutIfNeeded()` on a structured view, and
  `layoutStructuredSubtreeIfNeeded()` on any view, structured or not, in a window or not.

## AppKit's private `NSView` members — `import AppKitPlus.SPI` (0.15.0+)

**Replaces**: a sizing view plus a temporary width constraint, laid out to read `fittingSize` at a given
width; key-value coding strings that reach AppKit's private `NSView` members
(`setValue(true, forKeyPath: "ignoreHitTest")`); the app's own declarations of them in a bridging
header.

```bash
rg -n -e 'forKey(Path)?:\s*"(ignoreHitTest|maskView|frameTransform|_semanticContext|_effectiveSemanticContext)"' \
      -e 'systemLayoutSizeFittingSize' -e '\.fittingSize\b'
```

`AppKitPlus.SPI` declares members AppKit implements on `NSView` but leaves out of its public headers.
They are AppKit's own SPI, so `import AppKitPlus` does not include them: import the submodule in the
files that need it, prefer public API wherever it covers the need, and read a member's documentation in
the header before using it.

```swift
import AppKitPlus
import AppKitPlus.SPI

let rowSize = cellView.systemLayoutSizeFitting(
    NSSize(width: tableView.bounds.width, height: 0),
    withHorizontalFittingPriority: .required,
    verticalFittingPriority: .fittingSizeCompression)

dimmingView.ignoreHitTest = true   // a click on the view itself goes to the view below
let isInSidebar = view._effectiveSemanticContext == .sidebar
```

Also there: `mask` (`UIView.mask`'s counterpart), `frameTransform`, `_semanticContext`,
`_isUserInterfaceLayoutDirectionExplicitlySet()`, and the layout-margin hooks
`-_marginsInsetsForSafeAreaInsets:`, `-_layoutMargins` and `-_updateLayoutMarginsGuideConstraintsIfNecessary`.
Objective-C: `@import AppKitPlus.SPI;` or `#import <AppKitPlus/AppKitPlusSPI.h>`.

**Adopting**: delete the KVC strings and the app's own declarations of these members; a sizing view
kept only to call `fittingSize` at a width becomes one `systemLayoutSizeFitting` call on the view
itself (macOS 13.1).

## Effects — `NSEffectView`, `NSVisualEffect`, `NSGlassEffect`, `NSEffectHandler`

**Replaces**: hand-built `NSVisualEffectView` / `NSGlassEffectView` with `if #available(macOS 26, *)`
branches, and swapping one effect view for another at runtime.

```bash
rg -n -e 'NSVisualEffectView\(' -e 'NSGlassEffectView\(' -e '\.material\s*=' -e '\.blendingMode\s*='
```

```swift
let effectView = NSEffectView(effect: NSVisualEffect(material: .sidebar))
effectView.contentView.addSubview(contentStack)
if #available(macOS 26.0, *) {
    let glass = NSGlassEffect(style: .regular)
    glass.cornerRadius = 12
    effectView.effect = glass
}
```

Objective-C: `+[NSVisualEffect effectWithMaterial:]` (`blendingMode`, `state`, `emphasized`,
`maskImage`), `+[NSGlassEffect effectWithStyle:]` (`tintColor`, `cornerRadius`),
`-[NSEffectView initWithEffect:]`, `effect`, `contentView`.

**Adopting**: put content in `contentView`, change the look by assigning a new `effect`, and delete
the availability branches that picked a view class.

**A backdrop of your own** — a container that swaps its own backdrop view per style, or a material
no stock effect covers — becomes an `NSEffect` subclass carrying the values, plus an
`NSEffectHandler` that names the view drawing it and configures that view. The handler lives in
`AppKitPlus.NSEffectSubclass`, which `import AppKitPlus` does not include:

```swift
import AppKitPlus
import AppKitPlus.NSEffectSubclass

final class TintedBackdropEffect: NSEffect {
    var tint: NSColor = .clear

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = TintedBackdropEffect()
        copy.tint = tint
        return copy
    }
    override func isEqual(_ object: Any?) -> Bool { (object as? TintedBackdropEffect)?.tint == tint }
    override var hash: Int { tint.hash }
}

final class TintedBackdropEffectHandler: NSEffectHandler {
    override class var effectClass: AnyClass { TintedBackdropEffect.self }
    override var backingViewClass: AnyClass { TintedBackdropView.self }
    override func apply(_ effect: NSEffect, to backingView: NSView) {
        (backingView as! TintedBackdropView).tint = (effect as! TintedBackdropEffect).tint
    }
}

// applicationWillFinishLaunching(_:)
NSEffectHandler.register(TintedBackdropEffectHandler())

let backdrop = TintedBackdropEffect()
backdrop.tint = .systemTeal
effectView.effect = backdrop
```

The registered effect is accepted everywhere an `NSEffect` is: `NSEffectView.effect`,
`NSBackgroundConfiguration.visualEffect`, `NSModernDrawerConfiguration.effect`. Objective-C:
`@import AppKitPlus.NSEffectSubclass;`, `+[NSEffectHandler registerHandler:]`, `+effectClass`,
`backingViewClass`, `-applyEffect:toBackingView:`, and — for a backing view with a content slot of
its own — `-attachContentView:toBackingView:` / `-detachContentView:fromBackingView:`.

## Appearance proxies — `appearance()`

**Replaces**: theme singletons applied to every instance of a view class in `awakeFromNib` or
`viewDidMoveToWindow`.

```bash
rg -n -e 'Theme\.(shared|current)' -e 'applyTheme\(' -e 'override func (awakeFromNib|viewDidMoveToWindow)'
```

```swift
final class BadgeView: NSView {
    @objc dynamic var badgeColor: NSColor = .systemRed { didSet { needsDisplay = true } }
}

BadgeView.appearance().badgeColor = .systemOrange
BadgeView.appearance(whenContainedInInstancesOf: [SidebarContainerView.self]).badgeColor = .secondaryLabelColor
BadgeView.appearance(whenContainedInInstancesOf: [NSTableCellView.self, SidebarViewController.self])
    .badgeColor = .tertiaryLabelColor
```

Properties styled through a proxy are `@objc dynamic`. Set proxies at launch, before the views they
style enter a window. Container classes are listed innermost first, as in UIKit. A view controller is a
container too and contains its root view (0.22.0+). A setter with axes keeps one value per axis
(`setWidth:forSegment:`), and a getter sent to a proxy reads back what was recorded. Objective-C:
`+appearance`, `+appearanceWhenContainedInInstancesOfClasses:`.

`NSView.appearance()` (the proxy) and `view.appearance` (the view's `NSAppearance`) are unrelated.
