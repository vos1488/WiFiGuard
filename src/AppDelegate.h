//
//  AppDelegate.h
//  WiFiGuard
//
//  Application delegate for WiFiGuard
//

#import <UIKit/UIKit.h>

@class WGMainViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *navigationController;
@property (nonatomic, strong) WGMainViewController *mainViewController;

/// Shared instance for global access
+ (instancetype)sharedInstance;

/// Emergency kill switch - stops all operations
- (void)activateKillSwitch;

/// Check if disclaimer was accepted
- (BOOL)isDisclaimerAccepted;

/// Mark disclaimer as accepted
- (void)setDisclaimerAccepted:(BOOL)accepted;

@end
