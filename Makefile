ARCHS = arm64e
TARGET := iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Shelf
Shelf_FILES = Shelf.xm ShelfPrefs.m
Shelf_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
Shelf_FRAMEWORKS = UIKit Foundation CoreFoundation
Shelf_LIBRARIES = substrate

SUBPROJECTS = prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
