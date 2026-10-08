# Interactions and Controls

Drag and drop, pasteboard values, scroll paging and snapping, deferred menu items, closure actions,
button configurations, and a few smaller replacements.

## Drag and drop — `NSDragInteraction`, `NSDropInteraction`, `NSSpringLoadedInteraction`

Interactions attached to a view with `addInteraction(_:)`, driven by a delegate — the UIKit model.

**Replaces**: a view subclass overriding `draggingEntered` / `draggingUpdated` / `draggingExited` /
`prepareForDragOperation` / `performDragOperation` / `concludeDragOperation` together with
`registerForDraggedTypes`; `mouseDragged` starting `beginDraggingSession(with:event:source:)` with an
`NSDraggingSource`; `NSSpringLoadingDestination` methods.

```bash
rg -n -e 'registerForDraggedTypes' -e 'func dragging(Entered|Updated|Exited|Ended)' -e '(prepareFor|perform|conclude)DragOperation' \
      -e 'beginDraggingSession\(with' -e 'NSDraggingSource' -e 'springLoading(Activated|HighlightChanged|Entered|Updated|Exited)'
```

```swift
final class SwatchView: NSView, NSDragInteractionDelegate, NSDropInteractionDelegate {
    func installInteractions() {
        addInteraction(NSDragInteraction(delegate: self))

        let dropInteraction = NSDropInteraction(delegate: self)
        dropInteraction.supportedTypes = [.string, .fileURL]
        addInteraction(dropInteraction)

        addInteraction(NSSpringLoadedInteraction { interaction, context in self.openFolder() })
    }

    func dragInteraction(_ interaction: NSDragInteraction, itemsForBeginning session: any NSDragSession) -> [NSDragItem] {
        [NSDragItem(itemProvider: NSItemProvider(object: colorName as NSString))]
    }

    func dropInteraction(_ interaction: NSDropInteraction, canHandle session: any NSDropSession) -> Bool {
        session.canLoadObjects(ofClass: NSString.self)
    }

    func dropInteraction(_ interaction: NSDropInteraction, sessionDidUpdate session: any NSDropSession) -> NSDropProposal {
        NSDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: NSDropInteraction, performDrop session: any NSDropSession) {
        _ = session.loadObjects(ofClass: NSString.self) { objects in self.apply(objects) }
    }
}
```

Set `supportedTypes` before adding the drop interaction. A custom interaction conforms to
`NSViewInteraction` (`view`, `willMove(from:to:)`, `didMove(from:to:)` (0.8.0+); up to 0.7.0
the two methods are `willMove(to:)` and `didMove(to:)`).

Objective-C: `-initWithDelegate:`, `-[NSView addInteraction:]`,
`-dragInteraction:itemsForBeginningSession:`, `-dropInteraction:canHandleSession:`,
`-dropInteraction:sessionDidUpdate:`, `-dropInteraction:performDrop:`,
`-[NSDropSession loadObjectsOfClass:completion:]`, `-[NSSpringLoadedInteraction initWithActivationHandler:]`.

**Adopting**: delete the view's `NSDraggingDestination` / `NSDraggingSource` overrides and its
`registerForDraggedTypes` call once the interactions are in. Table, outline and collection views keep
their data-source drag methods, or the diffable reordering handlers in
[lists-and-cells](lists-and-cells.md).

## Pasteboard values — `NSPasteboard.string`, `url`, `image`, `color` (0.7.0+)

`UIPasteboard`'s convenience properties, on `NSPasteboard`.

**Replaces**: `string(forType: .string)`, `readObjects(forClasses: [NSURL.self], options: nil)?.first`,
`NSImage(pasteboard:)`, `NSColor(from:)`; `clearContents()` followed by `writeObjects(_:)` or
`setString(_:forType:)` to put one value on the pasteboard; `availableType(from:)` /
`canReadObject(forClasses:options:)` checks that decide whether Paste is enabled; an app's own
`UIPasteboard`-style `extension NSPasteboard`.

