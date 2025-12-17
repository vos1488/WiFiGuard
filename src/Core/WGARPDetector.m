/*
 * WGARPDetector.m - Passive ARP Spoofing Detection Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * DETECTION ONLY - NO ACTIVE ATTACKS OR COUNTERMEASURES
 * This module reads the system ARP table and detects anomalies.
 * It does NOT:
 *   - Send any ARP packets
 *   - Modify the ARP table
 *   - Perform any ARP spoofing/poisoning
 *   - Take any corrective/blocking actions
 */

#import "WGARPDetector.h"
#import "WGAuditLogger.h"
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <net/route.h>
#import <netinet/in.h>
#import <netinet/if_ether.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

// Route message structure for reading ARP table
struct rt_msghdr_ext {
    u_short rtm_msglen;
    u_char  rtm_version;
    u_char  rtm_type;
    u_short rtm_index;
    int     rtm_flags;
    int     rtm_addrs;
    pid_t   rtm_pid;
    int     rtm_seq;
    int     rtm_errno;
    int     rtm_use;
    u_int32_t rtm_inits;
    struct rt_metrics rtm_rmx;
};

#pragma mark - WGARPEntry Implementation

@implementation WGARPEntry

- (instancetype)init {
    self = [super init];
    if (self) {
        _macHistory = [NSMutableArray array];
        _firstSeen = [NSDate date];
        _lastSeen = [NSDate date];
    }
    return self;
}

- (void)updateMAC:(NSString *)mac {
    if (![self.macAddress isEqualToString:mac]) {
        if (self.macAddress) {
            [self.macHistory addObject:self.macAddress];
        }
        _macAddress = mac;
    }
    _lastSeen = [NSDate date];
}

- (NSDictionary *)toDictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    return @{
        @"ipAddress": self.ipAddress ?: @"",
        @"macAddress": self.macAddress ?: @"",
        @"interface": self.interface ?: @"",
        @"isComplete": @(self.isComplete),
        @"isPermanent": @(self.isPermanent),
        @"firstSeen": [formatter stringFromDate:self.firstSeen],
        @"lastSeen": [formatter stringFromDate:self.lastSeen],
        @"macHistory": [self.macHistory copy]
    };
}

@end

#pragma mark - WGARPAnomaly Implementation

@implementation WGARPAnomaly

- (instancetype)initWithType:(WGARPAnomalyType)type {
    self = [super init];
    if (self) {
        _type = type;
        _detectedAt = [NSDate date];
        _severity = 5; // Default medium severity
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    return @{
        @"type": @(self.type),
        @"typeName": [self typeString],
        @"ipAddress": self.ipAddress ?: @"",
        @"previousMAC": self.previousMAC ?: @"",
        @"currentMAC": self.currentMAC ?: @"",
        @"details": self.details ?: @"",
        @"severity": @(self.severity),
        @"detectedAt": [formatter stringFromDate:self.detectedAt]
    };
}

- (NSString *)typeString {
    switch (self.type) {
        case WGARPAnomalyTypeMACChange:
            return @"MAC_CHANGE";
        case WGARPAnomalyTypeDuplicateMAC:
            return @"DUPLICATE_MAC";
        case WGARPAnomalyTypeGatewayMACChange:
            return @"GATEWAY_MAC_CHANGE";
        case WGARPAnomalyTypeBSSIDMismatch:
            return @"BSSID_MISMATCH";
        case WGARPAnomalyTypeRapidChanges:
            return @"RAPID_CHANGES";
        case WGARPAnomalyTypeUnexpectedGratuitous:
            return @"UNEXPECTED_GRATUITOUS";
        default:
            return @"NONE";
    }
}

- (NSString *)localizedDescription {
    switch (self.type) {
        case WGARPAnomalyTypeMACChange:
            return [NSString stringWithFormat:@"⚠️ MAC address for %@ changed from %@ to %@",
                    self.ipAddress, self.previousMAC, self.currentMAC];
        case WGARPAnomalyTypeDuplicateMAC:
            return [NSString stringWithFormat:@"⚠️ Multiple IPs share MAC %@: %@",
                    self.currentMAC, self.details];
        case WGARPAnomalyTypeGatewayMACChange:
            return [NSString stringWithFormat:@"🚨 GATEWAY MAC changed! %@ → %@ (Possible MITM!)",
                    self.previousMAC, self.currentMAC];
        case WGARPAnomalyTypeBSSIDMismatch:
            return [NSString stringWithFormat:@"⚠️ MAC %@ doesn't match expected BSSID pattern",
                    self.currentMAC];
        case WGARPAnomalyTypeRapidChanges:
            return @"⚠️ Unusually rapid ARP table changes detected";
        default:
            return @"Unknown anomaly detected";
    }
}

@end

#pragma mark - WGARPStats Implementation

@implementation WGARPStats

- (instancetype)init {
    self = [super init];
    if (self) {
        _monitoringStarted = [NSDate date];
    }
    return self;
}

- (void)updateMonitoringTime {
    _totalMonitoringTime = [[NSDate date] timeIntervalSinceDate:self.monitoringStarted];
}

@end

#pragma mark - WGARPDetector Implementation

@interface WGARPDetector ()

@property (nonatomic, strong) WGAuditLogger *auditLogger;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WGARPEntry *> *arpCache;
@property (nonatomic, strong) NSMutableArray<WGARPAnomaly *> *anomalyHistory;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *trustedMACs; // IP -> MAC
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) WGARPStats *statistics;
@property (nonatomic, copy) NSString *gatewayIP;
@property (nonatomic, copy) NSString *lastGatewayMAC;
@property (nonatomic, assign) NSInteger changeCountInWindow;
@property (nonatomic, strong) NSDate *windowStartTime;

