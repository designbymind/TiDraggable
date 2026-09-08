# TiDraggable - Native Draggable Views

An enhanced fork of the original [TiDraggable](https://github.com/pec1985/TiDraggable) module by [Pedro](http://twitter.com/pecdev) [Enrique](https://github.com/pec1985), allows for simple creation of "draggable" views.

## Enhancements & Fixes

- Improved drag performance for iOS and Android.
- Updated public APIs for more seamless integration.
- Removed the InfiniteScroll class as it doesn't really have much to do with the overall module.
- Removed unnecessary APIs to reduce overall module footprint.
- Removed unused variables and organized imports.
- Added ability to unset boundaries.
- Mapped the missing `cancel` gesture to the `end` gesture (firing the respective event).
- Added `ensureRight` and `ensureBottom`, this allows for stable dragging of views where the dimensions are not known.
- Added `enabled` boolean property for toggeling drag
- Views can be mapped and translated with a draggable view.
- iOS: Added native bottom-sheet detents, nested scroll handoff, and detent-aware follower views.
- Draggable implementation now has its own configurable property called `draggable`.
- iOS: Supports all Ti.UI.View subclasses and Ti.UI.View wrapped views (View, Window, Label)
- Android: Fixed a bug where touch events were not correctly passed to children or bubbled to the parent.
- Android: Fixed a bug where min and max bounds were being incorrectly reported after being set.
- Android: Improved drag tracking. It plays nice with child views now.
- Android: Added a touch threshold to ensure all child views have a chance to have their respective events fired.

## Usage

```javascript
var Draggable = require('ti.draggable'),
    mainWindow = Ti.UI.createWindow({
        backgroundColor : 'white'
    }),
    draggableView = Draggable.createView({
        width : 100,
        height : 100,
        backgroundColor : 'black'
    });

mainWindow.add(draggableView);
mainWindow.open();
```

> If you are building the Android module, make sure you update the .classpath and build.properties files to match your setup.

## Module Reference

### Draggable.createView(viewOptions);

Create a draggable view. All of Titanium's properties are supported along the additional `draggableConfig` property containing any options that should be set upon creation. See [Options](#options)

> When the draggable proxy is created a new property is set called `draggable` which stores all the configuration properties and allows for options to be updated after creation.

**iOS Notes**
You can pass almost all of iOS' supported Ti.UI creation methods to the draggable module such as `Draggable.createView( ... )` or `Draggable.createWindow( ... )`. While `Ti.UI.View` and `Ti.UI.Window` are fully supported on iOS other APIs haven't been fully tested.

**Android Notes**
Android only supports the creation of Ti.UI.Views. At this time there are no plans to add support for other APIs.

## Options

Options can be set on view creation using `draggableConfig` or after creation using `DraggableView.draggable.setConfig( ... )`

***

The `setConfig` method can set options two different ways. You can pass an `object` containing the parameters you with to set or you can pass a key-value pair.

**Setting Options With An Object**
```javascript
DraggableView.draggable.setConfig('enabled', false);
```

**Setting Options With An Object**
```javascript
DraggableView.draggable.setConfig({
  enabled : false
});
```

***

### `Boolean` - enabled
Flag to enable or disable dragging.

### `String` - axis

Constrains how the view can be dragged.

Supported values:

- `x` — drag horizontally only

- `y` — drag vertically only

- `xy` — drag on either axis, but only one axis at a time per gesture

When `axis` is set to `xy`, the drag locks to the first dominant direction of the gesture.

This means the view can move horizontally or vertically, but not diagonally during the same drag.

If `axis` is omitted, the view can move freely on both axes.

## Native Bottom-Sheet Handoff (iOS)

Version 4.4.0 can coordinate a vertical draggable view with a descendant `Ti.UI.TableView`, `Ti.UI.ListView`, or `Ti.UI.ScrollView`. The inner scroll view scrolls while the sheet is expanded. A downward gesture first returns the inner content to its adjusted top offset, then transfers the same gesture to the draggable sheet without waiting for JavaScript.

```javascript
var tableView = Ti.UI.createTableView({
  top: 72,
  bottom: 0,
  data: rows
});

var mapButtons = Ti.UI.createView({
  right: 16,
  width: 48,
  height: 104
});

var expandedTop = 80;
var screenHeight = Ti.Platform.displayCaps.platformHeight;

var sheet = Draggable.createView({
  top: 700,
  left: 0,
  right: 0,
  height: screenHeight - expandedTop,
  draggableConfig: {
    axis: 'y',
    detents: {
      expanded: expandedTop,
      middle: 420,
      collapsed: 700
    },
    initialDetent: 'collapsed',
    scrollHandoff: {
      view: tableView,
      atTopBehavior: 'drag'
    },
    followers: [{
      view: mapButtons,
      attachUntil: 'middle',
      offset: -12,
      fadeBetween: ['middle', 'expanded'],
      disableTouchesWhenHidden: true
    }]
  }
});

sheet.add(tableView);
window.add(mapButtons); // Followers should be siblings of the sheet.
window.add(sheet);
```

All per-frame scrolling, dragging, snapping, follower positioning, and fading occurs in UIKit. JavaScript receives lifecycle events only.

### Detents

`detents` accepts a dictionary of names and absolute `top` positions. Names are arbitrary and positions are sorted from smallest (expanded) to largest (collapsed). When detents are configured they also become the vertical drag bounds.

- `initialDetent` (`String`) — Positions the sheet at a named detent after its native view is ready.
- `detentVelocityThreshold` (`Number`, default `500`) — Vertical velocity in points per second that advances to the next detent in the release direction.
- `detentDuration` (`Number`, default `0.42`) — Native snap duration in seconds.
- `detentDamping` (`Number`, default `0.86`) — Native snap spring damping ratio from `0.01` through `1.0`.

Move to a detent programmatically:

```javascript
sheet.draggable.setDetent('middle');
sheet.draggable.setDetent('expanded', { animated: false });
```

### Scroll Handoff

`scrollHandoff.view` is the descendant TableView, ListView, or ScrollView to coordinate. `atTopBehavior` may be changed at runtime:

```javascript
sheet.draggable.setConfig('scrollHandoff.atTopBehavior', 'scroll');
sheet.draggable.setConfig('scrollHandoff.atTopBehavior', 'drag');
sheet.draggable.setConfig('scrollHandoff.atTopBehavior', 'dismiss');
```

- `drag` (default) — A downward pull transfers from the inner content to the sheet when the content reaches its adjusted top offset.
- `scroll` — The inner view retains downward pulls while the sheet is expanded, including its normal edge behavior.
- `dismiss` — Uses the same native handoff as `drag`, then targets `dismissDetent` and emits `dismiss` when the release passes `dismissThreshold` or `detentVelocityThreshold`.
- `top` (`Number`) — Optional expanded sheet position used for handoff when no detents are configured. Otherwise the smallest detent or `minTop` is used.
- `topTolerance` (`Number`, default `1`) — Content and sheet top-edge tolerance in points.
- `dismissThreshold` (`Number`, default `120`) — Downward distance required for the `dismiss` policy.
- `dismissDetent` (`String`) — Named dismissal target. Defaults to the largest configured detent.

The module does not remove the sheet automatically. Handle the `dismiss` event to close, hide, or recycle it after the native motion completes.

Size the sheet so its bottom edge meets the window bottom at the expanded detent (`height: screenHeight - expandedTop`). Extra offscreen height also enlarges the native scroll view's viewport and can leave its final rows below the visible window.

### Follower Views

`followers` keeps sibling controls visually attached to the sheet without JavaScript `move` events. This is useful for map buttons or other controls that should travel with a collapsed sheet, clamp at a middle detent, and fade as the sheet expands.

- `view` (`Ti.UI.View`, required) — A sibling of the draggable sheet.
- `attachUntil` (`String` or `Number`) — Detent name or sheet top where the follower stops moving upward.
- `offset` (`Number`, default `-12`) — Vertical offset from the sheet top to the follower's bottom edge. A negative value creates a gap above the sheet.
- `gap` (`Number`) — Positive shorthand for a gap above the sheet; overrides `offset`.
- `fadeBetween` (`Array`) — Two detent names or numeric tops: fully visible first, fully hidden second.
- `visibleAlpha` / `hiddenAlpha` (`Number`, defaults `1` / `0`) — Alpha endpoints.
- `bringToFront` (`Boolean`, default `true`) — Keeps the follower above the sheet so its detent fade remains visible. Set to `false` when the application manages sibling z-order itself.
- `disableTouchesWhenHidden` (`Boolean`, default `true`) — Disables native hit testing at the hidden endpoint and restores the view's original interaction state when visible.

The sheet emits these lifecycle events:

- `handoff` — Gesture ownership changes; `owner` is `scroll` or `draggable`.
- `detentwillchange` — A native detent animation is about to begin.
- `detentchange` — The native detent animation completed; includes `detent` and `top`.
- `dismiss` — A `dismiss` policy release completed at its dismissal detent.

## Native Horizontal Release (iOS)

Set `nativeReleaseAnimation` to `true` to let the native pan recognizer decide and begin the horizontal release animation immediately. This avoids waiting for an `end` event to cross the JavaScript bridge before starting the swipe or snapback animation.

```javascript
var card = Draggable.createView({
  draggableConfig: {
    axis: 'xy',
    nativeReleaseAnimation: true,
    swipeThreshold: 80,
    swipeVelocityThreshold: 650,
    swipeOutDistance: Ti.Platform.displayCaps.platformWidth + 100,
    swipeOutDuration: 0.25,
    snapBack: true,
    snapBackDuration: 0.42,
    snapBackDamping: 0.84
  }
});
```

The native release path applies only to horizontal releases. With `axis: 'xy'`, vertical releases continue through the existing `end` event so the application can handle its own vertical behavior.

- `nativeReleaseAnimation` (`Boolean`, default `false`) — Enables the native horizontal release path.
- `swipeThreshold` (`Number`, default `80`) — Horizontal distance in points required to dismiss. Set to `0` to disable the distance threshold.
- `swipeVelocityThreshold` (`Number`, default `650`) — Horizontal release velocity in points per second required to dismiss. Set to `0` to disable the velocity threshold.
- `swipeOutDistance` (`Number`) — Horizontal distance from the gesture's starting center to the offscreen target. The default is the parent width plus the draggable view width.
- `swipeOutDuration` (`Number`, default `0.25`) — Swipe completion duration in seconds.
- `snapBack` (`Boolean`, default `true`) — Returns a horizontal release that misses both thresholds to its starting position.
- `snapBackDuration` (`Number`, default `0.42`) — Snapback duration in seconds.
- `snapBackDamping` (`Number`, default `0.84`) — Snapback spring damping ratio from `0.01` through `1.0`.

The existing `end` event still fires. Its payload includes `nativeReleaseHandled` and, when handled, `releaseAction` (`swipe` or `snapback`). The module also emits:

- `release` — Fires immediately after the native release animation starts.
- `swipe` — Fires when a native offscreen swipe finishes and includes `direction` (`left` or `right`).
- `snapback` — Fires when the native return animation finishes.

### `Number` - minLeft
The left-most boundary of the view being dragged. Can be set to `null` to disable property.

### `Number` - maxLeft
The right-most boundary of the view being dragged. Can be set to `null` to disable property.

### `Number` - minTop
The top-most boundary of the view being dragged. Can be set to `null` to disable property.

### `Number` - maxTop
The bottom-most boundary of the view being dragged. Can be set to `null` to disable property.

### `Boolean` - ensureRight
Ensure that that the `right` edge of the view being dragged keeps its integrity. Can be set to `null` to disable property.

### `Boolean` - ensureBottom
Ensure that that the `bottom` edge of the view being dragged keeps its integrity. Can be set to `null` to disable property.

### `Array` - maps
An array of views that should be translated along with the view being dragged. See [View Mapping](#view-mapping).

## View Mapping

In the case where you want multiple views to be translated at the same time you can pass the `maps` property to the draggable config. This functionality is useful for creating parallax or 1:1 movements.

The `maps` property accepts an array of objects containing any of the following. The `view` property is required.

### Map Options

### `Ti.UI.View` - view
The view to translate.

### `Number` - parallaxAmount
A positive or negative number. Numbers less than `|1|` such as `0.1`, `0.2`, or `0.3` will cause the translation to move *faster* then the translation. A `parallaxAmount` of 1 will translate mapped views 1:1. A parallaxAmount `> 1` will result in a slower translation.

### `Object` - constrain
An object containing the boundaries of the mapped view. Can have the following:

* **x**
  * **start** The start position for the mapped view.
  * **end** The end position for the mapped view.
  * **callback** A function that will receive the completed percentage of the mapped translation. . Android does not support this option.
  * **fromCenter** Translate the view from its center. Android does not support this option.
* **y**
  * **start** The start position for the mapped view.
  * **end** The end position for the mapped view.
  * **callback** A function that will receive the completed percentage of the mapped translation. . Android does not support this option.
  * **fromCenter** Translate the view from its center. Android does not support this option.

## Credits & Notes

The work is largely based on [Pedro](http://twitter.com/pecdev) [Enrique's](https://github.com/pec1985) [TiDraggable](https://github.com/pec1985/TiDraggable) module license under the MIT (V2) license.
