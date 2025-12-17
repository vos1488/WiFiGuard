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
#import <dlfcn.h>

// MobileWiFi.framework Private API Declarations
// RISK: These APIs are undocumented and may change between iOS versions
// Compatibility: Tested on iOS 16.0-16.2
typedef struct __WiFiManager *WiFiManagerRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;
typedef struct __WiFiDevice *WiFiDeviceRef;

// Function pointer types
typedef WiFiManagerRef (*WiFiManagerClientCreate_t)(CFAllocatorRef, int);
typedef CFArrayRef (*WiFiManagerClientCopyDevices_t)(WiFiManagerRef);
typedef CFArrayRef (*WiFiDeviceClientCopyCurrentNetwork_t)(WiFiDeviceRef);
typedef int (*WiFiDeviceClientGetPower_t)(WiFiDeviceRef);
typedef void (*WiFiDeviceClientScanAsync_t)(WiFiDeviceRef, CFDictionaryRef, void (^)(CFArrayRef, int), int);
typedef CFStringRef (*WiFiNetworkGetSSID_t)(WiFiNetworkRef);
typedef CFStringRef (*WiFiNetworkGetBSSID_t)(WiFiNetworkRef);
typedef CFNumberRef (*WiFiNetworkGetRSSI_t)(WiFiNetworkRef);
typedef CFNumberRef (*WiFiNetworkGetChannel_t)(WiFiNetworkRef);
typedef Boolean (*WiFiNetworkIsHidden_t)(WiFiNetworkRef);
typedef CFDictionaryRef (*WiFiNetworkCopyRecord_t)(WiFiNetworkRef);

// Function pointers (loaded dynamically)
static WiFiManagerClientCreate_t WiFiManagerClientCreate = NULL;
static WiFiManagerClientCopyDevices_t WiFiManagerClientCopyDevices = NULL;
static WiFiDeviceClientCopyCurrentNetwork_t WiFiDeviceClientCopyCurrentNetwork = NULL;
static WiFiDeviceClientGetPower_t WiFiDeviceClientGetPower = NULL;
static WiFiDeviceClientScanAsync_t WiFiDeviceClientScanAsync = NULL;
static WiFiNetworkGetSSID_t WiFiNetworkGetSSID = NULL;
static WiFiNetworkGetBSSID_t WiFiNetworkGetBSSID = NULL;
static WiFiNetworkGetRSSI_t WiFiNetworkGetRSSI = NULL;
static WiFiNetworkGetChannel_t WiFiNetworkGetChannel = NULL;
static WiFiNetworkIsHidden_t WiFiNetworkIsHidden = NULL;
static WiFiNetworkCopyRecord_t WiFiNetworkCopyRecord = NULL;

// Load MobileWiFi functions dynamically
static BOOL gMobileWiFiLoaded = NO;
static NSString *gLoadError = nil;

static void LoadMobileWiFiFunctions(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Try loading MobileWiFi.framework
        void *handle = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY);
        if (!handle) {
            gLoadError = [NSString stringWithFormat:@"dlopen failed: %s", dlerror()];
            NSLog(@"[WiFiGuard] %@", gLoadError);
            gMobileWiFiLoaded = NO;
            return;
        }
        
        WiFiManagerClientCreate = (WiFiManagerClientCreate_t)dlsym(handle, "WiFiManagerClientCreate");
        WiFiManagerClientCopyDevices = (WiFiManagerClientCopyDevices_t)dlsym(handle, "WiFiManagerClientCopyDevices");
        WiFiDeviceClientCopyCurrentNetwork = (WiFiDeviceClientCopyCurrentNetwork_t)dlsym(handle, "WiFiDeviceClientCopyCurrentNetwork");
        WiFiDeviceClientGetPower = (WiFiDeviceClientGetPower_t)dlsym(handle, "WiFiDeviceClientGetPower");
        WiFiDeviceClientScanAsync = (WiFiDeviceClientScanAsync_t)dlsym(handle, "WiFiDeviceClientScanAsync");
        WiFiNetworkGetSSID = (WiFiNetworkGetSSID_t)dlsym(handle, "WiFiNetworkGetSSID");
        WiFiNetworkGetBSSID = (WiFiNetworkGetBSSID_t)dlsym(handle, "WiFiNetworkGetBSSID");
        WiFiNetworkGetRSSI = (WiFiNetworkGetRSSI_t)dlsym(handle, "WiFiNetworkGetRSSI");
        WiFiNetworkGetChannel = (WiFiNetworkGetChannel_t)dlsym(handle, "WiFiNetworkGetChannel");
        WiFiNetworkIsHidden = (WiFiNetworkIsHidden_t)dlsym(handle, "WiFiNetworkIsHidden");
        WiFiNetworkCopyRecord = (WiFiNetworkCopyRecord_t)dlsym(handle, "WiFiNetworkCopyRecord");
        
        // Log which functions loaded
        NSLog(@"[WiFiGuard] WiFiManagerClientCreate: %@", WiFiManagerClientCreate ? @"✓" : @"✗");
        NSLog(@"[WiFiGuard] WiFiManagerClientCopyDevices: %@", WiFiManagerClientCopyDevices ? @"✓" : @"✗");
        NSLog(@"[WiFiGuard] WiFiDeviceClientScanAsync: %@", WiFiDeviceClientScanAsync ? @"✓" : @"✗");
        NSLog(@"[WiFiGuard] WiFiDeviceClientGetPower: %@", WiFiDeviceClientGetPower ? @"✓" : @"✗");
        
        // Verify critical functions loaded
        gMobileWiFiLoaded = (WiFiManagerClientCreate != NULL && 
                            WiFiManagerClientCopyDevices != NULL);
        
        if (!gMobileWiFiLoaded) {
            gLoadError = @"Critical functions not found";
            NSLog(@"[WiFiGuard] Some MobileWiFi functions failed to load");
        } else {
            gLoadError = nil;
            NSLog(@"[WiFiGuard] MobileWiFi.framework loaded successfully");
        }
    });
}

