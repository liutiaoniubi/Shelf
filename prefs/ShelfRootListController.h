#import <UIKit/UIKit.h>

// 不引入 Preferences 私有头文件，只做前向声明；
// 运行时由设置进程里已加载的 Preferences.framework 解析真正的 PSListController。
@interface PSListController : UIViewController
- (id)specifiers;
- (void)reloadSpecifiers;
@end

@interface ShelfRootListController : PSListController
@end
