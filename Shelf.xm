#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "ShelfPrefs.h"

#pragma mark - 弱引用注册表

@interface ShelfRegistry : NSObject
@property (nonatomic, strong) NSHashTable *quickActions;   // CSQuickActionsView
@property (nonatomic, strong) NSHashTable *prominent;      // CSProminentEmptyElementView
@property (nonatomic, strong) NSHashTable *lists;          // NCNotificationListView
+ (instancetype)sharedRegistry;
@end

@implementation ShelfRegistry

+ (instancetype)sharedRegistry {
    static ShelfRegistry *registry = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registry = [[ShelfRegistry alloc] init];
    });
    return registry;
}

- (instancetype)init {
    if ((self = [super init])) {
        _quickActions = [NSHashTable weakObjectsHashTable];
        _prominent    = [NSHashTable weakObjectsHashTable];
        _lists        = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

@end

static NSHashTable *ShelfQuickActions(void) { return [ShelfRegistry sharedRegistry].quickActions; }
static NSHashTable *ShelfProminent(void)    { return [ShelfRegistry sharedRegistry].prominent; }
static NSHashTable *ShelfLists(void)        { return [ShelfRegistry sharedRegistry].lists; }

static UIView *ShelfMatch(NSHashTable *table, UIWindow *window) {
    if (!window) return nil;
    for (UIView *view in table) {
        if (view.window == window && !CGRectIsEmpty(view.bounds)) return view;
    }
    return nil;
}

#pragma mark - 关联对象键

static char kShelfSystemCenterKey;
static char kShelfAppliedCenterKey;
static char kShelfSystemFrameKey;
static char kShelfAppliedFrameKey;
static char kShelfBusyKey;
static char kShelfDeltaKey;

#pragma mark - 几何常量（调参入口）

static CGFloat ShelfWidgetGap(void)   { return 8.0; }   // 小组件行 ↔ 快捷按钮
static CGFloat ShelfNotificationGap(void) { return 10.0; } // 通知列表 ↔ 小组件行

static BOOL ShelfNear(CGFloat a, CGFloat b) { return fabs(a - b) < 0.01; }

#pragma mark - 小组件行：绝对定位（以系统传入值为基准，防累积漂移）

static CGPoint ShelfAdjustedWidgetCenter(UIView *view, CGPoint systemCenter) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled) return systemCenter;

    NSValue *appliedValue = objc_getAssociatedObject(view, &kShelfAppliedCenterKey);
    if (appliedValue) {
        CGPoint applied = appliedValue.CGPointValue;
        if (ShelfNear(applied.x, systemCenter.x) && ShelfNear(applied.y, systemCenter.y)) {
            return systemCenter; // 回声：已是本次算过的结果
        }
    }
    objc_setAssociatedObject(view, &kShelfSystemCenterKey,
                             [NSValue valueWithCGPoint:systemCenter],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGPoint out = systemCenter;
    UIView *superview = view.superview;
    UIView *quickActions = ShelfMatch(ShelfQuickActions(), view.window);

    if (quickActions && superview) {
        CGRect qaFrame = [superview convertRect:quickActions.bounds fromView:quickActions];
        out.y = CGRectGetMinY(qaFrame) - ShelfWidgetGap() - view.bounds.size.height * 0.5;
    }
    out.y += p.widgetOffset;
    out.x += p.xOffset;

    objc_setAssociatedObject(view, &kShelfAppliedCenterKey,
                             [NSValue valueWithCGPoint:out],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return out;
}

static void ShelfRelayoutWidget(UIView *view) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled || !view.window) return;

    NSNumber *busy = objc_getAssociatedObject(view, &kShelfBusyKey);
    if (busy && busy.boolValue) return;
    objc_setAssociatedObject(view, &kShelfBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        NSValue *system = objc_getAssociatedObject(view, &kShelfSystemCenterKey);
        CGPoint base = system ? system.CGPointValue : view.center;
        CGPoint target = ShelfAdjustedWidgetCenter(view, base);
        if (!ShelfNear(view.center.x, target.x) || !ShelfNear(view.center.y, target.y)) {
            view.center = target;
        }
    } @finally {
        objc_setAssociatedObject(view, &kShelfBusyKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - 通知列表

static CGRect ShelfAdjustedListFrame(UIView *list, CGRect systemFrame) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled) return systemFrame;

    NSValue *appliedValue = objc_getAssociatedObject(list, &kShelfAppliedFrameKey);
    if (appliedValue) {
        CGRect applied = appliedValue.CGRectValue;
        if (ShelfNear(applied.origin.y, systemFrame.origin.y) &&
            ShelfNear(applied.size.height, systemFrame.size.height)) {
            return systemFrame;
        }
    }
    objc_setAssociatedObject(list, &kShelfSystemFrameKey,
                             [NSValue valueWithCGRect:systemFrame],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGRect out = systemFrame;
    UIView *superview = list.superview;
    CGFloat delta = 0.0;

    if (superview) {
        UIView *widget = ShelfMatch(ShelfProminent(), list.window);
        UIView *quickActions = ShelfMatch(ShelfQuickActions(), list.window);

        CGFloat referenceY = CGFLOAT_MAX;
        if (widget) referenceY = CGRectGetMinY([superview convertRect:widget.bounds fromView:widget]);
        if (quickActions) {
            CGFloat qaTop = CGRectGetMinY([superview convertRect:quickActions.bounds fromView:quickActions]);
            if (qaTop < referenceY) referenceY = qaTop;
        }

        if (referenceY != CGFLOAT_MAX) {
            CGFloat bottom = referenceY - ShelfNotificationGap() + p.notificationOffset;
            CGFloat candidateY = bottom - out.size.height;
            // 装不下就放弃调整，避免顶到时钟/状态栏
            if (candidateY >= CGRectGetMinY(superview.bounds)) {
                out.origin.y = candidateY;
            }
        } else {
            out.origin.y += p.notificationOffset;
        }
        delta = out.origin.y - systemFrame.origin.y;
    }

    objc_setAssociatedObject(list, &kShelfAppliedFrameKey,
                             [NSValue valueWithCGRect:out],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(list, &kShelfDeltaKey, @(delta),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return out;
}

static void ShelfRelayoutList(UIView *list) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled || !list.window) return;

    NSNumber *busy = objc_getAssociatedObject(list, &kShelfBusyKey);
    if (busy && busy.boolValue) return;
    objc_setAssociatedObject(list, &kShelfBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        NSValue *system = objc_getAssociatedObject(list, &kShelfSystemFrameKey);
        CGRect base = system ? system.CGRectValue : list.frame;
        CGRect target = ShelfAdjustedListFrame(list, base);
        if (!ShelfNear(list.frame.origin.y, target.origin.y) ||
            !ShelfNear(list.frame.size.height, target.size.height)) {
            list.frame = target;
        }
    } @finally {
        objc_setAssociatedObject(list, &kShelfBusyKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - "N 条更多通知" 胶囊：跟随列表位移

static CGPoint ShelfAdjustedIndicatorCenter(UIView *view, CGPoint systemCenter) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled) return systemCenter;

    NSValue *appliedValue = objc_getAssociatedObject(view, &kShelfAppliedCenterKey);
    if (appliedValue) {
        CGPoint applied = appliedValue.CGPointValue;
        if (ShelfNear(applied.y, systemCenter.y)) return systemCenter;
    }

    CGFloat delta = 0.0;
    UIView *list = ShelfMatch(ShelfLists(), view.window);
    if (list) {
        NSNumber *stored = objc_getAssociatedObject(list, &kShelfDeltaKey);
        if (stored) delta = stored.doubleValue;
    }

    CGPoint out = systemCenter;
    out.y += delta;
    objc_setAssociatedObject(view, &kShelfAppliedCenterKey,
                             [NSValue valueWithCGPoint:out],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return out;
}

#pragma mark - 层级查找与批量刷新

static UIView *ShelfFindSubview(UIView *root, Class cls, NSInteger depth) {
    if (!root || !cls || depth < 0) return nil;
    for (UIView *subview in root.subviews) {
        if ([subview isKindOfClass:cls]) return subview;
    }
    if (depth == 0) return nil;
    for (UIView *subview in root.subviews) {
        UIView *found = ShelfFindSubview(subview, cls, depth - 1);
        if (found) return found;
    }
    return nil;
}

static void ShelfRefreshWindow(UIWindow *window) {
    if (!window) return;
    for (UIView *view in ShelfProminent()) {
        if (view.window == window) ShelfRelayoutWidget(view);
    }
    for (UIView *list in ShelfLists()) {
        if (list.window == window) ShelfRelayoutList(list);
    }
}

static void ShelfRefreshAll(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *view in ShelfProminent()) ShelfRelayoutWidget(view);
        for (UIView *list in ShelfLists()) ShelfRelayoutList(list);
    });
}

static void ShelfPrefsChanged(CFNotificationCenterRef center,
                              void *observer,
                              CFStringRef name,
                              const void *object,
                              CFDictionaryRef userInfo) {
    [[ShelfPrefs sharedPrefs] reload];
    ShelfRefreshAll();
}

#pragma mark - Hooks
// 每个类单独成组：类不存在时跳过 %init，避免 MSHookMessageEx 传 nil 崩溃

%group G_QuickActions
%hook CSQuickActionsView
- (void)didMoveToWindow {
    %orig;
    if (self.window) [ShelfQuickActions() addObject:self];
    else             [ShelfQuickActions() removeObject:self];
    ShelfRefreshWindow(self.window);
}
- (void)layoutSubviews {
    %orig;
    ShelfRefreshWindow(self.window);
}
%end
%end

%group G_Prominent
%hook CSProminentEmptyElementView
- (void)didMoveToWindow {
    %orig;
    if (self.window) [ShelfProminent() addObject:self];
    else             [ShelfProminent() removeObject:self];
    ShelfRelayoutWidget(self);
}
- (void)layoutSubviews {
    %orig;
    ShelfRelayoutWidget(self);
}
- (void)setCenter:(CGPoint)center {
    %orig(ShelfAdjustedWidgetCenter(self, center));
}
%end
%end

%group G_Display
%hook CSProminentDisplayView
- (void)layoutSubviews {
    %orig;
    ShelfRefreshWindow(self.window);
}
%end
%end

%group G_List
%hook NCNotificationListView
- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [ShelfLists() addObject:self];
        ShelfRelayoutList(self);
    } else {
        [ShelfLists() removeObject:self];
    }
}
%end
%end

