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
