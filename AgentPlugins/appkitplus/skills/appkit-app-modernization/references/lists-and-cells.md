# Lists and Cells

Data sources, cell registration, and the configuration system that styles cells, rows, section
headers and collection items. The pieces compose: a diffable data source's cell provider dequeues
through a registration, and the registration's handler sets a content and a background
configuration.

## Outline views — `NSOutlineViewDiffableDataSource`

**Replaces**: an `NSOutlineViewDataSource` walking a hand-kept node tree; `reloadData()`,
`reloadItem(_:reloadChildren:)` or hand-computed `insertItems(at:inParent:)` / `removeItems` /
`moveItem` after model changes; `NSTreeController` with bindings; lazy loading in
`outlineViewItemWillExpand`; hand-written drag reordering (`pasteboardWriterForItem` /
`validateDrop` / `acceptDrop`).

```bash
rg -n -e 'NSOutlineViewDataSource' -e 'numberOfChildrenOfItem' -e 'isItemExpandable' -e 'NSTreeController' \
      -e '(insertItems|removeItems|moveItem)\(at:.*inParent' -e '(insert|remove)ItemsAtIndexes:.*inParent' \
      -e 'pasteboardWriterForItem' -e 'validateDrop.*proposedItem' -e 'outlineViewItemWillExpand'
```

```swift
struct FileNode: Hashable, Sendable {
    let id: UUID
    let name: String
    let isDirectory: Bool
}

final class FilesViewController: NSViewController {
    let outlineView = NSOutlineView()
    private var dataSource: NSOutlineViewDiffableDataSource<FileNode>!

    private lazy var cellRegistration = NSOutlineView.CellRegistration<NSTableCellView, FileNode> { cell, _, _, node in
        var content = cell.defaultContentConfiguration()
        content.text = node.name
        content.image = NSImage(systemSymbolName: node.isDirectory ? "folder" : "doc", accessibilityDescription: nil)
        cell.contentConfiguration = content
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = NSOutlineViewDiffableDataSource<FileNode>(outlineView: outlineView) { [unowned self] outlineView, column, row, node in
            outlineView.dequeueConfiguredReusableCellView(using: cellRegistration, ofColumn: column, forRow: row, item: node)
        }

        var sectionSnapshotHandlers = NSOutlineViewDiffableDataSource<FileNode>.SectionSnapshotHandlers()
        sectionSnapshotHandlers.shouldExpandItem = { node in node.isDirectory }
        sectionSnapshotHandlers.snapshotForExpandingParent = { parent, currentChildren in
            guard currentChildren.items.isEmpty else { return currentChildren }
            var loadedChildren = NSDiffableDataSourceSectionSnapshot<FileNode>()
            loadedChildren.append(loadChildren(of: parent))
            return loadedChildren
        }
        dataSource.sectionSnapshotHandlers = sectionSnapshotHandlers

        var reorderingHandlers = NSOutlineViewDiffableDataSource<FileNode>.ReorderingHandlers()
        reorderingHandlers.canReorderItem = { _ in true }
        reorderingHandlers.didReorder = { movedNode in /* write the move back to the model */ }
        dataSource.reorderingHandlers = reorderingHandlers
    }

    func show(root: FileNode, children: [FileNode]) {
        var snapshot = NSDiffableDataSourceSectionSnapshot<FileNode>()
        snapshot.append([root])
        snapshot.append(children, to: root)
        snapshot.expand([root])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
```

Reading back: `itemIdentifier(forRow:)`, `itemIdentifier(forOutlineViewItem:)`, `row(forItemIdentifier:)`,
`snapshot()`. `applySnapshotUsingReloadData(_:)` reloads without diffing. `rowViewProvider` supplies
row views.

**Sections** — `NSOutlineViewDiffableSectionDataSource<Section, Item>(outlineView:cellProvider:)`.
Apply an `NSDiffableDataSourceSnapshot<Section, Item>` for the section order, then one section
snapshot per section with `apply(_:to:animatingDifferences:)`; read one back with
`snapshot(for:)`. `sectionHeaderViewProvider = { outlineView, row, section in … }` builds the header
rows. Its `ReorderingHandlers` pass an `NSDiffableDataSourceTransaction<Section, Item>`.