@end

@implementation WGARPDetector

static WGARPDetector *_sharedInstance = nil;

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
        _auditLogger = logger;
        _arpCache = [NSMutableDictionary dictionary];
        _anomalyHistory = [NSMutableArray array];
        _trustedMACs = [NSMutableDictionary dictionary];
        _statistics = [[WGARPStats alloc] init];
        _checkInterval = 3.0;
        _alertOnGatewayChange = YES;
        _alertOnMACChange = YES;
        _alertOnDuplicateMAC = YES;
        _isMonitoring = NO;
        _changeCountInWindow = 0;
        _windowStartTime = [NSDate date];
        
        // Detect gateway IP
        [self detectGatewayIP];
        
        [_auditLogger logEvent:@"ARP_DETECTOR_INIT" 
                       details:@"Passive ARP monitoring module initialized"];
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

#pragma mark - Gateway Detection

- (void)detectGatewayIP {
    // Get default gateway from routing table
    @try {
        int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY};
        size_t len = 0;
        
        if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
            return;
        }
        
        char *buf = malloc(len);
        if (!buf) return;
        
        if (sysctl(mib, 6, buf, &len, NULL, 0) >= 0) {
            struct rt_msghdr *rtm;
            for (char *ptr = buf; ptr < buf + len; ptr += rtm->rtm_msglen) {
                rtm = (struct rt_msghdr *)ptr;
                struct sockaddr *sa = (struct sockaddr *)(rtm + 1);
                struct sockaddr *rti_info[RTAX_MAX];
                
                for (int i = 0; i < RTAX_MAX; i++) {
                    if (rtm->rtm_addrs & (1 << i)) {
                        rti_info[i] = sa;
                        sa = (struct sockaddr *)((char *)sa + 
                            (sa->sa_len > 0 ? (1 + ((sa->sa_len - 1) | (sizeof(long) - 1))) : sizeof(long)));
                    } else {
                        rti_info[i] = NULL;
                    }
                }
                
                if (rti_info[RTAX_DST] && rti_info[RTAX_GATEWAY]) {
                    struct sockaddr_in *dst = (struct sockaddr_in *)rti_info[RTAX_DST];
                    struct sockaddr_in *gw = (struct sockaddr_in *)rti_info[RTAX_GATEWAY];
                    
                    if (dst->sin_addr.s_addr == 0 && gw->sin_family == AF_INET) {
                        char gwAddr[INET_ADDRSTRLEN];
                        inet_ntop(AF_INET, &gw->sin_addr, gwAddr, sizeof(gwAddr));
                        self.gatewayIP = [NSString stringWithUTF8String:gwAddr];
                        break;
                    }
                }
            }
        }
        
        free(buf);
        
        NSLog(@"[WiFiGuard] Detected gateway IP: %@", self.gatewayIP ?: @"Unknown");
        
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Error detecting gateway: %@", exception);
    }
}

#pragma mark - Monitoring Control

- (BOOL)startMonitoring {
    if (self.isMonitoring) {
        return YES;
    }
    
    self.isMonitoring = YES;
    self.statistics = [[WGARPStats alloc] init];
    self.windowStartTime = [NSDate date];
    self.changeCountInWindow = 0;
    
    [self.auditLogger logEvent:@"ARP_MONITORING_STARTED" 
                       details:[NSString stringWithFormat:@"Interval: %.1fs", self.checkInterval]];
    
    // Perform initial check
    [self performSingleCheck];
    
    // Store initial gateway MAC
    self.lastGatewayMAC = [self gatewayMAC];
    
    // Start periodic checking
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:self.checkInterval
                                                       target:self
                                                     selector:@selector(performSingleCheck)
                                                     userInfo:nil
                                                      repeats:YES];
    
    [self.delegate arpDetectorDidStartMonitoring:self];
    
    NSLog(@"[WiFiGuard] ARP monitoring started (PASSIVE DETECTION ONLY)");
    
    return YES;
}

