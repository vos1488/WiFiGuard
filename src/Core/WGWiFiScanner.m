/*
 * WGWiFiScanner.m - Passive Wi-Fi Network Scanner Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * PASSIVE SCANNING ONLY - No active attacks implemented
 * Uses MobileWiFi.framework private APIs for scanning
 */

#import "WGWiFiScanner.h"
#import "WGAuditLogger.h"
#import "WGNetworkUtils.h"

// MobileWiFi.framework Private API Declarations
// RISK: These APIs are undocumented and may change between iOS versions
// Compatibility: Tested on iOS 16.0-16.2
typedef struct __WiFiManager *WiFiManagerRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;
typedef struct __WiFiDevice *WiFiDeviceRef;

extern WiFiManagerRef WiFiManagerClientCreate(CFAllocatorRef allocator, int flags);
extern CFArrayRef WiFiManagerClientCopyDevices(WiFiManagerRef manager);
extern CFArrayRef WiFiDeviceClientCopyCurrentNetwork(WiFiDeviceRef device);
extern int WiFiDeviceClientGetPower(WiFiDeviceRef device);
extern void WiFiDeviceClientScanAsync(WiFiDeviceRef device, CFDictionaryRef options, 
                                       void (^callback)(CFArrayRef results, int error), int flags);
extern CFStringRef WiFiNetworkGetSSID(WiFiNetworkRef network);
extern CFStringRef WiFiNetworkGetBSSID(WiFiNetworkRef network);
extern CFNumberRef WiFiNetworkGetRSSI(WiFiNetworkRef network);
extern CFNumberRef WiFiNetworkGetChannel(WiFiNetworkRef network);
extern Boolean WiFiNetworkIsHidden(WiFiNetworkRef network);
extern CFDictionaryRef WiFiNetworkCopyRecord(WiFiNetworkRef network);

#pragma mark - WGNetworkInfo Implementation

@implementation WGNetworkInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _rssiHistory = [NSMutableArray array];
        _rssiTimestamps = [NSMutableArray array];
        _lastSeen = [NSDate date];
        _channelWidth = 20;
        _securityType = @"Unknown";
    }
    return self;
}

- (void)addRSSISample:(NSInteger)rssi {
    [self.rssiHistory addObject:@(rssi)];
    [self.rssiTimestamps addObject:[NSDate date]];
    
    // Keep only last 100 samples
    if (self.rssiHistory.count > 100) {
        [self.rssiHistory removeObjectAtIndex:0];
        [self.rssiTimestamps removeObjectAtIndex:0];
    }
    
    self.rssi = rssi;
    self.lastSeen = [NSDate date];
}

- (NSDictionary *)toDictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    return @{
        @"ssid": self.ssid ?: @"<Hidden>",
        @"bssid": self.bssid ?: @"Unknown",
        @"channel": @(self.channel),
        @"rssi": @(self.rssi),
        @"channelWidth": @(self.channelWidth),
        @"securityType": self.securityType ?: @"Unknown",
        @"isHidden": @(self.isHidden),
        @"lastSeen": [formatter stringFromDate:self.lastSeen],
        @"rssiHistory": [self.rssiHistory copy],
        @"rssiTimestamps": [self.rssiTimestamps valueForKey:@"description"]
    };
}

+ (instancetype)networkFromDictionary:(NSDictionary *)dict {
    WGNetworkInfo *network = [[WGNetworkInfo alloc] init];
    network.ssid = dict[@"ssid"];
    network.bssid = dict[@"bssid"];
    network.channel = [dict[@"channel"] integerValue];
    network.rssi = [dict[@"rssi"] integerValue];
    network.channelWidth = [dict[@"channelWidth"] integerValue];
    network.securityType = dict[@"securityType"];
    network.isHidden = [dict[@"isHidden"] boolValue];
    return network;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<WGNetworkInfo: %@ (%@) Ch:%ld RSSI:%ld %@>",
            self.ssid ?: @"<Hidden>", self.bssid, (long)self.channel, 
            (long)self.rssi, self.securityType];
}

@end

#pragma mark - WGChannelStats Implementation

@implementation WGChannelStats

- (instancetype)initWithChannel:(NSInteger)channel {
    self = [super init];
    if (self) {
        _channel = channel;
        _networkCount = 0;
        _averageRSSI = -100;
        _congestionLevel = 0;
    }
    return self;
}

@end

#pragma mark - WGWiFiScanner Implementation

@interface WGWiFiScanner ()

