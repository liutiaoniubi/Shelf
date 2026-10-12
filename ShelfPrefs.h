#import <Foundation/Foundation.h>

@interface ShelfPrefs : NSObject

@property (nonatomic, assign, readonly) BOOL enabled;
/// 正值 = 向下微调
@property (nonatomic, assign, readonly) CGFloat widgetOffset;
/// 正值 = 向右
@property (nonatomic, assign, readonly) CGFloat xOffset;
/// 正值 = 向下微调
@property (nonatomic, assign, readonly) CGFloat notificationOffset;

+ (instancetype)sharedPrefs;
- (void)reload;

@end
