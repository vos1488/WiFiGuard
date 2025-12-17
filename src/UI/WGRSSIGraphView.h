/*
 * WGRSSIGraphView.h - RSSI Time Graph View
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WGNetworkInfo;

@interface WGRSSIGraphView : UIView

@property (nonatomic, strong) NSMutableArray<WGNetworkInfo *> *trackedNetworks;
@property (nonatomic, assign) NSTimeInterval timeWindow; // Default 60 seconds

- (void)trackNetwork:(WGNetworkInfo *)network;
- (void)stopTrackingNetwork:(WGNetworkInfo *)network;
- (void)updateNetwork:(WGNetworkInfo *)network;
- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