@property (nonatomic, strong) WGAuditLogger *auditLogger;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WGNetworkInfo *> *networkCache;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, WGChannelStats *> *channelStatsCache;
@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, assign) WiFiManagerRef wifiManager;
@property (nonatomic, assign) WiFiDeviceRef wifiDevice;

@end

@implementation WGWiFiScanner

#pragma mark - Initialization

- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger {
    self = [super init];
    if (self) {
        _auditLogger = logger;
        _networkCache = [NSMutableDictionary dictionary];
        _channelStatsCache = [NSMutableDictionary dictionary];
        _scanInterval = 5.0;
        _isScanning = NO;
        
        [self initializeWiFiManager];
        
        [_auditLogger logEvent:@"SCANNER_INIT" details:@"WiFi scanner initialized"];
    }
    return self;
}

- (void)initializeWiFiManager {
    @try {
        _wifiManager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        
        if (_wifiManager) {
            CFArrayRef devices = WiFiManagerClientCopyDevices(_wifiManager);
            if (devices && CFArrayGetCount(devices) > 0) {
                _wifiDevice = (WiFiDeviceRef)CFArrayGetValueAtIndex(devices, 0);
            }
            if (devices) CFRelease(devices);
        }
        
        NSLog(@"[WiFiGuard] WiFi manager initialized successfully");
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Error initializing WiFi manager: %@", exception);
        [self.auditLogger logEvent:@"SCANNER_INIT_ERROR" 
                           details:[NSString stringWithFormat:@"Exception: %@", exception]];
    }
}

- (void)dealloc {
    [self stopScanning];
    if (_wifiManager) {
        CFRelease(_wifiManager);
        _wifiManager = NULL;
    }
}

#pragma mark - Scanning Control

- (BOOL)startScanning {
    if (self.isScanning) {
        return YES;
    }
    
    if (!self.wifiDevice) {
        NSError *error = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                             code:1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"WiFi device not available"}];
        [self.delegate wifiScanner:self didEncounterError:error];
        return NO;
    }
    
    // Check if WiFi is powered on
    if (!WiFiDeviceClientGetPower(self.wifiDevice)) {
        NSError *error = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                             code:2 
                                         userInfo:@{NSLocalizedDescriptionKey: @"WiFi is turned off"}];
        [self.delegate wifiScanner:self didEncounterError:error];
        return NO;
    }
    
    self.isScanning = YES;
    
    [self.auditLogger logEvent:@"SCAN_STARTED" 
                       details:[NSString stringWithFormat:@"Interval: %.1fs", self.scanInterval]];
    
    // Perform initial scan
    [self performSingleScan];
    
    // Start periodic scanning
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:self.scanInterval
                                                      target:self
                                                    selector:@selector(performSingleScan)
                                                    userInfo:nil
                                                     repeats:YES];
    
    [self.delegate wifiScannerDidStartScanning:self];
    
    NSLog(@"[WiFiGuard] Passive scanning started (interval: %.1fs)", self.scanInterval);
    
    return YES;
}

- (void)stopScanning {
    if (!self.isScanning) {
        return;
    }
    
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    self.isScanning = NO;
    
    [self.auditLogger logEvent:@"SCAN_STOPPED" 
                       details:[NSString stringWithFormat:@"Networks found: %lu", 
                               (unsigned long)self.networkCache.count]];
    
    [self.delegate wifiScannerDidStopScanning:self];
    
    NSLog(@"[WiFiGuard] Scanning stopped");
}

- (void)performSingleScan {
    if (!self.wifiDevice) {
        return;
    }
    
    @try {
        // Perform passive scan - NO active probing
        NSDictionary *options = @{
            @"SCAN_MERGE": @YES,           // Merge results
            @"SCAN_TYPE": @"PASSIVE"       // Passive scan only
        };
        
        WiFiDeviceClientScanAsync(self.wifiDevice, 
                                  (__bridge CFDictionaryRef)options, 
                                  ^(CFArrayRef results, int error) {
            if (error != 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *scanError = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                                             code:error 
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Scan failed"}];
                    [self.delegate wifiScanner:self didEncounterError:scanError];
                });
                return;
            }
            
            [self processScanResults:results];
        }, 0);
        
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Scan error: %@", exception);
    }
}