```bash
rg -n -e 'string\(forType: *\.string\)' -e 'readObjects\(forClasses:' -e 'NSImage\(pasteboard:' -e 'NSColor\(from:' \
      -e 'canReadObject\(forClasses:' -e 'availableType\(from:' -e 'extension NSPasteboard'
```

```swift
@IBAction func paste(_ sender: Any?) {
    let pasteboard = NSPasteboard.general
    if let url = pasteboard.url {
        insertLink(to: url)
    } else if let text = pasteboard.string {
        insertText(text)
    }
}

func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard menuItem.action == #selector(paste(_:)) else { return true }
    return NSPasteboard.general.hasURLs || NSPasteboard.general.hasStrings
}

NSPasteboard.general.string = selectedText            // replaces the contents with one item
NSPasteboard.general.images = selection.map(\.image)  // one item per image
```

`string`, `url`, `image` and `color` are the first item's value; `strings`, `urls`, `images` and `colors`
collect every item's, skipping items without one. `hasStrings`, `hasURLs`, `hasImages` and `hasColors`
answer from the item types without reading any data. Setting a property replaces the pasteboard's
contents, and setting `nil` clears it. Objective-C: `string`, `strings`, `URL`, `URLs`, `image`, `images`,
`color`, `colors` with their setters, and `hasStrings`, `hasURLs`, `hasImages`, `hasColors`.

**Adopting**: delete any `NSPasteboard` extension or category of the app's own that declares these
names. Enable Paste commands from the `has…` properties rather than by reading the values.

## Scroll paging arrows — `NSScrollPagingInteraction`

The previous / next arrows that appear over a horizontal shelf on hover, as in the App Store and
Music.

**Replaces**: chevron `NSButton`s layered over an `NSScrollView`, a tracking area fading them in, and
click handlers scrolling with `contentView.animator().setBoundsOrigin` + `reflectScrolledClipView`.

```bash
rg -n -e 'chevron\.(left|right)' -e 'setBoundsOrigin' -e 'reflectScrolledClipView'
```

```swift
let pagingInteraction = NSScrollPagingInteraction()
pagingInteraction.arrowVisibility = .automatic
pagingInteraction.delegate = self                 // optional: adjust the landing origin
scrollView.addInteraction(pagingInteraction)
```

Also: `boundaryBehavior`, `orientation`, `arrowInsets`, `canPage(in:)`, `page(in:animated:)`; delegate
`scrollPagingInteraction(_:adjustedScrollOriginFor:direction:)` and `visualCenterOffset(for:)`.

**Adopting**: delete the overlay buttons, their tracking area and the scroll code.

## Scroll snapping — `NSScrollBehavior`, `NSScrollBehaviorInteraction`

Where momentum scrolling comes to rest on one axis: by page, or at named detents.

**Replaces**: `scrollWheel(with:)` overrides reading `momentumPhase` to snap;
`didEndLiveScrollNotification` observers animating to the nearest page; hand-written snapping math.

```bash
rg -n -e 'momentumPhase' -e 'didEndLiveScrollNotification' -e 'targetContentOffset\(forProposedContentOffset'
```

```swift
let pagingBehavior = NSScrollBehavior.pagingBehavior(
    with: .horizontal, pagingOrigin: 0, pageOffset: scrollView.contentView.bounds.width,
    decelerationRate: .fast, allowsFlickAcrossMultiplePages: false)
scrollView.addInteraction(NSScrollBehaviorInteraction(behavior: pagingBehavior))

let detentsBehavior = NSScrollBehavior.detentsBehavior(with: .vertical, detents: [
    NSScrollDetent(identifier: "top", offset: 0, availableForScrollingGesture: true),
    NSScrollDetent(identifier: "middle", offset: 300, availableForScrollingGesture: true),
], intrinsicContentOffset: 0)

// Without the interaction, e.g. inside a collection-view layout:
let landingOffset = detentsBehavior.adjustedTargetContentOffset(
    forProposedTargetContentOffset: proposedOffset, velocity: velocity,
    currentContentOffset: currentOffset, decelerationRate: nil)
```

