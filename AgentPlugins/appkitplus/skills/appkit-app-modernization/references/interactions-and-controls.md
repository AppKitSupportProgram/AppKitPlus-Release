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

## Type to filter a menu — `NSMenu.filtersItemsWhileTyping` (0.16.0+)

Typing while a pop-up or context menu is open brings up a search field at the top of the menu, and the
menu keeps only the items with a word beginning with the typed text — the menus of Xcode's jump bar.

**Replaces**: a search field put into an `NSMenu` as a custom view item; key handling in a menu delegate
or a Carbon event handler that hides items as the user types; a `DVTFilteringMenu`-style subclass.

```bash
rg -n -e 'FilteringMenu' -e 'menuHasKeyEquivalent' -e 'GetMenuTrackingData' -e 'HIMenuGetContentView' -e '_handleCarbonEvents'
```

```swift
let menu = NSMenu()
menu.filtersItemsWhileTyping = true    // and on each submenu that should filter as well
```

Objective-C: `filtersItemsWhileTyping`. `NSPopUpPathControl` turns it on for every menu it opens.

**Adopting**: delete the search item and the key handling; leave the items as they are.

## Jump bars — `NSPopUpPathControl` (0.8.0+)

A path bar whose every component opens a menu of the items that could take its place, lined up under
the pointer, as in the jump bar of an Xcode editor. Rows with children open submenus that list them
when they open. Choosing a row selects it, tells the delegate and sends the control's action. Typing
in any of these menus filters it (0.16.0+).

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

**Popovers instead of menus** (0.18.0+): set `navigationPresentationStyle = .popover` and each
component shows its peers in a searchable `NSNavigationPopoverController` under it — what Xcode's jump bar
does under its navigation popover setting. A row whose item has children shows a chevron and pushes them
in, with a back button; `.singleLevelPopover` lists one level and selects whatever is chosen.
`preferredPopoverEdge` picks the side. `popUpPathControl(_:navigationPopoverItemFor:defaultNavigationPopoverItem:)`
changes a row, the way `menuItemFor:defaultMenuItem:` changes a menu row, and
`popUpPathControl(_:willPresent:for:)` hands over the controller before it shows — for footer rows, a
width, or rows loaded asynchronously with `insertItems(_:at:animated:)` while `expectsMoreItems` spins.
Objective-C: `-[NSPopUpPathControlDelegate popUpPathControl:willPresentNavigationPopoverController:forItem:]`.

**Adopting**: delete the per-click menu assembly and the breadcrumb rebuilding; let the model objects
adopt `NSPopUpPathItem`.

## Filter fields — `NSFilterSearchField`, `NSFilterTokenField` (0.9.0+)

The filter fields of Xcode's navigators and debug console. `NSFilterSearchField` is a search field with
a filter icon and filter toggle buttons at its trailing end; the whole field turns active while any
filter is on, and it shows a spinner or a match count. `NSFilterTokenField` turns `kind:error` into a
two-part token whose key opens a menu to change its type or comparison; with two or more tokens a
capsule on the filter icon switches between matching all and any; completions pop up as you type,
sectioned by type; the icon's menu keeps recent and sample filters; the whole filter saves to data and
comes back from it.

**Replaces**: an `NSSearchField` with toggle buttons or a progress indicator laid over it, a hand-drawn
"filter is on" background, a match count drawn beside the text; an `NSTokenField` whose delegate parses
`key:value` strings into model objects, draws its own tokens, builds a completion popover by hand, or
saves recent filters to user defaults.

```bash
rg -n -e 'NSSearchField' -e 'NSTokenField' -e 'searchMenuTemplate' -e 'representedObjectForEditingString' -e 'completionsForSubstring' -e 'tokenField\('
```

```swift
let searchField = NSFilterSearchField()
searchField.delegate = self                                   // menu(for:) gives the filter icon a menu
let recentButton = searchField.addFilterButton(
    with: NSImage(systemSymbolName: "clock", accessibilityDescription: nil)!,
    alternateImage: NSImage(systemSymbolName: "clock.fill", accessibilityDescription: nil),
    toolTip: "Show Only Recent Files",
    accessibilityLabel: "Recent Files")
recentButton.target = self
recentButton.action = #selector(toggleRecentFiles(_:))
searchField.progress = NSFilterFieldProgressIndeterminate     // while filtering in the background
searchField.numberOfMatches = matches.count                   // -1 hides it

let messageType = NSFilterTokenType(identifier: "message", title: "Message")
let kindType = NSFilterTokenType(identifier: "kind", title: "Kind")
let isType = NSFilterTokenComparisonType(identifier: "is", title: "is", exclusion: false)
let isNotType = NSFilterTokenComparisonType(identifier: "isNot", title: "is not", exclusion: true)
let tokenField = NSFilterTokenField()
tokenField.tokenTypes = [messageType, kindType]
tokenField.comparisonTypes = [isType, isNotType]
tokenField.defaultTokenType = messageType                     // free text becomes a Message token
tokenField.defaultComparisonType = isType
tokenField.recentFiltersEnabled = true
tokenField.delegate = self

func filterTokenFieldDidChangeFilter(_ tokenField: NSFilterTokenField) {
    applyFilter(tokens: tokenField.filterTokens, text: tokenField.editingString, combining: tokenField.globalOperator)
}

func filterTokenField(_ tokenField: NSFilterTokenField, completionsFor string: String) async -> [NSFilterToken]? {
    await messageIndex.completions(matching: string)
}

UserDefaults.standard.set(tokenField.encodedState, forKey: "consoleFilter")
try tokenField.restoreState(from: savedState)
```

