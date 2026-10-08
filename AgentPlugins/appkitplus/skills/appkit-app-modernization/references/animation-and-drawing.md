# Animation and Drawing

Block-based view animation, image and PDF renderers, UIKit-style path construction, and a
lightweight label.

## View animation — the `NSView.animate` family

All of `UIView`'s static animation API: duration and delay, both spring models, keyframes,
transitions, repeat, and the system delete animation.

**Replaces**: `NSAnimationContext.runAnimationGroup { … view.animator().alphaValue = … }` and
`beginGrouping` / `endGrouping`; `CABasicAnimation`, `CASpringAnimation` or `CAKeyframeAnimation`
added by hand to a view's backing layer; `CATransition` around `addSubview` / `removeFromSuperview`;
the legacy `NSViewAnimation` dictionaries; `view.animations = ["center": …]` opt-ins.

```bash
rg -n -e 'NSAnimationContext\.(runAnimationGroup|beginGrouping)' -e '\.animator\(\)' -e ' animator\]' \
      -e 'CA(Basic|Spring|Keyframe)Animation\(' -e 'CATransition\(\)' -e 'NSViewAnimation(\(|\.Key)' -e '\.animations\s*='
```

```swift
NSView.animate(withDuration: 0.25) { panelView.alphaValue = 0 }

NSView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
    panelView.frame.origin.y += 20
} completion: { finished in
    panelView.removeFromSuperview()
}

NSView.animate(withSpringDuration: 0.5, bounce: 0.3, initialSpringVelocity: 0, delay: 0,
               options: [.allowUserInteraction],
               animations: { cardView.center = targetPoint },
               completion: nil)

// Views placed by Auto Layout: change the constraints, then lay out inside the block.
NSView.animate(withDuration: 0.3) {
    trailingConstraint.constant = 24
    containerView.layoutSubtreeIfNeeded()
}

NSView.transition(from: oldView, to: newView, duration: 0.4,
                  options: [.transitionCrossDissolve], completion: nil)

NSView.animateKeyframes(withDuration: 1, delay: 0, options: []) {
    NSView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) { dotView.center = firstPoint }
    NSView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) { dotView.center = secondPoint }
}

NSView.performSystemAnimation(.delete, on: [rowView], options: [], animations: nil, completion: nil)
```

Pass `[]` for default options. `.allowUserInteraction` keeps the animated views clickable while
they move. Also: `NSView.performWithoutAnimation { … }`, `setAnimationsEnabled(_:)`,
`inheritedAnimationDuration`, `modifyAnimations(withRepeatCount:autoreverses:animations:)`,
`animate(withDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)`,
`transition(with:duration:options:animations:completion:)`. Honour Reduce Motion by checking
`traitCollection.reduceMotion == .on`.

Objective-C: `+animateWithDuration:animations:completion:`,
`+animateWithDuration:delay:options:animations:completion:`,
`+animateWithSpringDuration:bounce:initialSpringVelocity:delay:options:animations:completion:`,
`+transitionWithView:duration:options:animations:completion:`,
`+transitionFromView:toView:duration:options:completion:`,
`+animateKeyframesWithDuration:delay:options:animations:completion:`,
`+addKeyframeWithRelativeStartTime:relativeDuration:animations:`,
`+performSystemAnimation:onViews:options:animations:completion:`, `+performWithoutAnimation:`.

**Adopting**: replace the group or the hand-built `CAAnimation` with the matching call and delete any
`view.animations[key]` entries it relied on. `NSAnimationContext` groups whose purpose is to switch
off AppKit's own animations (table-view inserts and moves, split views) are not view animations —
leave them.

## Image and PDF rendering — `NSGraphicsImageRenderer`, `NSGraphicsPDFRenderer`

**Replaces**: `NSImage.lockFocus()` / `unlockFocus()`; `NSBitmapImageRep(bitmapDataPlanes:…)` with
`NSGraphicsContext(bitmapImageRep:)`; `CGContext(data:…)` bitmaps; `CGPDFContextCreate` /
`CGContext(consumer:mediaBox:)` with `beginPDFPage`; saving and swapping
`NSGraphicsContext.current` by hand.

```bash
rg -n -e 'lockFocus|unlockFocus' -e 'NSBitmapImageRep\(bitmapDataPlanes' -e 'NSGraphicsContext\(bitmapImageRep' \
      -e 'CGContext\(data:|CGBitmapContextCreate' -e 'CGPDFContextCreate|CGContext\(consumer:|beginPDFPage' \
      -e 'NSGraphicsContext\.current\s*='
```