Objective-C: `-initWithOutlineView:cellProvider:`, `-applySnapshot:animatingDifferences:completion:`,
`-applySnapshot:toSection:animatingDifferences:`, `-applySnapshotUsingReloadData:`,
`-snapshotForSection:`, `sectionSnapshotHandlers`, `reorderingHandlers`, `rowViewProvider`,
`sectionHeaderViewProvider`.

**Adopting**

- Delete the `NSOutlineViewDataSource` conformance and its methods. Keep your `NSOutlineViewDelegate`
  and assign it to `outlineView.delegate` as before, in any order; the cell provider replaces
  `outlineView(_:viewFor:item:)`.
- Every mutation of the model becomes "build a snapshot, apply it". Expansion lives in the snapshot
  (`expand` / `collapse`); lazy children move into `snapshotForExpandingParent`.
- Item identifiers must be unique across the whole tree. Use distinct types for sections and items.
- Hand-written reordering moves into `reorderingHandlers`; `didReorder` is where the model is updated.
- Keep the data source in a stored property.

## Tables — `NSTableViewDiffableReorderableDataSource`

AppKit's `NSTableViewDiffableDataSource` plus drag-and-drop reordering and column sorting. Switching
to it is a type-name change: it has every member of AppKit's class.

**Replaces**: `NSTableViewDataSource` with `numberOfRows(in:)`; hand-written reordering
(`pasteboardWriterForRow` + `validateDrop` + `acceptDrop` + `moveRow(at:to:)`); your own
`tableView(_:sortDescriptorsDidChange:)`; a subclass of AppKit's diffable data source adding those
methods.

```bash
rg -n -e 'NSTableViewDataSource' -e 'numberOfRows\(in' -e 'pasteboardWriterForRow' -e 'acceptDrop.*dropOperation' \
      -e 'moveRow\(at' -e 'moveRowAtIndex:' -e 'sortDescriptorsDidChange' -e 'NSTableViewDiffableDataSource<'
```

```swift
private var dataSource: NSTableViewDiffableReorderableDataSource<Section, Contact>!

dataSource = NSTableViewDiffableReorderableDataSource<Section, Contact>(tableView: tableView) { [unowned self] tableView, column, row, contact in
    tableView.dequeueConfiguredReusableCellView(using: cellRegistration, ofColumn: column, forRow: row, item: contact)
}

var reorderingHandlers = NSTableViewDiffableReorderableDataSource<Section, Contact>.ReorderingHandlers()
reorderingHandlers.canReorderItem = { _ in true }
reorderingHandlers.didReorder = { transaction in /* update the model from transaction.difference */ }
dataSource.reorderingHandlers = reorderingHandlers

dataSource.sortDescriptorsDidChange = { [unowned self] tableView, oldDescriptors in
    applySorted(by: tableView.sortDescriptors)
}
dataSource.apply(snapshot, animatingDifferences: true)
```

Objective-C: `reorderingHandlers`, `sortDescriptorsDidChangeHandler`,
`-applySnapshotUsingReloadData:completion:`.

**Adopting**: delete the drag and sort data source methods; the reorder handlers receive the
before/after snapshots and a per-section transaction. To also accept drops from elsewhere, subclass
and call `super` first.

## Browsers — `NSViewBasedBrowser` + `NSBrowserDiffableDataSource`

Rows that are real `NSView`s, the way Finder's column view has them, fed by a snapshot.

**Replaces**: `NSBrowserDelegate` (item-based or matrix-based), custom `NSBrowserCell` drawing, and
`loadColumnZero()` / `reloadColumn(_:)` after model changes.

