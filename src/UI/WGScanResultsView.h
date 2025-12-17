/*
 * WGScanResultsView.h - Scan Results View
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WGNetworkInfo;

@interface WGScanResultsView : UIView

@property (nonatomic, strong) NSArray<WGNetworkInfo *> *networks;

- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
