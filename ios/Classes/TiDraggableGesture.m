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
#import "TiViewProxy+ViewProxyExtended.h"
#import "TiDraggableGesture.h"

static const void *kTiDraggableLockedAxisKey = &kTiDraggableLockedAxisKey;
static const void *kTiDraggableFollowerInteractionKey = &kTiDraggableFollowerInteractionKey;
static const void *kTiDraggableFollowerOriginalClassKey = &kTiDraggableFollowerOriginalClassKey;
static void *kTiDraggableContentOffsetContext = &kTiDraggableContentOffsetContext;

static UIView *TiDraggableFollowerPassThroughHitTest(id view, SEL selector, CGPoint point, UIEvent *event)
{
    Class currentClass = object_getClass(view);
    struct objc_super superInfo = {
        .receiver = view,
        .super_class = class_getSuperclass(currentClass)
    };
    UIView *hitView = ((UIView *(*)(struct objc_super *, SEL, CGPoint, UIEvent *))objc_msgSendSuper)(&superInfo, selector, point, event);

    return hitView == view ? nil : hitView;
}

static Class TiDraggableFollowerPassThroughSubclass(Class originalClass)
{
    NSString *subclassName = [NSString stringWithFormat:@"TiDraggableFollowerPassThrough_%@", NSStringFromClass(originalClass)];
    subclassName = [subclassName stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    Class subclass = NSClassFromString(subclassName);

    if (subclass != Nil)
    {
        return class_getSuperclass(subclass) == originalClass ? subclass : Nil;
    }

    @synchronized([TiDraggableGesture class])
    {
        subclass = NSClassFromString(subclassName);

        if (subclass == Nil)
        {
            subclass = objc_allocateClassPair(originalClass, [subclassName UTF8String], 0);
            Method hitTestMethod = class_getInstanceMethod(originalClass, @selector(hitTest:withEvent:));

            if (subclass == Nil || hitTestMethod == NULL || !class_addMethod(subclass,
                                                                            @selector(hitTest:withEvent:),
                                                                            (IMP)TiDraggableFollowerPassThroughHitTest,
                                                                            method_getTypeEncoding(hitTestMethod)))
            {
                if (subclass != Nil)
                {
                    objc_disposeClassPair(subclass);
                }

                return Nil;
            }

            objc_registerClassPair(subclass);
        }
    }

    return class_getSuperclass(subclass) == originalClass ? subclass : Nil;
}

static void TiDraggableSetFollowerPassThroughTouches(UIView *view, BOOL enabled)
{
    Class originalClass = (Class)objc_getAssociatedObject(view, kTiDraggableFollowerOriginalClassKey);

    if (enabled)
    {
        if (originalClass != Nil)
        {
            return;
        }

        originalClass = object_getClass(view);
        Class passThroughClass = TiDraggableFollowerPassThroughSubclass(originalClass);

        if (passThroughClass != Nil)
        {
            objc_setAssociatedObject(view, kTiDraggableFollowerOriginalClassKey, originalClass, OBJC_ASSOCIATION_ASSIGN);
            object_setClass(view, passThroughClass);
        }

        return;
    }

    if (originalClass != Nil)
    {
        object_setClass(view, originalClass);
        objc_setAssociatedObject(view, kTiDraggableFollowerOriginalClassKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
}

typedef NS_ENUM(NSInteger, TiDraggableVerticalPanOwner) {
    TiDraggableVerticalPanOwnerNone = 0,
    TiDraggableVerticalPanOwnerScrollView,
    TiDraggableVerticalPanOwnerSheet
};

@interface TiDraggableGesture ()

- (BOOL)startNativeHorizontalReleaseForRecognizer:(UIPanGestureRecognizer *)panRecognizer
                                        lockedAxis:(NSString *)lockedAxis
                                         properties:(NSMutableDictionary *)properties;
- (void)persistCurrentViewPositionUpdatingX:(BOOL)updateX updatingY:(BOOL)updateY;
- (void)updateGestureCoordination;
- (void)setObservedScrollView:(UIScrollView *)scrollView;
- (UIScrollView *)configuredScrollView;
- (UIScrollView *)firstScrollViewInView:(UIView *)view;
- (BOOL)gestureBeganInsideScrollView:(UIScrollView *)scrollView recognizer:(UIPanGestureRecognizer *)panRecognizer;
- (BOOL)shouldMoveSheetForVerticalTranslation:(CGFloat)translationY;
- (void)setVerticalPanOwner:(TiDraggableVerticalPanOwner)owner;
- (CGFloat)topContentOffsetForScrollView:(UIScrollView *)scrollView;
- (void)pinConfiguredScrollViewToTop;
- (NSArray *)sortedDetents;
- (NSDictionary *)detentNamed:(NSString *)name;
- (CGFloat)topHandoffPosition;
- (BOOL)startNativeVerticalDetentReleaseForRecognizer:(UIPanGestureRecognizer *)panRecognizer
                                           lockedAxis:(NSString *)lockedAxis
                                            properties:(NSMutableDictionary *)properties;
- (void)animateToDetent:(NSDictionary *)detent
               velocity:(CGFloat)velocity
               animated:(BOOL)animated
          releaseAction:(NSString *)releaseAction
             properties:(NSMutableDictionary *)properties;
- (void)updateFollowersForSheetTop:(CGFloat)sheetTop persistLayout:(BOOL)persistLayout;
- (void)cancelFollowerAnimations;
- (CGFloat)topForDetentReference:(id)reference found:(BOOL *)found;
- (void)emitDetentProgressForSheetTop:(CGFloat)sheetTop interactive:(BOOL)interactive;
- (void)startDetentProgressTracking;
- (void)stopDetentProgressTracking;
- (void)updateDetentProgressFromDisplayLink:(CADisplayLink *)displayLink;
- (void)setConfigValue:(id)value forKeyPath:(NSString *)keyPath;

@end

@implementation TiDraggableGesture

- (id)initWithProxy:(TiViewProxy*)proxy andOptions:(NSDictionary *)options
{
    if (self = [super init])
    {
        _passThroughFollowerViews = [[NSMutableSet alloc] init];
        _lastDetentProgressValues = [[NSMutableDictionary alloc] init];
        self.proxy = proxy;
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDetected:)];
        self.gesture = panGesture;
        [panGesture release];

        [self.proxy setValue:self forKey:@"draggable"];
        [self.proxy setProxyObserver:self];

        [self setValuesForKeysWithDictionary:options];
        [self updateGestureCoordination];
        [self correctMappedProxyPositions];
    }

    return self;
}

- (void)proxyDidRelayout:(id)sender
{
    BOOL gestureIsAttached = [self.proxy.view.gestureRecognizers containsObject:self.gesture];

    if (! gestureIsAttached && [self.proxy viewReady])
    {
        [self.proxy.view addGestureRecognizer:self.gesture];
    }

    [self updateGestureCoordination];

    if (!_didApplyInitialDetent && [self.proxy viewReady])
    {
        NSString *initialDetent = [TiUtils stringValue:[self valueForKey:@"initialDetent"]];
        NSDictionary *detent = [self detentNamed:initialDetent];

        if (detent != nil)
        {
            _didApplyInitialDetent = YES;
            [self animateToDetent:detent velocity:0.0f animated:NO releaseAction:@"initial" properties:nil];
        }
    }

    if ([self.proxy viewReady])
    {
        [self updateFollowersForSheetTop:self.proxy.view.frame.origin.y persistLayout:NO];
    }
}

- (void)dealloc
{
    [self stopDetentProgressTracking];

    for (UIView *view in _passThroughFollowerViews)
    {
        TiDraggableSetFollowerPassThroughTouches(view, NO);
    }

    [_passThroughFollowerViews release];
    _passThroughFollowerViews = nil;
    [_lastDetentProgressValues release];
    _lastDetentProgressValues = nil;
    [self setObservedScrollView:nil];
    self.gesture.delegate = nil;
    self.gesture = nil;
    _coordinatedScrollView = nil;

    [super dealloc];
}

- (void)setConfig:(id)args
{
    BOOL didUpdateConfig = NO;

    if ([args isKindOfClass:[NSDictionary class]])
    {
        [self setValuesForKeysWithDictionary:args];

        didUpdateConfig = YES;
    }
    else if ([args isKindOfClass:[NSArray class]] && [args count] >= 2)
    {
        NSString* key = nil;
        id value = [args objectAtIndex:1];

        ENSURE_ARG_AT_INDEX(key, args, 0, NSString);

        [self setConfigValue:value forKeyPath:key];

        didUpdateConfig = YES;
    }

    if (didUpdateConfig)
    {
        [_lastDetentProgressValues removeAllObjects];
        [self updateGestureCoordination];
        [self correctMappedProxyPositions];

        if ([self.proxy viewReady])
        {
            [self updateFollowersForSheetTop:self.proxy.view.frame.origin.y persistLayout:YES];
        }
    }
}

- (void)setConfigValue:(id)value forKeyPath:(NSString *)keyPath
{
    if ([keyPath length] == 0)
    {
        return;
    }

    NSArray *components = [keyPath componentsSeparatedByString:@"."];
    NSString *rootKey = [components objectAtIndex:0];

    if ([rootKey length] == 0)
    {
        return;
    }

    if ([components count] == 1)
    {
        if (value == nil || value == [NSNull null])
        {
            [self deleteKey:rootKey];
        }
        else
        {
            [self replaceValue:value forKey:rootKey notification:NO];
        }

        return;
    }

    id configuredRoot = [self valueForKey:rootKey];
    NSMutableDictionary *rootDictionary = [configuredRoot isKindOfClass:[NSDictionary class]]
        ? [configuredRoot mutableCopy]
        : [[NSMutableDictionary alloc] init];
    NSMutableDictionary *currentDictionary = rootDictionary;

    for (NSUInteger index = 1; index + 1 < [components count]; index++)
    {
        NSString *component = [components objectAtIndex:index];
        id nestedValue = [currentDictionary objectForKey:component];
        NSMutableDictionary *nestedDictionary = [nestedValue isKindOfClass:[NSDictionary class]]
            ? [[nestedValue mutableCopy] autorelease]
            : [NSMutableDictionary dictionary];

        [currentDictionary setObject:nestedDictionary forKey:component];
        currentDictionary = nestedDictionary;
    }

    NSString *finalKey = [components lastObject];

    if ([finalKey length] == 0)
    {
        [rootDictionary release];
        return;
    }

    if (value == nil || value == [NSNull null])
    {
        [currentDictionary removeObjectForKey:finalKey];
    }
    else
    {
        [currentDictionary setObject:value forKey:finalKey];
    }

    [self replaceValue:[[rootDictionary copy] autorelease] forKey:rootKey notification:NO];
    [rootDictionary release];
}

- (void)setDetent:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);

    NSString *name = nil;
    NSDictionary *options = nil;

    if ([args isKindOfClass:[NSArray class]])
    {
        if ([args count] > 0)
        {
            name = [TiUtils stringValue:[args objectAtIndex:0]];
        }

        if ([args count] > 1 && [[args objectAtIndex:1] isKindOfClass:[NSDictionary class]])
        {
            options = [args objectAtIndex:1];
        }
    }
    else
    {
        name = [TiUtils stringValue:args];
    }

    NSDictionary *detent = [self detentNamed:name];

    if (detent == nil)
    {
        [self throwException:@"Unknown detent"
                   subreason:[NSString stringWithFormat:@"No detent named '%@' is configured.", name ?: @""]
                    location:CODELOCATION];
        return;
    }

    BOOL animated = [TiUtils boolValue:[options objectForKey:@"animated"] def:YES];
    [self animateToDetent:detent velocity:0.0f animated:animated releaseAction:@"programmatic" properties:nil];
}