Objective-C: `+pagingBehaviorWithOrientation:pagingOrigin:pageOffset:decelerationRate:allowsFlickAcrossMultiplePages:`,
`+detentsBehaviorWithOrientation:detents:intrinsicContentOffset:`, `+normalBehaviorWithOrientation:`,
`-[NSScrollBehaviorInteraction initWithBehavior:]`.

**Adopting**: delete the snapping code and its observers.

## Cursors and hover — `NSCursorInteraction`, `NSHoverAppearanceInteraction` (0.6.0+)

A view's cursor, and its hover highlight, each from one `addInteraction(_:)`.

**Replaces**: `addCursorRect(_:cursor:)` in `resetCursorRects` with `invalidateCursorRects(for:)` calls;
`NSCursor.set()` / `push()` / `pop()` from `mouseEntered`, `mouseExited` or `mouseMoved`;
`cursorUpdate(with:)` overrides; hover tracking areas rebuilt in `updateTrackingAreas`, with
`mouseEntered` / `mouseExited` toggling a highlight, and the code that clears the highlight when the view
scrolls, hides or is reused.

```bash
rg -n -e 'addCursorRect|resetCursorRects|invalidateCursorRects' \
      -e 'NSCursor\.\w+\.(set|push)\(\)|NSCursor\.pop\(\)' \
      -e 'func (cursorUpdate|mouseEntered|mouseExited|updateTrackingAreas)\('
```

```swift
cardView.addInteraction(NSCursorInteraction(cursor: .pointingHand))

let hover = NSHoverAppearanceInteraction { _, isHovered in
    highlightView.alphaValue = isHovered ? 1 : 0     // a view property, so the fade animates
}
hover.animationDuration = 0.15
cardView.addInteraction(hover)
```

Also: `cursor` and `isEnabled` on the cursor interaction; `isHovered` (key-value observable), `isEnabled`
and `activeScope` (`.always`, `.inKeyWindow`, `.inActiveApp`) on the hover interaction. Objective-C:
`-[NSCursorInteraction initWithCursor:]`, `-[NSHoverAppearanceInteraction initWithAppearanceHandler:]`.

**Adopting**: delete the cursor rectangles, the tracking area and its `updateTrackingAreas` override, the
`mouseEntered` / `mouseExited` / `cursorUpdate` overrides, and the code resetting the highlight on scroll,
hide or cell reuse. Keep the resting appearance in the view's own setup — the handler runs only when the
hover state changes. A table or collection cell that already has a `configurationUpdateHandler` reads
hover from its configuration state instead ([lists-and-cells](lists-and-cells.md)).

## Menu items filled on demand — `NSDeferredMenuItem`

A menu item that shows a disabled "Loading…" placeholder when its menu opens and is replaced in place
by the items its provider delivers, synchronously or later.

**Replaces**: `menuNeedsUpdate(_:)` / `menuWillOpen(_:)` starting async work and patching the menu
afterwards; delegate-built menus (`numberOfItems(in:)` + `menu(_:update:at:shouldCancel:)`); a
"Loading…" item managed by hand.

```bash
rg -n -e 'menuNeedsUpdate' -e 'menuWillOpen' -e 'numberOfItems\(in menu' -e 'menu\(_ menu: NSMenu, update' -e 'Loading(…|\.\.\.)'
```

```swift
menu.addItem(NSDeferredMenuItem { completion in
    Task { completion(await loadRecentItems()) }                 // asked once, then cached
})
menu.addItem(NSDeferredMenuItem.uncached { completion in
    completion(currentWindowItems())                             // asked every time the menu opens
})

// Items supplied by whatever is in focus when the menu opens:
menu.addItem(NSDeferredMenuItem.usingFocus(identifier: NSUserInterfaceItemIdentifier("recent"), shouldCacheItems: false))

final class DocumentPageViewController: NSViewController {
    override func provider(for deferredMenuItem: NSDeferredMenuItem) -> NSDeferredMenuItem.Provider? {
        guard deferredMenuItem.identifier == NSUserInterfaceItemIdentifier("recent") else {
            return super.provider(for: deferredMenuItem)
        }
        return NSDeferredMenuItem.Provider { completion in completion(recentItems()) }
    }
}
```

