/*
 * WGDisclaimerView.h - Legal Disclaimer View
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WGDisclaimerCompletionHandler)(BOOL accepted);

@interface WGDisclaimerView : UIView

@property (nonatomic, copy) WGDisclaimerCompletionHandler completionHandler;

- (void)showInView:(UIView *)parentView;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