```bash
rg -n -e 'NSBrowserDelegate' -e 'NSBrowserCell' -e 'willDisplayCell.*atRow' -e 'numberOfRowsInColumn' \
      -e 'isLeafItem' -e 'loadColumnZero' -e 'reloadColumn'
```

```swift
let browser = NSViewBasedBrowser()
private var dataSource: NSBrowserDiffableDataSource<FileNode>!

dataSource = NSBrowserDiffableDataSource<FileNode>(browser: browser) { browser, _, column, node in
    let rowView = (browser as? NSViewBasedBrowser)?
        .makeView(withIdentifier: NSUserInterfaceItemIdentifier("Row"), owner: nil, inColumn: column) as? NSTableCellView
        ?? NSTableCellView()
    var content = rowView.defaultContentConfiguration()
    content.text = node.name
    rowView.contentConfiguration = content
    return rowView
}
dataSource.delegate = self                      // your NSBrowserDelegate callbacks arrive here
dataSource.leafItemProvider = { node in !node.isDirectory }
browser.rowHeight = 28
dataSource.apply(snapshot, animatingDifferences: false)
```

Objective-C: `-initWithBrowser:cellProvider:`, `delegate`, `leafItemProvider`, `rowViewProvider`,
`branchViewProvider`, `headerViewControllerProvider`, `previewViewControllerProvider`,
`-itemIdentifierAtRow:inColumn:`, `-indexPathForItemIdentifier:`;
`-[NSViewBasedBrowser makeViewWithIdentifier:owner:inColumn:]`.

**Adopting**: replace the `NSBrowser` with `NSViewBasedBrowser`, delete the item / matrix delegate
methods, and route the delegate methods you keep through `dataSource.delegate`.

## List and scroll view controllers — `NSTableViewController` and friends (0.7.0+)

`UITableViewController` and `UICollectionViewController` for AppKit, plus outline and browser
counterparts. Each builds the scroll view, the list view and its column, makes itself the `dataSource`
and `delegate` before `viewDidLoad`, and hands keyboard focus to the list when an
`NSNavigationController` shows the page.

**Replaces**: `loadView` / `viewDidLoad` code that creates an `NSScrollView`, a table or outline view, an
`NSTableColumn` (and `outlineTableColumn`), sets `headerView = nil`, `documentView`, `dataSource` and
`delegate`; `override var preferredFirstResponder: NSResponder? { tableView }`; an `NSStackView` form
in a scroll view with width constraints, a flipped wrapper or flipped `NSClipView` subclass, and inset
bookkeeping.

```swift
final class LibraryViewController: NSOutlineViewController {
    private var dataSource: NSOutlineViewDiffableDataSource<LibraryItem>!

    init() { super.init(style: .sourceList) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func viewDidLoad() {
        super.viewDidLoad()
        outlineView.floatsGroupRows = false
        dataSource = NSOutlineViewDiffableDataSource(outlineView: outlineView) { outlineView, column, row, item in
            outlineView.dequeueConfiguredReusableCellView(using: self.cellRegistration, ofColumn: column,
                                                          forRow: row, item: item)
        }
    }

    // Delegate methods are overrides, as in a UITableViewController subclass.
    override func outlineViewSelectionDidChange(_ notification: Notification) { … }
}

let gallery = NSCollectionViewController(collectionViewLayout: compositionalLayout)
let browserPage = NSBrowserViewController()        // an NSViewBasedBrowser in the safe area
let settingsPage = NSScrollViewController(documentView: settingsStackView)
```

- `NSTableViewController(style:)` / `NSOutlineViewController(style:)` — one column that follows the
  table's width, no header; `.automatic` becomes a source list inside a sidebar. Add columns or a header
  in `viewDidLoad`.
- `NSCollectionViewController(collectionViewLayout:)` — selectable; a flow layout when built with `init()`.
- `NSBrowserViewController` — configure `titled`, `maxVisibleColumns` and the rest in `viewDidLoad`, then
  install the `NSBrowserDiffableDataSource`.
