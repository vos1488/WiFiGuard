/*
 * WGRSSIGraphView.m - RSSI Time Graph Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGRSSIGraphView.h"
#import "../Core/WGWiFiScanner.h"

@interface WGRSSIGraphView ()

@property (nonatomic, strong) NSArray<UIColor *> *lineColors;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIScrollView *legendScrollView;

@end

@implementation WGRSSIGraphView

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
    
    _trackedNetworks = [NSMutableArray array];
    _timeWindow = 60.0;
    
    _lineColors = @[
        [UIColor systemBlueColor],
        [UIColor systemGreenColor],
        [UIColor systemOrangeColor],
        [UIColor systemPurpleColor],
        [UIColor systemPinkColor],
        [UIColor systemTealColor]
    ];
    
    // Title
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"📊 RSSI Over Time";
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self addSubview:_titleLabel];
    
    // Legend
    _legendScrollView = [[UIScrollView alloc] init];
    _legendScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _legendScrollView.showsHorizontalScrollIndicator = NO;
    [self addSubview:_legendScrollView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        
        [_legendScrollView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:8],
        [_legendScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_legendScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_legendScrollView.heightAnchor constraintEqualToConstant:30]
    ]];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGFloat graphTop = 80;
    CGFloat graphBottom = rect.size.height - 30;
    CGFloat graphLeft = 50;
    CGFloat graphRight = rect.size.width - 20;
    CGFloat graphHeight = graphBottom - graphTop;
    CGFloat graphWidth = graphRight - graphLeft;
    
    // Draw grid
    CGContextSetStrokeColorWithColor(context, [UIColor systemGray5Color].CGColor);
    CGContextSetLineWidth(context, 0.5);
    
    // Horizontal grid lines (RSSI levels)
    NSArray *rssiLevels = @[@-30, @-50, @-70, @-90];
    for (NSNumber *level in rssiLevels) {
        CGFloat y = [self yPositionForRSSI:level.integerValue 
                                    inRect:CGRectMake(graphLeft, graphTop, graphWidth, graphHeight)];
        CGContextMoveToPoint(context, graphLeft, y);
        CGContextAddLineToPoint(context, graphRight, y);
        CGContextStrokePath(context);
        
        // Label
        NSString *label = [NSString stringWithFormat:@"%@ dBm", level];
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:10],
            NSForegroundColorAttributeName: [UIColor systemGrayColor]
        };
        [label drawAtPoint:CGPointMake(5, y - 6) withAttributes:attrs];
    }
    
    // Draw data lines
    for (NSUInteger i = 0; i < self.trackedNetworks.count; i++) {
        WGNetworkInfo *network = self.trackedNetworks[i];
        UIColor *color = self.lineColors[i % self.lineColors.count];
        
        [self drawLineForNetwork:network 
                       withColor:color 
                       inContext:context 
                          inRect:CGRectMake(graphLeft, graphTop, graphWidth, graphHeight)];
    }
    
    // Draw axes
    CGContextSetStrokeColorWithColor(context, [UIColor labelColor].CGColor);
    CGContextSetLineWidth(context, 1.5);
    CGContextMoveToPoint(context, graphLeft, graphTop);
    CGContextAddLineToPoint(context, graphLeft, graphBottom);
    CGContextAddLineToPoint(context, graphRight, graphBottom);
    CGContextStrokePath(context);
    
    // Time labels
    NSDictionary *timeAttrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [UIColor systemGrayColor]
    };
    [@"Now" drawAtPoint:CGPointMake(graphRight - 15, graphBottom + 5) withAttributes:timeAttrs];
    [[NSString stringWithFormat:@"-%.0fs", self.timeWindow] drawAtPoint:CGPointMake(graphLeft - 5, graphBottom + 5) withAttributes:timeAttrs];
}

- (void)drawLineForNetwork:(WGNetworkInfo *)network 
                 withColor:(UIColor *)color 
                 inContext:(CGContextRef)context 
                    inRect:(CGRect)graphRect {
    
    if (network.rssiHistory.count < 2) return;
    
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    NSDate *now = [NSDate date];
    BOOL started = NO;
    
    for (NSUInteger i = 0; i < network.rssiHistory.count; i++) {
        NSNumber *rssi = network.rssiHistory[i];
        NSDate *timestamp = network.rssiTimestamps[i];
        
        NSTimeInterval age = [now timeIntervalSinceDate:timestamp];
        if (age > self.timeWindow) continue;
        
        CGFloat x = graphRect.origin.x + graphRect.size.width * (1.0 - age / self.timeWindow);
        CGFloat y = [self yPositionForRSSI:rssi.integerValue inRect:graphRect];
        
        if (!started) {
            CGContextMoveToPoint(context, x, y);
            started = YES;
        } else {
            CGContextAddLineToPoint(context, x, y);
        }
    }
    
    CGContextStrokePath(context);
}

- (CGFloat)yPositionForRSSI:(NSInteger)rssi inRect:(CGRect)rect {
    // RSSI range: -30 (best) to -100 (worst)
    CGFloat normalized = (rssi - (-100)) / 70.0; // 0.0 to 1.0
    normalized = MAX(0, MIN(1, normalized));
    return rect.origin.y + rect.size.height * (1.0 - normalized);
}

#pragma mark - Public Methods

- (void)trackNetwork:(WGNetworkInfo *)network {
    if (![self.trackedNetworks containsObject:network]) {
        [self.trackedNetworks addObject:network];
        [self updateLegend];
        [self setNeedsDisplay];
    }
}

- (void)stopTrackingNetwork:(WGNetworkInfo *)network {
    [self.trackedNetworks removeObject:network];
    [self updateLegend];
    [self setNeedsDisplay];
}

- (void)updateNetwork:(WGNetworkInfo *)network {
    if ([self.trackedNetworks containsObject:network]) {
        [self setNeedsDisplay];
    }
}

- (void)clearAll {
    [self.trackedNetworks removeAllObjects];
    [self updateLegend];
    [self setNeedsDisplay];
}

- (void)updateLegend {
    // Clear existing legend
    for (UIView *subview in self.legendScrollView.subviews) {
        [subview removeFromSuperview];
    }
    
    CGFloat xOffset = 0;
    
    for (NSUInteger i = 0; i < self.trackedNetworks.count; i++) {
        WGNetworkInfo *network = self.trackedNetworks[i];
        UIColor *color = self.lineColors[i % self.lineColors.count];
        
        UIView *legendItem = [[UIView alloc] initWithFrame:CGRectMake(xOffset, 0, 120, 24)];
        
        UIView *colorDot = [[UIView alloc] initWithFrame:CGRectMake(0, 7, 10, 10)];
        colorDot.backgroundColor = color;
        colorDot.layer.cornerRadius = 5;
        [legendItem addSubview:colorDot];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 100, 24)];
        nameLabel.text = network.ssid ?: @"<Hidden>";
        nameLabel.font = [UIFont systemFontOfSize:11];
        nameLabel.textColor = [UIColor secondaryLabelColor];
        [legendItem addSubview:nameLabel];
        
        [self.legendScrollView addSubview:legendItem];
        
        xOffset += 130;
    }
    
    self.legendScrollView.contentSize = CGSizeMake(xOffset, 30);
}

@end
