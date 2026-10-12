#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "ShelfPrefs.h"

#pragma mark - 私有类声明

@interface CSQuickActionsView : UIView
@end
@interface CSProminentEmptyElementView : UIView
@end
@interface CSProminentDisplayView : UIView
@end
@interface NCNotificationListView : UIView
@end
@interface NCNotificationListCountIndicatorView : UIView
@end
@interface NCNotificationStructuredListViewController : UIViewController
@end
@interface CSCombinedListViewController : UIViewController
@end

#pragma mark - 注册表

@interface ShelfRegistry : NSObject
@property (nonatomic, strong) NSHashTable *prominent;
@property (nonatomic, strong) NSHashTable *lists;
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
        _prominent = [NSHashTable weakObjectsHashTable];
        _lists     = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

@end

static NSHashTable *ShelfProminent(void) { return [ShelfRegistry sharedRegistry].prominent; }
static NSHashTable *ShelfLists(void)     { return [ShelfRegistry sharedRegistry].lists; }

#pragma mark - 关联对象键

static char kShelfBusyKey;
static char kShelfListDeltaKey;

#pragma mark - 类名子串搜索

static UIView *ShelfFindByClassName(UIView *root, NSString *sub, NSInteger depth) {
    if (!root || !sub || depth < 0) return nil;
    NSString *cls = NSStringFromClass([root class]);
    if (cls && [cls rangeOfString:sub options:NSCaseInsensitiveSearch].location != NSNotFound) {
        if (!CGRectIsEmpty(root.bounds)) return root;
    }
    if (depth == 0) return nil;
    for (UIView *v in root.subviews) {
        UIView *found = ShelfFindByClassName(v, sub, depth - 1);
        if (found) return found;
    }
    return nil;
}

#pragma mark - 小组件：相对位移，正值向下

