# Navigation and Windows

A navigation stack with bars, view-controller transitions, a drawer that replaces `NSDrawer`, open and
save panel configurations, and the document launch window.

## Navigation stack — `NSNavigationController`

Push and pop with an animated transition, a navigation bar with a back button, a bottom toolbar, and
trackpad swipe-back. Any `NSViewController` can be a page, `NSHostingController` included.

**Replaces**: a hand-rolled stack of child view controllers switched with
`transition(from:to:options:)`; a tabless `NSTabView` or an `NSPageController` used for drill-down; a
custom header view with a `chevron.backward` back button and a title label; swipe-back built on
`scrollWheel` + `trackSwipeEvent`.

```bash
rg -n -e 'transition\(from:[^)]*to:[^)]*options:' -e 'transitionFromViewController:toViewController:options:' \
      -e 'NSPageController' -e 'selectTabViewItem' -e 'trackSwipeEvent' -e 'chevron\.(backward|left)'
```

```swift
let libraryPage = LibraryViewController()
libraryPage.navigationItem.title = "Library"
libraryPage.navigationItem.trailingBarButtonItems = [
    NSBarButtonItem(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!,
                    style: .plain, target: self, action: #selector(addItem(_:))),
]
libraryPage.toolbarItems = [
    NSBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(edit(_:))),
    NSBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
    NSBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(share(_:))),
]

let navigationController = NSNavigationController(rootViewController: libraryPage)
navigationController.delegate = self
addChild(navigationController)
containerView.addSubview(navigationController.view)

navigationController.pushViewController(DetailViewController(), animated: true)
navigationController.popViewController(animated: true)
```

The bars float over the page and are part of its safe area (0.7.0+): lay content out against
`view.safeAreaLayoutGuide`, and a scroll view that keeps `automaticallyAdjustsContentInsets` starts
below the navigation bar and scrolls under it — no inset code. A document view in such a scroll view
starts at its top only when it or the clip view is flipped; `NSScrollViewController` takes care of that.

A page can name the view that takes keyboard focus when it appears, and finish loading before its
transition starts:

```swift
final class DetailViewController: NSViewController {
    override var preferredFirstResponder: NSResponder? { tableView }   // already so for NSTableViewController

    override func prepareForTransition(withContext context: (any NSViewControllerContextTransitioning)?,
                                       completion: @escaping () -> Void) {
        loadContent { completion() }
    }
}
```

Also: `setViewControllers(_:animated:)`, `popToRootViewController(animated:)`,
`setNavigationBarHidden(_:animated:)`, `navigationItem.leadingBarButtonItems`, and the delegate's
`navigationController(_:didShow:)`,
`navigationController(_:shouldBeginInteractivePopFrom:to:)` and
`navigationController(_:animationControllerFor:from:to:)`.

Objective-C: `-initWithRootViewController:`, `-pushViewController:animated:`,
`-popViewControllerAnimated:`, `-setViewControllers:animated:`; on `NSViewController`:
`navigationController`, `navigationItem`, `toolbarItems`, `preferredFirstResponder`,
`-prepareForTransitionWithContext:completion:`.

**Adopting**: delete the child-controller juggling, the header view with its back button and the
swipe tracking. Rename the app's own view-controller properties that already use a name the
navigation API now provides (`navigationController`, `navigationItem`, `toolbarItems`, `toolbar`,
`accessory`).

## Zoom transition — `preferredTransition` (0.22.0+)

iOS 18's zoom: set on a page, it makes `NSNavigationController` grow the page out of a view on the page
underneath when pushing it, and shrink it back into that view when popping it. On the zoomed page the
user can go back with the trackpad — two fingers toward the trailing edge or downward, or pinching in —
and the page follows the fingers. Same spelling as UIKit's.

**Replaces**: snapshot views animated between a grid item and a pushed page; a navigation delegate
returning a hand-written zoom or hero animator; trackpad tracking that shrinks the page back.

```bash
rg -n -e 'animationControllerFor' -e 'snapshotView|cacheDisplay\(in' -e 'magnify\(with' -e 'hero'
```

```swift
detailPage.preferredTransition = .zoom { context in
    let detail = context.zoomedViewController as! DetailViewController
    return gridPage.cellView(for: detail.itemIdentifier)   // asked again when the pop starts
}
navigationController.pushViewController(detailPage, animated: true)

// Line a part of the page up with the cell, and keep the trackpad dismissal off while editing.
let options = NSViewController.Transition.ZoomOptions()
options.alignmentRectProvider = { context in (context.zoomedViewController as? DetailViewController)?.heroFrame }
options.interactiveDismissShouldBegin = { _ in !detailPage.isEditing }
detailPage.preferredTransition = .zoom(options: options) { _ in gridPage.selectedCellView }
```

