/*
 * WGDisclaimerView.m - Disclaimer Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGDisclaimerView.h"

@interface WGDisclaimerView ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITextView *disclaimerText;
@property (nonatomic, strong) UISwitch *confirmSwitch;
@property (nonatomic, strong) UIButton *acceptButton;

@end

@implementation WGDisclaimerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    
    // Container
    _containerView = [[UIView alloc] init];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView.backgroundColor = [UIColor systemBackgroundColor];
    _containerView.layer.cornerRadius = 16;
    _containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    _containerView.layer.shadowOffset = CGSizeMake(0, 4);
    _containerView.layer.shadowOpacity = 0.3;
    _containerView.layer.shadowRadius = 16;
    [self addSubview:_containerView];
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"⚠️ Legal Disclaimer";
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [_containerView addSubview:titleLabel];
    
    // Disclaimer text
    _disclaimerText = [[UITextView alloc] init];
    _disclaimerText.translatesAutoresizingMaskIntoConstraints = NO;
    _disclaimerText.editable = NO;
    _disclaimerText.font = [UIFont systemFontOfSize:14];
    _disclaimerText.textColor = [UIColor secondaryLabelColor];
    _disclaimerText.text = 
        @"WiFiGuard - Passive Wi-Fi Network Analyzer\n\n"
        @"LEGAL NOTICE:\n\n"
        @"This tool performs PASSIVE ANALYSIS ONLY. No active attacks are implemented or supported.\n\n"
        @"By using this tool, you confirm that:\n\n"
        @"1. You are the owner of the network(s) you will analyze, OR\n\n"
        @"2. You have explicit WRITTEN PERMISSION from the network owner to perform analysis.\n\n"
        @"UNAUTHORIZED NETWORK MONITORING IS ILLEGAL in most jurisdictions and may result in criminal prosecution.\n\n"
        @"The developers of this tool accept NO RESPONSIBILITY for any misuse or illegal activity conducted with this software.\n\n"
        @"This confirmation will be logged for audit purposes.\n\n"
        @"---\n\n"
        @"NETWORK OWNER PERMISSION TEMPLATE:\n\n"
        @"I, [Owner Name], owner/administrator of the network [Network SSID], grant permission to [Your Name] to perform passive Wi-Fi network analysis for [Purpose] on [Date].\n\n"
        @"Signed: _______________\n"
        @"Date: _______________";
    [_containerView addSubview:_disclaimerText];
    
    // Confirm switch row
    UIView *switchRow = [[UIView alloc] init];
    switchRow.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:switchRow];
    
    _confirmSwitch = [[UISwitch alloc] init];
    _confirmSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
    [switchRow addSubview:_confirmSwitch];
    
    UILabel *switchLabel = [[UILabel alloc] init];
    switchLabel.translatesAutoresizingMaskIntoConstraints = NO;
    switchLabel.text = @"I confirm I own or have permission to analyze the target network(s)";
    switchLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    switchLabel.numberOfLines = 2;
    [switchRow addSubview:switchLabel];
    
    // Accept button
    _acceptButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _acceptButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_acceptButton setTitle:@"Accept & Continue" forState:UIControlStateNormal];
    [_acceptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _acceptButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    _acceptButton.backgroundColor = [UIColor systemGrayColor];
    _acceptButton.layer.cornerRadius = 12;
    _acceptButton.enabled = NO;
    [_acceptButton addTarget:self action:@selector(acceptTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_acceptButton];
    
    // Cancel button
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:cancelButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [_containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_containerView.widthAnchor constraintEqualToConstant:340],
        [_containerView.heightAnchor constraintLessThanOrEqualToConstant:600],
        
        [titleLabel.topAnchor constraintEqualToAnchor:_containerView.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-20],
        
        [_disclaimerText.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [_disclaimerText.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
        [_disclaimerText.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
        [_disclaimerText.heightAnchor constraintEqualToConstant:300],
        
        [switchRow.topAnchor constraintEqualToAnchor:_disclaimerText.bottomAnchor constant:16],
        [switchRow.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
        [switchRow.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
        
        [_confirmSwitch.leadingAnchor constraintEqualToAnchor:switchRow.leadingAnchor],
        [_confirmSwitch.centerYAnchor constraintEqualToAnchor:switchRow.centerYAnchor],
        
        [switchLabel.leadingAnchor constraintEqualToAnchor:_confirmSwitch.trailingAnchor constant:12],
        [switchLabel.trailingAnchor constraintEqualToAnchor:switchRow.trailingAnchor],
        [switchLabel.centerYAnchor constraintEqualToAnchor:switchRow.centerYAnchor],
        [switchRow.heightAnchor constraintEqualToConstant:50],
        
        [_acceptButton.topAnchor constraintEqualToAnchor:switchRow.bottomAnchor constant:16],
        [_acceptButton.leadingAnchor constraintEqualToAnchor:_containerView.leadingAnchor constant:16],
        [_acceptButton.trailingAnchor constraintEqualToAnchor:_containerView.trailingAnchor constant:-16],
        [_acceptButton.heightAnchor constraintEqualToConstant:50],
        
        [cancelButton.topAnchor constraintEqualToAnchor:_acceptButton.bottomAnchor constant:12],
        [cancelButton.centerXAnchor constraintEqualToAnchor:_containerView.centerXAnchor],
        [cancelButton.bottomAnchor constraintEqualToAnchor:_containerView.bottomAnchor constant:-16]
    ]];
}

- (void)switchChanged {
    self.acceptButton.enabled = self.confirmSwitch.isOn;
    self.acceptButton.backgroundColor = self.confirmSwitch.isOn ? 
        [UIColor systemGreenColor] : [UIColor systemGrayColor];
}

- (void)acceptTapped {
    if (self.completionHandler) {
        self.completionHandler(YES);
    }
    if (self.onAccept) {
        self.onAccept();
    }
    [self dismiss];
}

- (void)cancelTapped {
    if (self.completionHandler) {
        self.completionHandler(NO);
    }
    if (self.onDecline) {
        self.onDecline();
    }
    [self dismiss];
}

- (void)showInView:(UIView *)parentView {
    self.frame = parentView.bounds;
    self.alpha = 0;
    self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [parentView addSubview:self];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
        self.containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
        self.containerView.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
