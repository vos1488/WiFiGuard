/*
 * WGARPAlertView.m - ARP Alert Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGARPAlertView.h"
#import "WGARPDetector.h"

@interface WGARPAlertView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIImageView *iconView;

@end

@implementation WGARPAlertView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor systemRedColor];
    self.layer.cornerRadius = 12;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowOpacity = 0.3;
    self.layer.shadowRadius = 8;
    
    _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"exclamationmark.triangle.fill"]];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.tintColor = [UIColor whiteColor];
    [self addSubview:_iconView];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.text = @"ARP Anomaly Detected!";
    [self addSubview:_titleLabel];
    
    _detailLabel = [[UILabel alloc] init];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font = [UIFont systemFontOfSize:13];
    _detailLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    _detailLabel.numberOfLines = 2;
    [self addSubview:_detailLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:32],
        [_iconView.heightAnchor constraintEqualToConstant:32],
        
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16]
    ]];
}

- (void)showAnomaly:(WGARPAnomaly *)anomaly {
    switch (anomaly.type) {
        case WGARPAnomalyTypeGatewayMACChange:
            self.backgroundColor = [UIColor systemRedColor];
            self.titleLabel.text = @"🚨 Critical: Gateway MAC Changed!";
            break;
        case WGARPAnomalyTypeMACChange:
            self.backgroundColor = [UIColor systemOrangeColor];
            self.titleLabel.text = @"⚠️ Warning: MAC Address Changed";
            break;
        case WGARPAnomalyTypeDuplicateMAC:
            self.backgroundColor = [UIColor systemOrangeColor];
            self.titleLabel.text = @"⚠️ Warning: Duplicate MAC Detected";
            break;
        default:
            self.backgroundColor = [UIColor systemYellowColor];
            self.titleLabel.text = @"⚠️ ARP Anomaly Detected";
            break;
    }
    
    self.detailLabel.text = [anomaly localizedDescription];
    
    // Animate in
    self.alpha = 0;
    self.transform = CGAffineTransformMakeTranslation(0, -50);
    self.hidden = NO;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    }];
    
    // Auto dismiss after 5 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

- (void)dismiss {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeTranslation(0, -50);
    } completion:^(BOOL finished) {
        self.hidden = YES;
    }];
}

@end