Typing `kind:error` makes a `KIND error` token, `kind!:error` the excluding one, and the other words
join into a token of `defaultTokenType`; implement `filterTokenField(_:tokensFor:)` to parse text your
own way. Tokens are immutable values: set `filterTokens` to change them. The delegate hears each change
of the filter once — typed text after a 0.2-second pause. `operatorDisplayMode`, `defaultGlobalOperator`
and `globalOperatorThreshold` tune the all / any capsule; `sampleFilterTokens` and
`additionalIconMenuItems` fill the icon's menu; `presentsPopUpsAboveField = false` opens the completion
list and the menu below the field. Both fields have `addFilterButton(with:alternateImage:toolTip:accessibilityLabel:)`,
`progress`, `borderDisplayMode`, and take `drawsBackground` with `backgroundColor` as a fill of your own. Both take
every `controlSize`, `.mini` through `.extraLarge`, as `NSSearchField` does — the icon, the buttons, the tokens and the
completion list follow it, and the token field is as tall as a search field of the same size.
Objective-C: `-[NSFilterSearchFieldDelegate menuForFilterSearchField:]`,
`-[NSFilterTokenFieldDelegate filterTokenFieldDidChangeFilter:]`,
`-filterTokenField:completionsForString:completionHandler:`, `-filterTokenField:tokensForString:`,
`-filterTokenField:editingStringForToken:` (0.18.0+), `-[NSFilterTokenField restoreStateFromData:error:]`.

**Text tokens, as in Xcode's navigators** (0.18.0+): the Project navigator's filter turns typed text
into tokens whose key shows only a menu arrow, switching between Contains, Does Not Contain, Begins With
and Ends With, with Begins With drawn as `loo ⋯` and Ends With as `⋯ loo`. Give the field one type whose
`title` is empty and those four comparison types; `valuePrefix` / `valueSuffix` put the marks on the value.
A token whose comparison type is not among `comparisonTypes` — a wildcard pattern your parser makes — gets
no comparison items, and with no types to choose, no menu and no arrow. Parse `loo*` and `*loo` in
`filterTokenField(_:tokensFor:)`, and give each token back the text it parses from in
`filterTokenField(_:editingStringFor:)`: a double click, `stringValue`, VoiceOver and copied text all read
it. The navigators combine every token with AND, so set `operatorDisplayMode = .never`.

```swift
let textType = NSFilterTokenType(identifier: "text", title: "")         // the key shows only the arrow
let contains = NSFilterTokenComparisonType(identifier: "contains", title: "Contains", exclusion: false)
let doesNotContain = NSFilterTokenComparisonType(identifier: "doesNotContain", title: "Does Not Contain", exclusion: true)
let beginsWith = NSFilterTokenComparisonType(identifier: "beginsWith", title: "Begins With", exclusion: false,
                                             valuePrefix: nil, valueSuffix: "⋯")
let endsWith = NSFilterTokenComparisonType(identifier: "endsWith", title: "Ends With", exclusion: false,
                                           valuePrefix: "⋯", valueSuffix: nil)
navigatorField.tokenTypes = [textType]
navigatorField.comparisonTypes = [contains, doesNotContain, beginsWith, endsWith]
navigatorField.defaultTokenType = textType
navigatorField.defaultComparisonType = contains
navigatorField.operatorDisplayMode = .never

func filterTokenField(_ tokenField: NSFilterTokenField, editingStringFor token: NSFilterToken) -> String? {
    switch token.comparisonType {
    case beginsWith: token.value + "*"
    case endsWith: "*" + token.value
    default: nil                                                          // the field's own form
    }
}
```

**Adopting**: delete the overlay buttons, the background drawing and the match-count label; replace the
token field delegate's parsing, display strings and completion popover with token types and the two
delegate methods; drop hand-kept recent filters for `recentFiltersEnabled` and `encodedState`.

## Find fields with patterns — `NSFindPatternSearchField` (0.13.0+)

The find field of Xcode's find navigator. Besides text, the user inserts patterns — Digits, Any
Characters, Email Address, twelve in all — as capsules, with Control-Option-Command-P or an Insert
Pattern menu item; the field's content becomes a regular expression in which the text matches itself.
Paired with a replace field, a find token double-clicked into the replace field stands there for what it
matched, as a backreference.

**Upgrading from 0.12.0**: there the field was `NSSearchPatternField` (cell `NSSearchPatternFieldCell`),
the model `NSSearchPattern` and `NSSearchPatternComponents`, the content `searchPatternComponents`.
Rename each to the name used here; there are no aliases, and the pasteboard type changed with them.

