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
package ti.draggable;

import java.lang.ref.WeakReference;

import org.appcelerator.kroll.KrollProxy;
import org.appcelerator.titanium.TiC;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.util.TiConvert;
import org.appcelerator.titanium.view.TiCompositeLayout;
import org.appcelerator.titanium.view.TiCompositeLayout.LayoutArrangement;
import org.appcelerator.titanium.view.TiUIView;

import android.content.Context;
import android.view.MotionEvent;

public class DraggableImpl extends TiUIView {
	public DraggableGesture listener;
	protected TiCompositeLayout.LayoutParams layout;

	public class DraggableView extends TiCompositeLayout
	{
		public DraggableView(Context context, LayoutArrangement arrangement)
		{
			super(context, arrangement);
		}

		@Override
	    public boolean onInterceptTouchEvent(MotionEvent event)
		{
			switch (event.getAction())
			{
				case MotionEvent.ACTION_DOWN:
					listener.startDrag(event);
				case MotionEvent.ACTION_MOVE:
					listener.determineDrag(event);
					break;
				case MotionEvent.ACTION_UP:
				case MotionEvent.ACTION_CANCEL:
					listener.stopDrag(event);
					break;
			}

			return listener.isBeingDragged;
	    }
	}

	public DraggableImpl(KrollProxy proxy)
	{
		super((TiViewProxy) proxy);

		LayoutArrangement arrangement = LayoutArrangement.DEFAULT;

		if (proxy.hasProperty(TiC.PROPERTY_LAYOUT))
		{
			String layoutProperty = TiConvert.toString(proxy.getProperty(TiC.PROPERTY_LAYOUT));

			if (layoutProperty.equals(TiC.LAYOUT_HORIZONTAL))
			{
				arrangement = LayoutArrangement.HORIZONTAL;
			}
			else if (layoutProperty.equals(TiC.LAYOUT_VERTICAL))
			{
				arrangement = LayoutArrangement.VERTICAL;
			}
		}

		setNativeView(new DraggableView(proxy.getActivity(), arrangement));
		setupDraggableGesture();
	}

	protected void setupDraggableGesture()
	{
		ConfigProxy draggableConfig = (ConfigProxy) proxy.getProperty("draggable");
		WeakReference<ConfigProxy> weakConfig = new WeakReference<ConfigProxy>(draggableConfig);

		this.getLayoutParams().autoFillsHeight = true;
        this.getLayoutParams().autoFillsWidth = true;
        this.listener = new DraggableGesture((TiViewProxy) proxy, this, weakConfig);

		this.getOuterView().setOnTouchListener(listener);

		draggableConfig.setDraggableImpl(new WeakReference<DraggableImpl>(this));
	}

	@Override
	public void registerForTouch()
	{
		//
	}
}