- (void)stopMonitoring {
    if (!self.isMonitoring) {
        return;
    }
    
    [self.checkTimer invalidate];
    self.checkTimer = nil;
    self.isMonitoring = NO;
    
    [self.statistics updateMonitoringTime];
    
    [self.auditLogger logEvent:@"ARP_MONITORING_STOPPED" 
                       details:[NSString stringWithFormat:@"Anomalies detected: %ld", 
                               (long)self.statistics.anomaliesDetected]];
    
    [self.delegate arpDetectorDidStopMonitoring:self];
    
    NSLog(@"[WiFiGuard] ARP monitoring stopped");
}

#pragma mark - ARP Table Reading (Passive)

- (void)performSingleCheck {
    @try {
        NSArray<WGARPEntry *> *entries = [self readARPTable];
        
        // Check for anomalies
        [self analyzeARPTable:entries];
        
        // Update statistics
        self.statistics.totalEntriesMonitored = entries.count;
        
        // Notify delegate
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate arpDetector:self didUpdateTable:entries];
        });
        
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Error reading ARP table: %@", exception);
    }
}

- (NSArray<WGARPEntry *> *)readARPTable {
    /*
     * This method ONLY READS the system ARP table.
     * It does NOT send any packets or modify anything.
     * Uses sysctl() to read kernel routing/ARP information.
     */
    
    NSMutableArray<WGARPEntry *> *entries = [NSMutableArray array];
    
    int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO};
    size_t len = 0;
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        NSLog(@"[WiFiGuard] sysctl estimate failed");
        return entries;
    }
    
    if (len == 0) {
        return entries;
    }
    
    char *buf = malloc(len);
    if (!buf) {
        return entries;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        free(buf);
        NSLog(@"[WiFiGuard] sysctl read failed");
        return entries;
    }
    
    char *next = buf;
    char *end = buf + len;
    
    while (next < end) {
        struct rt_msghdr *rtm = (struct rt_msghdr *)next;
        
        if (rtm->rtm_msglen == 0) {
            break;
        }
        
        struct sockaddr_inarp *sin = (struct sockaddr_inarp *)(rtm + 1);
        struct sockaddr_dl *sdl = (struct sockaddr_dl *)((char *)sin + 
            (sin->sin_len > 0 ? (1 + ((sin->sin_len - 1) | (sizeof(long) - 1))) : sizeof(long)));
        
        if (sdl->sdl_family == AF_LINK && sdl->sdl_alen > 0) {
            WGARPEntry *entry = [[WGARPEntry alloc] init];
            
            // Get IP address
            char ipStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &sin->sin_addr, ipStr, sizeof(ipStr));
            entry.ipAddress = [NSString stringWithUTF8String:ipStr];
            
            // Get MAC address
            unsigned char *mac = (unsigned char *)LLADDR(sdl);
            entry.macAddress = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                               mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]];
            
            // Get interface name
            if (sdl->sdl_nlen > 0) {
                char ifname[IFNAMSIZ];
                memcpy(ifname, sdl->sdl_data, MIN(sdl->sdl_nlen, IFNAMSIZ - 1));
                ifname[MIN(sdl->sdl_nlen, IFNAMSIZ - 1)] = '\0';
                entry.interface = [NSString stringWithUTF8String:ifname];
            }
            
            // Check flags
            entry.isComplete = (rtm->rtm_flags & RTF_LLINFO) != 0;
            entry.isPermanent = (rtm->rtm_flags & RTF_STATIC) != 0;
            
            [entries addObject:entry];
        }
        
        next += rtm->rtm_msglen;
    }
    
    free(buf);
    
    return entries;
}

#pragma mark - Anomaly Detection