// CREDIT: https://github.com/mikefogg/TiDraggable/commit/bebd0ddd2836faa08e86f08619b7503977ecc5b0
- (void)removeGesture:(id)args
{
    BOOL gestureIsAttached = [self.proxy.view.gestureRecognizers containsObject:self.gesture];
    
    if (gestureIsAttached && [self.proxy viewReady])
    {
        [self.proxy.view removeGestureRecognizer:self.gesture];
        
        TiViewProxy* panningProxy = (TiViewProxy*)[self.proxy.view proxy];
        
        [panningProxy fireEvent:@"remove_gesture"];
    }
}

- (void)addGesture:(id)args
{
    BOOL gestureIsAttached = [self.proxy.view.gestureRecognizers containsObject:self.gesture];
    
    if (! gestureIsAttached && [self.proxy viewReady])
    {
        [self.proxy.view addGestureRecognizer:self.gesture];
        
        TiViewProxy* panningProxy = (TiViewProxy*)[self.proxy.view proxy];
        
        [panningProxy fireEvent:@"add_gesture"];
    }
}

- (void)panDetected:(UIPanGestureRecognizer *)panRecognizer
{
    ENSURE_UI_THREAD_1_ARG(panRecognizer);

    if ([TiUtils boolValue:[self valueForKey:@"enabled"] def:YES] == NO)
    {
        return;
    }

    NSString* axis = [self valueForKey:@"axis"];
    CGFloat maxLeft = [[self valueForKey:@"maxLeft"] floatValue];
    CGFloat minLeft = [[self valueForKey:@"minLeft"] floatValue];
    CGFloat maxTop = [[self valueForKey:@"maxTop"] floatValue];
    CGFloat minTop = [[self valueForKey:@"minTop"] floatValue];
    BOOL hasMaxLeft = [self valueForKey:@"maxLeft"] != nil;
    BOOL hasMinLeft = [self valueForKey:@"minLeft"] != nil;
    BOOL hasMaxTop = [self valueForKey:@"maxTop"] != nil;
    BOOL hasMinTop = [self valueForKey:@"minTop"] != nil;
    BOOL ensureRight = [TiUtils boolValue:[self valueForKey:@"ensureRight"] def:NO];
    BOOL ensureBottom = [TiUtils boolValue:[self valueForKey:@"ensureBottom"] def:NO];
    BOOL cancelAnimations = [TiUtils boolValue:[self valueForKey:@"cancelAnimations"] def:YES];
    NSArray *detents = [self sortedDetents];

    if ([detents count] > 0)
    {
        minTop = [[[detents objectAtIndex:0] objectForKey:@"top"] floatValue];
        maxTop = [[[detents lastObject] objectForKey:@"top"] floatValue];
        hasMinTop = YES;
        hasMaxTop = YES;
    }

    if (cancelAnimations && [[self.proxy.view.layer animationKeys] count] > 0)
    {
        [self.proxy.view setFrame:[[self.proxy.view.layer presentationLayer] frame]];
        [self.proxy.view.layer removeAllAnimations];
        [self cancelFollowerAnimations];
    }

    CGFloat sheetTopBeforeUpdate = self.proxy.view.frame.origin.y;

    CGPoint translation = [panRecognizer translationInView:self.proxy.view];
    CGPoint newCenter = self.proxy.view.center;
    CGSize size = self.proxy.view.frame.size;

    float tmpTranslationX = 0.0f;
    float tmpTranslationY = 0.0f;

    if ([panRecognizer state] == UIGestureRecognizerStateBegan)
    {
        [self stopDetentProgressTracking];
        _detentProgressTrackingGeneration++;
        [_lastDetentProgressValues removeAllObjects];
        touchStart = self.proxy.view.frame.origin;
        touchStartCenter = self.proxy.view.center;
        _coordinatedScrollView = [self configuredScrollView];
        _gestureBeganInCoordinatedScrollView = [self gestureBeganInsideScrollView:_coordinatedScrollView recognizer:panRecognizer];
        _verticalPanOwner = TiDraggableVerticalPanOwnerNone;
        objc_setAssociatedObject(self, kTiDraggableLockedAxisKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if ([axis isEqualToString:@"x"])
    {
        tmpTranslationX = translation.x;
        newCenter.x += translation.x;
    }
    else if ([axis isEqualToString:@"y"])
    {
        if ([self shouldMoveSheetForVerticalTranslation:translation.y])
        {
            tmpTranslationY = translation.y;
            newCenter.y += translation.y;
        }
    }
    else if ([axis isEqualToString:@"xy"])
    {
        NSString *lockedAxis = objc_getAssociatedObject(self, kTiDraggableLockedAxisKey);

        if (lockedAxis == nil && (fabs(translation.x) > 0.0f || fabs(translation.y) > 0.0f))
        {
            lockedAxis = fabs(translation.x) >= fabs(translation.y) ? @"x" : @"y";
            objc_setAssociatedObject(self, kTiDraggableLockedAxisKey, lockedAxis, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        if ([lockedAxis isEqualToString:@"y"])
        {
            if ([self shouldMoveSheetForVerticalTranslation:translation.y])
            {
                tmpTranslationY = translation.y;
                newCenter.y += translation.y;
            }
        }
        else
        {
            tmpTranslationX = translation.x;
            newCenter.x += translation.x;
        }
    }
    else
    {
        tmpTranslationX = translation.x;
        tmpTranslationY = translation.y;

        newCenter.x += translation.x;
        newCenter.y += translation.y;
    }

    if (hasMaxLeft || hasMaxTop || hasMinLeft || hasMinTop)
    {
        if (hasMaxLeft && newCenter.x - size.width / 2 > maxLeft)
        {
            newCenter.x = maxLeft + size.width / 2;
        }
        else if (hasMinLeft && newCenter.x - size.width / 2 < minLeft)
        {
            newCenter.x = minLeft + size.width / 2;
        }

        if (hasMaxTop && newCenter.y - size.height / 2 > maxTop)
        {
            newCenter.y = maxTop + size.height / 2;
        }
        else if (hasMinTop && newCenter.y - size.height / 2 < minTop)
        {
            newCenter.y = minTop + size.height / 2;
        }
    }

    BOOL updateXLayout = (axis == nil || [axis isEqualToString:@"x"] || [axis isEqualToString:@"xy"]);
    BOOL updateYLayout = (axis == nil || [axis isEqualToString:@"y"] || [axis isEqualToString:@"xy"]);
    BOOL scrollViewOwnsThisUpdate = _gestureBeganInCoordinatedScrollView &&
        _verticalPanOwner == TiDraggableVerticalPanOwnerScrollView &&
        fabs(tmpTranslationX) < 0.001f && fabs(tmpTranslationY) < 0.001f;

    if (!scrollViewOwnsThisUpdate)
    {
        LayoutConstraint* layoutProperties = [self.proxy layoutProperties];

        if (updateXLayout)
        {
            layoutProperties->left = TiDimensionDip(newCenter.x - size.width / 2);

            if (ensureRight)
            {
                layoutProperties->right = TiDimensionDip(layoutProperties->left.value * -1);
            }
        }

        if (updateYLayout)
        {
            layoutProperties->top = TiDimensionDip(newCenter.y - size.height / 2);

            if (ensureBottom)
            {
                layoutProperties->bottom = TiDimensionDip(layoutProperties->top.value * -1);
            }
        }

        [self.proxy refreshView:nil];

        if (_verticalPanOwner == TiDraggableVerticalPanOwnerSheet)
        {
            [self pinConfiguredScrollViewToTop];
        }

        [self updateFollowersForSheetTop:self.proxy.view.frame.origin.y persistLayout:YES];

        CGFloat sheetTop = self.proxy.view.frame.origin.y;
        if ([panRecognizer state] == UIGestureRecognizerStateChanged &&
            fabs(sheetTop - sheetTopBeforeUpdate) > 0.001f)
        {
            [self emitDetentProgressForSheetTop:sheetTop interactive:YES];
        }
    }

    [panRecognizer setTranslation:CGPointZero inView:self.proxy.view];

    if (!scrollViewOwnsThisUpdate)
    {
        [self mapProxyOriginToCollection:[self valueForKey:@"maps"]
                        withTranslationX:tmpTranslationX
                         andTranslationY:tmpTranslationY];
    }

    UIGestureRecognizerState gestureState = [panRecognizer state];
    NSString *lockedAxis = objc_getAssociatedObject(self, kTiDraggableLockedAxisKey);

    if (gestureState == UIGestureRecognizerStateEnded ||
        gestureState == UIGestureRecognizerStateCancelled ||
        gestureState == UIGestureRecognizerStateFailed)
    {
        // Capture the position after the recognizer's final translation has been applied.
        touchEnd = self.proxy.view.frame.origin;
    }

    if ([panRecognizer state] == UIGestureRecognizerStateEnded ||
        [panRecognizer state] == UIGestureRecognizerStateCancelled ||
        [panRecognizer state] == UIGestureRecognizerStateFailed)
    {
        if ([panRecognizer state] != UIGestureRecognizerStateEnded)
        {
            [_lastDetentProgressValues removeAllObjects];
        }

        objc_setAssociatedObject(self, kTiDraggableLockedAxisKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    TiViewProxy* panningProxy = (TiViewProxy*)[self.proxy.view proxy];

    float left = [panningProxy view].frame.origin.x;
    float top = [panningProxy view].frame.origin.y;

    NSMutableDictionary *tiProps = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithFloat:left], @"left",
                                    [NSNumber numberWithFloat:top], @"top",
                                    [TiUtils pointToDictionary:self.proxy.view.center], @"center",
                                    [TiUtils pointToDictionary:[panRecognizer velocityInView:self.proxy.view]], @"velocity",
                                    nil];

    if (gestureState == UIGestureRecognizerStateEnded || gestureState == UIGestureRecognizerStateCancelled)
    {
        [tiProps setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithFloat:touchEnd.x - touchStart.x], @"x",
                           [NSNumber numberWithFloat:touchEnd.y - touchStart.y], @"y",
                           nil]
                    forKey:@"distance"];
    }

    BOOL nativeReleaseHandled = NO;

    if (gestureState == UIGestureRecognizerStateEnded &&
        [TiUtils boolValue:[self valueForKey:@"nativeReleaseAnimation"] def:NO])
    {
        nativeReleaseHandled = [self startNativeHorizontalReleaseForRecognizer:panRecognizer
                                                                     lockedAxis:lockedAxis
                                                                      properties:tiProps];
    }

    if (gestureState == UIGestureRecognizerStateEnded && !nativeReleaseHandled)
    {
        nativeReleaseHandled = [self startNativeVerticalDetentReleaseForRecognizer:panRecognizer
                                                                         lockedAxis:lockedAxis
                                                                          properties:tiProps];
    }

    if (gestureState == UIGestureRecognizerStateEnded || gestureState == UIGestureRecognizerStateCancelled)
    {
        [tiProps setObject:[NSNumber numberWithBool:nativeReleaseHandled] forKey:@"nativeReleaseHandled"];
    }

    if([panningProxy _hasListeners:@"start"] && [panRecognizer state] == UIGestureRecognizerStateBegan)
    {
        [panningProxy fireEvent:@"start" withObject:tiProps];
    }
    else if([panningProxy _hasListeners:@"move"] &&
            [panRecognizer state] == UIGestureRecognizerStateChanged &&
            !scrollViewOwnsThisUpdate)
    {
        [panningProxy fireEvent:@"move" withObject:tiProps];
    }
    else if([panRecognizer state] == UIGestureRecognizerStateEnded || [panRecognizer state] == UIGestureRecognizerStateCancelled)
    {
        [panningProxy fireEvent:([panRecognizer state] == UIGestureRecognizerStateCancelled ? @"cancel" : @"end")
                     withObject:tiProps];

        if (nativeReleaseHandled && [panningProxy _hasListeners:@"release"])
        {
            [panningProxy fireEvent:@"release" withObject:tiProps];
        }

        _coordinatedScrollView = nil;
        _gestureBeganInCoordinatedScrollView = NO;
        _verticalPanOwner = TiDraggableVerticalPanOwnerNone;
    }
}

- (BOOL)startNativeHorizontalReleaseForRecognizer:(UIPanGestureRecognizer *)panRecognizer
                                        lockedAxis:(NSString *)lockedAxis
                                         properties:(NSMutableDictionary *)properties
{
    NSString *axis = [self valueForKey:@"axis"];
    CGPoint distance = CGPointMake(touchEnd.x - touchStart.x, touchEnd.y - touchStart.y);
    UIView *view = self.proxy.view;
    UIView *parentView = view.superview;
    CGPoint velocity = [panRecognizer velocityInView:parentView ?: view];

    BOOL isHorizontalRelease = [axis isEqualToString:@"x"] ||
        ([axis isEqualToString:@"xy"] && [lockedAxis isEqualToString:@"x"]);

    if (axis == nil)
    {
        isHorizontalRelease = fabs(velocity.x) >= fabs(velocity.y);

        if (fabs(velocity.x) < 1.0f && fabs(velocity.y) < 1.0f)
        {
            isHorizontalRelease = fabs(distance.x) >= fabs(distance.y);
        }
    }

    if (!isHorizontalRelease)
    {
        return NO;
    }

    CGFloat swipeThreshold = MAX(0.0f, [TiUtils floatValue:[self valueForKey:@"swipeThreshold"] def:80.0f]);
    CGFloat swipeVelocityThreshold = MAX(0.0f, [TiUtils floatValue:[self valueForKey:@"swipeVelocityThreshold"] def:650.0f]);
    BOOL passedDistanceThreshold = swipeThreshold > 0.0f && fabs(distance.x) >= swipeThreshold;
    BOOL passedVelocityThreshold = swipeVelocityThreshold > 0.0f && fabs(velocity.x) >= swipeVelocityThreshold;
    BOOL shouldSwipe = passedDistanceThreshold || passedVelocityThreshold;

    NSString *direction = nil;

    if (shouldSwipe)
    {
        CGFloat directionValue = passedVelocityThreshold ? velocity.x : distance.x;
        direction = directionValue < 0.0f ? @"left" : @"right";
    }

    BOOL shouldSnapBack = !shouldSwipe && [TiUtils boolValue:[self valueForKey:@"snapBack"] def:YES];

    if (!shouldSwipe && !shouldSnapBack)
    {
        [properties setObject:@"none" forKey:@"releaseAction"];
        return NO;
    }

    NSString *releaseAction = shouldSwipe ? @"swipe" : @"snapback";
    [properties setObject:releaseAction forKey:@"releaseAction"];
    [properties setObject:[NSNumber numberWithBool:YES] forKey:@"nativeReleaseHandled"];

    if (direction != nil)
    {
        [properties setObject:direction forKey:@"direction"];
    }

    [properties setObject:[TiUtils pointToDictionary:velocity] forKey:@"velocity"];

    CGPoint currentCenter = view.center;
    CGPoint targetCenter = currentCenter;
    NSTimeInterval duration;
    CGFloat damping;

    if (shouldSwipe)
    {
        CGFloat defaultSwipeOutDistance = (parentView != nil ? parentView.bounds.size.width : view.bounds.size.width) + view.bounds.size.width;
        CGFloat swipeOutDistance = fabs([TiUtils floatValue:[self valueForKey:@"swipeOutDistance"] def:defaultSwipeOutDistance]);
        CGFloat directionMultiplier = [direction isEqualToString:@"left"] ? -1.0f : 1.0f;

        targetCenter.x = touchStartCenter.x + directionMultiplier * swipeOutDistance;
        duration = MAX(0.05, [TiUtils doubleValue:[self valueForKey:@"swipeOutDuration"] def:0.25]);
        damping = 1.0f;
    }
    else
    {
        targetCenter.x = touchStartCenter.x;
        duration = MAX(0.05, [TiUtils doubleValue:[self valueForKey:@"snapBackDuration"] def:0.42]);
        damping = MIN(1.0f, MAX(0.01f, [TiUtils floatValue:[self valueForKey:@"snapBackDamping"] def:0.84f]));
    }

    CGFloat remainingDistance = targetCenter.x - currentCenter.x;
    CGFloat initialSpringVelocity = fabs(remainingDistance) > 0.5f ? velocity.x / remainingDistance : 0.0f;
    initialSpringVelocity = MIN(20.0f, MAX(-20.0f, initialSpringVelocity));

    TiViewProxy *panningProxy = self.proxy;
    NSMutableDictionary *completionProperties = [[properties mutableCopy] autorelease];

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:initialSpringVelocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         view.center = targetCenter;
                     }
                     completion:^(BOOL finished) {
                         if (!finished)
                         {
                             return;
                         }

                         [self persistCurrentViewPositionUpdatingX:YES updatingY:NO];

                         CGRect finalFrame = view.frame;
                         [completionProperties setObject:[NSNumber numberWithFloat:finalFrame.origin.x] forKey:@"left"];
                         [completionProperties setObject:[NSNumber numberWithFloat:finalFrame.origin.y] forKey:@"top"];
                         [completionProperties setObject:[TiUtils pointToDictionary:view.center] forKey:@"center"];

                         NSString *completionEvent = shouldSwipe ? @"swipe" : @"snapback";

                         if ([panningProxy _hasListeners:completionEvent])
                         {
                             [panningProxy fireEvent:completionEvent withObject:completionProperties];
                         }
                     }];

    return YES;
}

