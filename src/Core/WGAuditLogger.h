/*
 * WGAuditLogger.h - Audit Logging Module
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * Maintains local audit trail of all monitoring activities
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGAuditLogEntry : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *eventType;
@property (nonatomic, copy) NSString *details;
@property (nonatomic, copy) NSString *sessionId;

- (NSDictionary *)toDictionary;
- (NSString *)toCSVLine;

@end

@interface WGAuditLogger : NSObject

@property (nonatomic, readonly) NSString *sessionId;
@property (nonatomic, readonly) NSArray<WGAuditLogEntry *> *allEntries;
@property (nonatomic, readonly) NSString *logFilePath;

// Initialization
- (instancetype)init;

// Logging
- (void)logEvent:(NSString *)eventType details:(nullable NSString *)details;
- (void)logMonitoringStart;
- (void)logMonitoringStop;
- (void)logOwnerConfirmation;
- (void)logExport:(NSString *)filename;
- (void)logError:(NSString *)errorDescription;

// Query
- (NSArray<WGAuditLogEntry *> *)entriesSince:(NSDate *)date;
- (NSArray<WGAuditLogEntry *> *)entriesOfType:(NSString *)eventType;

// Export
- (BOOL)exportToFile:(NSString *)path error:(NSError **)error;
- (NSString *)generateCSVExport;
- (NSDictionary *)generateJSONExport;

// Cleanup
- (void)clearLogs;
- (void)pruneLogsOlderThan:(NSTimeInterval)age;

@end

NS_ASSUME_NONNULL_END
