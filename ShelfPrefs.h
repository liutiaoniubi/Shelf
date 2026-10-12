#import <Foundation/Foundation.h>

@interface ShelfPrefs : NSObject

@property (nonatomic, assign, readonly) BOOL enabled;
/// 小组件位移：0 = 系统原始位置，正值 = 向下
@property (nonatomic, assign, readonly) CGFloat widgetOffset;
/// 小组件水平位移：正值 = 向右
@property (nonatomic, assign, readonly) CGFloat xOffset;
/// 通知位移：0 = 系统原始位置，正值 = 向上
@property (nonatomic, assign, readonly) CGFloat notificationOffset;

+ (instancetype)sharedPrefs;
- (void)reload;

@end