- `NSScrollViewController<DocumentView>` — `scrollDirection` (`NSCollectionView.ScrollDirection`) picks the
  axis; an Auto Layout document view is kept as wide as what is visible and at least as tall.
- Subclass with a custom list class through `class var tableViewClass` / `collectionViewClass` /
  `browserClass`; a nib or storyboard connects the `tableView` / `outlineView` / `collectionView` /
  `browser` / `scrollView` outlet.

Objective-C: `-initWithStyle:`, `-initWithCollectionViewLayout:`, `-initWithDocumentView:`, `tableView`,
`outlineView`, `collectionView`, `browser`, `scrollView`, `documentView`, `+tableViewClass`.

**Adopting**: make the controller the subclass of the matching class, delete the hand-built scroll view,
column and wiring, and keep the data source and cell configuration in `viewDidLoad`.

## Cell and item registration

**Replaces**: `NSUserInterfaceItemIdentifier` constants; `register(_:forIdentifier:)` followed by
`makeView(withIdentifier:owner:) as? MyCell`; `register(_:forItemWithIdentifier:)` followed by
`makeItem(withIdentifier:for:) as! MyItem`.

```bash
rg -n -e 'makeItem\(withIdentifier:' -e 'forItemWithIdentifier:' -e 'register\([^)]*forIdentifier:' \
      -e 'NSUserInterfaceItemIdentifier\(' -e 'makeView\(withIdentifier:[^)]*\)\s*as[!?]'
rg -n -e 'makeItemWithIdentifier:forIndexPath:|registerClass:forItemWithIdentifier:|registerNib:forIdentifier:|makeViewWithIdentifier:owner:'
```

```swift
// Create each registration once and keep it in a stored property.
private lazy var cellRegistration = NSTableView.CellRegistration<NSTableCellView, Contact> { cell, column, row, contact in
    var content = cell.defaultContentConfiguration()
    content.text = contact.name
    cell.contentConfiguration = content
}
private lazy var rowRegistration = NSTableView.RowRegistration<NSTableRowView, Contact> { rowView, row, contact in }
private let itemRegistration = NSCollectionView.ItemRegistration<NSCollectionViewListItem, Photo> { item, indexPath, photo in
    var content = item.defaultContentConfiguration()
    content.text = photo.title
    item.contentConfiguration = content
}
private let headerRegistration = NSCollectionView.SupplementaryRegistration<NSView>(
    elementKind: NSCollectionView.elementKindSectionHeader) { view, kind, indexPath in }

// In a provider or a classic delegate method:
tableView.dequeueConfiguredReusableCellView(using: cellRegistration, ofColumn: column, forRow: row, item: contact)
tableView.dequeueConfiguredReusableRowView(using: rowRegistration, forRow: row, item: contact)
collectionView.dequeueConfiguredReusableItem(using: itemRegistration, for: indexPath, item: photo)
collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
```

`NSOutlineView` has the same three: `CellRegistration`, `RowRegistration`,
`SectionHeaderRegistration`. Nib-based forms: `init(cellNib:handler:)`, `init(rowNib:handler:)`,
`init(itemNib:handler:)`, `init(supplementaryNib:elementKind:handler:)`.

Objective-C: `+registrationWithCellClass:configurationHandler:` (and `…CellNib:`, `…RowClass:`,
`…SectionHeaderClass:`, `…ItemClass:`, `…SupplementaryClass:elementKind:`);
`-dequeueConfiguredReusableCellViewWithRegistration:ofColumn:forRow:item:`,
`-dequeueConfiguredReusableRowViewWithRegistration:forRow:item:`,
`-dequeueConfiguredReusableSectionHeaderViewWithRegistration:forRow:item:`,
`-dequeueConfiguredReusableItemWithRegistration:forIndexPath:item:`,
`-dequeueConfiguredReusableSupplementaryViewWithRegistration:forIndexPath:`.

**Adopting**: delete the identifier constants and `register` calls; configuration code moves from
`viewFor` into the handler. Registrations work in classic delegate methods too — a diffable data
source is not required.