The page's zoom comes before the navigation delegate, which is not asked for an animation or
interaction controller for that push or pop. The trackpad dismissal is turned off only through
`interactiveDismissShouldBegin` — not `interactivePopGestureRecognizer`. A push or pop that is not
animated does not zoom.

Objective-C: `+[NSViewControllerTransition zoomWithOptions:sourceViewProvider:]`,
`NSZoomTransitionOptions`, `NSViewController.preferredTransition`.

**Adopting**: delete the delegate's zoom animator and the snapshot code; set `preferredTransition` on
the page before pushing it and return the cell from the provider.

## Transitions — `NSNavigationParallaxTransition` and the transition controllers

**Replaces**: hand-written `NSViewControllerPresentationAnimator`s that slide a view controller in,
and custom slide code inside container controllers.

```bash
rg -n -e 'NSViewControllerPresentationAnimator' -e 'animatePresentation\(of' -e 'animateDismissal\(of'
```

```swift
// A push-style transition within one pane, without a navigation stack.
present(detailViewController, animator: NSNavigationParallaxTransition())
dismiss(detailViewController)

// The macOS App Store's variant.
present(detailViewController, animator: NSNavigationParallaxTransition.appStoreStyle())
```

Inside a navigation stack the controller animates push and pop itself, with UXKit's parallax, which
also follows the trackpad swipe back. A page can prefer one of the navigation controller's other
transitions (0.22.0+); it pushes and pops with it, and the delegate is not asked:

```swift
detailPage.preferredTransition = .navigationParallax   // UIKit's look
// also .appStoreParallax, .slide, .zoomingCrossfade, and .parallax (the default)
navigationController.pushViewController(detailPage, animated: true)
```

Objective-C: `+[NSViewControllerTransition navigationParallaxTransition]` and its siblings.

For an animation of your own, return an `NSViewControllerAnimatedTransitioning` from
`navigationController(_:animationControllerFor:from:to:)` for pages without a preferred transition:
it implements `transitionDuration(using:)` and `animateTransition(using:)`, reads the two controllers
with `viewController(forKey: .from)` / `.to`, and ends with `completeTransition(_:)`.

**Adopting**: a delegate that only returned `NSNavigationParallaxTransitionController` (removed in 0.20.0) or a
hand-written UIKit-style slide becomes `preferredTransition = .navigationParallax` on the pages; keep a
genuinely custom animator's code inside `animateTransition(using:)`.

### A custom animator that follows a gesture — `NSPercentDrivenInteractiveTransition` (0.24.0+)

**Replaces**: gesture handlers that move the pages frame by frame for a custom push or pop and then animate the
rest by hand; custom transitions that can only run on their own.

Return `NSPercentDrivenInteractiveTransition` from the delegate while a gesture drives the transition, and feed
it the gesture's progress. It works with an unchanged `animateTransition(using:)` that uses `NSView.animate`;
`interruptibleAnimator(using:)` gives it an `NSViewPropertyAnimator` to scrub instead, which also keeps the
animator's own timing for the finish.

```swift
final class NavigationDelegate: NSObject, NSNavigationControllerDelegate {
    let interactor = NSPercentDrivenInteractiveTransition()
    var gestureIsDriving = false

    func navigationController(_ navigationController: NSNavigationController,
                              animationControllerFor operation: NSNavigationTransitionOperation,
                              from fromViewController: NSViewController,
                              to toViewController: NSViewController) -> NSViewControllerAnimatedTransitioning? {
        SlideAnimator(operation: operation)
    }

    func navigationController(_ navigationController: NSNavigationController,
                              interactionControllerFor animationController: NSViewControllerAnimatedTransitioning)
        -> NSViewControllerInteractiveTransitioning? {
        gestureIsDriving ? interactor : nil
    }
}

// In the gesture handler:
//   began:   delegate.gestureIsDriving = true; navigationController.popViewController(animated: true)
//   changed: delegate.interactor.update(progress)
//   ended:   progress > 0.5 ? delegate.interactor.finish() : delegate.interactor.cancel()
//            delegate.gestureIsDriving = false
```

