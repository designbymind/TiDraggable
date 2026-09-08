# [TiDraggable](https://github.com/designbymind/TiDraggable) - Native Draggable Views

An enhanced fork of the original [TiDraggable](https://github.com/pec1985/TiDraggable) module by [Pedro](http://twitter.com/pecdev) [Enrique](https://github.com/pec1985), allows for simple creation of "draggable" views.

## Installation

In your `tiapp.xml` file add the following to the `modules` node:

	<module version="4.4.0">ti.draggable</module>

## Usage

See the [root README](../README.md) for the 4.4.0 bottom-sheet detents, native scroll handoff, and follower-view APIs.

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

## Credits & Notes

The work is largely based on [Pedro](http://twitter.com/pecdev) [Enrique's](https://github.com/pec1985) [TiDraggable](https://github.com/pec1985/TiDraggable) module license under the MIT (V2) license.