`title` changes the placeholder text. Objective-C: `+itemWithProvider:`, `+itemWithUncachedProvider:`,
`+itemUsingFocusWithIdentifier:shouldCacheItems:`, `-[NSResponder providerForDeferredMenuItem:]`,
`+[NSDeferredMenuItemProvider providerWithElementProvider:]`.

**Adopting**: delete the menu delegate code that existed only to load items late.

## Jump bars — `NSPopUpPathControl` (0.8.0+)

A path bar whose every component opens a menu of the items that could take its place, lined up under
the pointer, as in the jump bar of an Xcode editor. Rows with children open submenus that list them
when they open. Choosing a row selects it, tells the delegate and sends the control's action.

**Replaces**: `NSPathControl` with `pathStyle = .popUp`, or one built from `NSPathControlItem`s with a
menu assembled per click (`pathControl(_:willPopUp:)`); a row of `NSPopUpButton`s acting as a
breadcrumb, rebuilt by hand whenever the selection or the model changes.

```bash
rg -n -e 'NSPathControl' -e 'pathStyle' -e 'willPopUp' -e 'NSPathComponentCell' -e 'pathItems' -e 'breadcrumb'
```

```swift
// The model objects themselves adopt the item protocol — there is no item class to fill in.
final class FolderItem: NSObject, NSPopUpPathItem {
    let url: URL
    weak var parentItem: (any NSPopUpPathItem)?

    init(url: URL, parent: FolderItem?) {
        self.url = url
        self.parentItem = parent
    }

    var pathComponentName: String { FileManager.default.displayName(atPath: url.path) }
    var pathComponentIcon: NSImage? { NSWorkspace.shared.icon(forFile: url.path) }
    var representedFileURL: URL? { url }                       // Command-click shows the enclosing folders
    var isLeaf: Bool { !url.hasDirectoryPath }                  // keeps childItems lazy
    var childItems: [any NSPopUpPathItem]? { loadChildren() }   // asked when a menu or submenu opens
}

let jumpBar = NSPopUpPathControl()
jumpBar.rootItems = [projectRoot]          // the first component's menu
jumpBar.selectedItem = currentFile         // the path is its parentItem chain up to a root item
jumpBar.delegate = self
jumpBar.target = self
jumpBar.action = #selector(jumpBarChanged(_:))

func popUpPathControl(_ pathControl: NSPopUpPathControl, didSelect item: any NSPopUpPathItem) {
    open(item)
}
```

Return the same item objects every time — the path and the menus compare them by identity. Make
`pathComponentName` and `pathComponentIcon` KVO-compliant (`@objc dynamic`) and the bar follows
renames and icon changes by itself; call `invalidateContent()` after anything else changes, such as an
item moving to another parent. `popUpMenuForComponent(at:)` opens a component's menu from a keyboard
shortcut. The delegate customises the menus: `menuItemFor:defaultMenuItem:`,
`shouldSeparateDisplayOfChildItemsFor:` (inline children), `shouldEnableSelectionOf:`. Appearance:
`lastComponentFillsWidth`, `wantsCapsuleHighlights`, `selectsComponentsOneAtATime`, `controlSize`.
Objective-C: `-[NSPopUpPathControlDelegate popUpPathControl:didSelectItem:]`, `-popUpMenuForComponentAtIndex:`.

**Adopting**: delete the per-click menu assembly and the breadcrumb rebuilding; let the model objects
adopt `NSPopUpPathItem`.

## Closure actions — `NSAction`

**Replaces**: `target = self` / `action = #selector(…)` with an `@objc` handler method per control;
home-made closure trampolines kept alive with `objc_setAssociatedObject`.