Only plain and spring `NSView.animate` calls that `animateTransition(using:)` makes itself are scrubbed; keyframe
and transition animations, `NSAnimationContext` groups and Core Animation run on their own. Alongside animations
registered with the coordinator before the gesture starts move with it, and `isInterruptible` tells them apart.
The finish runs over the rest of the duration divided by `completionSpeed`, on `timingCurve`, a set
`completionCurve`, or a critically damped spring. A finish or cancel made while a page still prepares
(`prepareForTransition(withContext:completion:)`) is applied when the transition starts; one made with no
transition waiting does nothing.

## Custom presentation — `presentAsCustom(_:)` and `NSPresentationController` (0.24.0+)

**Replaces**: a card, panel or overlay added over the window's content by hand — with its own dimming view, a view
that swallows clicks underneath and focus moved in and back — and hand-written `NSViewControllerPresentationAnimator`s
that do the same; UIKit code that presents with `modalPresentationStyle = .custom` and a transitioning delegate.

```bash
rg -n -e 'NSViewControllerPresentationAnimator' -e 'addSubview\(.*(overlay|dimming|card)' -i
```

UIKit's custom presentation, presented the way AppKit presents a sheet: `presentAsCustom(_:)` sits beside
`presentAsSheet(_:)`, AppKit records the presentation (`presentingViewController`, `presentedViewControllers`), and
`dismiss(_:)` / `dismiss(_ sender:)` dismiss it. The presented view controller's `transitioningDelegate` supplies an
`NSPresentationController` and the animators, with UIKit's method names.

```swift
final class CardTransitioningDelegate: NSObject, NSViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: NSViewController, presenting: NSViewController?,
                                source: NSViewController) -> NSPresentationController? {
        CardPresentationController(presentedViewController: presented, presenting: presenting)
    }
    func animationController(forPresented presented: NSViewController, presenting: NSViewController,
                             source: NSViewController) -> (any NSViewControllerAnimatedTransitioning)? {
        CardAnimator(isPresenting: true)    // adds view(forKey: .to) to containerView at finalFrame(for:)
    }
    func animationController(forDismissed dismissed: NSViewController) -> (any NSViewControllerAnimatedTransitioning)? {
        CardAnimator(isPresenting: false)   // animates view(forKey: .from) away
    }
}

final class CardPresentationController: NSPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds.insetBy(dx: 80, dy: 60) ?? .zero
    }
    override func presentationTransitionWillBegin() {
        // add a dimming view to containerView; fade it with presentedViewController.transitionCoordinator
    }
}

card.transitioningDelegate = cardTransitioningDelegate   // weak; keep it alive
presentAsCustom(card)
dismiss(card)
```

- With no delegate the presented view fills the window's content view and cross-fades in and out.
- The container covers the window's content view; `shouldPresentInFullscreen` returning `false` covers only the
  presenting view controller's view — one pane of a split view, say.
- `interactionControllerForDismissal(using:)` can return an `NSPercentDrivenInteractiveTransition` for a dismissal that
  follows a gesture; a cancelled one leaves the presentation as it was.
- A dismissal that slides the presented view out of sight moves its layer with an explicit Core Animation animation and
  leaves the frame where it is: AppKit stops drawing a view whose frame lies wholly outside a view that clips (split
  views and the window frame do), so a frame animated past the edge loses its text on the way out. A percent-driven
  interaction drives only `NSView.animate` frame changes; to make such a slide follow a gesture, return an interaction
  controller of your own that pauses the container's layer time (`speed = 0`) and sets `timeOffset` from the gesture.
- While a dismissal runs, AppKit has already cleared `presentingViewController`; `presentationController` and its
  `presentingViewController` stay set until it ends.
- Closing the window dismisses the presentation without animation.

### A presentation that leaves the rest usable — `containerIgnoresMouseEvents` (0.24.0+)

**Replaces**: an inline banner or toast added over an editor by hand — a view laid on top whose `hitTest(_:)` is
overridden to let clicks through, and code that keeps or puts back the editor's focus.

```swift
final class BannerPresentationController: NSPresentationController {
    override init(presentedViewController: NSViewController, presenting: NSViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presenting)
        containerIgnoresMouseEvents = true      // clicks, drags, scrolling outside the banner reach the editor
    }
    override var shouldPresentInFullscreen: Bool { false }           // cover only the editor
    override var frameOfPresentedViewInContainerView: CGRect { /* top centre */ }
}

editorViewController.presentAsCustom(banner)                       // several at once stack
```

- Only what lands on the container itself passes; the presented view and views the presentation controller adds
  (a dimming view) still take clicks.
- No transition blocks input, and keyboard focus stays where it is.

## Drawers — `NSModernDrawer`

`NSDrawer`'s command set on a modern child window, with configurable effect, shape and animation.

