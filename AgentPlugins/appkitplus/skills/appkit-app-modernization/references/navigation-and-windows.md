# Navigation and Windows

A navigation stack with bars, view-controller transitions, a drawer that replaces `NSDrawer`, and the
document launch window.

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