- (void)analyzeARPTable:(NSArray<WGARPEntry *> *)entries {
    // Check for rapid changes (too many changes in time window)
    [self checkForRapidChanges];
    
    for (WGARPEntry *entry in entries) {
        NSString *ip = entry.ipAddress;
        NSString *mac = entry.macAddress;
        
        WGARPEntry *cached = self.arpCache[ip];
        
        if (cached) {
            // Check for MAC change on same IP
            if (self.alertOnMACChange && 
                cached.macAddress && 
                ![cached.macAddress isEqualToString:mac]) {
                
                // Is this the gateway?
                if ([ip isEqualToString:self.gatewayIP]) {
                    [self reportAnomaly:WGARPAnomalyTypeGatewayMACChange
                                     ip:ip
                            previousMAC:cached.macAddress
                             currentMAC:mac
                               severity:10];
                } else {
                    [self reportAnomaly:WGARPAnomalyTypeMACChange
                                     ip:ip
                            previousMAC:cached.macAddress
                             currentMAC:mac
                               severity:6];
                }
                
                self.changeCountInWindow++;
            }
            
            [cached updateMAC:mac];
        } else {
            // New entry
            self.arpCache[ip] = entry;
        }
    }
    
    // Check for duplicate MACs (same MAC on multiple IPs)
    if (self.alertOnDuplicateMAC) {
        [self checkForDuplicateMACs:entries];
    }
    
    // Check gateway MAC
    if (self.alertOnGatewayChange && self.gatewayIP) {
        [self checkGatewayMAC];
    }
}

- (void)checkForDuplicateMACs:(NSArray<WGARPEntry *> *)entries {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *macToIPs = [NSMutableDictionary dictionary];
    
    for (WGARPEntry *entry in entries) {
        NSString *mac = entry.macAddress;
        if (!macToIPs[mac]) {
            macToIPs[mac] = [NSMutableArray array];
        }
        [macToIPs[mac] addObject:entry.ipAddress];
    }
    
    for (NSString *mac in macToIPs) {
        NSArray *ips = macToIPs[mac];
        if (ips.count > 1) {
            // Same MAC for multiple IPs - potential spoofing
            // But exclude broadcast/multicast MACs
            if (![self isBroadcastOrMulticastMAC:mac]) {
                NSString *details = [ips componentsJoinedByString:@", "];
                
                WGARPAnomaly *anomaly = [[WGARPAnomaly alloc] initWithType:WGARPAnomalyTypeDuplicateMAC];
                anomaly.currentMAC = mac;
                anomaly.details = details;
                anomaly.severity = 7;
                
                [self recordAnomaly:anomaly];
                self.statistics.duplicateMACsDetected++;
            }
        }
    }
}

- (BOOL)isBroadcastOrMulticastMAC:(NSString *)mac {
    // Broadcast: FF:FF:FF:FF:FF:FF
    if ([mac isEqualToString:@"FF:FF:FF:FF:FF:FF"]) {
        return YES;
    }
    
    // Multicast: first byte has LSB set
    NSString *firstByte = [mac substringToIndex:2];
    unsigned int byte = 0;
    [[NSScanner scannerWithString:firstByte] scanHexInt:&byte];
    
    return (byte & 0x01) != 0;
}

- (void)checkGatewayMAC {
    NSString *currentGatewayMAC = [self gatewayMAC];
    
    if (self.lastGatewayMAC && currentGatewayMAC &&
        ![self.lastGatewayMAC isEqualToString:currentGatewayMAC]) {
        
        // Check if it's a trusted MAC
        NSString *trustedMAC = self.trustedMACs[self.gatewayIP];
        if (trustedMAC && [currentGatewayMAC isEqualToString:trustedMAC]) {
            // Trusted, no alert
            self.lastGatewayMAC = currentGatewayMAC;
            return;
        }
        
        [self reportAnomaly:WGARPAnomalyTypeGatewayMACChange
                         ip:self.gatewayIP
                previousMAC:self.lastGatewayMAC
                 currentMAC:currentGatewayMAC
                   severity:10];
        
        self.statistics.gatewayAnomalies++;
    }
    
    self.lastGatewayMAC = currentGatewayMAC;
}

- (void)checkForRapidChanges {
    NSTimeInterval windowDuration = 60.0; // 1 minute window
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.windowStartTime];
    
    if (elapsed >= windowDuration) {
        // Check if too many changes in this window
        if (self.changeCountInWindow > 10) {
            WGARPAnomaly *anomaly = [[WGARPAnomaly alloc] initWithType:WGARPAnomalyTypeRapidChanges];
            anomaly.details = [NSString stringWithFormat:@"%ld changes in %.0f seconds",
                              (long)self.changeCountInWindow, elapsed];
            anomaly.severity = 8;
            
            [self recordAnomaly:anomaly];
        }
        
        // Reset window
        self.windowStartTime = [NSDate date];
        self.changeCountInWindow = 0;
    }
}