**Replaces**: `NSDrawer` (deprecated since macOS 10.13) and `NSDrawerDelegate`.

```bash
rg -n -e '\bNSDrawer\b' -e 'NSDrawerDelegate' -e 'drawer(Should|Will|Did)(Open|Close)' -e 'NSDrawer(Will|Did)(Open|Close)Notification'
rg -n '<drawer ' -g '*.xib'
```

| `NSDrawer` | `NSModernDrawer` |
|---|---|
| `init(contentSize:preferredEdge:)` | same, or `init(contentSize:preferredEdge:configuration:)` |
| `parentWindow`, `contentView`, `open()`, `open(on:)`, `close()`, `toggle(_:)`, `edge`, `contentSize`, `minContentSize`, `maxContentSize`, `leadingOffset`, `trailingOffset` | same names |
| `state` (`Int`) | `state` (`NSModernDrawerState`: `.closed`, `.opening`, `.open`, `.closing`) |
| `drawerShouldOpen(_:)`, `drawerShouldClose(_:)`, `drawerWillResizeContents(_:to:)` | `modernDrawerShouldOpen(_:)`, `modernDrawerShouldClose(_:)`, `modernDrawer(_:willResizeContentsTo:)` |
| `drawerWillOpen(_:)` and the other notification methods | `modernDrawerWillOpen(_:)` and so on |
| `NSDrawer.willOpenNotification` and the others | `NSModernDrawer.willOpenNotification` and so on |
| `window.drawers` | `window.modernDrawers`, `window.firstModernDrawer(on:)` |

```swift
let configuration = NSModernDrawerConfiguration.inspector()     // .default(), .sidebar(), .hud(), .glass()
configuration.acceptsKeyEvents = true                            // for drawers with text fields
let drawer = NSModernDrawer(contentSize: NSSize(width: 240, height: 400), preferredEdge: .maxX,
                            configuration: configuration)
drawer.contentView = inspectorView
drawer.delegate = self
drawer.parentWindow = window
self.inspectorDrawer = drawer
drawer.open(on: .maxX)
```

`open(on:completion:)` and `close(completion:)` report when the animation ends; `async` forms exist
too. Objective-C: `+defaultConfiguration`, `+inspectorConfiguration` and the other presets,
`-initWithContentSize:preferredEdge:configuration:`.

**Adopting**: rename per the table, keep the drawer in a stored property, and move drawers defined
in a nib into code.

## Open and save panels — `NSOpenPanel.Configuration` (0.24.0+)

A panel's settings as a value you keep, copy and compare, with presets for the common tasks.
`makePanel()` creates a panel with them; `apply(to:)` writes them to a panel you already have.

**Replaces**: an `NSOpenPanel` or `NSSavePanel` configured property by property at every place it is
shown.

```bash
rg -n -e 'NSOpenPanel\(\)' -e 'NSSavePanel\(\)' -e 'openPanel\]' -e 'savePanel\]' -e '\.(canChooseDirectories|canChooseFiles|allowedContentTypes|nameFieldStringValue|canCreateDirectories) = '
```

| Task | Preset |
|---|---|
| File > Open…, several documents | `NSOpenPanel.Configuration.documents(contentTypes:)` |
| one file to import or attach | `.file(contentTypes:)` |
| one folder | `.folder()` |
| files and folders together | `.filesAndFolders(contentTypes:)` |
| an application | `.application()` |
| save a document of one type | `NSSavePanel.Configuration.document(contentType:)` |
| export in one of several formats | `.export(contentTypes:)` — the format pop-up needs macOS 15 |

```swift
// Before
let panel = NSOpenPanel()
panel.canChooseDirectories = true
panel.canChooseFiles = false
panel.directoryURL = projectURL
panel.message = "Choose the folder to export to."

// After
var configuration = NSOpenPanel.Configuration.folder()
configuration.directoryURL = projectURL
configuration.message = "Choose the folder to export to."
let panel = configuration.makePanel()
if await panel.beginSheetModal(for: window) == .OK, let folderURL = panel.url { … }
```

Keep a configuration shown in several places as a static property, and set what changes per use — the
file name, the starting folder — on a copy. The settings keep AppKit's names. A `nil` setting, and
`showsHiddenFiles = false`, leaves the panel's own value, so a configuration can be applied after other
setup, and an `identifier` still restores the folder the user last used. The configuration sets
`canChooseFiles` and `canChooseDirectories` itself, after the allowed types: set
`canChooseDirectories = true` when the allowed types include folders. The panel's `delegate` and
`accessoryView` are set on the panel after `makePanel()`. Objective-C: `NSOpenPanelConfiguration` and
`NSSavePanelConfiguration`, `+folderConfiguration` and the other presets, `-makePanel`,
`-applyToPanel:`.

