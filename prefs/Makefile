include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShelfPrefs
ShelfPrefs_FILES = ShelfRootListController.m
ShelfPrefs_INSTALL_PATH = /Library/PreferenceBundles
ShelfPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ShelfPrefs_FRAMEWORKS = UIKit Foundation

# 不链接 Preferences 私有框架：CI 的 iOS SDK 里没有它。
# 运行时由加载本 bundle 的设置进程提供 PSListController，
# 因此允许未定义符号，交给动态查找解析。
ShelfPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