- (void)processScanResults:(CFArrayRef)results {
    if (!results) return;
    
    NSMutableArray<WGNetworkInfo *> *updatedNetworks = [NSMutableArray array];
    
    CFIndex count = CFArrayGetCount(results);
    for (CFIndex i = 0; i < count; i++) {
        WiFiNetworkRef network = (WiFiNetworkRef)CFArrayGetValueAtIndex(results, i);
        
        WGNetworkInfo *info = [self parseNetworkInfo:network];
        if (info && info.bssid) {
            // Update or add to cache
            WGNetworkInfo *existing = self.networkCache[info.bssid];
            if (existing) {
                [existing addRSSISample:info.rssi];
                existing.channel = info.channel;
                existing.securityType = info.securityType;
                existing.channelWidth = info.channelWidth;
                [updatedNetworks addObject:existing];
            } else {
                [info addRSSISample:info.rssi];
                self.networkCache[info.bssid] = info;
                [updatedNetworks addObject:info];
            }
        }
    }
    
    // Update channel statistics
    [self updateChannelStatistics];
    
    // Notify delegate on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate wifiScanner:self didFindNetworks:[self.networkCache.allValues copy]];
    });
}

- (WGNetworkInfo *)parseNetworkInfo:(WiFiNetworkRef)network {
    WGNetworkInfo *info = [[WGNetworkInfo alloc] init];
    
    // Get SSID
    CFStringRef ssidRef = WiFiNetworkGetSSID(network);
    if (ssidRef) {
        info.ssid = (__bridge NSString *)ssidRef;
    }
    
    // Get BSSID
    CFStringRef bssidRef = WiFiNetworkGetBSSID(network);
    if (bssidRef) {
        info.bssid = (__bridge NSString *)bssidRef;
    }
    
    // Get RSSI
    CFNumberRef rssiRef = WiFiNetworkGetRSSI(network);
    if (rssiRef) {
        int rssi = 0;
        CFNumberGetValue(rssiRef, kCFNumberIntType, &rssi);
        info.rssi = rssi;
    }
    
    // Get Channel
    CFNumberRef channelRef = WiFiNetworkGetChannel(network);
    if (channelRef) {
        int channel = 0;
        CFNumberGetValue(channelRef, kCFNumberIntType, &channel);
        info.channel = channel;
    }
    
    // Check if hidden
    info.isHidden = WiFiNetworkIsHidden(network);
    
    // Get security type from network record
    CFDictionaryRef record = WiFiNetworkCopyRecord(network);
    if (record) {
        info.securityType = [self parseSecurityType:record];
        info.channelWidth = [self parseChannelWidth:record];
        CFRelease(record);
    }
    
    return info;
}

- (NSString *)parseSecurityType:(CFDictionaryRef)record {
    // Parse security mode from network record
    CFStringRef securityMode = CFDictionaryGetValue(record, CFSTR("WEP"));
    if (securityMode && CFBooleanGetValue((CFBooleanRef)securityMode)) {
        return @"WEP";
    }
    
    CFDictionaryRef wpaMode = CFDictionaryGetValue(record, CFSTR("WPA"));
    if (wpaMode) {
        // Check for WPA3
        CFBooleanRef wpa3 = CFDictionaryGetValue(record, CFSTR("WPA3"));
        if (wpa3 && CFBooleanGetValue(wpa3)) {
            return @"WPA3";
        }
        return @"WPA2";
    }
    
    return @"Open";
}

- (NSInteger)parseChannelWidth:(CFDictionaryRef)record {
    CFNumberRef widthRef = CFDictionaryGetValue(record, CFSTR("CHANNEL_WIDTH"));
    if (widthRef) {
        int width = 20;
        CFNumberGetValue(widthRef, kCFNumberIntType, &width);
        return width;
    }
    return 20;
}

#pragma mark - Channel Statistics

- (void)updateChannelStatistics {
    [self.channelStatsCache removeAllObjects];
    
    // Group networks by channel
    NSMutableDictionary<NSNumber *, NSMutableArray *> *networksByChannel = [NSMutableDictionary dictionary];
    
    for (WGNetworkInfo *network in self.networkCache.allValues) {
        NSNumber *channelKey = @(network.channel);
        if (!networksByChannel[channelKey]) {
            networksByChannel[channelKey] = [NSMutableArray array];
        }
        [networksByChannel[channelKey] addObject:network];
    }
    
    // Calculate statistics for each channel
    for (NSNumber *channel in networksByChannel) {
        NSArray *networks = networksByChannel[channel];
        WGChannelStats *stats = [[WGChannelStats alloc] initWithChannel:channel.integerValue];
        stats.networkCount = networks.count;
        
        // Calculate average RSSI
        CGFloat totalRSSI = 0;
        for (WGNetworkInfo *network in networks) {
            totalRSSI += network.rssi;
        }
        stats.averageRSSI = totalRSSI / networks.count;
        
        // Calculate congestion level (0-100)
        // Based on number of networks and average RSSI
        NSInteger congestion = MIN(100, networks.count * 15);
        if (stats.averageRSSI > -50) {
            congestion += 20; // Strong signals indicate close/overlapping networks
        }
        stats.congestionLevel = MIN(100, congestion);
        
        self.channelStatsCache[channel] = stats;
    }
}

