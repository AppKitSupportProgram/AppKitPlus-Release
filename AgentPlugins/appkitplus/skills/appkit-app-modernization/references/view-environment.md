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

## Layer-backed base classes — `NSLayerBackedView`, `NSLayerBackedViewController`

A view already set up for layer-backed drawing, and a view controller with first-layout and
first-appearance hooks.

**Replaces**: `wantsLayer = true` + `layerContentsRedrawPolicy = .onSetNeedsDisplay` in every
initialiser; `didLayoutOnce` / `hasAppeared` flags; `loadView() { view = NSView(); view.wantsLayer = true }`;
per-container `contentInsets` / `padding` properties used as constraint constants.

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
```

`NSLayerBackedView`: `layerClass`, `userInteractionEnabled`, `sizeThatFits(_:)`,
`layoutMargins`, `directionalLayoutMargins`, `preservesSuperviewLayoutMargins`,
`insetsLayoutMarginsFromSafeArea`, `layoutMarginsDidChange()`. `NSLayerBackedViewController`:
`viewClass`, `layerBackedView`, `viewWillFirstLayout` / `viewDidFirstLayout`,
`viewWillFirstAppear` / `viewDidFirstAppear`, `viewSafeAreaInsetsDidChange`. `viewClass` is typed
`any NSLayerBackedViewProtocol.Type` (0.8.0+); up to 0.7.0 it is `AnyClass`.

**Adopting**: change the superclass, move drawing into `updateLayer()`, and delete the layer setup and
the once-flags. A view that must keep drawing in `draw(_:)` overrides `wantsUpdateLayer` to return
`false`.

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
```

Properties styled through a proxy are `@objc dynamic`. Set proxies at launch, before the views they
style enter a window. Objective-C: `+appearance`, `+appearanceWhenContainedInInstancesOfClasses:`.

`NSView.appearance()` (the proxy) and `view.appearance` (the view's `NSAppearance`) are unrelated.
