/*
 * WGARPAlertView.h - ARP Alert Display
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WGARPAnomaly;

@interface WGARPAlertView : UIView

- (void)showAnomaly:(WGARPAnomaly *)anomaly;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
