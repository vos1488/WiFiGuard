/*
 * WGDisclaimerView.h - Legal Disclaimer View
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WGDisclaimerCompletionHandler)(BOOL accepted);
typedef void (^WGDisclaimerActionBlock)(void);

@interface WGDisclaimerView : UIView

@property (nonatomic, copy, nullable) WGDisclaimerCompletionHandler completionHandler;
@property (nonatomic, copy, nullable) WGDisclaimerActionBlock onAccept;
@property (nonatomic, copy, nullable) WGDisclaimerActionBlock onDecline;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)showInView:(UIView *)parentView;
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