**Replaces**: a search field whose text is escaped into an `NSRegularExpression` by hand; checkboxes or
a pop-up for "digits", "whitespace" or "any word" beside the field; a replace field where the user has to
type `$1`.

```bash
rg -n -e 'escapedPattern\(for' -e 'NSRegularExpression\(pattern' -e 'stringByReplacingMatches' -e 'withTemplate'
```

```swift
let findField = NSFindPatternSearchField()
let replaceField = NSFindPatternSearchField()
findField.replaceField = replaceField                       // replaceField.findField points back
findField.searchesImmediatelyAfterInsertingPattern = false  // search on Return only, as Xcode does
findField.allowsPatternInsertion = searchesText             // Xcode allows patterns in text queries only
findField.delegate = self                                   // menu(for:) supplies the magnifying glass's menu
findField.target = self
findField.action = #selector(find(_:))

func menu(for searchField: NSFilterSearchField) -> NSMenu? {
    let field = searchField as! NSFindPatternSearchField
    let menu = NSMenu()
    if field.allowsPatternInsertion {                       // Xcode leaves the item out rather than disable it
        menu.addItem(field.insertPatternMenuItem())
        menu.addItem(.separator())
    }
    for query in recentQueries {                            // property lists you keep yourself
        guard let components = NSFindPatternComponents(propertyListRepresentation: query) else { continue }
        let item = menu.addItem(withTitle: components.plainText, action: #selector(restoreQuery(_:)), keyEquivalent: "")
        item.attributedTitle = components.attributedString(font: menu.font, textColor: nil)  // tokens as in the field
        item.representedObject = query
    }
    return menu
}

@objc func find(_ sender: NSFindPatternSearchField) {
    let components: NSFindPatternComponents = sender.findPatternComponents   // not stringValue: tokens are U+FFFC there
    guard let expression = try? components.regularExpression(matchingType: .contains, caseSensitive: false) else { return }
    let template = replaceField.findPatternComponents.replacementTemplate(searchComponents: components)
    recentQueries.insert(components.propertyListRepresentation, at: 0)
    …
}

let custom = NSFindPattern(regularExpression: #"\d+(?:\.\d+)*"#, title: "Version Number", tokenTitle: "Version")
findField.patternGroups = NSFindPattern.standardPatternGroups + [[custom]]
for case .pattern(let pattern) in components.components { … }   // components is [.text(String) / .pattern(NSFindPattern)]
```

Text is escaped; each token of a pattern with backreferences is a capture group the first time it appears
and a backreference after that. `regularExpressionPattern(escapingText: false)` is for a field the user
types regular expression syntax into. A replace field's menu offers the patterns that have a
`replacementString` (Tab, Line Break) and the find field's tokens. The field edits in a TextKit 1 field
editor of its own, one per window, that copies and pastes tokens — also from Xcode's find field — so the
window delegate's `windowWillReturnFieldEditor(_:to:)` is not asked for it. The field is an
`NSFilterSearchField` with `usesFilterAppearance` off and no placeholder; it is active while it holds text
or tokens. With `allowsPatternInsertion` off the key equivalent and `insertPattern(_:)` insert nothing and
the menu item validates as disabled, while the tokens already in the field stay and pasting still works.
`NSSearchField`'s recent searches keep `stringValue` and lose the tokens — keep
`propertyListRepresentation` instead, and show a query with `attributedString(font:textColor:)`, which draws
its tokens as the field does. Objective-C: `-insertPattern:`, `-insertPatternMenuItem`,
`-regularExpressionWithMatchingType:caseSensitive:error:`, `-replacementTemplateWithSearchComponents:`,
`-attributedStringWithFont:textColor:`, `-[NSFindPattern patternWithIdentifier:]`.

**Adopting**: delete the escaping and the option checkboxes; read `findPatternComponents` where the code
read `stringValue`; store recent queries as property lists and title them with
`attributedString(font:textColor:)`; build the replacement template from the two fields instead of
letting the user type group numbers.

## Find bar — `NSFindInteraction`, `NSTextProvidingFindSession`, `NSTextSearchingFindSession` (0.14.0+)

AppKit's own find bar — Find, Find Next and Previous, Use Selection for Find, Replace and Replace All, every match
highlighted as the user types — for any view inside a scroll view, from one `addInteraction(_:)`, with no
`NSTextFinderClient` to write.

**Replaces**: an `NSTextFinder` kept by hand with its `client` and `findBarContainer` wiring;
`performTextFinderAction(_:)` / `performFindPanelAction(_:)` overrides that forward the sender's tag and the
`validateUserInterfaceItem(_:)` cases for them; `NSTextFinderClient` implementations — `string`,
`stringAtIndex(_:effectiveRange:endsWithSearchBoundary:)`, `stringLength`, `firstSelectedRange`,
`contentView(at:effectiveCharacterRange:)`, `rects(forCharacterRange:)`, `drawCharacters(in:forContentView:)` — and
the `noteClientStringWillChange()` calls around content changes.