## Cell content — `NSListContentConfiguration`

**Replaces**: `cell.textField?.stringValue = …` / `cell.imageView?.image = …` in `viewFor`; cell
subclasses that lay out their own title, subtitle and icon subviews.

```bash
rg -n -e '\.(textField|imageView)\??\.(stringValue|attributedStringValue|image)\s*=' \
      -e 'class \w+\s*:\s*NS(TableCellView|TableRowView)\b'
```

```swift
var content = cell.defaultContentConfiguration()        // .cell()
content.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: nil)
content.text = contact.name
content.secondaryText = contact.role
content.imageProperties.maximumSize = NSSize(width: 20, height: 20)
content.secondaryTextProperties.color = .secondaryLabelColor
cell.contentConfiguration = content
```

Styles: `.cell()` (text with secondary text below), `.valueCell()` (secondary text beside the text),
`.header()`, `.footer()`. Each takes its fonts, colours and symbol size from the table it sits in — the
table's row size and style — the way AppKit's own table cells do, and inside a source-list table each
takes the sidebar look by itself. For the sidebar look outside a table, set
`traitOverrides.tableViewStyle = .sourceList` on the host.

Properties: `image`, `imageProperties` (`preferredSymbolConfiguration`, `tintColor`, `cornerRadius`,
`maximumSize`, `reservedLayoutSize`), `text` / `attributedText` / `textProperties`, `secondaryText` /
`secondaryAttributedText` / `secondaryTextProperties`, `directionalLayoutMargins`,
`prefersSideBySideTextAndSecondaryText`, `imageToTextPadding`, `textToSecondaryTextHorizontalPadding`,
`textToSecondaryTextVerticalPadding`. Text properties: `font`, `color`, `colorTransformer`,
`alignment`, `lineBreakMode`, `numberOfLines`, `adjustsFontSizeToFitWidth`, `minimumScaleFactor`,
`transform`.

Outside a cell: `NSListContentView(configuration:)`, with `textLayoutGuide`,
`secondaryTextLayoutGuide` and `imageLayoutGuide` for aligning neighbours.

Custom content: a type conforming to `NSContentConfiguration` (`makeContentView()`,
`updated(for:)`) whose view conforms to `NSContentView` (`configuration`).

Objective-C: `+cellConfiguration` (and the other `+…Configuration` styles), `contentConfiguration`,
`-initWithConfiguration:`.

**Adopting**

- Use plain `NSTableCellView` (or a class-based registration) and delete the `textField` / `imageView`
  outlets and subviews the old cell carried. Your own extra subviews go into
  `configurationContentView`.
- Two-line styles need rows tall enough for two lines: `tableView.usesAutomaticRowHeights = true`,
  or `prefersSideBySideTextAndSecondaryText = true` to keep one line.
- In an `NSCollectionView`, set `collectionView.traitOverrides.tableViewStyle = .sourceList` (or
  another style) for list and sidebar looks; tables and outlines provide their style themselves.

## Backgrounds and state — `NSBackgroundConfiguration`, configuration state

Four hosts take a `contentConfiguration` and a `backgroundConfiguration` and re-resolve them from their
state: `NSTableCellView`, `NSTableRowView`, `NSTableSectionHeaderView`, and `NSCollectionViewItem` /
`NSCollectionViewListItem`.

**Replaces**: `drawSelection(in:)` / `drawBackground(in:)` overrides; restyling inside
`override var isSelected` / `highlightState` / `backgroundStyle` / `isEmphasized`; per-cell tracking
areas for hover; `reloadData(forRowIndexes:columnIndexes:)` just to restyle; row feedback for drops
(`drawDraggingDestinationFeedback(in:)`, `highlightState == .asDropTarget`).

```bash
rg -n -e 'override func draw(Background|Selection)\(in' -e 'override var (isSelected|highlightState|backgroundStyle|isEmphasized)\b' \
      -e 'NSTrackingArea\(|updateTrackingAreas' -e 'reloadData\(forRowIndexes' \
      -e 'drawDraggingDestinationFeedback|isTargetForDropOperation|asDropTarget'
```