```swift
let format = NSGraphicsImageRendererFormat.preferred()
format.scale = window?.backingScaleFactor ?? 2
let renderer = NSGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format)

let image = renderer.image { context in                  // origin at the top left, as in UIKit
    effectiveAppearance.performAsCurrentDrawingAppearance {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: context.format.bounds, xRadius: 12, yRadius: 12).fill()
    }
}
let pngData = renderer.pngData { context in context.fill(context.format.bounds) }
let jpegData = renderer.jpegData(withCompressionQuality: 0.9) { context in context.fill(context.format.bounds) }

let pdfRenderer = NSGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
let pdfData = pdfRenderer.pdfData { context in
    context.beginPage()
    reportTitle.draw(at: CGPoint(x: 72, y: 72))
}
try pdfRenderer.writePDF(to: fileURL) { context in context.beginPage() }
```

The context: `cgContext`, `format`, `fill(_:)`, `fill(_:blendMode:)`, `stroke(_:)`, `clip(to:)`,
`currentImage`; PDF pages add `beginPage(withBounds:pageInfo:)`, `setURL(_:for:)`,
`addDestination(withName:at:)`. `NSGraphicsPDFRendererFormat.documentInfo` sets the document
metadata. `NSGraphicsContext.push(_:)` / `pop()` replace manual current-context swapping.

Objective-C: `-initWithSize:format:`, `-imageWithActions:`, `-PNGDataWithActions:`,
`-JPEGDataWithCompressionQuality:actions:`, `+preferredFormat`, `-PDFDataWithActions:`,
`-writePDFToURL:withActions:error:`.

A renderer for another output subclasses `NSGraphicsRenderer` with the hooks in
`AppKitPlus.NSGraphicsRendererSubclass`, which `import AppKitPlus` does not include: override
`rendererContextClass()`, `context(with:)` and `prepare(_:with:)`, and draw through
`runDrawingActions(_:completionActions:)`.

**Adopting**: move the drawing into the actions block. Drawing code written for an unflipped
`lockFocus` context flips its y coordinates. Images meant to redraw themselves when the appearance or
backing scale changes stay on `NSImage(size:flipped:drawingHandler:)`.

## Path construction — UIKit-style `NSBezierPath`

**Replaces**: an app's own `extension NSBezierPath` supplying `addLine(to:)`, `addCurve`,
`addQuadCurve`, `addArc`, `apply(_:)` or `init(roundedRect:byRoundingCorners:cornerRadii:)`; arcs
converted between degrees and radians by hand; `windingRule = .evenOdd`.

```bash
rg -n -e 'extension NSBezierPath' -e 'func (addLine|addCurve|addQuadCurve|addArc)\(' -e 'byRoundingCorners' \
      -e 'appendArc\(withCenter' -e 'windingRule\s*='
```

```swift
let cardPath = NSBezierPath(roundedRect: bounds, cornerRadius: 12)          // continuous corners, as on iOS
let sheetPath = NSBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight],
                             cornerRadii: NSSize(width: 12, height: 12))
let arcPath = NSBezierPath(arcCenter: center, radius: 20, startAngle: 0, endAngle: .pi / 2, clockwise: true)

let shapePath = NSBezierPath()
shapePath.move(to: startPoint)
shapePath.addLine(to: middlePoint)
shapePath.addQuadCurve(to: endPoint, controlPoint: controlPoint)
shapePath.addArc(withCenter: center, radius: 8, startAngle: 0, endAngle: .pi, clockwise: true)
shapePath.apply(CGAffineTransform(translationX: 10, y: 10))
shapePath.usesEvenOddFillRule = true
shapePath.fill(with: .multiply, alpha: 0.5)
```

`NSRectCorner` names corners in the path's own coordinate space: `.topLeft` is `(minX, minY)`.
Objective-C reaches the same members through `compatibility` (AppKitPlus 0.6.0 and later; 0.5.0 had them
directly on `NSBezierPath`):

```objc
NSBezierPath *card = [NSBezierPath.compatibility bezierPathWithRoundedRect:bounds cornerRadius:12];
[path.compatibility addLineToPoint:point];
path.compatibility.usesEvenOddFillRule = YES;
```

The class side has the three factories (`bezierPathWithRoundedRect:cornerRadius:`,
`…byRoundingCorners:cornerRadii:`, `bezierPathWithArcCenter:…`); the instance side has `addLineToPoint:`,
`addCurveToPoint:…`, `addQuadCurveToPoint:controlPoint:`, `addArcWithCenter:…`, `appendPath:`,
`applyTransform:`, `usesEvenOddFillRule`, `fillWithBlendMode:alpha:`, `strokeWithBlendMode:alpha:`.

**Adopting**