- (void)persistCurrentViewPositionUpdatingX:(BOOL)updateX updatingY:(BOOL)updateY
{
    LayoutConstraint *layoutProperties = [self.proxy layoutProperties];
    CGRect frame = self.proxy.view.frame;

    if (updateX)
    {
        layoutProperties->left = TiDimensionDip(frame.origin.x);
    }

    if (updateY)
    {
        layoutProperties->top = TiDimensionDip(frame.origin.y);
    }

    [self.proxy refreshView:nil];
}

- (void)updateGestureCoordination
{
    NSDictionary *scrollHandoff = [self valueForKey:@"scrollHandoff"];
    BOOL enabled = [scrollHandoff isKindOfClass:[NSDictionary class]] &&
        [[scrollHandoff objectForKey:@"view"] isKindOfClass:[TiViewProxy class]];
    UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)self.gesture;

    panGesture.delegate = enabled ? self : nil;
    panGesture.cancelsTouchesInView = !enabled;
    [self setObservedScrollView:enabled ? [self configuredScrollView] : nil];

    if (!enabled)
    {
        _coordinatedScrollView = nil;
        _gestureBeganInCoordinatedScrollView = NO;
        _verticalPanOwner = TiDraggableVerticalPanOwnerNone;
    }
}

- (void)setObservedScrollView:(UIScrollView *)scrollView
{
    if (_observedScrollView == scrollView)
    {
        return;
    }

    if (_observedScrollView != nil)
    {
        [_observedScrollView removeObserver:self
                                 forKeyPath:@"contentOffset"
                                    context:kTiDraggableContentOffsetContext];
        [_observedScrollView release];
        _observedScrollView = nil;
    }

    if (scrollView != nil)
    {
        _observedScrollView = [scrollView retain];
        [_observedScrollView addObserver:self
                              forKeyPath:@"contentOffset"
                                 options:NSKeyValueObservingOptionNew
                                 context:kTiDraggableContentOffsetContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if (context == kTiDraggableContentOffsetContext)
    {
        UIGestureRecognizerState state = self.gesture.state;
        BOOL gestureIsActive = state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged;

        if (gestureIsActive && _verticalPanOwner == TiDraggableVerticalPanOwnerSheet && !_isPinningScrollView)
        {
            [self pinConfiguredScrollViewToTop];
        }

        return;
    }

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (UIScrollView *)configuredScrollView
{
    NSDictionary *scrollHandoff = [self valueForKey:@"scrollHandoff"];

    if (![scrollHandoff isKindOfClass:[NSDictionary class]])
    {
        return nil;
    }

    TiViewProxy *scrollProxy = [scrollHandoff objectForKey:@"view"];

    if (![scrollProxy isKindOfClass:[TiViewProxy class]])
    {
        return nil;
    }

    return [self firstScrollViewInView:[scrollProxy view]];
}

- (UIScrollView *)firstScrollViewInView:(UIView *)view
{
    if ([view isKindOfClass:[UIScrollView class]])
    {
        return (UIScrollView *)view;
    }

    for (UIView *subview in view.subviews)
    {
        UIScrollView *scrollView = [self firstScrollViewInView:subview];

        if (scrollView != nil)
        {
            return scrollView;
        }
    }

    return nil;
}

- (BOOL)gestureBeganInsideScrollView:(UIScrollView *)scrollView recognizer:(UIPanGestureRecognizer *)panRecognizer
{
    if (scrollView == nil || scrollView.hidden || scrollView.alpha <= 0.01f)
    {
        return NO;
    }

    CGPoint location = [panRecognizer locationInView:scrollView];
    return CGRectContainsPoint(scrollView.bounds, location);
}

- (CGFloat)topContentOffsetForScrollView:(UIScrollView *)scrollView
{
    return -scrollView.adjustedContentInset.top;
}

- (void)pinConfiguredScrollViewToTop
{
    UIScrollView *scrollView = _coordinatedScrollView ?: _observedScrollView;

    if (scrollView == nil || _isPinningScrollView)
    {
        return;
    }

    CGFloat topOffset = [self topContentOffsetForScrollView:scrollView];

    if (fabs(scrollView.contentOffset.y - topOffset) <= 0.01f)
    {
        return;
    }

    CGPoint contentOffset = scrollView.contentOffset;
    contentOffset.y = topOffset;
    _isPinningScrollView = YES;
    [scrollView setContentOffset:contentOffset animated:NO];
    _isPinningScrollView = NO;
}

- (BOOL)shouldMoveSheetForVerticalTranslation:(CGFloat)translationY
{
    if (!_gestureBeganInCoordinatedScrollView || _coordinatedScrollView == nil)
    {
        return YES;
    }

    NSDictionary *scrollHandoff = [self valueForKey:@"scrollHandoff"];
    NSString *atTopBehavior = [TiUtils stringValue:[scrollHandoff objectForKey:@"atTopBehavior"]];

    if (![atTopBehavior isEqualToString:@"scroll"] &&
        ![atTopBehavior isEqualToString:@"dismiss"] &&
        ![atTopBehavior isEqualToString:@"drag"])
    {
        atTopBehavior = @"drag";
    }

    CGFloat tolerance = MAX(0.0f, [TiUtils floatValue:[scrollHandoff objectForKey:@"topTolerance"] def:1.0f]);
    CGFloat sheetTop = self.proxy.view.frame.origin.y;
    CGFloat expandedTop = [self topHandoffPosition];
    CGFloat scrollTop = [self topContentOffsetForScrollView:_coordinatedScrollView];
    BOOL sheetIsExpanded = sheetTop <= expandedTop + tolerance;
    BOOL scrollIsAtTop = _coordinatedScrollView.contentOffset.y <= scrollTop + tolerance;

    if (!sheetIsExpanded)
    {
        // The sheet owns vertical movement until it reaches its expanded detent.
        [self pinConfiguredScrollViewToTop];
        [self setVerticalPanOwner:TiDraggableVerticalPanOwnerSheet];
        return YES;
    }

    if ([atTopBehavior isEqualToString:@"scroll"])
    {
        [self setVerticalPanOwner:TiDraggableVerticalPanOwnerScrollView];
        return NO;
    }

    if (translationY > 0.0f && scrollIsAtTop)
    {
        // Keep the content pinned so the ancestor recognizer can continue the same touch.
        [self pinConfiguredScrollViewToTop];
        [self setVerticalPanOwner:TiDraggableVerticalPanOwnerSheet];
        return YES;
    }

    if (translationY < 0.0f || !scrollIsAtTop)
    {
        [self setVerticalPanOwner:TiDraggableVerticalPanOwnerScrollView];
        return NO;
    }

    return _verticalPanOwner == TiDraggableVerticalPanOwnerSheet;
}

- (void)setVerticalPanOwner:(TiDraggableVerticalPanOwner)owner
{
    if (_verticalPanOwner == owner)
    {
        return;
    }

    _verticalPanOwner = owner;
    TiViewProxy *panningProxy = self.proxy;

    if (![panningProxy _hasListeners:@"handoff"])
    {
        return;
    }

    NSString *ownerName = owner == TiDraggableVerticalPanOwnerSheet ? @"draggable" : @"scroll";
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       ownerName, @"owner",
                                       [NSNumber numberWithFloat:self.proxy.view.frame.origin.y], @"top",
                                       nil];

    if (_coordinatedScrollView != nil)
    {
        [properties setObject:[TiUtils pointToDictionary:_coordinatedScrollView.contentOffset] forKey:@"contentOffset"];
    }

    [panningProxy fireEvent:@"handoff" withObject:properties];
}

- (NSArray *)sortedDetents
{
    id configuredDetents = [self valueForKey:@"detents"];
    NSMutableArray *detents = [NSMutableArray array];

    if ([configuredDetents isKindOfClass:[NSDictionary class]])
    {
        [(NSDictionary *)configuredDetents enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            NSNumber *top = [TiUtils numberFromObject:value];

            if (top != nil)
            {
                [detents addObject:@{ @"name" : [TiUtils stringValue:key], @"top" : top }];
            }
        }];
    }
    else if ([configuredDetents isKindOfClass:[NSArray class]])
    {
        for (id value in (NSArray *)configuredDetents)
        {
            if (![value isKindOfClass:[NSDictionary class]])
            {
                continue;
            }

            NSString *name = [TiUtils stringValue:[value objectForKey:@"name"]];
            NSNumber *top = [TiUtils numberFromObject:[value objectForKey:@"top"]];

            if ([name length] > 0 && top != nil)
            {
                [detents addObject:@{ @"name" : name, @"top" : top }];
            }
        }
    }

    [detents sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        NSComparisonResult topComparison = [[left objectForKey:@"top"] compare:[right objectForKey:@"top"]];
        return topComparison == NSOrderedSame ? [[left objectForKey:@"name"] compare:[right objectForKey:@"name"]] : topComparison;
    }];

    return detents;
}