static BOOL IsMobileWiFiAvailable(void) {
    LoadMobileWiFiFunctions();
    return gMobileWiFiLoaded;
}

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

static WGWiFiScanner *_sharedInstance = nil;

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] initWithAuditLogger:[WGAuditLogger sharedInstance]];
    });
    return _sharedInstance;
}

#pragma mark - Initialization

- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger {
    self = [super init];
    if (self) {
        // Load MobileWiFi functions
        LoadMobileWiFiFunctions();
        
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
    if (!IsMobileWiFiAvailable()) {
        NSLog(@"[WiFiGuard] MobileWiFi.framework not available - WiFi scanning disabled");
        [self.auditLogger logEvent:@"SCANNER_INIT_ERROR" 
                           details:@"MobileWiFi.framework not available"];
        return;
    }
    
    @try {
        if (WiFiManagerClientCreate) {
            _wifiManager = WiFiManagerClientCreate(kCFAllocatorDefault, 0);
        }
        
        if (_wifiManager && WiFiManagerClientCopyDevices) {
            CFArrayRef devices = WiFiManagerClientCopyDevices(_wifiManager);
            if (devices && CFArrayGetCount(devices) > 0) {
                _wifiDevice = (WiFiDeviceRef)CFArrayGetValueAtIndex(devices, 0);
            }
            if (devices) CFRelease(devices);
        }
        
        if (_wifiDevice) {
            NSLog(@"[WiFiGuard] WiFi manager initialized successfully");
        } else {
            NSLog(@"[WiFiGuard] WiFi manager created but no device found");
        }
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
    
    if (!IsMobileWiFiAvailable()) {
        NSError *error = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                             code:0 
                                         userInfo:@{NSLocalizedDescriptionKey: @"MobileWiFi.framework not available. Requires jailbroken device."}];
        if ([self.delegate respondsToSelector:@selector(wifiScanner:didEncounterError:)]) {
            [self.delegate wifiScanner:self didEncounterError:error];
        }
        return NO;
    }
    
    if (!self.wifiDevice) {
        NSError *error = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                             code:1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"WiFi device not available"}];
        if ([self.delegate respondsToSelector:@selector(wifiScanner:didEncounterError:)]) {
            [self.delegate wifiScanner:self didEncounterError:error];
        }
        return NO;
    }
    
    // Note: WiFiDeviceClientGetPower may not work correctly on iOS 16+
    // We'll try scanning anyway and let the scan callback handle errors
    NSLog(@"[WiFiGuard] Starting scan (WiFi power check skipped for iOS 16+ compatibility)");
    
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
    
    if ([self.delegate respondsToSelector:@selector(wifiScannerDidStartScanning:)]) {
        [self.delegate wifiScannerDidStartScanning:self];
    }
    
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
    
    if ([self.delegate respondsToSelector:@selector(wifiScannerDidStopScanning:)]) {
        [self.delegate wifiScannerDidStopScanning:self];
    }
    
    NSLog(@"[WiFiGuard] Scanning stopped");
}

