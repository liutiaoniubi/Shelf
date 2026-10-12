#import "ShelfPrefs.h"

static NSString *const kShelfSuiteName              = @"com.shelf.prefs";
static NSString *const kShelfEnabledKey              = @"enabled";
static NSString *const kShelfWidgetOffsetKey         = @"widgetOffset";
static NSString *const kShelfXOffsetKey              = @"xOffset";
static NSString *const kShelfNotificationOffsetKey   = @"notificationOffset";

@interface ShelfPrefs ()
@property (nonatomic, assign, readwrite) BOOL enabled;
@property (nonatomic, assign, readwrite) CGFloat widgetOffset;
@property (nonatomic, assign, readwrite) CGFloat xOffset;
@property (nonatomic, assign, readwrite) CGFloat notificationOffset;
@end

@implementation ShelfPrefs {
    NSUserDefaults *_defaults;
}

+ (instancetype)sharedPrefs {
    static ShelfPrefs *prefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefs = [[ShelfPrefs alloc] init];
    });
    return prefs;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSUserDefaults *suite = [[NSUserDefaults alloc] initWithSuiteName:kShelfSuiteName];
        _defaults = suite ?: [NSUserDefaults standardUserDefaults];
        [_defaults registerDefaults:@{
            kShelfEnabledKey: @YES,
            kShelfWidgetOffsetKey: @0.0,
            kShelfXOffsetKey: @0.0,
            kShelfNotificationOffsetKey: @0.0
        }];
        [self reload];
    }
    return self;
}

- (void)reload {
    [_defaults synchronize];
    self.enabled            = [_defaults boolForKey:kShelfEnabledKey];
    self.widgetOffset       = [_defaults floatForKey:kShelfWidgetOffsetKey];
    self.xOffset            = [_defaults floatForKey:kShelfXOffsetKey];
    self.notificationOffset = [_defaults floatForKey:kShelfNotificationOffsetKey];
}

@end