- Delete the app's compatibility extension; its members are now the library's. **An Objective-C
  category (or `@objc` extension member) on `NSBezierPath` with these UIKit names must go in any case**:
  MapKit, PencilKit, AnnotationKit and five other system frameworks define the same selectors on
  `NSBezierPath`, and the first context menu of a process loads MapKit & co., whose category then takes
  those selectors over. A plain Swift extension (no `@objc`) is not affected, but duplicates the library's
  names and becomes ambiguous.
- The UIKit-style arc calls take radians and UIKit's `clockwise` (increasing angle). AppKit's own
  `appendArc(withCenter:radius:startAngle:endAngle:clockwise:)` takes degrees and the opposite
  `clockwise`. When switching an arc from one to the other, convert both the angles and the flag.

## Geometry helpers — `UIGeometry.h`

UIKit's geometry helpers under UIKit's names, with UIKit's output (0.6.0+): insetting a rectangle
by edge insets, string conversion for points, vectors, sizes, rectangles, affine transforms and both
edge-inset types, `NSValue` boxing, and keyed `NSCoder` coding.

**Replaces**: an app's own `extension CGRect` insetting by `NSEdgeInsets`; `extension NSEdgeInsets` /
`NSDirectionalEdgeInsets` adding `Equatable`, `Codable` or `.zero`; `NSStringFromCGRect`-style shims or
`#if os(iOS)` branches around them; `NSValue(bytes:objCType:)` or `getValue(_:size:)` for transforms;
transforms and insets archived as hand-built arrays or dictionaries.

```bash
rg -n -e 'extension (NSEdgeInsets|NSDirectionalEdgeInsets)' -e 'func inset\(by' -e 'NSStringFromCG|CG\w+FromString' \
      -e 'objCType:.*CGAffineTransform' -e 'encode.*(Transform|Insets)'
```

```swift
let contentRect = bounds.inset(by: NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))

let text = NSCoder.string(for: transform)                 // "[1, 0, 0, 1, 10, 20]"
let restored = NSCoder.cgAffineTransform(for: text)
let insets = NSCoder.nsEdgeInsets(for: "{8, 12, 8, 12}")

let boxed = NSValue(cgAffineTransform: transform)
let unboxed = boxed.cgAffineTransformValue

coder.encode(transform, forKey: "transform")
coder.encode(insets, forKey: "insets")
let decoded = coder.decodeCGAffineTransform(forKey: "transform")

if insets == .zero { … }                                  // NSEdgeInsets and NSDirectionalEdgeInsets are Equatable and Codable
```

Objective-C uses UIKit's spellings: `NSEdgeInsetsInsetRect`, `NSStringFromCGAffineTransform`,
`CGRectFromString`, `NSStringFromEdgeInsets` / `NSEdgeInsetsFromString` (UIKit's `…UIEdgeInsets…`),
`+[NSValue valueWithCGAffineTransform:]`, `-[NSCoder encodeCGAffineTransform:forKey:]`,
`-[NSCoder encodeEdgeInsets:forKey:]` (UIKit's `encodeUIEdgeInsets:`), and
`NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets`.

**Adopting**

- Delete the app's own `Equatable`, `Codable` and `.zero` for `NSEdgeInsets` / `NSDirectionalEdgeInsets`
  and its own `CGRect.inset(by:)`: they now duplicate the library's and make `==`, `.zero` and
  `inset(by:)` ambiguous. With UIFoundation, turn on its `AppKitPlus` trait instead of deleting —
  `UIFoundationToolbox` then drops its copy.
- The string format and the archive format are UIKit's, so strings and archives written on iOS read
  back unchanged. Code that parsed Foundation's `NSStringFromRect` output with `NSRectFromString`
  keeps working; `CGRectFromString` reads the same well-formed text.

## Labels — `NSLabel`

A `UILabel`-shaped read-only text view: `text`, `attributedText`, `font`, `textColor`,
`numberOfLines`, `lineBreakMode`, `adjustsFontSizeToFitWidth`, `minimumScaleFactor`, shadow.

**Replaces**: `NSTextField(labelWithString:)` in code ported from `UILabel` (including
`textRect(forBounds:limitedToNumberOfLines:)` / `drawText(in:)` overrides), and labels whose text has
to shrink to fit.

```bash
rg -n -e 'adjustsFontSizeToFitWidth|minimumScaleFactor' -e 'drawText\(in' -e 'textRect\(forBounds:.*limitedToNumberOfLines'
```

```swift
let titleLabel = NSLabel(frame: .zero)
titleLabel.text = title
titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
titleLabel.numberOfLines = 2
titleLabel.adjustsFontSizeToFitWidth = true
titleLabel.minimumScaleFactor = 0.7
titleLabel.preferredMaxLayoutWidth = 240
```

Labels that users select, copy or edit, and labels built in Interface Builder, stay `NSTextField`.