%group G_StructuredVC
%hook NCNotificationStructuredListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *list = ShelfFindSubview(self.view, NSClassFromString(@"NCNotificationListView"), 6);
    if (list) ShelfRelayoutList(list);
}
%end
%end

%group G_Indicator
%hook NCNotificationListCountIndicatorView
- (void)setCenter:(CGPoint)center {
    %orig(ShelfAdjustedIndicatorCenter(self, center));
}
- (void)layoutSubviews {
    %orig;
    CGPoint target = ShelfAdjustedIndicatorCenter(self, self.center);
    if (!ShelfNear(self.center.y, target.y)) self.center = target;
}
%end
%end

%group G_Combined
%hook CSCombinedListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ShelfRefreshWindow(self.view.window);
}
%end
%end

#pragma mark - 构造

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isSpringBoard = [bundleID isEqualToString:@"com.apple.springboard"];
    BOOL isPosterBoard = [bundleID isEqualToString:@"com.apple.PosterBoard"];
    if (!isSpringBoard && !isPosterBoard) return;

    [[ShelfPrefs sharedPrefs] reload];

    if (objc_getClass("CSQuickActionsView"))                    %init(G_QuickActions);
    if (objc_getClass("CSProminentEmptyElementView"))           %init(G_Prominent);
    if (objc_getClass("CSProminentDisplayView"))                %init(G_Display);
    if (objc_getClass("NCNotificationListView"))                %init(G_List);
    if (objc_getClass("NCNotificationStructuredListViewController")) %init(G_StructuredVC);
    if (objc_getClass("NCNotificationListCountIndicatorView"))  %init(G_Indicator);
    if (objc_getClass("CSCombinedListViewController"))          %init(G_Combined);

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    ShelfPrefsChanged,
                                    CFSTR("com.shelf.prefs/ReloadPrefs"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
}
