/*
 * WGARPDetector.h - Passive ARP Spoofing Detection Module
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * DETECTION ONLY - NO ACTIVE ATTACKS OR COUNTERMEASURES
 * This module passively monitors the ARP table for anomalies
 * indicating potential ARP spoofing/MITM attacks
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WGAuditLogger;

// ARP Table Entry
@interface WGARPEntry : NSObject

@property (nonatomic, copy) NSString *ipAddress;
@property (nonatomic, copy) NSString *macAddress;
@property (nonatomic, copy) NSString *interface;
@property (nonatomic, assign) BOOL isComplete;
@property (nonatomic, assign) BOOL isPermanent;
@property (nonatomic, strong) NSDate *firstSeen;
@property (nonatomic, strong) NSDate *lastSeen;
@property (nonatomic, strong) NSMutableArray<NSString *> *macHistory; // Track MAC changes

- (NSDictionary *)toDictionary;

@end

// ARP Anomaly Types
typedef NS_ENUM(NSInteger, WGARPAnomalyType) {
    WGARPAnomalyTypeNone = 0,
    WGARPAnomalyTypeMACChange,           // MAC address changed for same IP
    WGARPAnomalyTypeDuplicateMAC,        // Same MAC for multiple IPs
    WGARPAnomalyTypeGatewayMACChange,    // Gateway MAC changed (high severity)
    WGARPAnomalyTypeBSSIDMismatch,       // MAC doesn't match expected BSSID pattern
    WGARPAnomalyTypeRapidChanges,        // Too many ARP table changes
    WGARPAnomalyTypeUnexpectedGratuitous // Gratuitous ARP detected
};

// ARP Anomaly Alert
@interface WGARPAnomaly : NSObject

@property (nonatomic, assign) WGARPAnomalyType type;
@property (nonatomic, copy) NSString *ipAddress;
@property (nonatomic, copy) NSString *previousMAC;
@property (nonatomic, copy) NSString *currentMAC;
@property (nonatomic, copy) NSString *details;
@property (nonatomic, assign) NSInteger severity; // 1-10
@property (nonatomic, strong) NSDate *detectedAt;

- (NSDictionary *)toDictionary;
- (NSString *)localizedDescription;

@end

// Detection Statistics
@interface WGARPStats : NSObject

@property (nonatomic, assign) NSInteger totalEntriesMonitored;
@property (nonatomic, assign) NSInteger anomaliesDetected;
@property (nonatomic, assign) NSInteger macChangesDetected;
@property (nonatomic, assign) NSInteger duplicateMACsDetected;
@property (nonatomic, assign) NSInteger gatewayAnomalies;
@property (nonatomic, strong) NSDate *monitoringStarted;
@property (nonatomic, assign) NSTimeInterval totalMonitoringTime;

@end

// Delegate Protocol
@protocol WGARPDetectorDelegate <NSObject>
@optional
- (void)arpDetector:(id)detector didDetectAnomaly:(WGARPAnomaly *)anomaly;
- (void)arpDetector:(id)detector didUpdateTable:(NSArray<WGARPEntry *> *)entries;
- (void)arpDetectorDidStartMonitoring:(id)detector;
- (void)arpDetectorDidStopMonitoring:(id)detector;
@end

// Main ARP Detection Class
@interface WGARPDetector : NSObject

@property (nonatomic, weak, nullable) id<WGARPDetectorDelegate> delegate;
@property (nonatomic, readonly) BOOL isMonitoring;
@property (nonatomic, readonly) NSArray<WGARPEntry *> *currentARPTable;
@property (nonatomic, readonly) NSArray<WGARPAnomaly *> *detectedAnomalies;
@property (nonatomic, readonly) WGARPStats *statistics;
@property (nonatomic, assign) NSTimeInterval checkInterval; // Default 3 seconds
@property (nonatomic, assign) BOOL alertOnGatewayChange;    // Default YES
@property (nonatomic, assign) BOOL alertOnMACChange;        // Default YES
@property (nonatomic, assign) BOOL alertOnDuplicateMAC;     // Default YES

// Singleton
+ (instancetype)sharedInstance;

// Initialization
- (instancetype)initWithAuditLogger:(WGAuditLogger *)logger;

// Monitoring Control
- (BOOL)startMonitoring;
- (void)stopMonitoring;
- (void)performSingleCheck;

// Configuration
- (void)setGatewayIP:(NSString *)ip;
- (void)addTrustedMAC:(NSString *)mac forIP:(NSString *)ip;
- (void)removeTrustedMAC:(NSString *)mac;
- (void)clearTrustedMACs;

// Data Access
- (nullable WGARPEntry *)entryForIP:(NSString *)ip;
- (NSArray<WGARPEntry *> *)entriesWithMAC:(NSString *)mac;
- (nullable NSString *)gatewayMAC;
- (nullable NSString *)gatewayIP;

// Anomaly Management
- (void)clearAnomalyHistory;
- (NSArray<WGARPAnomaly *> *)anomaliesSince:(NSDate *)date;
- (NSArray<WGARPAnomaly *> *)anomaliesOfType:(WGARPAnomalyType)type;

// Export
- (NSArray<NSDictionary *> *)exportARPTable;
- (NSArray<NSDictionary *> *)exportAnomalies;

@end

NS_ASSUME_NONNULL_END
