/*
 * WGChannelSummaryView.m - Channel Summary Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGChannelSummaryView.h"
#import "../Core/WGWiFiScanner.h"

@interface WGChannelSummaryView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *recommendationLabel;
@property (nonatomic, strong) UIStackView *channelBarsStack;
@property (nonatomic, strong) NSArray<WGChannelStats *> *currentStats;

@end

@implementation WGChannelSummaryView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [UIColor systemBackgroundColor];
    self.layer.cornerRadius = 12;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor systemGray4Color].CGColor;
    
    // Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"📡 Channel Congestion (2.4 GHz)";
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self addSubview:_titleLabel];
    
    // Recommendation
    _recommendationLabel = [[UILabel alloc] init];
    _recommendationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recommendationLabel.text = @"Recommended: —";
    _recommendationLabel.font = [UIFont systemFontOfSize:14];
    _recommendationLabel.textColor = [UIColor systemGreenColor];
    [self addSubview:_recommendationLabel];
    
    // Channel bars container
    _channelBarsStack = [[UIStackView alloc] init];
    _channelBarsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _channelBarsStack.axis = UILayoutConstraintAxisHorizontal;
    _channelBarsStack.spacing = 4;
    _channelBarsStack.distribution = UIStackViewDistributionFillEqually;
    _channelBarsStack.alignment = UIStackViewAlignmentBottom;
    [self addSubview:_channelBarsStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        
        [_recommendationLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_recommendationLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        
        [_channelBarsStack.topAnchor constraintEqualToAnchor:_recommendationLabel.bottomAnchor constant:16],
        [_channelBarsStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_channelBarsStack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_channelBarsStack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-40]
    ]];
    
    // Create initial channel bars for channels 1-14
    [self createChannelBars];
}

- (void)createChannelBars {
    for (NSInteger channel = 1; channel <= 14; channel++) {
        UIView *barContainer = [[UIView alloc] init];
        barContainer.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Bar
        UIView *bar = [[UIView alloc] init];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.backgroundColor = [UIColor systemGray4Color];
        bar.layer.cornerRadius = 3;
        bar.tag = 100 + channel;
        [barContainer addSubview:bar];
        
        // Channel label
        UILabel *label = [[UILabel alloc] init];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.text = [NSString stringWithFormat:@"%ld", (long)channel];
        label.font = [UIFont systemFontOfSize:10];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor secondaryLabelColor];
        [barContainer addSubview:label];
        
        // Count label
        UILabel *countLabel = [[UILabel alloc] init];
        countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        countLabel.text = @"0";
        countLabel.font = [UIFont systemFontOfSize:9];
        countLabel.textAlignment = NSTextAlignmentCenter;
        countLabel.textColor = [UIColor tertiaryLabelColor];
        countLabel.tag = 200 + channel;
        [barContainer addSubview:countLabel];
        
        [NSLayoutConstraint activateConstraints:@[
            [bar.bottomAnchor constraintEqualToAnchor:label.topAnchor constant:-4],
            [bar.centerXAnchor constraintEqualToAnchor:barContainer.centerXAnchor],
            [bar.widthAnchor constraintEqualToConstant:16],
            [bar.heightAnchor constraintEqualToConstant:10], // Initial height
            
            [label.bottomAnchor constraintEqualToAnchor:barContainer.bottomAnchor],
            [label.centerXAnchor constraintEqualToAnchor:barContainer.centerXAnchor],
            
            [countLabel.bottomAnchor constraintEqualToAnchor:bar.topAnchor constant:-2],
            [countLabel.centerXAnchor constraintEqualToAnchor:barContainer.centerXAnchor]
        ]];
        
        [self.channelBarsStack addArrangedSubview:barContainer];
    }
}

- (void)updateWithStatistics:(NSArray<WGChannelStats *> *)stats {
    self.currentStats = stats;
    
    // Find max for scaling
    NSInteger maxCount = 1;
    for (WGChannelStats *stat in stats) {
        if (stat.networkCount > maxCount) {
            maxCount = stat.networkCount;
        }
    }
    
    // Find least congested non-overlapping channel (1, 6, 11)
    NSInteger bestChannel = 1;
    NSInteger lowestCount = NSIntegerMax;
    NSArray *nonOverlapping = @[@1, @6, @11];
    
    // Update bars
    for (NSInteger channel = 1; channel <= 14; channel++) {
        WGChannelStats *channelStat = nil;
        for (WGChannelStats *stat in stats) {
            if (stat.channel == channel) {
                channelStat = stat;
                break;
            }
        }
        
        NSInteger count = channelStat ? channelStat.networkCount : 0;
        
        // Update bar height
        UIView *bar = [self viewWithTag:100 + channel];
        if (bar) {
            CGFloat height = MAX(10, (count / (CGFloat)maxCount) * 100);
            
            for (NSLayoutConstraint *constraint in bar.constraints) {
                if (constraint.firstAttribute == NSLayoutAttributeHeight) {
                    constraint.constant = height;
                }
            }
            
            // Color based on congestion
            if (count == 0) {
                bar.backgroundColor = [UIColor systemGray4Color];
            } else if (count <= 2) {
                bar.backgroundColor = [UIColor systemGreenColor];
            } else if (count <= 5) {
                bar.backgroundColor = [UIColor systemYellowColor];
            } else {
                bar.backgroundColor = [UIColor systemRedColor];
            }
            
            // Highlight non-overlapping channels
            if ([nonOverlapping containsObject:@(channel)]) {
                bar.layer.borderWidth = 2;
                bar.layer.borderColor = [UIColor systemBlueColor].CGColor;
            } else {
                bar.layer.borderWidth = 0;
            }
        }
        
        // Update count label
        UILabel *countLabel = [self viewWithTag:200 + channel];
        if (countLabel) {
            countLabel.text = [NSString stringWithFormat:@"%ld", (long)count];
        }
        
        // Track best channel
        if ([nonOverlapping containsObject:@(channel)] && count < lowestCount) {
            lowestCount = count;
            bestChannel = channel;
        }
    }
    
    // Update recommendation
    self.recommendationLabel.text = [NSString stringWithFormat:@"✅ Recommended channel: %ld (%ld networks)", 
                                     (long)bestChannel, (long)lowestCount];
    
    [self setNeedsLayout];
}

@end
