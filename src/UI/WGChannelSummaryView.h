/*
 * WGChannelSummaryView.h - Channel Congestion Summary
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class WGChannelStats;

@interface WGChannelSummaryView : UIView

- (void)updateWithStatistics:(NSArray<WGChannelStats *> *)stats;

@end

NS_ASSUME_NONNULL_END