```bash
rg -n -e 'NSTextFinder\b|NSTextFinderClient|performTextFinderAction|performFindPanelAction' \
      -e 'stringAtIndex|endsWithSearchBoundary|contentView\(at:|noteClientStringWillChange'
```

```swift
final class LogViewController: NSViewController, NSFindInteractionDelegate, NSTextProviding {
    @IBOutlet var tableView: NSTableView!
    var rows: [[String]] = []                                   // two columns
    private lazy var findSession = NSTextProvidingFindSession(textProvider: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.addInteraction(NSFindInteraction(sessionDelegate: self))
    }

    func findInteraction(_ interaction: NSFindInteraction, sessionFor view: NSView) -> NSFindSession? {
        findSession
    }

    var numberOfProvidedStrings: Int { rows.count * 2 }        // one string per cell

    func providedString(at stringIndex: Int) -> String {
        rows[stringIndex / 2][stringIndex % 2]
    }

    func viewForProvidedString(at stringIndex: Int) -> NSView? {
        let cellView = tableView.view(atColumn: stringIndex % 2, row: stringIndex / 2, makeIfNecessary: true)
        return (cellView as? NSTableCellView)?.textField      // a text field: rectangles are measured for you
    }

    var visibleProvidedStringIndexes: IndexSet {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        return IndexSet(integersIn: visibleRows.location * 2 ..< NSMaxRange(visibleRows) * 2)
    }

    func scrollRangeToVisible(_ range: NSProvidedTextRange) {
        tableView.scrollRowToVisible(range.stringIndex / 2)
    }

    func reload(_ newRows: [[String]]) {
        rows = newRows
        tableView.reloadData()
        findSession.noteProvidedTextChanged()
    }
}
```