#pragma mark - Data Access

- (NSArray<WGNetworkInfo *> *)discoveredNetworks {
    return [self.networkCache.allValues sortedArrayUsingComparator:^NSComparisonResult(WGNetworkInfo *n1, WGNetworkInfo *n2) {
        return [@(n2.rssi) compare:@(n1.rssi)]; // Sort by RSSI descending
    }];
}

- (NSArray<WGChannelStats *> *)channelStatistics {
    return [self.channelStatsCache.allValues sortedArrayUsingComparator:^NSComparisonResult(WGChannelStats *s1, WGChannelStats *s2) {
        return [@(s1.channel) compare:@(s2.channel)];
    }];
}

- (WGNetworkInfo *)networkWithBSSID:(NSString *)bssid {
    return self.networkCache[bssid];
}

- (NSArray<WGNetworkInfo *> *)networksOnChannel:(NSInteger)channel {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channel == %ld", (long)channel];
    return [self.networkCache.allValues filteredArrayUsingPredicate:predicate];
}

- (NSArray<WGNetworkInfo *> *)networksWithSecurityType:(NSString *)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"securityType == %@", type];
    return [self.networkCache.allValues filteredArrayUsingPredicate:predicate];
}

- (NSArray<WGNetworkInfo *> *)hiddenNetworks {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isHidden == YES"];
    return [self.networkCache.allValues filteredArrayUsingPredicate:predicate];
}

#pragma mark - Statistics

- (WGChannelStats *)statsForChannel:(NSInteger)channel {
    return self.channelStatsCache[@(channel)];
}

- (NSInteger)mostCrowdedChannel {
    WGChannelStats *maxStats = nil;
    for (WGChannelStats *stats in self.channelStatsCache.allValues) {
        if (!maxStats || stats.networkCount > maxStats.networkCount) {
            maxStats = stats;
        }
    }
    return maxStats ? maxStats.channel : 0;
}

- (NSInteger)leastCrowdedChannel {
    // Consider 2.4GHz channels: 1, 6, 11 (non-overlapping)
    NSArray *nonOverlappingChannels = @[@1, @6, @11];
    NSInteger bestChannel = 1;
    NSInteger lowestCount = NSIntegerMax;
    
    for (NSNumber *channel in nonOverlappingChannels) {
        WGChannelStats *stats = self.channelStatsCache[channel];
        NSInteger count = stats ? stats.networkCount : 0;
        if (count < lowestCount) {
            lowestCount = count;
            bestChannel = channel.integerValue;
        }
    }
    
    return bestChannel;
}

- (NSArray<NSNumber *> *)recommendedChannels {
    // Return channels sorted by least congestion
    NSArray *sortedStats = [self.channelStatsCache.allValues 
        sortedArrayUsingComparator:^NSComparisonResult(WGChannelStats *s1, WGChannelStats *s2) {
            return [@(s1.congestionLevel) compare:@(s2.congestionLevel)];
        }];
    
    NSMutableArray *recommended = [NSMutableArray array];
    for (WGChannelStats *stats in sortedStats) {
        [recommended addObject:@(stats.channel)];
        if (recommended.count >= 3) break;
    }
    
    return recommended;
}

#pragma mark - Cache Management

- (void)clearCache {
    [self.networkCache removeAllObjects];
    [self.channelStatsCache removeAllObjects];
    [self.auditLogger logEvent:@"CACHE_CLEARED" details:@"Network cache cleared"];
}

- (void)clearRSSIHistory {
    for (WGNetworkInfo *network in self.networkCache.allValues) {
        [network.rssiHistory removeAllObjects];
        [network.rssiTimestamps removeAllObjects];
    }
    [self.auditLogger logEvent:@"RSSI_HISTORY_CLEARED" details:@"RSSI history cleared"];
}

#pragma mark - Export

- (NSArray<NSDictionary *> *)exportData {
    NSMutableArray *data = [NSMutableArray array];
    for (WGNetworkInfo *network in self.discoveredNetworks) {
        [data addObject:[network toDictionary]];
    }
    return data;
}

@end