static void ShelfApplyWidget(UIView *view) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!view.window) return;

    NSNumber *busy = objc_getAssociatedObject(view, &kShelfBusyKey);
    if (busy && busy.boolValue) return;
    objc_setAssociatedObject(view, &kShelfBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        if (!p.enabled) {
            view.transform = CGAffineTransformIdentity;
            return;
        }
        CGFloat dy = p.widgetOffset;
        CGFloat dx = p.xOffset;
        if (fabs(dy) < 0.5 && fabs(dx) < 0.5) {
            view.transform = CGAffineTransformIdentity;
        } else {
            view.transform = CGAffineTransformMakeTranslation(dx, dy);
        }
    } @finally {
        objc_setAssociatedObject(view, &kShelfBusyKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - 通知列表：相对位移，正值向上

static void ShelfApplyList(UIView *list) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!list.window) return;

    NSNumber *busy = objc_getAssociatedObject(list, &kShelfBusyKey);
    if (busy && busy.boolValue) return;
    objc_setAssociatedObject(list, &kShelfBusyKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        if (!p.enabled) {
            list.transform = CGAffineTransformIdentity;
            objc_setAssociatedObject(list, &kShelfListDeltaKey, @0.0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        CGFloat dy = -p.notificationOffset;   // 正值 = 向上
        if (fabs(dy) < 0.5) {
            list.transform = CGAffineTransformIdentity;
        } else {
            list.transform = CGAffineTransformMakeTranslation(0, dy);
        }
        objc_setAssociatedObject(list, &kShelfListDeltaKey, @(dy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        objc_setAssociatedObject(list, &kShelfBusyKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - 更多通知胶囊：跟随列表

static void ShelfApplyIndicator(UIView *view) {
    ShelfPrefs *p = [ShelfPrefs sharedPrefs];
    if (!p.enabled || !view.window) return;
    for (UIView *list in ShelfLists()) {
        if (list.window == view.window) {
            NSNumber *delta = objc_getAssociatedObject(list, &kShelfListDeltaKey);
            CGFloat dy = delta ? delta.doubleValue : 0.0;
            if (fabs(dy) < 0.5) view.transform = CGAffineTransformIdentity;
            else                view.transform = CGAffineTransformMakeTranslation(0, dy);
            return;
        }
    }
}

#pragma mark - 扫描与刷新

static void ShelfScanWindow(UIWindow *window) {
    if (!window || window.hidden) return;
    UIView *pm = ShelfFindByClassName(window, @"Prominent", 8);
    if (pm) [ShelfProminent() addObject:pm];
    UIView *ls = ShelfFindByClassName(window, @"NotificationListView", 10);
    if (ls) [ShelfLists() addObject:ls];
}

static void ShelfRefreshWindow(UIWindow *window) {
    if (!window) return;
    ShelfScanWindow(window);
    for (UIView *view in ShelfProminent()) {
        if (view.window == window) ShelfApplyWidget(view);
    }
    for (UIView *list in ShelfLists()) {
        if (list.window == window) ShelfApplyList(list);
    }
}

static void ShelfRefreshAll(void) {
    for (UIView *view in ShelfProminent()) ShelfApplyWidget(view);
    for (UIView *list in ShelfLists())     ShelfApplyList(list);
}

static void ShelfScanAllWindows(void) {
    NSArray *windows = nil;
    @try {
        windows = [UIApplication sharedApplication].windows;
    } @catch (NSException *e) {
        windows = nil;
    }
    for (UIWindow *w in windows) ShelfScanWindow(w);
    ShelfRefreshAll();
}

static void ShelfPrefsChanged(CFNotificationCenterRef center,
                              void *observer,
                              CFStringRef name,
                              const void *object,
                              CFDictionaryRef userInfo) {
    [[ShelfPrefs sharedPrefs] reload];
    dispatch_async(dispatch_get_main_queue(), ^{
        ShelfScanAllWindows();
    });
}

#pragma mark - Hooks

%group G_Prominent
%hook CSProminentEmptyElementView
- (void)didMoveToWindow {
    %orig;
    UIView *v = (UIView *)self;
    if (v.window) [ShelfProminent() addObject:v];
    else          [ShelfProminent() removeObject:v];
    ShelfApplyWidget(v);
}
- (void)layoutSubviews {
    %orig;
    ShelfApplyWidget((UIView *)self);
}
%end
%end

%group G_Display
%hook CSProminentDisplayView
- (void)layoutSubviews {
    %orig;
    ShelfRefreshWindow(((UIView *)self).window);
}
%end
%end

%group G_List
%hook NCNotificationListView
- (void)didMoveToWindow {
    %orig;
    UIView *v = (UIView *)self;
    if (v.window) {
        [ShelfLists() addObject:v];
        ShelfApplyList(v);
    } else {
        [ShelfLists() removeObject:v];
    }
}
- (void)layoutSubviews {
    %orig;
    ShelfApplyList((UIView *)self);
}
%end
%end

%group G_StructuredVC
%hook NCNotificationStructuredListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *root = ((UIViewController *)self).view;
    UIView *list = ShelfFindByClassName(root, @"NotificationListView", 8);
    if (list) {
        if (list.window) [ShelfLists() addObject:list];
        ShelfApplyList(list);
    }
    ShelfRefreshWindow(root.window);
}
%end
%end

%group G_Indicator
%hook NCNotificationListCountIndicatorView
- (void)layoutSubviews {
    %orig;
    ShelfApplyIndicator((UIView *)self);
}
%end
%end

%group G_Combined
%hook CSCombinedListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ShelfRefreshWindow(((UIViewController *)self).view.window);
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

    if (objc_getClass("CSProminentEmptyElementView"))           %init(G_Prominent);
    if (objc_getClass("CSProminentDisplayView"))                %init(G_Display);
    if (objc_getClass("NCNotificationListView"))                %init(G_List);
    if (objc_getClass("NCNotificationStructuredListViewController")) %init(G_StructuredVC);
    if (objc_getClass("NCNotificationListCountIndicatorView"))  %init(G_Indicator);
    if (objc_getClass("CSCombinedListViewController"))          %init(G_Combined);

    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 1; i <= 4; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                ShelfScanAllWindows();
            });
        }
    });

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    ShelfPrefsChanged,
                                    CFSTR("com.shelf.prefs/ReloadPrefs"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
}