```bash
rg -n -e '\.target\s*=\s*self' -e '\.action\s*=\s*#selector' -e 'target:\s*self,\s*action:\s*#selector' \
      -e 'class \w*(Trampoline|ClosureTarget|BlockTarget)' -e 'objc_setAssociatedObject'
```

```swift
openMenuItem.primaryAction = NSAction { [weak self] _ in self?.openSelection() }
refreshButton.addAction(NSAction(identifier: NSAction.Identifier("refresh")) { [weak self] _ in self?.refresh() })
refreshButton.removeAction(identifiedBy: NSAction.Identifier("refresh"))
```

`NSAction` is a class, as `UIAction` is. Subclass it to carry state the handler needs:
`MyAction(handler:)` returns a `MyAction`, and a subclass with an initializer of its own calls
`super.init(identifier:handler:)`.

Available on `NSControl`, `NSMenuItem` and `NSToolbarItem`. Objective-C: `+actionWithHandler:`,
`+actionWithIdentifier:handler:`, `-initWithIdentifier:handler:`, `-addAction:`, `-removeAction:`,
`-removeActionForIdentifier:`, `primaryAction`.

### Per control event — `addAction(_:for:)` (0.7.0+)

**Replaces**: a second target kept alongside `target` / `action`; a closure trampoline per
`mouseDown(with:)` / `mouseUp(with:)` override, just to react to a control being pressed or released.

```bash
rg -n -e 'override func mouse(Down|Up)\(with' -e 'addTarget\(.*for:' -e '\.sendAction\(.*to:'
```

```swift
slider.addAction(NSAction(identifier: NSAction.Identifier("preview")) { [weak self] _ in self?.updatePreview() },
                 for: .trackingEndedInside)
slider.removeAction(identifiedBy: NSAction.Identifier("preview"), for: .trackingEndedInside)

if #available(macOS 27, *) {
    button.addAction(NSAction { [weak self] _ in self?.save() }, for: .primaryActionTriggered)
}

button.enumerateEventHandlers { action, targetAction, events, stop in /* … */ }
button.sendActions(for: NSControl.Events(rawValue: 1 << 24))   // the .applicationReserved range
```

`UIControl`'s whole event-handler API, with its Swift names: `addAction(_:for:)`, `removeAction(_:for:)`,
`removeAction(identifiedBy:for:)`, `allTargets`, `allControlEvents`, `actions(forTarget:forControlEvent:)`,
`enumerateEventHandlers(_:)`, `sendAction(_:)` (override it to observe or suppress), `sendActions(for:)`.
It shares one table with AppKit's `addTarget(_:action:for:)`, and builds against SDKs older than macOS 27
too. Objective-C: `-addAction:forControlEvents:`, `-removeAction:forControlEvents:`,
`-removeActionForIdentifier:forControlEvents:`, `allTargets`, `allControlEvents`,
`-actionsForTarget:forControlEvent:`, `-enumerateEventHandlers:`, `-sendAction:`,
`-sendActionsForControlEvents:`.

**Adopting**: move the extra targets and the press / release trampolines onto control events; keep the
control's own `target` / `action` (or `addAction(_:)`) for its primary action.

**Adopting**: delete the `@objc` handler methods and trampolines. Actions sent up the responder chain
— nil-targeted menu items such as `copy:` and `undo:`, and items enabled through `validateMenuItem(_:)`
— stay target/action.

## Button styling — `NSButton.Configuration`

**Replaces**: imperative styling spread across `bezelStyle`, `setButtonType`, `isBordered`,
`bezelColor`, `contentTintColor`, `imagePosition`, `attributedTitle`, `alternateTitle` /
`alternateImage`; `NSButtonCell` subclasses restyling on press.

```bash
rg -n -e '\.bezelStyle\s*=' -e 'setButtonType\(' -e '\.bezelColor\s*=' -e '\.imagePosition\s*=' \
      -e '\.alternate(Title|Image)\s*=' -e 'class \w+\s*:\s*NSButtonCell'
```

