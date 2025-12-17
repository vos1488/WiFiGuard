/*
 * WGWiFiScanner.h - Passive Wi-Fi Network Scanner
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * PASSIVE SCANNING ONLY - No active attacks implemented
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WGAuditLogger;

// Wi-Fi Network Information Structure
@interface WGNetworkInfo : NSObject

@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, copy) NSString *bssid;
@property (nonatomic, assign) NSInteger channel;
@property (nonatomic, assign) NSInteger rssi;
@property (nonatomic, assign) NSInteger channelWidth; // 20, 40, 80, 160 MHz
@property (nonatomic, copy) NSString *securityType; // WPA2, WPA3, WEP, Open
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, strong) NSDate *lastSeen;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *rssiHistory;
@property (nonatomic, strong) NSMutableArray<NSDate *> *rssiTimestamps;

- (NSDictionary *)toDictionary;
+ (instancetype)networkFromDictionary:(NSDictionary *)dict;

@end

// Channel Statistics
@interface WGChannelStats : NSObject

@property (nonatomic, assign) NSInteger channel;
@property (nonatomic, assign) NSInteger networkCount;
@property (nonatomic, assign) CGFloat averageRSSI;
@property (nonatomic, assign) NSInteger congestionLevel; // 0-100

@end

// Scan Result Delegate
@protocol WGWiFiScannerDelegate <NSObject>
@optional
- (void)wifiScanner:(id)scanner didFindNetworks:(NSArray<WGNetworkInfo *> *)networks;
- (void)wifiScanner:(id)scanner didUpdateNetwork:(WGNetworkInfo *)network;
- (void)wifiScanner:(id)scanner didEncounterError:(NSError *)error;
- (void)wifiScannerDidStartScanning:(id)scanner;
- (void)wifiScannerDidStopScanning:(id)scanner;
@end

// Main Scanner Class
@interface WGWiFiScanner : NSObject

@property (nonatomic, weak, nullable) id<WGWiFiScannerDelegate> delegate;
@property (nonatomic, readonly) BOOL isScanning;
@property (nonatomic, readonly) NSArray<WGNetworkInfo *> *discoveredNetworks;
@property (nonatomic, readonly) NSArray<WGChannelStats *> *channelStatistics;
@property (nonatomic, assign) NSTimeInterval scanInterval; // Default 5 seconds

// Initialization
- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger;

// Scanning Control
- (BOOL)startScanning;
- (void)stopScanning;
- (void)performSingleScan;

// Data Access
- (nullable WGNetworkInfo *)networkWithBSSID:(NSString *)bssid;
- (NSArray<WGNetworkInfo *> *)networksOnChannel:(NSInteger)channel;
- (NSArray<WGNetworkInfo *> *)networksWithSecurityType:(NSString *)type;
- (NSArray<WGNetworkInfo *> *)hiddenNetworks;

// Statistics
- (WGChannelStats *)statsForChannel:(NSInteger)channel;
- (NSInteger)mostCrowdedChannel;
- (NSInteger)leastCrowdedChannel;
- (NSArray<NSNumber *> *)recommendedChannels;

// Cache Management
- (void)clearCache;
- (void)clearRSSIHistory;

// Export
- (NSArray<NSDictionary *> *)exportData;

@end

NS_ASSUME_NONNULL_END
