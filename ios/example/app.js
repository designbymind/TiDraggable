/*global require,console,Ti*/
/*jslint devel: true, forin: true */
/**
 * An enhanced fork of the original TiDraggable module by Pedro Enrique,
 * allows for simple creation of "draggable" views.
 *
 * Copyright (C) 2013 Seth Benjamin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * -- Original License --
 *
 * Copyright 2012 Pedro Enrique
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var Draggable = require('ti.draggable');
var screenHeight = Ti.Platform.displayCaps.platformHeight;
var expandedTop = Ti.UI.statusBarHeight + 5 + 36 + 16;
var middleTop = Math.round(screenHeight * 0.43);
// var collapsedTop = Math.round(screenHeight * 0.73);
var collapsedTop = Ti.Platform.displayCaps.platformHeight - 106; // 72 + 34 (bottom safe area)
var mainWindow = Ti.UI.createWindow({
	backgroundColor: '#dbe8d4'
	// fullscreen: true
});
var rows = [];
var index;

for (index = 1; index <= 40; index += 1) {
	rows.push({
		title: 'Nearby place ' + index,
		color: '#18201b',
		height: 58
	});
}

mainWindow.add(
	Ti.UI.createLabel({
		text: 'Map content',
		top: 145,
		color: '#647162',
		font: { fontSize: 28, fontWeight: 'bold' }
	})
);

var mapButtons = Ti.UI.createView({
	right: 16,
	top: collapsedTop - 116,
	width: 48,
	height: 104,
	layout: 'vertical'
});

mapButtons.add(
	Ti.UI.createButton({
		title: '+',
		width: 48,
		height: 48,
		borderRadius: 24,
		backgroundColor: 'white',
		color: '#18201b'
	})
);
mapButtons.add(
	Ti.UI.createButton({
		title: '◎',
		top: 8,
		width: 48,
		height: 48,
		borderRadius: 24,
		backgroundColor: 'white',
		color: '#18201b'
	})
);

var tableView = Ti.UI.createTableView({
	top: 72,
	left: 0,
	right: 0,
	bottom: 0,
	backgroundColor: 'transparent',
	separatorColor: '#e7e7e7',
	data: rows
});

var sheet = Draggable.createView({
	top: collapsedTop,
	left: 0,
	right: 0,
	height: screenHeight - expandedTop,
	borderRadius: 24,
	backgroundColor: '#ffffff',
	draggableConfig: {
		axis: 'y',
		detents: {
			expanded: expandedTop,
			middle: middleTop,
			collapsed: collapsedTop
		},
		initialDetent: 'collapsed',
		detentVelocityThreshold: 500,
		scrollHandoff: {
			view: tableView,
			atTopBehavior: 'drag',
			dismissThreshold: 120,
			dismissDetent: 'collapsed'
		},
		followers: [
			{
				view: mapButtons,
				attachUntil: 'middle',
				offset: -12,
				fadeBetween: ['middle', 'expanded'],
				disableTouchesWhenHidden: true
			}
		]
	}
});

sheet.add(
	Ti.UI.createView({
		top: 10,
		width: 42,
		height: 5,
		borderRadius: 3,
		backgroundColor: '#c3c5c4'
	})
);
sheet.add(
	Ti.UI.createView({
		top: 72,
		width: Ti.UI.FILL,
		height: 1,
		backgroundColor: '#000000'
	})
);
sheet.add(
	Ti.UI.createLabel({
		text: 'Nearby homes',
		top: 28,
		left: 20,
		color: '#18201b',
		font: { fontSize: 24, fontWeight: 'bold' }
	})
);
sheet.add(tableView);

var policyLabel = Ti.UI.createLabel({
	text: 'At top: drag',
	top: 44,
	left: 16,
	color: '#18201b',
	font: { fontSize: 14, fontWeight: 'semibold' }
});
var policyButtons = Ti.UI.createView({
	top: Ti.UI.statusBarHeight + 5 + 8,
	left: 12,
	height: 36,
	layout: 'horizontal'
});

['drag', 'scroll', 'dismiss'].forEach(function (behavior) {
	var button = Ti.UI.createButton({
		title: behavior,
		width: 82,
		height: 34,
		right: 6,
		borderRadius: 17,
		backgroundColor: '#ffffff',
		color: '#18201b',
		font: { fontSize: 13 }
	});

	button.addEventListener('click', function () {
		sheet.draggable.setConfig('scrollHandoff.atTopBehavior', behavior);
		policyLabel.text = 'At top: ' + behavior;
	});
	policyButtons.add(button);
});

sheet.addEventListener('handoff', function (event) {
	Ti.API.info('Handoff owner: ' + event.owner);
});
sheet.addEventListener('detentchange', function (event) {
	Ti.API.info('Settled at detent: ' + event.detent);
});
sheet.addEventListener('dismiss', function () {
	Ti.API.info('Dismiss policy reached its target detent');
});

mainWindow.add(mapButtons);
mainWindow.add(sheet);
mainWindow.add(policyLabel);
mainWindow.add(policyButtons);

mainWindow.open();
