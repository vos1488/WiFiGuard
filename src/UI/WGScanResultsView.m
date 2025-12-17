/*
 * WGScanResultsView.m - Scan Results Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGScanResultsView.h"
#import "WGWiFiScanner.h"

@implementation WGScanResultsView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];
    }
    return self;
}

- (void)reloadData {
    [self setNeedsDisplay];
}

@end
