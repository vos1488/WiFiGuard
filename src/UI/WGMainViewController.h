/*
 * WGMainViewController.h - Main Interface Controller
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WGWiFiScanner;
@class WGARPDetector;
@class WGAuditLogger;

@interface WGMainViewController : UIViewController

@property (nonatomic, strong) WGWiFiScanner *wifiScanner;
@property (nonatomic, strong) WGARPDetector *arpDetector;
@property (nonatomic, strong) WGAuditLogger *auditLogger;

@end

NS_ASSUME_NONNULL_END