- (NSDictionary *)detentNamed:(NSString *)name
{
    if ([name length] == 0)
    {
        return nil;
    }

    for (NSDictionary *detent in [self sortedDetents])
    {
        if ([[detent objectForKey:@"name"] isEqualToString:name])
        {
            return detent;
        }
    }

    return nil;
}

- (CGFloat)topForDetentReference:(id)reference found:(BOOL *)found
{
    NSNumber *top = [reference isKindOfClass:[NSNumber class]] ? reference : nil;

    if (top != nil)
    {
        if (found != NULL)
        {
            *found = YES;
        }
        return [top floatValue];
    }

    NSDictionary *detent = [self detentNamed:[TiUtils stringValue:reference]];

    if (found != NULL)
    {
        *found = detent != nil;
    }

    return [[detent objectForKey:@"top"] floatValue];
}

- (void)emitDetentProgressForSheetTop:(CGFloat)sheetTop interactive:(BOOL)interactive
{
    TiViewProxy *panningProxy = self.proxy;

    if (![panningProxy _hasListeners:@"detentprogress"])
    {
        return;
    }

    id configuredRanges = [self valueForKey:@"progressRanges"];
    if (![configuredRanges isKindOfClass:[NSArray class]])
    {
        return;
    }

    NSUInteger index = 0;
    for (id configuredRange in (NSArray *)configuredRanges)
    {
        if (![configuredRange isKindOfClass:[NSDictionary class]])
        {
            index++;
            continue;
        }

        NSDictionary *range = (NSDictionary *)configuredRange;
        NSString *identifier = [TiUtils stringValue:[range objectForKey:@"id"]];
        id fromReference = [range objectForKey:@"from"];
        id toReference = [range objectForKey:@"to"];
        BOOL foundFrom = NO;
        BOOL foundTo = NO;
        CGFloat fromTop = [self topForDetentReference:fromReference found:&foundFrom];
        CGFloat toTop = [self topForDetentReference:toReference found:&foundTo];

        if ([identifier length] == 0 || !foundFrom || !foundTo || fabs(toTop - fromTop) < 0.001f)
        {
            index++;
            continue;
        }

        CGFloat progress = (sheetTop - fromTop) / (toTop - fromTop);
        progress = MIN(1.0f, MAX(0.0f, progress));

        NSString *stateKey = [NSString stringWithFormat:@"%lu:%@", (unsigned long)index, identifier];
        NSNumber *lastProgress = [_lastDetentProgressValues objectForKey:stateKey];

        if (lastProgress != nil && fabs(progress - [lastProgress floatValue]) < 0.0001f)
        {
            index++;
            continue;
        }

        [_lastDetentProgressValues setObject:[NSNumber numberWithFloat:progress] forKey:stateKey];

        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             identifier, @"id",
                                             [NSNumber numberWithFloat:progress], @"progress",
                                             [NSNumber numberWithFloat:sheetTop], @"top",
                                             [NSNumber numberWithFloat:fromTop], @"fromTop",
                                             [NSNumber numberWithFloat:toTop], @"toTop",
                                             [NSNumber numberWithBool:interactive], @"interactive",
                                             nil];

        if (fromReference != nil)
        {
            [properties setObject:fromReference forKey:@"from"];
        }

        if (toReference != nil)
        {
            [properties setObject:toReference forKey:@"to"];
        }

        [panningProxy fireEvent:@"detentprogress" withObject:properties];
        index++;
    }
}

