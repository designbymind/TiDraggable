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

#import <objc/runtime.h>
#import <objc/message.h>
#import "TiDraggableModule.h"
#import "TiDraggableGesture.h"
#import "TiUINavigationWindowProxy.h"

@implementation TiDraggableModule

#pragma mark Internal

- (id)moduleGUID
{
	return @"e8c13998-8fa8-4cee-8078-353c27e84d19";
}

- (NSString*)moduleId
{
	return @"ti.draggable";
}

- (void)makeDraggable:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);

    TiViewProxy* proxy = nil;
    NSDictionary* options = nil;

    ENSURE_ARG_AT_INDEX(proxy, args, 0, TiViewProxy);
    ENSURE_ARG_OR_NIL_AT_INDEX(options, args, 1, NSDictionary);

    if (proxy)
    {
        [[TiDraggableGesture alloc] initWithProxy:proxy andOptions:options withDelegate:self];
    }
}

- (id)createProxy:(NSArray*)args forName:(NSString*)name context:(id<TiEvaluator>)context
{
    TiViewProxy* proxy = nil;

    if ([name isEqualToString:@"createNavigationWindow"])
    {
        proxy = [[[TiUINavigationWindowProxy alloc] _initWithPageContext:[self executionContext] args:args] autorelease];
    }
    else
    {
        Ivar nameLookupIvar = class_getInstanceVariable([super class], "classNameLookup");
        CFMutableDictionaryRef cnLookup = (CFMutableDictionaryRef) object_getIvar(self, nameLookupIvar);
        Class resultClass = (Class) CFDictionaryGetValue(cnLookup, name);

        if (resultClass == NULL)
        {
            NSRange range = [name rangeOfString:@"create"];

            if (range.location == NSNotFound)
            {
                return nil;
            }

            NSString *className = [NSString stringWithFormat:@"Ti%@Proxy", [name substringFromIndex:range.location + 6]];

            resultClass = NSClassFromString(className);

            if (! [resultClass isSubclassOfClass:[TiViewProxy class]])
            {
                @throw [NSException exceptionWithName:@"ti.draggable"
                                               reason:[NSString stringWithFormat:@"invalid method (%@) passed to %@", name, [self class]]
                                             userInfo:nil];
            }

            CFDictionarySetValue(cnLookup, name, resultClass);
        }

        proxy = [[[resultClass alloc] _initWithPageContext:context args:args] autorelease];
    }

    if (proxy)
    {
        NSDictionary* options = [proxy valueForKeyPath:@"draggableConfig"];

        [[TiDraggableGesture alloc] initWithProxy:proxy andOptions:options withDelegate:self];
    }

    return proxy;
}

#pragma TiDraggableGestureDelegate

- (void)fireGlobalEvent:(NSString *)eventName withObject:(NSDictionary*)eventData
{
    if ([self _hasListeners:eventName]) {
        [self fireEvent:eventName withObject:eventData];
    }
}
 
- (void)fireGlobalEvent:(NSString *)eventName withObject:(NSDictionary*)eventData withSource:(id)source
{
    if ([self _hasListeners:eventName]) {
        [self fireEvent:eventName withObject:eventData withSource:source];
    }
}

@end
