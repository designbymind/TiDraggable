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
var collapsedTop = Ti.Platform.displayCaps.platformHeight - 106; // 72 + 34 (bottom safe area)
var mainWindow = Ti.UI.createWindow({ backgroundColor: '#F3F2F8' });
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
		text: 'MAP',
		top: 200,
		color: '#999999',
		font: { fontSize: 44, fontWeight: 'bold' }
	})
);

var mapButtons = Ti.UI.createView({
	right: 16,
	top: collapsedTop - 116,
	width: 48,
	height: 108,
	layout: 'vertical',
	clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED
});

mapButtons.add(
	Ti.UI.createButton({
		width: 48,
		height: 48,
		top: 0,
		clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED,
		configuration: Ti.UI.iOS.createButtonConfiguration({
			style: 'prominentClearGlass',
			color: '#FFFFFF',
			backgroundColor: Ti.UI.userInterfaceStyle === 1 ? '#007AFF' : '#0A84FF',
			image: Ti.UI.iOS.systemImage('plus', { weight: 'bold', size: 18 })
		})
	})
);
mapButtons.add(
	Ti.UI.createButton({
		width: 48,
		height: 48,
		top: 12,
		clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED,
		configuration: Ti.UI.iOS.createButtonConfiguration({
			style: 'prominentClearGlass',
			color: '#FFFFFF',
			backgroundColor: Ti.UI.userInterfaceStyle === 1 ? '#007AFF' : '#0A84FF',
			image: Ti.UI.iOS.systemImage('minus', { weight: 'bold', size: 18 })
		})
	})
);

var tableView = Ti.UI.createTableView({
	top: 72,
	left: 0,
	width: Ti.UI.FILL,
	height: Ti.UI.FILL,
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
	viewShadowColor: 'rgba(0, 0, 0, 0.32)',
	viewShadowOffset: { x: 0, y: -1 },
	viewShadowRadius: 5,
	draggableConfig: {
		axis: 'y',
		detents: {
			expanded: expandedTop,
			middle: middleTop,
			collapsed: collapsedTop
		},
		initialDetent: 'collapsed',
		detentVelocityThreshold: 650,
		progressRanges: [
			{ id: 'collapsedToMiddle', from: 'collapsed', to: 'middle' },
			{ id: 'middleToExpanded', from: 'middle', to: 'expanded' }
		],
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
				bringToFront: false,
				passThroughTouches: true,
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
		borderRadius: 2.5,
		backgroundColor: '#000000',
		opacity: 0.15
	})
);
sheet.add(
	Ti.UI.createView({
		top: 72,
		width: Ti.UI.FILL,
		height: 0.33,
		backgroundColor: '#3C3C43',
		opacity: 0.29
	})
);
sheet.add(
	Ti.UI.createLabel({
		text: 'Nearby People',
		top: 28,
		left: 20,
		color: '#18201b',
		font: { fontSize: 24, fontWeight: 'bold' }
	})
);
sheet.add(tableView);

var policyButtons = Ti.UI.createView({
	top: Ti.UI.statusBarHeight + 5 + 8,
	left: 12,
	height: 36,
	layout: 'horizontal',
	clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED
});

['Drag', 'Scroll', 'Dismiss'].forEach(function (behavior) {
	// Update the selected button configuration to indicate it is selected
	if (behavior === 'Drag') {
		var button = Ti.UI.createButton({
			title: 'Drag',
			width: 100,
			height: 34,
			right: 6,
			clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED,
			configuration: Ti.UI.iOS.createButtonConfiguration({
				title: 'Drag',
				font: { fontSize: 13, fontWeight: 'bold' },
				style: 'prominentClearGlass',
				color: '#000000',
				image: Ti.UI.iOS.systemImage('circlebadge.fill', { weight: 'regular', size: 14 }),
				imagePadding: 6
			})
		});
	} else {
		var button = Ti.UI.createButton({
			title: behavior,
			width: 100,
			height: 34,
			right: 6,
			clipMode: Ti.UI.iOS.CLIP_MODE_DISABLED,
			configuration: Ti.UI.iOS.createButtonConfiguration({
				style: 'prominentClearGlass',
				title: behavior,
				font: { fontSize: 13, fontWeight: 'medium' },
				color: Ti.UI.userInterfaceStyle === 1 ? '#007AFF' : '#0A84FF',
				image: Ti.UI.iOS.systemImage('circlebadge', { weight: 'regular', size: 14 }),
				imagePadding: 6
			})
		});
	}

	button.addEventListener('click', function () {
		// Update the draggable sheet's behavior based on the selected button
		sheet.draggable.setConfig('scrollHandoff.atTopBehavior', behavior.toLowerCase());

		// The selected behavior button should have black text
		policyButtons.children.forEach(function (btn) {
			// Ti.API.info('Updating button configuration for behavior: ' + behavior);
			// Ti.API.info('btn: ' + JSON.stringify(btn));

			// Update the selected button configuration to indicate it is selected
			if (btn === button) {
				btn.configuration = Ti.UI.iOS.createButtonConfiguration({
					title: btn.title,
					font: { fontSize: 13, fontWeight: 'bold' },
					style: 'prominentClearGlass',
					color: '#000000',
					image: Ti.UI.iOS.systemImage('circlebadge.fill', { weight: 'regular', size: 14 }),
					imagePadding: 6
				});
			} else {
				btn.configuration = Ti.UI.iOS.createButtonConfiguration({
					title: btn.title,
					font: { fontSize: 13, fontWeight: 'medium' },
					style: 'prominentClearGlass',
					color: Ti.UI.userInterfaceStyle === 1 ? '#007AFF' : '#0A84FF',
					image: Ti.UI.iOS.systemImage('circlebadge', { weight: 'regular', size: 14 }),
					imagePadding: 6
				});
			}
		});
	});
	policyButtons.add(button);
});

sheet.addEventListener('handoff', function (event) {
	Ti.API.info('Handoff owner: ' + event.owner);
});
sheet.addEventListener('detentwillchange', function (event) {
	Ti.API.info('Will change to detent: ' + event.detent);
});
sheet.addEventListener('detentchange', function (event) {
	Ti.API.info('Settled at detent: ' + event.detent);
});
sheet.addEventListener('detentprogress', function (event) {
	Ti.API.info('Interactive progress ' + event.id + ': ' + event.progress.toFixed(3));
});
sheet.addEventListener('Dismiss', function () {
	Ti.API.info('Dismiss policy reached its target detent');
});

mainWindow.add(mapButtons);
mainWindow.add(sheet);
mainWindow.add(policyButtons);

mainWindow.open();