```swift
// Closure form, set when the cell is configured.
cell.configurationUpdateHandler = { cell, state in
    var content = cell.defaultContentConfiguration().updated(for: state)
    content.text = item.title
    content.textProperties.font = .systemFont(ofSize: 13, weight: state.isSelected ? .semibold : .regular)
    cell.contentConfiguration = content

    var background = NSBackgroundConfiguration.listCell().updated(for: state)
    if state.isHovered && !state.isSelected { background.backgroundColor = .quaternaryLabelColor }
    if state.isTargeted { background.backgroundColor = .selectedContentBackgroundColor }
    cell.backgroundConfiguration = background
}

// Subclass form.
final class ProjectItem: NSCollectionViewListItem {
    var project: Project? { didSet { setNeedsUpdateConfiguration() } }

    override func updateConfiguration(using state: NSCollectionViewItemConfigurationState) {
        super.updateConfiguration(using: state)
        var content = defaultContentConfiguration().updated(for: state)
        content.text = project?.name
        contentConfiguration = content
    }
}

// A row view that paints its own hover and selection background.
final class HoverRowView: NSTableRowView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        selectionHighlightStyle = .none          // the background configuration draws selection instead
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration(using state: NSTableRowViewConfigurationState) {
        super.updateConfiguration(using: state)
        guard state.isHovered || state.isSelected else { backgroundConfiguration = nil; return }
        var background = NSBackgroundConfiguration.clear()
        background.backgroundColor = state.isSelected ? .selectedContentBackgroundColor : .quaternaryLabelColor
        background.cornerRadius = 8
        backgroundConfiguration = background
    }
}
```

Background styles: `.clear()`, `.listCell()`, `.listHeader()`, `.listFooter()`. Properties:
`backgroundColor`, `backgroundColorTransformer`, `cornerRadius`, `backgroundInsets`, `visualEffect`,
`image`, `customView`, `strokeColor`, `strokeWidth`, `strokeOutset`, `shadowProperties`.

State: every host's state has `isSelected`, `isHighlighted`, `isHovered`, `isDisabled`, `isFocused`,
`dropState` / `isTargeted`, `dragState`, `traitCollection`, and custom keys through a subscript. Row and
cell states add `isExpanded`, `isPreviousRowSelected`, `isNextRowSelected`, `isPinned`, `isSwiped`,
`isReordering` (cells also `isEditing`); section headers add `isExpanded`. Values your app knows
better — editing, reordering, dragging — go in by overriding `configurationState`:

```swift
override var configurationState: NSTableCellViewConfigurationState {
    var state = super.configurationState
    state.isEditing = isRenaming
    return state
}
```

Use `isTargeted` to ask "is this the drop target". Spring loading comes from an
`NSSpringLoadedInteraction` on the cell with `.continuousActivation` in its options (see
[interactions-and-controls](interactions-and-controls.md)).

Members on each host: `contentConfiguration`, `backgroundConfiguration`,
`defaultContentConfiguration()`, `configurationState`, `setNeedsUpdateConfiguration()`,
`updateConfiguration(using:)`, `configurationUpdateHandler`,
`automaticallyUpdatesContentConfiguration`, `automaticallyUpdatesBackgroundConfiguration`,
`configurationContentView`, `directionalLayoutMargins`. Objective-C:
`-updateConfigurationUsingState:`, `-setNeedsUpdateConfiguration`.

**Adopting**

- Build configurations inside the handler or `updateConfiguration(using:)` from
  `.updated(for: state)`, as above.
- Delete the `draw…` overrides, the state-driven `didSet` restyling, the per-cell tracking areas and
  the restyling reloads.
- Outline group headers that show their expansion state become a
  `NSOutlineView.SectionHeaderRegistration<NSTableSectionHeaderView, Section>` whose handler reads
  `state.isExpanded`.

## Accessories — `NSViewAccessory`