- (void)startDetentProgressTracking
{
    if (![self.proxy _hasListeners:@"detentprogress"] ||
        ![[self valueForKey:@"progressRanges"] isKindOfClass:[NSArray class]])
    {
        return;
    }

    _detentProgressDisplayLink = [[CADisplayLink displayLinkWithTarget:self selector:@selector(updateDetentProgressFromDisplayLink:)] retain];
    [_detentProgressDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDetentProgressTracking
{
    [_detentProgressDisplayLink invalidate];
    [_detentProgressDisplayLink release];
    _detentProgressDisplayLink = nil;
}

- (void)updateDetentProgressFromDisplayLink:(CADisplayLink *)displayLink
{
    if (displayLink != _detentProgressDisplayLink || ![self.proxy viewReady])
    {
        return;
    }

    CALayer *presentationLayer = (CALayer *)[self.proxy.view.layer presentationLayer];
    if (presentationLayer != nil)
    {
        [self emitDetentProgressForSheetTop:presentationLayer.frame.origin.y interactive:NO];
    }
}

- (CGFloat)topHandoffPosition
{
    NSDictionary *scrollHandoff = [self valueForKey:@"scrollHandoff"];
    NSNumber *configuredTop = [TiUtils numberFromObject:[scrollHandoff objectForKey:@"top"]];

    if (configuredTop != nil)
    {
        return [configuredTop floatValue];
    }

    NSArray *detents = [self sortedDetents];

    if ([detents count] > 0)
    {
        return [[[detents objectAtIndex:0] objectForKey:@"top"] floatValue];
    }

    NSNumber *minTop = [TiUtils numberFromObject:[self valueForKey:@"minTop"]];
    return minTop != nil ? [minTop floatValue] : self.proxy.view.frame.origin.y;
}

- (BOOL)startNativeVerticalDetentReleaseForRecognizer:(UIPanGestureRecognizer *)panRecognizer
                                           lockedAxis:(NSString *)lockedAxis
                                            properties:(NSMutableDictionary *)properties
{
    NSArray *detents = [self sortedDetents];

    if ([detents count] == 0)
    {
        return NO;
    }

    if (_gestureBeganInCoordinatedScrollView && _verticalPanOwner != TiDraggableVerticalPanOwnerSheet)
    {
        // A content-only scroll must never trigger a sheet detent release.
        return NO;
    }

    NSString *axis = [self valueForKey:@"axis"];
    CGPoint distance = CGPointMake(touchEnd.x - touchStart.x, touchEnd.y - touchStart.y);
    CGPoint velocity = [panRecognizer velocityInView:self.proxy.view.superview ?: self.proxy.view];
    BOOL isVerticalRelease = [axis isEqualToString:@"y"] ||
        ([axis isEqualToString:@"xy"] && [lockedAxis isEqualToString:@"y"]);

    if (axis == nil)
    {
        isVerticalRelease = fabs(velocity.y) > fabs(velocity.x);

        if (fabs(velocity.x) < 1.0f && fabs(velocity.y) < 1.0f)
        {
            isVerticalRelease = fabs(distance.y) > fabs(distance.x);
        }
    }

    if (!isVerticalRelease)
    {
        return NO;
    }

    CGFloat currentTop = self.proxy.view.frame.origin.y;
    CGFloat velocityThreshold = MAX(0.0f, [TiUtils floatValue:[self valueForKey:@"detentVelocityThreshold"] def:500.0f]);
    NSDictionary *targetDetent = nil;
    NSString *releaseAction = @"detent";
    NSDictionary *scrollHandoff = [self valueForKey:@"scrollHandoff"];
    NSString *atTopBehavior = [TiUtils stringValue:[scrollHandoff objectForKey:@"atTopBehavior"]];
    CGFloat dismissThreshold = MAX(0.0f, [TiUtils floatValue:[scrollHandoff objectForKey:@"dismissThreshold"] def:120.0f]);
    BOOL beganAtExpandedTop = touchStart.y <= [self topHandoffPosition] + 1.0f;
    BOOL shouldDismiss = [atTopBehavior isEqualToString:@"dismiss"] &&
        _gestureBeganInCoordinatedScrollView && beganAtExpandedTop &&
        ((dismissThreshold > 0.0f && distance.y >= dismissThreshold) ||
         (velocityThreshold > 0.0f && velocity.y >= velocityThreshold));

    if (shouldDismiss)
    {
        targetDetent = [self detentNamed:[TiUtils stringValue:[scrollHandoff objectForKey:@"dismissDetent"]]];
        targetDetent = targetDetent ?: [detents lastObject];
        releaseAction = @"dismiss";
    }
    else if (velocityThreshold > 0.0f && velocity.y >= velocityThreshold)
    {
        for (NSDictionary *detent in detents)
        {
            if ([[detent objectForKey:@"top"] floatValue] > currentTop + 1.0f)
            {
                targetDetent = detent;
                break;
            }
        }
        targetDetent = targetDetent ?: [detents lastObject];
    }
    else if (velocityThreshold > 0.0f && velocity.y <= -velocityThreshold)
    {
        for (NSDictionary *detent in [detents reverseObjectEnumerator])
        {
            if ([[detent objectForKey:@"top"] floatValue] < currentTop - 1.0f)
            {
                targetDetent = detent;
                break;
            }
        }
        targetDetent = targetDetent ?: [detents objectAtIndex:0];
    }
    else
    {
        CGFloat shortestDistance = CGFLOAT_MAX;

        for (NSDictionary *detent in detents)
        {
            CGFloat candidateDistance = fabs([[detent objectForKey:@"top"] floatValue] - currentTop);

            if (candidateDistance < shortestDistance)
            {
                shortestDistance = candidateDistance;
                targetDetent = detent;
            }
        }
    }

    if (targetDetent == nil || properties == nil)
    {
        return NO;
    }

    [properties setObject:[NSNumber numberWithBool:YES] forKey:@"nativeReleaseHandled"];
    [properties setObject:releaseAction forKey:@"releaseAction"];
    [properties setObject:[targetDetent objectForKey:@"name"] forKey:@"detent"];
    [self animateToDetent:targetDetent velocity:velocity.y animated:YES releaseAction:releaseAction properties:properties];

    return YES;
}

- (void)animateToDetent:(NSDictionary *)detent
               velocity:(CGFloat)velocity
               animated:(BOOL)animated
          releaseAction:(NSString *)releaseAction
             properties:(NSMutableDictionary *)properties
{
    if (detent == nil || ![self.proxy viewReady])
    {
        return;
    }

    [self stopDetentProgressTracking];
    _detentProgressTrackingGeneration++;
    NSUInteger progressTrackingGeneration = _detentProgressTrackingGeneration;
    BOOL shouldTrackProgress = animated && properties != nil;

    UIView *view = self.proxy.view;
    CGFloat targetTop = [[detent objectForKey:@"top"] floatValue];
    CGPoint targetCenter = view.center;
    targetCenter.y = targetTop + view.frame.size.height / 2.0f;
    CGFloat remainingDistance = targetCenter.y - view.center.y;
    CGFloat initialSpringVelocity = fabs(remainingDistance) > 0.5f ? velocity / remainingDistance : 0.0f;
    initialSpringVelocity = MIN(20.0f, MAX(-20.0f, initialSpringVelocity));
    NSTimeInterval duration = MAX(0.05, [TiUtils doubleValue:[self valueForKey:@"detentDuration"] def:0.42]);
    CGFloat damping = MIN(1.0f, MAX(0.01f, [TiUtils floatValue:[self valueForKey:@"detentDamping"] def:0.86f]));
    NSMutableDictionary *eventProperties = properties != nil ? [[properties mutableCopy] autorelease] : [NSMutableDictionary dictionary];

    [eventProperties setObject:[detent objectForKey:@"name"] forKey:@"detent"];
    [eventProperties setObject:[NSNumber numberWithFloat:targetTop] forKey:@"top"];
    [eventProperties setObject:releaseAction ?: @"detent" forKey:@"releaseAction"];

    if ([self.proxy _hasListeners:@"detentwillchange"])
    {
        [self.proxy fireEvent:@"detentwillchange" withObject:eventProperties];
    }

    void (^animations)(void) = ^{
        view.center = targetCenter;
        [self updateFollowersForSheetTop:targetTop persistLayout:NO];
    };

    void (^completion)(BOOL) = ^(BOOL finished) {
        if (shouldTrackProgress && progressTrackingGeneration == _detentProgressTrackingGeneration)
        {
            [self stopDetentProgressTracking];

            if (finished)
            {
                // Bypass the per-frame epsilon so every configured range receives
                // an exact value for the final visible sheet position.
                [_lastDetentProgressValues removeAllObjects];
                [self emitDetentProgressForSheetTop:targetTop interactive:NO];
            }
        }

        if (!finished)
        {
            return;
        }

        [self persistCurrentViewPositionUpdatingX:NO updatingY:YES];
        [self updateFollowersForSheetTop:targetTop persistLayout:YES];
        [eventProperties setObject:[TiUtils pointToDictionary:view.center] forKey:@"center"];

        if ([self.proxy _hasListeners:@"detentchange"])
        {
            [self.proxy fireEvent:@"detentchange" withObject:eventProperties];
        }

        if ([releaseAction isEqualToString:@"dismiss"] && [self.proxy _hasListeners:@"dismiss"])
        {
            [self.proxy fireEvent:@"dismiss" withObject:eventProperties];
        }
    };

    if (!animated)
    {
        animations();
        completion(YES);
        return;
    }

    if (shouldTrackProgress)
    {
        [self startDetentProgressTracking];
    }

    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:damping
          initialSpringVelocity:initialSpringVelocity
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:animations
                     completion:completion];
}

- (void)updateFollowersForSheetTop:(CGFloat)sheetTop persistLayout:(BOOL)persistLayout
{
    NSArray *followers = [self valueForKey:@"followers"];

    if (![followers isKindOfClass:[NSArray class]])
    {
        for (UIView *view in _passThroughFollowerViews)
        {
            TiDraggableSetFollowerPassThroughTouches(view, NO);
        }

        [_passThroughFollowerViews removeAllObjects];
        return;
    }

    NSMutableSet *activePassThroughViews = [NSMutableSet set];

    for (id value in followers)
    {
        if (![value isKindOfClass:[NSDictionary class]])
        {
            continue;
        }

        NSDictionary *follower = value;
        TiViewProxy *proxy = [follower objectForKey:@"view"];

        if (![proxy isKindOfClass:[TiViewProxy class]] || ![proxy viewReady])
        {
            continue;
        }

        UIView *followerView = [proxy view];
        BOOL passThroughTouches = [TiUtils boolValue:[follower objectForKey:@"passThroughTouches"] def:NO];

        TiDraggableSetFollowerPassThroughTouches(followerView, passThroughTouches);

        if (passThroughTouches)
        {
            [activePassThroughViews addObject:followerView];
        }

        if ([TiUtils boolValue:[follower objectForKey:@"bringToFront"] def:YES] && followerView.superview != nil)
        {
            [followerView.superview bringSubviewToFront:followerView];
        }

        BOOL foundAttachDetent = NO;
        CGFloat attachTop = [self topForDetentReference:[follower objectForKey:@"attachUntil"] found:&foundAttachDetent];
        // Below attachUntil the follower tracks 1:1; above it the follower is clamped.
        CGFloat anchorTop = foundAttachDetent ? MAX(sheetTop, attachTop) : sheetTop;
        id gapValue = [follower objectForKey:@"gap"];
        CGFloat offset = gapValue != nil
            ? -[TiUtils floatValue:gapValue def:12.0f]
            : [TiUtils floatValue:[follower objectForKey:@"offset"] def:-12.0f];
        CGRect frame = followerView.frame;
        frame.origin.y = anchorTop + offset - frame.size.height;
        followerView.frame = frame;

        if (persistLayout)
        {
            LayoutConstraint *layoutProperties = [proxy layoutProperties];
            layoutProperties->top = TiDimensionDip(frame.origin.y);
        }

        NSArray *fadeBetween = [follower objectForKey:@"fadeBetween"];

        if ([fadeBetween isKindOfClass:[NSArray class]] && [fadeBetween count] >= 2)
        {
            BOOL foundVisibleDetent = NO;
            BOOL foundHiddenDetent = NO;
            CGFloat visibleTop = [self topForDetentReference:[fadeBetween objectAtIndex:0] found:&foundVisibleDetent];
            CGFloat hiddenTop = [self topForDetentReference:[fadeBetween objectAtIndex:1] found:&foundHiddenDetent];

            if (foundVisibleDetent && foundHiddenDetent && fabs(hiddenTop - visibleTop) > 0.5f)
            {
                CGFloat progress = (sheetTop - visibleTop) / (hiddenTop - visibleTop);
                progress = MIN(1.0f, MAX(0.0f, progress));
                CGFloat visibleAlpha = [TiUtils floatValue:[follower objectForKey:@"visibleAlpha"] def:1.0f];
                CGFloat hiddenAlpha = [TiUtils floatValue:[follower objectForKey:@"hiddenAlpha"] def:0.0f];
                CGFloat alpha = visibleAlpha + (hiddenAlpha - visibleAlpha) * progress;
                followerView.alpha = alpha;

                if ([TiUtils boolValue:[follower objectForKey:@"disableTouchesWhenHidden"] def:YES])
                {
                    NSNumber *originalInteraction = objc_getAssociatedObject(followerView, kTiDraggableFollowerInteractionKey);

                    if (originalInteraction == nil)
                    {
                        originalInteraction = [NSNumber numberWithBool:followerView.userInteractionEnabled];
                        objc_setAssociatedObject(followerView, kTiDraggableFollowerInteractionKey, originalInteraction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }

                    followerView.userInteractionEnabled = alpha > MIN(visibleAlpha, hiddenAlpha) + 0.01f
                        ? [originalInteraction boolValue]
                        : NO;
                }
            }
        }
    }

    for (UIView *view in [[_passThroughFollowerViews copy] autorelease])
    {
        if (![activePassThroughViews containsObject:view])
        {
            TiDraggableSetFollowerPassThroughTouches(view, NO);
        }
    }

    [_passThroughFollowerViews setSet:activePassThroughViews];
}

- (void)cancelFollowerAnimations
{
    NSArray *followers = [self valueForKey:@"followers"];

    if (![followers isKindOfClass:[NSArray class]])
    {
        return;
    }

    for (NSDictionary *follower in followers)
    {
        TiViewProxy *proxy = [follower objectForKey:@"view"];

        if (![proxy isKindOfClass:[TiViewProxy class]] || ![proxy viewReady])
        {
            continue;
        }

        UIView *view = [proxy view];
        CALayer *presentationLayer = view.layer.presentationLayer;

        if (presentationLayer != nil)
        {
            view.frame = presentationLayer.frame;
            view.alpha = presentationLayer.opacity;
        }

        [view.layer removeAllAnimations];
    }
}

- (void)correctMappedProxyPositions
{
    NSArray* maps = [self valueForKey:@"maps"];

    if ([maps isKindOfClass:[NSArray class]])
    {
        [maps enumerateObjectsUsingBlock:^(id map, NSUInteger index, BOOL *stop) {
            TiViewProxy* proxy = [map objectForKey:@"view"];
            NSDictionary* constraints = [map objectForKey:@"constrain"];
            NSDictionary* constraintX = [constraints objectForKey:@"x"];
            NSDictionary* constraintY = [constraints objectForKey:@"y"];
            BOOL fromCenterX = [TiUtils boolValue:[constraintX objectForKey:@"fromCenter"] def:NO];
            BOOL fromCenterY = [TiUtils boolValue:[constraintY objectForKey:@"fromCenter"] def:NO];

            CGSize proxySize = [proxy view].frame.size;
            CGPoint proxyCenter = [proxy view].center;

            NSNumber* parallaxAmount = [TiUtils numberFromObject:[map objectForKey:@"parallaxAmount"]];

            if (! parallaxAmount)
            {
                parallaxAmount = [NSNumber numberWithInteger:1];
            }

            if (constraintX)
            {
                NSNumber* startX = [constraintX objectForKey:@"start"];

                if (fromCenterX)
                {
                    proxyCenter.x = [startX floatValue];
                    proxyCenter.x += [proxy.parent view].frame.size.width / 2;
                }
                else
                {
                    proxyCenter.x = [startX floatValue] / [parallaxAmount floatValue];
                    proxyCenter.x += proxySize.width / 2;
                }
            }

            if (constraintY)
            {
                NSNumber* startY = [constraintY objectForKey:@"start"];

                if (fromCenterY)
                {
                    proxyCenter.y = [startY floatValue];
                    proxyCenter.y += [proxy.parent view].frame.size.height / 2;
                }
                else
                {
                    proxyCenter.y = [startY floatValue] / [parallaxAmount floatValue];
                    proxyCenter.y += proxySize.height / 2;
                }
            }

            if (constraintX || constraintY)
            {
                [proxy view].center = proxyCenter;
            }

            LayoutConstraint* layoutProperties = [proxy layoutProperties];

            if (constraintX)
            {
                layoutProperties->left = TiDimensionDip([proxy view].frame.origin.x);
            }

            if (constraintY)
            {
                layoutProperties->top = TiDimensionDip([proxy view].frame.origin.y);
            }

            [proxy respositionEx];
        }];
    }
}

- (void)mapProxyOriginToCollection:(NSArray*)proxies withTranslationX:(float)translationX andTranslationY:(float)translationY
{
    if ([proxies isKindOfClass:[NSArray class]])
    {
        BOOL cancelAnimations = [TiUtils boolValue:[self valueForKey:@"cancelAnimations"] def:YES];

        [proxies enumerateObjectsUsingBlock:^(id map, NSUInteger index, BOOL *stop) {
            TiViewProxy* proxy = [map objectForKey:@"view"];

            if (cancelAnimations && [[proxy.view.layer animationKeys] count] > 0)
            {
                [proxy.view setFrame:[[proxy.view.layer presentationLayer] frame]];
                [proxy.view.layer removeAllAnimations];
            }

            CGPoint proxyCenter = [proxy view].center;
            CGSize proxySize = [proxy view].frame.size;
            CGSize parentSize = [[proxy.parent view] frame].size;

            NSNumber* parallaxAmount = [TiUtils numberFromObject:[map objectForKey:@"parallaxAmount"]];

            if (! parallaxAmount)
            {
                parallaxAmount = [NSNumber numberWithInteger:1];
            }

            NSDictionary* constraints = [map objectForKey:@"constrain"];
            NSDictionary* xConstraint = [constraints objectForKey:@"x"];
            NSDictionary* yConstraint = [constraints objectForKey:@"y"];
            NSString* constraintAxis = [constraints objectForKey:@"axis"];

            if (constraints)
            {
                if (xConstraint && ([constraintAxis isEqualToString:@"x"] || constraintAxis == nil))
                {
                    NSNumber* parentMinLeft = [self valueForKey:@"minLeft"];
                    NSNumber* parentMaxLeft = [self valueForKey:@"maxLeft"];
                    NSNumber* xStart = [xConstraint objectForKey:@"start"];
                    NSNumber* xEnd = [xConstraint objectForKey:@"end"];

                    float xDistance = [parentMaxLeft floatValue] - [parentMinLeft floatValue];
                    float xCalcCenter = proxySize.width / 2;
                    float xWidth, xRatio;
                    float xStartParallax = 0.0f;

                    if (xStart && xEnd)
                    {
                        xStartParallax = [xStart floatValue] / [parallaxAmount floatValue];
                        xWidth = fabsf(xStartParallax) + fabsf([xEnd floatValue]);
                    }
                    else
                    {
                        xWidth = proxySize.width / [parallaxAmount floatValue];
                    }

                    if (parentMinLeft || parentMaxLeft)
                    {
                        xRatio = xDistance == 0 ? 1 : xWidth / xDistance;
                    }
                    else
                    {
                        xRatio = xWidth / (parentSize.width / 2);
                    }

                    proxyCenter.x += (translationX * ([xEnd floatValue] < xStartParallax ? -1 : 1)) * xRatio;

                    if(xStart && xEnd)
                    {
                        BOOL xFromCenter = [TiUtils boolValue:[xConstraint objectForKey:@"fromCenter"] def:NO];
                        float xLeftEdge = proxyCenter.x - xCalcCenter;

                        if (xFromCenter)
                        {
                            xStart = [NSNumber numberWithFloat:[xStart floatValue] + xLeftEdge];
                            xEnd = [NSNumber numberWithFloat:[xEnd floatValue] + xLeftEdge];
                        }

                        if ([xEnd floatValue] > [xStart floatValue])
                        {
                            if(xLeftEdge > [xEnd floatValue])
                            {
                                proxyCenter.x = [xEnd floatValue] + xCalcCenter;
                            }
                            else if(xLeftEdge < xStartParallax)
                            {
                                proxyCenter.x = xStartParallax + xCalcCenter;
                            }
                        }
                        else
                        {
                            if(xLeftEdge < [xEnd floatValue])
                            {
                                proxyCenter.x = [xEnd floatValue] + xCalcCenter;
                            }
                            else if(xLeftEdge > xStartParallax)
                            {
                                proxyCenter.x = xStartParallax + xCalcCenter;
                            }
                        }

                        KrollCallback* xCallback = [xConstraint objectForKey:@"callback"];

                        if (xCallback)
                        {
                            float currentLeftEdge = proxyCenter.x - xCalcCenter;
                            float translationCompleted = fabsf((currentLeftEdge - xStartParallax) / xWidth);

                            [proxy.parent _fireEventToListener:@"translated"
                                                    withObject:@{ @"completed" : [NSNumber numberWithFloat:translationCompleted] }
                                                      listener:xCallback
                                                    thisObject:nil];
                        }
                    }
                }
                else if ([constraintAxis isEqualToString:@"x"])
                {
                    proxyCenter.x += translationX / [parallaxAmount floatValue];
                }

                if (yConstraint && ([constraintAxis isEqualToString:@"y"] || constraintAxis == nil))
                {
                    NSNumber* parentMinTop = [self valueForKey:@"minTop"];
                    NSNumber* parentMaxTop = [self valueForKey:@"maxTop"];
                    NSNumber* yStart = [yConstraint objectForKey:@"start"];
                    NSNumber* yEnd = [yConstraint objectForKey:@"end"];

                    float yDistance = [parentMaxTop floatValue] - [parentMinTop floatValue];
                    float yCalcCenter = proxySize.height / 2;
                    float yHeight, yRatio;
                    float yStartParallax = 0.0f;

                    if (yStart && yEnd)
                    {
                        yStartParallax = [yStart floatValue] / [parallaxAmount floatValue];
                        yHeight = fabsf(yStartParallax) + fabsf([yEnd floatValue]);
                    }
                    else
                    {
                        yHeight = proxySize.height / [parallaxAmount floatValue];
                    }

                    if (parentMinTop || parentMaxTop)
                    {
                        yRatio = yDistance == 0 ? 1 : yHeight / yDistance;
                    }
                    else
                    {
                        yRatio = yHeight / (parentSize.height / 2);
                    }

                    proxyCenter.y += (translationY * ([yEnd floatValue] < yStartParallax ? -1 : 1)) * yRatio;

                    if(yStart && yEnd)
                    {
                        BOOL yFromCenter = [TiUtils boolValue:[yConstraint objectForKey:@"fromCenter"] def:NO];
                        float yTopEdge = proxyCenter.y - yCalcCenter;

                        if (yFromCenter)
                        {
                            yStart = [NSNumber numberWithFloat:[yStart floatValue] + yTopEdge];
                            yEnd = [NSNumber numberWithFloat:[yEnd floatValue] + yTopEdge];
                        }

                        if ([yEnd floatValue] > [yStart floatValue])
                        {
                            if(yTopEdge > [yEnd floatValue])
                            {
                                proxyCenter.y = [yEnd floatValue] + yCalcCenter;
                            }
                            else if(yTopEdge < yStartParallax)
                            {
                                proxyCenter.y = yStartParallax + yCalcCenter;
                            }
                        }
                        else
                        {
                            if(yTopEdge < [yEnd floatValue])
                            {
                                proxyCenter.y = [yEnd floatValue] + yCalcCenter;
                            }
                            else if(yTopEdge > yStartParallax)
                            {
                                proxyCenter.y = yStartParallax + yCalcCenter;
                            }
                        }

                        KrollCallback* yCallback = [yConstraint objectForKey:@"callback"];

                        if (yCallback)
                        {
                            float currentTopEdge = proxyCenter.y - yCalcCenter;
                            float translationCompleted = fabsf((currentTopEdge - yStartParallax) / yHeight);

                            [proxy.parent _fireEventToListener:@"translated"
                                                    withObject:@{ @"completed" : [NSNumber numberWithFloat:translationCompleted] }
                                                      listener:yCallback
                                                    thisObject:nil];
                        }
                    }
                }
                else if ([constraintAxis isEqualToString:@"y"])
                {
                    proxyCenter.y += translationY / [parallaxAmount floatValue];
                }
            }
            else
            {
                proxyCenter.x += translationX / [parallaxAmount floatValue];
                proxyCenter.y += translationY / [parallaxAmount floatValue];
            }

            TiProxy* proxyDraggable = [proxy valueForKey:@"draggable"];

            NSInteger maxLeft = [[proxyDraggable valueForKey:@"maxLeft"] floatValue];
            NSInteger minLeft = [[proxyDraggable valueForKey:@"minLeft"] floatValue];
            NSInteger maxTop = [[proxyDraggable valueForKey:@"maxTop"] floatValue];
            NSInteger minTop = [[proxyDraggable valueForKey:@"minTop"] floatValue];
            BOOL hasMaxLeft = [proxyDraggable valueForKey:@"maxLeft"] != nil;
            BOOL hasMinLeft = [proxyDraggable valueForKey:@"minLeft"] != nil;
            BOOL hasMaxTop = [proxyDraggable valueForKey:@"maxTop"] != nil;
            BOOL hasMinTop = [proxyDraggable valueForKey:@"minTop"] != nil;
            BOOL ensureRight = [TiUtils boolValue:[proxyDraggable valueForKey:@"ensureRight"] def:NO];
            BOOL ensureBottom = [TiUtils boolValue:[proxyDraggable valueForKey:@"ensureBottom"] def:NO];

            if(hasMaxLeft || hasMaxTop || hasMinLeft || hasMinTop)
            {
                if(hasMaxLeft && proxyCenter.x - proxySize.width / 2 > maxLeft)
                {
                    proxyCenter.x = maxLeft + proxySize.width / 2;
                }
                else if(hasMinLeft && proxyCenter.x - proxySize.width / 2 < minLeft)
                {
                    proxyCenter.x = minLeft + proxySize.width / 2;
                }

                if(hasMaxTop && proxyCenter.y - proxySize.height / 2 > maxTop)
                {
                    proxyCenter.y = maxTop + proxySize.height / 2;
                }
                else if(hasMinTop && proxyCenter.y - proxySize.height / 2 < minTop)
                {
                    proxyCenter.y = minTop + proxySize.height / 2;
                }
            }

            LayoutConstraint* layoutProperties = [proxy layoutProperties];

            layoutProperties->top = TiDimensionDip(proxyCenter.y - proxySize.height / 2);
            layoutProperties->left = TiDimensionDip(proxyCenter.x - proxySize.width / 2);

            if (ensureBottom)
            {
                layoutProperties->bottom = TiDimensionDip(layoutProperties->top.value * -1);
            }

            if (ensureRight)
            {
                layoutProperties->right = TiDimensionDip(layoutProperties->left.value * -1);
            }
            
            [proxy respositionEx];
        }];
    }
}


#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    UIScrollView *scrollView = _coordinatedScrollView ?: [self configuredScrollView];

    if (scrollView == nil)
    {
        return NO;
    }

    return gestureRecognizer == scrollView.panGestureRecognizer ||
        otherGestureRecognizer == scrollView.panGestureRecognizer;
}

@end