- (void)reportAnomaly:(WGARPAnomalyType)type
                   ip:(NSString *)ip
          previousMAC:(NSString *)previousMAC
           currentMAC:(NSString *)currentMAC
             severity:(NSInteger)severity {
    
    WGARPAnomaly *anomaly = [[WGARPAnomaly alloc] initWithType:type];
    anomaly.ipAddress = ip;
    anomaly.previousMAC = previousMAC;
    anomaly.currentMAC = currentMAC;
    anomaly.severity = severity;
    
    [self recordAnomaly:anomaly];
    
    if (type == WGARPAnomalyTypeMACChange || type == WGARPAnomalyTypeGatewayMACChange) {
        self.statistics.macChangesDetected++;
    }
}

- (void)recordAnomaly:(WGARPAnomaly *)anomaly {
    [self.anomalyHistory addObject:anomaly];
    self.statistics.anomaliesDetected++;
    
    // Log to audit
    [self.auditLogger logEvent:@"ARP_ANOMALY_DETECTED" 
                       details:[anomaly localizedDescription]];
    
    // Keep only last 1000 anomalies
    if (self.anomalyHistory.count > 1000) {
        [self.anomalyHistory removeObjectAtIndex:0];
    }
    
    // Notify delegate on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate arpDetector:self didDetectAnomaly:anomaly];
    });
    
    NSLog(@"[WiFiGuard] %@", [anomaly localizedDescription]);
}

#pragma mark - Configuration

- (void)setGatewayIP:(NSString *)ip {
    _gatewayIP = ip;
    [self.auditLogger logEvent:@"GATEWAY_SET" details:ip];
}

- (void)addTrustedMAC:(NSString *)mac forIP:(NSString *)ip {
    self.trustedMACs[ip] = [mac uppercaseString];
    [self.auditLogger logEvent:@"TRUSTED_MAC_ADDED" 
                       details:[NSString stringWithFormat:@"%@ -> %@", ip, mac]];
}

- (void)removeTrustedMAC:(NSString *)mac {
    NSArray *keysToRemove = [self.trustedMACs allKeysForObject:[mac uppercaseString]];
    for (NSString *key in keysToRemove) {
        [self.trustedMACs removeObjectForKey:key];
    }
}

- (void)clearTrustedMACs {
    [self.trustedMACs removeAllObjects];
    [self.auditLogger logEvent:@"TRUSTED_MACS_CLEARED" details:@"All trusted MACs removed"];
}

#pragma mark - Data Access

- (NSArray<WGARPEntry *> *)currentARPTable {
    return [self.arpCache.allValues copy];
}

- (NSArray<WGARPAnomaly *> *)detectedAnomalies {
    return [self.anomalyHistory copy];
}

- (WGARPEntry *)entryForIP:(NSString *)ip {
    return self.arpCache[ip];
}

- (NSArray<WGARPEntry *> *)entriesWithMAC:(NSString *)mac {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"macAddress ==[c] %@", mac];
    return [self.arpCache.allValues filteredArrayUsingPredicate:predicate];
}

- (NSString *)gatewayMAC {
    if (!self.gatewayIP) {
        return nil;
    }
    
    WGARPEntry *gatewayEntry = self.arpCache[self.gatewayIP];
    return gatewayEntry.macAddress;
}

- (NSString *)gatewayIP {
    return _gatewayIP;
}

#pragma mark - Anomaly Management

- (void)clearAnomalyHistory {
    [self.anomalyHistory removeAllObjects];
    self.statistics.anomaliesDetected = 0;
    [self.auditLogger logEvent:@"ANOMALY_HISTORY_CLEARED" details:@"All anomalies cleared"];
}

- (NSArray<WGARPAnomaly *> *)anomaliesSince:(NSDate *)date {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"detectedAt >= %@", date];
    return [self.anomalyHistory filteredArrayUsingPredicate:predicate];
}

- (NSArray<WGARPAnomaly *> *)anomaliesOfType:(WGARPAnomalyType)type {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %ld", (long)type];
    return [self.anomalyHistory filteredArrayUsingPredicate:predicate];
}

#pragma mark - Export

- (NSArray<NSDictionary *> *)exportARPTable {
    NSMutableArray *data = [NSMutableArray array];
    for (WGARPEntry *entry in self.arpCache.allValues) {
        [data addObject:[entry toDictionary]];
    }
    return data;
}

- (NSArray<NSDictionary *> *)exportAnomalies {
    NSMutableArray *data = [NSMutableArray array];
    for (WGARPAnomaly *anomaly in self.anomalyHistory) {
        [data addObject:[anomaly toDictionary]];
    }
    return data;
}

@end