**Replaces**: controls hand-built into cells and items — an info button, a checkmark image, a count
label, a pop-up chevron, a leading status dot, a hover-revealed "…" button that rebuilds the row's
context menu by hand, an info button that shows a popover — and the tracking areas that show them on
hover.

```bash
rg -l 'class \w+\s*:\s*NS(TableCellView|CollectionViewItem|CollectionViewListItem)' \
  | xargs rg -n 'NSButton\(|NSPopUpButton\(|NSImageView\(|systemSymbolName: "(checkmark|info\.circle)'
```

```swift
tableView.menu = rowMenu                                                // the right-click menu
cell.accessories = [                                                    // leading → trailing
    .customView(configuration: .init(customView: statusDot, placement: .leading())),
    .label(text: "\(item.count)", options: .init(tintColor: .secondaryLabelColor)),
    .popUpMenu(priorityMenu),                                           // choose one value
    .actionMenu(displayed: .whenHovered),                               // "…" = the row's context menu
    .detail(displayed: .whenHovered, popover: { _ in InfoViewController(item: item) }),
    .checkmark(options: .init(isHidden: !item.isChosen, reservedLayoutWidth: .standard)),
]
cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
```

`.popUpMenu` is for choosing a value; `.actionMenu` is for commands. `.actionMenu` takes no menu: it
opens the menu a right-click on that row opens — the table's `menu` — with `clickedRow` /
`clickedColumn` naming the row, the right-click highlight ring, and the table's cleanup afterwards, so
a menu delegate written for right-clicks works unchanged. A row that needs its own menu sets it on
the cell view's `menu`. `.detail(popover:)` shows a popover anchored to the info button, sized to its
content (the view controller's `preferredContentSize`, else its view's fitting size — plain Auto
Layout content needs neither a frame nor a preferred size). The closure runs on every opening and
receives an `NSViewAccessory.PopoverPresentation`: set `behavior` (default `.transient`), `animates` or
`contentSize` there, and keep it to `close()` the popover from its content.
`.detail(displayed:options:actionHandler:)` stays for anything else, such as a sheet.

For an `NSCollectionViewListItem` set `item.accessories`. Placement relative to another accessory:
`.trailing(at: NSViewAccessory.Placement.position(after: .checkmark()))`. `reservedLayoutWidth`
lines the accessories up across rows.

Objective-C: `NSViewAccessoryDetail` (`actionHandler`, `popoverContentViewControllerProvider`, which
receives an `NSViewAccessoryPopoverPresentation`), `NSViewAccessoryCheckmark`,
`NSViewAccessoryPopUpMenu`, `NSViewAccessoryActionMenu`, `NSViewAccessoryLabel`,
`NSViewAccessoryCustomView`; `-[NSView setAccessories:]`.

**Adopting**: delete the hand-built controls and their constraints; the cell content moves aside for
the accessories on its own. Selection changes from a pop-up accessory arrive in
`selectedElementDidChangeHandler`. A "…" button that rebuilt the row's menu, or set up `clickedRow`
itself, becomes `.actionMenu` with the one menu kept on the table. Hover-only accessories stay on
screen while their menu or popover is open, and every clickable accessory is published as an
accessibility custom action of its cell — delete hand-written custom actions that duplicated them,
and keep only the cell's own (they are listed first).

## SwiftUI in cells — `NSHostingConfiguration` (macOS 13)

**Replaces**: an `NSHostingView(rootView:)` embedded in an `NSTableCellView` or
`NSCollectionViewItem`, pinned with constraints and updated through `rootView` on reuse.

```bash
rg -l 'class \w+\s*:\s*NS(TableCellView|CollectionViewItem)' | xargs rg -n 'NSHostingView\(rootView:|\.rootView\s*='
```

```swift
private lazy var registration = NSTableView.CellRegistration<NSTableCellView, Mailbox> { cell, _, _, mailbox in
    cell.configurationUpdateHandler = { cell, state in
        cell.contentConfiguration = NSHostingConfiguration {
            MailboxRow(mailbox: mailbox, isSelected: state.isSelected)
        }
        .margins(.horizontal, 8)
        .margins(.vertical, 4)
    }
}
tableView.usesAutomaticRowHeights = true
```