- (void)performSingleScan {
    if (!self.wifiDevice) {
        NSLog(@"[WiFiGuard] Cannot scan: no WiFi device");
        return;
    }
    
    // Check if async scan function is available
    if (!WiFiDeviceClientScanAsync) {
        NSLog(@"[WiFiGuard] WiFiDeviceClientScanAsync not available");
        return;
    }
    
    NSLog(@"[WiFiGuard] Initiating WiFi scan...");
    
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
                NSLog(@"[WiFiGuard] Scan callback error: %d", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *scanError = [NSError errorWithDomain:@"WGWiFiScannerError" 
                                                             code:error 
                                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Scan failed with code %d", error]}];
                    if ([self.delegate respondsToSelector:@selector(wifiScanner:didEncounterError:)]) {
                        [self.delegate wifiScanner:self didEncounterError:scanError];
                    }
                });
                return;
            }
            
            NSLog(@"[WiFiGuard] Scan completed, processing results...");
            [self processScanResults:results];
        }, 0);
        
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Scan exception: %@", exception);
    }
}

- (void)processScanResults:(CFArrayRef)results {
    if (!results) {
        NSLog(@"[WiFiGuard] processScanResults: results is NULL");
        return;
    }
    
    CFIndex count = CFArrayGetCount(results);
    NSLog(@"[WiFiGuard] Processing %ld scan results", (long)count);
    
    NSMutableArray<WGNetworkInfo *> *updatedNetworks = [NSMutableArray array];
    
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
                NSLog(@"[WiFiGuard] New network: %@ (%@) Ch:%ld RSSI:%ld", 
                      info.ssid ?: @"<Hidden>", info.bssid, (long)info.channel, (long)info.rssi);
            }
        }
    }
    
    // Update channel statistics
    [self updateChannelStatistics];
    
    // Notify delegate on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(wifiScanner:didFindNetworks:)]) {
            [self.delegate wifiScanner:self didFindNetworks:[self.networkCache.allValues copy]];
        }
    });
}

- (WGNetworkInfo *)parseNetworkInfo:(WiFiNetworkRef)network {
    if (!network) return nil;
    
    WGNetworkInfo *info = [[WGNetworkInfo alloc] init];
    
    // Get SSID
    if (WiFiNetworkGetSSID) {
        CFStringRef ssidRef = WiFiNetworkGetSSID(network);
        if (ssidRef) {
            info.ssid = (__bridge NSString *)ssidRef;
        }
    }
    
    // Get BSSID
    if (WiFiNetworkGetBSSID) {
        CFStringRef bssidRef = WiFiNetworkGetBSSID(network);
        if (bssidRef) {
            info.bssid = (__bridge NSString *)bssidRef;
        }
    }
    
    // Get RSSI
    if (WiFiNetworkGetRSSI) {
        CFNumberRef rssiRef = WiFiNetworkGetRSSI(network);
        if (rssiRef) {
            int rssi = 0;
            CFNumberGetValue(rssiRef, kCFNumberIntType, &rssi);
            info.rssi = rssi;
        }
    }
    
    // Get Channel
    if (WiFiNetworkGetChannel) {
        CFNumberRef channelRef = WiFiNetworkGetChannel(network);
        if (channelRef) {
            int channel = 0;
            CFNumberGetValue(channelRef, kCFNumberIntType, &channel);
            info.channel = channel;
        }
    }
    
    // Check if hidden
    if (WiFiNetworkIsHidden) {
        info.isHidden = WiFiNetworkIsHidden(network);
    }
    
    // Get security type from network record
    if (WiFiNetworkCopyRecord) {
        CFDictionaryRef record = WiFiNetworkCopyRecord(network);
        if (record) {
            info.securityType = [self parseSecurityType:record];
            info.channelWidth = [self parseChannelWidth:record];
            CFRelease(record);
        }
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
#pragma mark - Diagnostics

- (NSString *)diagnosticStatus {
    // Force load attempt
    LoadMobileWiFiFunctions();
    
    if (!gMobileWiFiLoaded) {
        if (gLoadError) {
            return [NSString stringWithFormat:@"❌ %@", gLoadError];
        }
        return @"❌ MobileWiFi not loaded";
    }
    if (!self.wifiManager) {
        return @"❌ No WiFi Manager";
    }
    if (!self.wifiDevice) {
        return @"❌ No WiFi Device";
    }
    if (self.isScanning) {
        NSInteger count = self.networkCache.count;
        if (count > 0) {
            return [NSString stringWithFormat:@"✅ Found %ld", (long)count];
        }
        return @"🔍 Scanning...";
    }
    return @"⏸ Ready";
}
@end