Content that searches itself — millions of rows, pages loaded on demand, an existing search engine — adopts
`NSTextSearching` (UIKit's `UITextSearching`, with `NSTextRange`s whose `NSTextLocation`s it defines) and returns
`NSTextSearchingFindSession(searchableObject:)`; adopting `NSFoundTextLocating` as well lets the find bar mark the
matches itself, otherwise the content decorates them in `decorate(foundTextRange:document:usingStyle:)`.

Also: `presentFindNavigator(showingReplace:)`, `dismissFindNavigator()`, `findNext()`, `findPrevious()`,
`searchText`, `isFindNavigatorVisible` and `activeFindSession` on the interaction; `resultCount` and
`highlightedResultIndex` on a session; `NSFindInteraction.rects(forCharacterRange:in:)` for ranges in text fields;
`selectedProvidedTextRange`, `selectProvidedTextRange(_:)` and the replacement members on `NSTextProviding`.
Objective-C: `-[NSFindInteraction initWithSessionDelegate:]`, `-[NSTextProvidingFindSession initWithTextProvider:]`,
`-[NSTextSearchingFindSession initWithSearchableObject:]`.

**Adopting**: delete the text finder, its client, the two action overrides and their validation, and the
string-index bookkeeping behind `stringAtIndex`; keep the lookup that finds a row's text field. Report content
changes after they happen with `noteProvidedTextChanged()` instead of `noteClientStringWillChange()` before them.

## Filter bar — `NSFilterControlBar` (0.10.0+)

The bar at the bottom of an Xcode navigator: a filter field across the middle and buttons on either side
of it — pull-down menus, or buttons that send an action — sized together by one `controlSize`. Under the macOS 26 design, from macOS 27, at
`.large` and `.extraLarge` the field and each button sit on their own capsule of interactive Liquid Glass,
as in Xcode 27. The field is an `NSFilterSearchField` until you set another — an `NSFilterTokenField` or
any `NSTextField`.

**Replaces**: a hand-built bar under a sidebar or list — a search field and menu or action buttons laid out by
frame or constraints, the field's height and insets picked per control size; an `NSGlassEffectView`
wrapped around a search field, or around a pair of buttons, by hand.

```bash
rg -n -e 'NSGlassEffectView' -e 'pullsDown' -e 'pullDownButton' -e 'addBottomAlignedAccessoryViewController'
```

```swift
let optionsMenu = NSMenu(title: "Filter Options")
optionsMenu.addItem(withTitle: "", action: nil, keyEquivalent: "")   // item 0: the pull-down's face, not listed
optionsMenu.addItem(withTitle: "Show Only Recent Files", action: #selector(toggleRecentFiles(_:)), keyEquivalent: "")
let optionsItem = NSFilterControlBarItem(
    image: NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: nil),
    menu: optionsMenu)
optionsItem.toolTip = "Filter Options"
let clearItem = NSFilterControlBarItem(              // no menu: pressing it sends the action
    image: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil),
    target: self, action: #selector(clearFilter(_:)))
clearItem.toolTip = "Clear Filter"

let filterBar = NSFilterControlBar(frame: .zero)
filterBar.controlSize = .large                       // Xcode's navigators; glass from macOS 27
filterBar.leadingItems = [optionsItem]
filterBar.trailingItems = [clearItem]                // after the field
filterBar.filterField.target = self
filterBar.filterField.action = #selector(filterChanged(_:))

// Two buttons on one capsule of glass instead of a circle each (0.14.0+):
let recentItem = NSFilterControlBarItem(
    image: NSImage(systemSymbolName: "clock", accessibilityDescription: nil),
    target: self, action: #selector(toggleRecent(_:)))
let filterGroup = NSFilterControlBarItemGroup(subitems: [recentItem, clearItem])
filterGroup.title = "Filters"                        // what VoiceOver calls the group
filterBar.trailingItems = [filterGroup]

// At the bottom of a sidebar, with the list fading out under it as in Xcode:
let accessory = NSSplitViewItemAccessoryViewController()
accessory.view = filterBar
accessory.preferredScrollEdgeEffectStyle = .soft    // macOS 26.1
sidebarItem.addBottomAlignedAccessoryViewController(accessory)
```

Each `NSFilterControlBarItem` shows its `image` and pops its `menu` up when pressed as a pull-down
`NSPopUpButton` does (0.11.0+): below the button, or above it when there is no room below, and
without item 0, the pull-down's face — so start the menu with an empty item, or its first entry goes
missing. A menu of a single item performs that item instead. A symbol image is sized to the field's symbols and keeps its
hierarchical or palette colours (0.10.1+) — an item has no tint, so swap in an accent-coloured symbol
to show that a filter it controls is on. An item without a menu sends its `action` to its `target`, from
the bar's button — show a popover from the sender. Items lay out in array order — the first leading item outermost,
the first trailing item next to the field — and swap sides in a right-to-left layout. An
`NSFilterControlBarItemGroup` (0.14.0+) is an item too, put in either array: on glass its `subitems`
abut in one capsule, each as wide as a lone item's circle; off glass it looks exactly like its subitems
put in one by one. A group's `isEnabled = false` disables every subitem; its own image, menu, target,
action and tool tip are not used, and a group cannot hold another group. The bar sets the
field's `controlSize` and frame, and its own intrinsic height follows: 44 points at `.large` under the
macOS 26 design. While the field is on glass the bar keeps the filter field's background and border off;
configure everything else — target and action, delegate, filter buttons — on the field directly.
Objective-C: `-[NSFilterControlBarItem initWithImage:menu:]`, `-[NSFilterControlBarItem initWithImage:target:action:]`,
`-[NSFilterControlBarItemGroup initWithSubitems:]`, `NSFilterControlBar.filterField`.

**Adopting**: delete the hand-made bar view, its layout and per-size metrics, and any glass wrapped around
the field; move each menu button's menu, or each plain button's target and action, into an
`NSFilterControlBarItem`, and buttons that shared one piece of glass into an `NSFilterControlBarItemGroup`.
A pull-down `NSPopUpButton`'s menu already starts with its face; a menu popped up by hand needs one put in
front.

## Playback scrubbers — `NSPlaybackSlider` (0.18.0+)

The time slider of the Music app's full-screen player: a thin capsule with no knob, its elapsed part
drawn brighter and added onto the dark backdrop behind it. Pressing anywhere moves the value to the
pointer and grows the bar to the full height of the slider with a spring; dragging scrubs; letting go
shrinks it back. It is an `NSSlider` in every other respect — value, range, target and action,
bindings, the keyboard and accessibility work as for any slider.

**Replaces**: an `NSSlider` subclass or a custom `NSSliderCell` drawing a thin track; a knob hidden by
drawing over it, or through a private `hidesKnob`; a progress bar animated by hand to grow on mouse
down; a SwiftUI `Slider` with a custom style hosted in an AppKit window only for this look; an
`NSProgressIndicator` with a click recognizer standing in for a scrubber.

```bash
rg -n -e 'NSSliderCell' -e 'drawBar' -e 'drawKnob' -e 'hidesKnob' -e 'knobThickness' -e 'scrubb' -e 'NSProgressIndicator' -e 'SliderStyle'
```

```swift
let timeSlider = NSPlaybackSlider()          // 16 points tall, continuous, linear
timeSlider.minValue = 0
timeSlider.maxValue = duration
timeSlider.doubleValue = currentTime
timeSlider.target = self
timeSlider.action = #selector(scrub(_:))
timeSlider.scrubbingDelegate = self

// Stop following playback while the user drags; seek when they let go.
func playbackSliderDidBeginScrubbing(_ playbackSlider: NSPlaybackSlider) {
    isScrubbing = true
}

func playbackSliderDidEndScrubbing(_ playbackSlider: NSPlaybackSlider) {
    isScrubbing = false
    player.seek(to: playbackSlider.doubleValue)
}
```

Put it on a dark backdrop, as Music's player is. Its frame is its alignment rectangle, so time labels
6 points below the slider's `bottomAnchor` sit where Music puts them. Objective-C:
`-[NSPlaybackSliderDelegate playbackSliderDidBeginScrubbing:]`, `-playbackSliderDidEndScrubbing:`.

**Adopting**: delete the custom track drawing, the knob hiding and the press animation, and make the
slider an `NSPlaybackSlider` — in a nib, setting the slider's class is enough; its cell follows.

## Choosers in a popover — `NSNavigationPopoverController` (0.18.0+)

The searchable list Xcode's toolbar opens for its scheme and run destination: a transient popover with
a filter field on top that keeps the keyboard focus while Up Arrow, Down Arrow and Return work the
list. Rows carry icons, a key equivalent column and indentation, or are headers, separators and bold
headings that float as the list scrolls; footer rows sit under the list and are pinned to the bottom
when everything does not fit on the screen. Rows can arrive after the popover opened, with a spinner
by the filter field; a chosen row can keep the popover open with a spinner of its own while the work
finishes. Pressing on the anchor, dragging in and letting go chooses, as in a pop-up menu, and a row
can lead to more rows with a back button.

**Replaces**: an `NSTableView` and an `NSSearchField` in an `NSPopover` built by hand — the filtering,
the arrow keys forwarded from the field to the table, the hover selection, the sizing to the content;
an `NSMenu` with a search field in a custom `NSMenuItem.view`; a pop-up button whose menu is too long
to scan.

```bash
rg -n -e 'NSPopover' -e 'contentViewController' -e 'controlTextDidChange' -e 'doCommandBy' -e 'moveDown' -e 'NSMenuItem.*view'
```

```swift
let items = schemes.map { scheme -> NSNavigationPopoverItem in
    let item = NSNavigationPopoverItem(title: scheme.name)
    item.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
    item.representedObject = scheme
    return item
}
let chooser = NSNavigationPopoverController(items: items, footerItems: [manageItem], title: "Filter")
chooser.delegate = self
chooser.resizingBehavior = [.grows, .shrinks, .keepsTopStable]   // follow the filter, top edge still
chooser.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY, animated: true)

func navigationPopoverController(_ controller: NSNavigationPopoverController, didSelect item: NSNavigationPopoverItem) -> Bool {
    select(item.representedObject as! Scheme)
    return true                                              // close
}
```

Filtering keeps the rows whose title contains the typed text, ignoring case; implement
`navigationPopoverController(_:filterStringDidChange:)` and set `filteredItems` to filter yourself. Grow
the list while it is open with `insertItems(_:at:animated:)` and `expectsMoreItems`; keep it open after a
choice with `indicateMoreTimeNeededForSelectedItem()`; show the rows a row leads to with
`pushItems(_:footerItems:title:animated:)`, with `hierarchyStyle = .pushNavigation` set before showing for
the back button. Objective-C: `-showRelativeToRect:ofView:preferredEdge:animated:`,
`-[NSNavigationPopoverControllerDelegate navigationPopoverController:didSelectItem:]`.

**Adopting**: delete the hand-built table, field and popover glue — the arrow-key forwarding, the
hover tracking area, the size computation — and turn the model objects into items.

## Object graphs — `NSObjectGridGraph` (0.15.0+)

The graph view of Xcode's Debug Memory Graph. One object, the pivot, sits in the middle; the objects
referencing it fan out to the left a generation at a time, the objects it references to the right,
joined by right-angle arrows. Several references between the same two objects become one line with a
count badge that lists them. Buttons beside each node expand or collapse its neighbors; the view
pans, zooms and gives VoiceOver every node and line.

**Replaces**: a custom `NSView` that lays nodes out in columns and draws arrows with `CAShapeLayer` or
`NSBezierPath`; a web view running a JavaScript graph library; an outline view standing in for a graph.

```bash
rg -n -e 'CAShapeLayer' -e 'graphviz' -e 'dagre' -e 'cytoscape' -e 'WKWebView' -e 'class \w*Graph\w*View'
```

```swift
// Describe the graph by identifier: nodes by NSObjectGridGraph.NodeIdentifier, a structure wrapping a 32-bit integer
// (NodeIdentifier(8), .rawValue, and .none for no node), references by NSObjectGridGraph.ReferenceIdentifier, which
// wraps a 64-bit integer the same way. The graph asks only for the part it shows.
final class ReferenceGraphViewController: NSViewController, NSObjectGridGraphDataSource, NSObjectGridGraphDelegate {
    private let graph = NSObjectGridGraph()
    private let store: ReferenceStore   // your model
    // One image object for every node that looks alike: the graph draws a texture of up to a megabyte for each image
    // object it is given, and NSImage(systemSymbolName:accessibilityDescription:) makes a new one on every call.
    private let objectIcon = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: nil)

    init(store: ReferenceStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        graph.dataSource = self
        graph.delegate = self
        graph.gridCellSize = NSSize(width: 150, height: 100)   // Xcode's; the shorter side is 50 pt at zoom level 1
        view = graph
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // The graph frames itself from its size when the pivot is set: set the first one once it has a size.
        if graph.pivotNodeIdentifier == .none && !graph.bounds.isEmpty {
            graph.setPivotNodeIdentifier(store.rootIdentifier, maintainingCoordinates: nil)
        }
    }

    func objectGridGraph(_ graph: NSObjectGridGraph,
                         enumerateIncomingReferencesForNode node: NSObjectGridGraph.NodeIdentifier,
                         using block: (NSObjectGridGraph.ReferenceIdentifier, NSObjectGridGraph.NodeIdentifier,
                                       NSObjectGridGraph.NodeIdentifier, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for edge in store.edges(into: node) where !stop.boolValue {
            block(edge.identifier, edge.source, node, 0, &stop)
        }
    }

    func objectGridGraph(_ graph: NSObjectGridGraph,
                         enumerateOutgoingReferencesForNode node: NSObjectGridGraph.NodeIdentifier,
                         using block: (NSObjectGridGraph.ReferenceIdentifier, NSObjectGridGraph.NodeIdentifier,
                                       NSObjectGridGraph.NodeIdentifier, Double, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        for edge in store.edges(outOf: node) where !stop.boolValue {
            block(edge.identifier, node, edge.destination, 0, &stop)
        }
    }

    func objectGridGraph(_ graph: NSObjectGridGraph, willDisplay node: any NSObjectGridNode) {
        node.label = store.typeName(of: node.identifier)
        node.icon = objectIcon   // a symbol takes the label color
    }

    func objectGridGraph(_ graph: NSObjectGridGraph, willDisplay reference: any NSObjectGridReference) {
        reference.label = store.name(of: reference.identifier)
        reference.style = store.isWeak(reference.identifier) ? .light : .default
    }
}
```

The graph keeps no copy of your data: it asks again whenever it lays a node's neighbors out, so the
answers must stay the same until you set the pivot again — which is also how you show changed data
(`setPivotNodeIdentifier(graph.pivotNodeIdentifier, maintainingCoordinates: graph.selectedNode)` keeps
the selected node where it is). A double click makes a node the pivot, keeping it in place; implement
`objectGridGraph(_:didDoubleClick:)` to do something else. Other delegate methods: `didClick` /
`didCommandClick` for nodes and references, `contextMenuFor`, and two to hide the pivot frame and the
arrows pointing at an off-screen selection. Group nodes — Xcode's reference cycles — come from the
data source's `memberNodeCountForGroupNode` and `enumerateMemberNodesOfGroupNode`; report every reference
between a member and an object outside the group as a reference of the group's identifier, at both ends,
and only the references among members under the members' identifiers — the graph does not gather a group's
references from its members.

`layoutMode = .exploration` shows only some neighbors of an expanded node — the referrers on a path to
a root, and the first referenced nodes in your order — and turns the buttons beside a node into a
popover that lists every neighbor with a checkbox. Give it details through
`objectGridGraph(_:neighborDetailsForNodesWithIncomingEdges:toNode:)` and its outgoing twin (objects
adopting `NSObjectGridNeighborDetails`: `identifier`, optional `isOnPathToRoot` and `title`), and
columns through `objectGridGraph(_:filteringTableColumnsFor:showsIncomingEdges:)` — `NSTableColumn`s
whose `identifier` is a key path into your details.

Objective-C: `-objectGridGraph:enumerateIncomingReferencesForNode:usingBlock:`,
`-objectGridGraph:willDisplayNode:`, `-setPivotNodeIdentifier:maintainingCoordinates:`,
`NSObjectGridNodeIdentifierNone`.

**Adopting**: keep the model, drop the layout and drawing code; implement the two enumeration methods
and the two `willDisplay` methods, then set a pivot.

### Panning, zooming and shortcuts — `interactionConfiguration` (0.16.0+)

By default the graph behaves as Xcode's: two fingers on a trackpad pan, a mouse's scroll wheel zooms,
Shift makes scrolling zoom, pinching zooms, dragging pans, and the keyboard does nothing.
`interactionConfiguration` — a value type in Swift, so assigning through the property writes back —
changes each of these and adds keyboard shortcuts:

```swift
// Scrolling pans with a mouse too; Command and scroll zooms, as in a design tool.
graph.interactionConfiguration.scrollWheelAction = .pan
graph.interactionConfiguration.zoomingScrollModifierFlags = .command
graph.interactionConfiguration.zoomInShortcut = NSObjectGridGraph.KeyboardShortcut(keyEquivalent: "=", modifierFlags: .command)
graph.interactionConfiguration.zoomToFitShortcut = NSObjectGridGraph.KeyboardShortcut(keyEquivalent: "9", modifierFlags: .command)
graph.interactionConfiguration.returnToHomePivotShortcut = NSObjectGridGraph.KeyboardShortcut(keyEquivalent: "h", modifierFlags: [.command, .shift])
graph.interactionConfiguration.arrowKeyPanDistance = 40

graph.zoomToFit()          // every shown node in view, zooming in no further than the actual size
graph.returnToHomePivot()  // back to where you last laid the graph out afresh, framed as setting it did
```

The home pivot moves only when you lay the graph out afresh around another node —
`setPivotNodeIdentifier(_:maintainingCoordinates: nil)`. Setting the current pivot again (new data, a
`layoutMode` change) and moving while keeping a node in place (a "Focus on" menu item, like a double
click) leave it where it was.

Also there: `gestureScrollAction`, `panningScrollModifierFlags`, `scrollWheelLineScroll` (points per
line a wheel pans), `scrollZoomSensitivity`, `reversesScrollZoomDirection`, `allowsMagnification`,
`panningButtonMask`, `zoomOutShortcut`, `actualSizeShortcut`; `.none` as a scroll action passes the
scroll up the responder chain. Shortcuts match as menu key equivalents do and work only while the
graph is first responder: with any keyboard control configured, the graph takes the focus when
clicked and draws a focus ring (turn it off with `focusRingType = .none`); with none, it never takes
the focus, as Xcode's does.

**Replaces**: a `scrollWheel(with:)` override or local event monitor rewriting the graph's scroll
events; hidden menu items or a `keyDown(with:)` override sending zoom commands to the graph.

### Top to bottom — `layoutOrientation` (0.17.0+)

`layoutOrientation = .vertical` lays the graph out from the top down: the referrers in rows above the
pivot, the objects it references in rows below, each generation left to right in your order. Lines
leave a node under its label and come into the next one at the top of its icon. The default,
`.horizontal`, is Xcode's.

```swift
graph.gridCellSize = NSSize(width: 140, height: 175)   // taller than wide: a label and the line under it
graph.layoutOrientation = .vertical
```

`gridCellSize` still means the distance between columns × the distance between rows, so give a
vertical graph cells taller than wide: with Xcode's 150 × 100 the rows of a zoomed-out graph stand 6
points apart. Labels show in a vertical graph once rows are 100 points apart, against 70 across.
Changing the orientation lays the graph out again around the pivot, animated; what is expanded, the
selection, the home pivot and the zoom stay.

**Replaces**: a rotated layer or view turning a graph on its side; a hand-drawn tree or org chart
view for a top-down layout next to the graph.

### Expand and collapse everything — `expandAll(_:)`, `collapseAll(_:)` (0.17.0+)

`expandAll(.referencedNodes)` expands the objects the pivot references, then the ones they
reference, a generation at a time, until every object reachable that way is shown.
`collapseAll(.referencedNodes)` goes back to the pivot's own neighbors, each collapsed. Pass
`.referrers` for the other side, or both.

```swift
expandAllButton.addAction(NSAction { [weak self] _ in self?.graph.expandAll(.referencedNodes) })
collapseAllButton.addAction(NSAction { [weak self] _ in self?.graph.collapseAll(.referencedNodes) })
```

The graph is a tree drawn from the pivot, so expanding nodes one by one shows an object referenced
from several shown objects under each of them. Expanding all shows every object once instead, in its
place nearest the pivot, and leaves it off — with the line to it — under the other objects
referencing it: 600 libraries with 7,000 links between them show 600 nodes rather than 7,000, and
cycles end. An object whose neighbors are all shown elsewhere stays collapsed; one whose neighbors
are partly shown elsewhere shows the rest, and its button then opens the neighbor filtering popover
to add the others, as every node's does in exploration mode — Option-click collapses it. The view
stays where it is; call `zoomToFit()` to see the whole graph. In exploration mode each node shows,
of the neighbors its button shows at first, those shown nowhere else.

Thousands of nodes — a graph expanded by hand, or one with that many objects — stay responsive as
long as the icons are shared image objects (see the sample above). The icon set in `willDisplay`
is drawn once for all the places of a node; an image object made anew for every node is drawn once
for each.

**Replaces**: walking your model to expand the graph's nodes one at a time; an outline view standing
in for a graph to get Expand All.

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
battery, `IOPSCopyPowerSourcesInfo`, `Host.current()`.

```bash
rg -n -e 'sysctlbyname\("hw\.' -e 'machdep\.cpu\.brand_string' -e 'IOPlatformSerialNumber|IOPlatformExpertDevice' \
      -e 'AppleSmartBattery|IOPSCopyPowerSourcesInfo' -e 'Host\.current\(\)'
```

`NSDevice.current` hands out readings grouped by area (0.18.0+): `model`, `system`, `processor`,
`memory`, `storage`, and `battery`, which is nil on a Mac without one. Each reading is immutable and read at
one moment; `model` and `processor` are read once per process, the others again on every access.

```swift
let device = NSDevice.current
let summary = "\(device.model.marketingName) (\(device.model.identifier)), \(device.processor.name)"
if let battery = device.battery {
    showBattery(level: battery.level, state: battery.state, health: battery.health)
    if battery.isChargingPaused { explainPause(battery.chargingPauseReason) }  // .chargeLimit, .optimizedCharging
}
```

`battery.state` means what `UIDevice.batteryState` means: plugged in and not full is `.charging`, also while
the system holds the battery at a charge limit, which `isChargingPaused` and `chargingPauseReason` report.
The battery also has `cycleCount`, `designCapacity` and `fullChargeCapacity` (mAh), `temperature`, `voltage`,
`amperage`, `timeToEmpty`, `timeToFullCharge` and `adapterWattage`; `system` has `version`, `computerName`,
`uptime` and `thermalState`; `model` has `serialNumber`, `icon` and `symbolName`; `processor` has
`performanceCoreCount` and `efficiencyCoreCount`.

Up to 0.17.0 these were flat properties on `NSDevice` itself (`modelIdentifier`, `batteryLevel`,
`batteryHealth`, `thermalState`, `diskAvailableCapacity`, …).

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