Modifiers: `.background { … }`, `.background(_:)` with a `ShapeStyle`, `.margins(_:_:)`,
`.minSize(width:height:)`. SwiftUI content reads the host's traits through
`EnvironmentValues.hostTraitCollection`, or through an `EnvironmentKey` that conforms to
`NSTraitBridgedEnvironmentKey`.

**Adopting**: delete the hosting view, its constraints and the reuse code; pass cell state into the
SwiftUI view as an input, as above.

## Empty and loading states — `NSContentUnavailableConfiguration`

**Replaces**: empty-state labels, stacks and images toggled with `isHidden = items.isEmpty`; spinner
overlays while loading; a "No Results" label tied to a search field.

```bash
rg -n -i -e '(empty|placeholder|noResults?|noContent)(State)?(View|Label)' -e '\.isHidden\s*=\s*!?\s*[\w.]+\.isEmpty'
```

```swift
final class LibraryViewController: NSViewController {
    var items: [Item] = [] { didSet { setNeedsUpdateContentUnavailableConfiguration() } }
    var isLoading = false { didSet { setNeedsUpdateContentUnavailableConfiguration() } }
    var query = "" { didSet { setNeedsUpdateContentUnavailableConfiguration() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsUpdateContentUnavailableConfiguration()
    }

    override var contentUnavailableConfigurationState: NSContentUnavailableConfigurationState {
        var state = super.contentUnavailableConfigurationState
        state.searchText = query
        return state
    }

    override func updateContentUnavailableConfiguration(using state: NSContentUnavailableConfigurationState) {
        if isLoading {
            contentUnavailableConfiguration = NSContentUnavailableConfiguration.loading()
        } else if items.isEmpty {
            var configuration = state.searchText?.isEmpty == false
                ? NSContentUnavailableConfiguration.search()
                : NSContentUnavailableConfiguration.empty()
            configuration.text = "No Items"
            configuration.secondaryText = "Add an item to get started."
            configuration.button = .push()
            configuration.button.title = "Add Item"
            configuration.buttonProperties.primaryAction = NSAction { [weak self] _ in self?.addItem() }
            contentUnavailableConfiguration = configuration
        } else {
            contentUnavailableConfiguration = nil
        }
    }
}
```

On macOS 14 and later, `@Observable` properties read inside
`updateContentUnavailableConfiguration(using:)` schedule the next update by themselves.

**One part of a window** — a list of search results, a sidebar — gets its own empty state from the same
members on that view: every `NSView` has `contentUnavailableConfiguration`,
`contentUnavailableConfigurationState`, `setNeedsUpdateContentUnavailableConfiguration()` and
`updateContentUnavailableConfiguration(using:)`, and the overlay covers that view only. For a list, use the
scroll view that holds it:

```swift
func showResults(_ results: [SearchResult]) {
    resultsScrollView.contentUnavailableConfiguration = results.isEmpty ? NSContentUnavailableConfiguration.search() : nil
}
```

`NSContentUnavailableView(configuration:)` is the view itself, for laying one out by hand.

An empty state written in SwiftUI is assigned the same way —
`contentUnavailableConfiguration = NSHostingConfiguration { EmptyLibraryView() }` — and so is a content
configuration of your own; its `updated(for:)` receives the `NSContentUnavailableConfigurationState`,
`searchText` included.

Objective-C: `+emptyConfiguration`, `+loadingConfiguration`, `+searchConfiguration`;
`contentUnavailableConfiguration`, `-setNeedsUpdateContentUnavailableConfiguration`,
`-updateContentUnavailableConfigurationUsingState:`.

**Adopting**: delete the overlay views and their `isHidden` toggling; each input that affects the
empty state calls `setNeedsUpdateContentUnavailableConfiguration()`.