**Adopting**: move each panel's fixed settings into a configuration, delete the property-by-property
setup, and present the panel `makePanel()` returns exactly as before.

## Document launch window — `NSDocumentController.launchOptions`

An Xcode-style welcome window for document-based apps — shown at launch and whenever no document is
open, closed when one opens — plus a view controller bound to one document.

**Replaces**: a welcome-window controller shown from `applicationDidFinishLaunching` together with
`applicationShouldOpenUntitledFile` returning `false`; an `NSDocumentController` subclass
overriding `openUntitledDocumentAndDisplay` or `newDocument` for that purpose; a recent-documents list
built from `recentDocumentURLs`; `makeWindowControllers` code that wires the window title and undo
manager by hand.

```bash
rg -n -e 'applicationShouldOpenUntitledFile|applicationOpenUntitledFile' -e 'recentDocumentURLs' \
      -e '[Ww]elcome\w*(Window|Controller)' -e 'openUntitledDocumentAndDisplay' -e 'override func newDocument'
```

```swift
func applicationWillFinishLaunching(_ notification: Notification) {
    let launchOptions = NSDocumentController.LaunchOptions()
    launchOptions.title = "My App"
    launchOptions.primaryAction = NSDocumentLaunchAction(
        title: "New Document", subtitle: nil,
        image: NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil)
    ) { _ in NSDocumentController.shared.newDocument(nil) }
    launchOptions.secondaryAction = NSDocumentLaunchAction(title: "Open…", image: nil) { _ in
        NSDocumentController.shared.openDocument(nil)
    }
    NSDocumentController.launchOptions = launchOptions
}

final class TextDocument: NSDocument {
    override func makeWindowControllers() {
        addWindowController(NSDocumentWindowController(documentViewController: TextViewController(document: self)))
    }
}

final class TextViewController: NSDocumentViewController {
    override func documentDidOpen() {
        super.documentDidOpen()
        // fill the UI from the document
    }
}
```

`NSDocumentViewController` keeps the window title and represented URL in step with the document and
answers `undoManager` with the document's. Objective-C: `+[NSDocumentController setLaunchOptions:]`,
`NSDocumentControllerLaunchOptions`, `-[NSDocumentWindowController initWithDocumentViewController:]`.

**Adopting**: set the launch options in `applicationWillFinishLaunching`, then delete the welcome
window controller, the `applicationShouldOpenUntitledFile` override and the `NSDocumentController`
overrides that existed only for it. Code that created a blank document by calling
`openUntitledDocumentAndDisplay(_:)` calls `newDocument(nil)` instead.

## Debugging the responder chain — `NSResponderDebugPanel` (0.24.0+)

A floating panel that shows how AppKit routes events and actions in the app, and never becomes the key or the main
window, so showing it and clicking it leave the key window and its first responder as they were. Use it in place of
`po [[NSApp keyWindow] firstResponder]` and hand-written `nextResponder` or `nextKeyView` walks.

```swift
// A Debug menu item, or a breakpoint action: `expr NSResponderDebugPanel.shared.orderFront(nil)`
@objc func toggleResponderDebugPanel(_ sender: Any?) {
    let panel = NSResponderDebugPanel.shared
    if panel.isVisible { panel.orderOut(sender) } else { panel.orderFront(sender) }
}

// Trace an action no main menu item sends — a toolbar item's or a button's with a nil target
NSResponderDebugPanel.shared.actionSelector = #selector(MyEditor.formatDocument(_:))
```

Its three sections:

- **Chain** — the key window, the main window and the first responder, then every object AppKit asks for a nil-targeted
  action in AppKit's order — the key window's chain with the window's delegate, window controller, content view
  controller and document, the main window's chain, `NSApp` and its delegate, the shared document controller — with
  the handler of the chosen action marked and the target `targetForAction(_:to:from:)` resolves. The pop-up lists the
  main menu's nil-target actions; `actionSelector` traces any other.
- **Key View Loop** — the views Tab visits from the first responder, with the reason each skipped view is passed over
  (hidden, refuses first responder, needs Full Keyboard Access).
- **Under Mouse** — the view a click at the pointer would hit and its superviews, outlined in its window.

The `⋯` menu writes each section to the console. Objective-C: `NSResponderDebugPanel.sharedPanel`,
`sharedPanelExists`, `actionSelector`. Check `sharedPanelExists` instead of reading `shared` where merely asking must
not create the panel.
