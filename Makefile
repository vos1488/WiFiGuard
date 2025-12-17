# WiFiGuard - Passive Wi-Fi Network Analyzer for iOS 16.1.2 (Dopamine Rootless)
# Educational/Lab use only - No active attacks implemented
# Standalone Application

THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

TARGET := iphone:clang:latest:16.0

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = WiFiGuard

WiFiGuard_FILES = src/main.m \
                  src/AppDelegate.m \
                  src/Core/WGWiFiScanner.m \
                  src/Core/WGARPDetector.m \
                  src/Core/WGAuditLogger.m \
                  src/Core/WGDataExporter.m \
                  src/Core/WGSimulationEngine.m \
                  src/UI/WGMainViewController.m \
                  src/UI/WGScanResultsView.m \
                  src/UI/WGRSSIGraphView.m \
                  src/UI/WGChannelSummaryView.m \
                  src/UI/WGARPAlertView.m \
                  src/UI/WGDisclaimerView.m \
                  src/UI/WGSettingsViewController.m \
                  src/Utils/WGSecureStorage.m \
                  src/Utils/WGEncryption.m \
                  src/Utils/WGNetworkUtils.m

WiFiGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Isrc -Isrc/Core -Isrc/Utils -Isrc/UI
WiFiGuard_LDFLAGS = -lMobileGestalt -weak_framework MobileWiFi
WiFiGuard_FRAMEWORKS = UIKit Foundation CoreFoundation SystemConfiguration Security
WiFiGuard_CODESIGN_FLAGS = -Sentitlements.plist

# Rootless support for Dopamine
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS_MAKE_PATH)/application.mk

# Development targets
.PHONY: clean-all package-debug

clean-all:
	rm -rf .theos packages obj

package-debug:
	$(MAKE) package DEBUG=1