```swift
var configuration = NSButton.Configuration.push()
configuration.title = "Save"
configuration.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
saveButton.configuration = configuration

saveButton.configurationUpdateHandler = { button in
    var updatedConfiguration = button.configuration
    updatedConfiguration?.title = button.isHighlighted ? "Saving…" : "Save"
    button.configuration = updatedConfiguration
}
```

Styles: `.push()`, `.flexiblePush()`, `.toolbar()`, `.accessoryBar()`, `.accessoryBarAction()`,
`.smallSquare()`, `.badge()`, `.checkbox()`, `.radio()`, `.disclosure()`, `.pushDisclosure()`,
`.circular()`, `.help()`, `.togglePush()`, `.toggleToolbar()`, `.automatic()` (macOS 14),
`.glass()` (macOS 26). Also `automaticallyUpdatesConfiguration`, `setNeedsUpdateConfiguration()`.
Objective-C: `+pushButtonConfiguration` and the other `+…Configuration` styles,
`-updatedConfigurationForButton:`.

**Adopting**: move the scattered styling into one configuration, and state-dependent styling into
`configurationUpdateHandler`; delete the `NSButtonCell` subclasses that existed for press styling.

## Calendars — `NSCalendarView`

A month calendar with single-date, multi-date and week-of-year selection and per-day decorations.

**Replaces**: `NSDatePicker` in calendar style used to pick days; hand-built day grids for
multi-selection, week selection or per-day markers.

```bash
rg -n -e 'clockAndCalendar' -e 'NSClockAndCalendarDatePickerStyle'
```

```swift
let calendarView = NSCalendarView()
calendarView.calendar = Calendar(identifier: .gregorian)
calendarView.selectionBehavior = NSCalendarSelectionSingleDate(delegate: self)   // or MultiDate, WeekOfYear
calendarView.delegate = self
calendarView.wantsDateDecorations = true

func calendarView(_ calendarView: NSCalendarView, decorationFor dateComponents: DateComponents) -> NSCalendarViewDecoration? {
    hasEvents(on: dateComponents) ? .color(.systemRed, size: .small) : nil
}
```

Selections arrive as `DateComponents` through the selection behaviour's delegate.

## Device information — `NSDevice`

**Replaces**: `sysctlbyname("hw.model")` and friends, IOKit queries for the serial number or the
battery, `Host.current()`.

```bash
rg -n -e 'sysctlbyname\("hw\.' -e 'machdep\.cpu\.brand_string' -e 'IOPlatformSerialNumber|IOPlatformExpertDevice' \
      -e 'AppleSmartBattery|IOPSCopyPowerSourcesInfo' -e 'Host\.current\(\)'
```

```swift
let device = NSDevice.current
let summary = "\(device.marketingName) (\(device.modelIdentifier)), \(device.processorName)"
if device.isBatteryAvailable { showBattery(level: device.batteryLevel, state: device.batteryState) }
```

Also `serialNumber`, `systemVersion`, `physicalMemory`, `batteryHealth`, `batteryCycleCount`,
`thermalState`, `diskAvailableCapacity`, `deviceSymbolName`.

## Key codes — `NSEvent.key`, `NSVirtualKey`

**Replaces**: comparing `event.keyCode` with numbers or Carbon `kVK_…` constants.

```bash
rg -n -e 'keyCode\s*==\s*[0-9]' -e 'kVK_' -e 'Carbon\.HIToolbox'
```

```swift
override func keyDown(with event: NSEvent) {
    guard let key = event.key else { return super.keyDown(with: event) }
    switch key.keyCode {
    case .keyEscape: cancelOperation(nil)
    case .keyReturnOrEnter: confirm()
    default: super.keyDown(with: event)
    }
}
```

`NSKey` also carries `characters`, `charactersIgnoringModifiers` and `modifierFlags`.

**Adopting**: delete the Carbon import and the numeric constants.
