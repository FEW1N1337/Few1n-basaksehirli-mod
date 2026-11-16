ARCHS = arm64
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = basaksehirli

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FEW1NBasaksehirli

FEW1NBasaksehirli_FILES = FEW1NBasaksehirli.m
FEW1NBasaksehirli_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
FEW1NBasaksehirli_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
