/*
 * WGAuditLogger.m - Audit Logging Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGAuditLogger.h"

#pragma mark - WGAuditLogEntry Implementation

@implementation WGAuditLogEntry

- (instancetype)initWithEvent:(NSString *)eventType details:(NSString *)details sessionId:(NSString *)sessionId {
    self = [super init];
    if (self) {
        _timestamp = [NSDate date];
        _eventType = eventType;
        _details = details ?: @"";
        _sessionId = sessionId;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    
    return @{
        @"timestamp": [formatter stringFromDate:self.timestamp],
        @"eventType": self.eventType ?: @"",
        @"details": self.details ?: @"",
        @"sessionId": self.sessionId ?: @""
    };
}

- (NSString *)toCSVLine {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    
    // Escape CSV fields
    NSString *escapedDetails = [self.details stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    
    return [NSString stringWithFormat:@"\"%@\",\"%@\",\"%@\",\"%@\"",
            [formatter stringFromDate:self.timestamp],
            self.eventType,
            escapedDetails,
            self.sessionId];
}

@end

#pragma mark - WGAuditLogger Implementation

@interface WGAuditLogger ()

@property (nonatomic, strong) NSMutableArray<WGAuditLogEntry *> *entries;
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic, copy) NSString *logFilePath;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) dispatch_queue_t logQueue;

@end

@implementation WGAuditLogger

static WGAuditLogger *_sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        _sessionId = [[NSUUID UUID] UUIDString];
        _logQueue = dispatch_queue_create("com.wifiguard.auditlog", DISPATCH_QUEUE_SERIAL);
        
        [self setupLogFile];
    }
    return self;
}

- (void)startNewSession {
    _sessionId = [[NSUUID UUID] UUIDString];
    [self logEvent:@"SESSION_STARTED" details:[NSString stringWithFormat:@"Session ID: %@", _sessionId]];
}

- (void)endSession {
    [self logEvent:@"SESSION_ENDED" details:nil];
}

- (void)dealloc {
    [self logEvent:@"SESSION_ENDED" details:nil];
    [self.fileHandle closeFile];
}

- (void)setupLogFile {
    // Create log directory in app's Documents folder
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    NSString *logDir = [documentsDir stringByAppendingPathComponent:@"WiFiGuard/Logs"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    
    if (![fm fileExistsAtPath:logDir]) {
        [fm createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"[WiFiGuard] Error creating log directory: %@", error);
        }
    }
    
    // Create log file with timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    
    self.logFilePath = [logDir stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"audit_%@.log", dateStr]];
    
    // Create file if needed
    if (![fm fileExistsAtPath:self.logFilePath]) {
        [fm createFileAtPath:self.logFilePath contents:nil attributes:nil];
        
        // Write CSV header
        NSString *header = @"\"Timestamp\",\"Event Type\",\"Details\",\"Session ID\"\n";
        [header writeToFile:self.logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    // Open file handle for appending
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
    [self.fileHandle seekToEndOfFile];
}

#pragma mark - Logging

- (void)logEvent:(NSString *)eventType details:(NSString *)details {
    dispatch_async(self.logQueue, ^{
        WGAuditLogEntry *entry = [[WGAuditLogEntry alloc] initWithEvent:eventType
                                                                 details:details
                                                               sessionId:self.sessionId];
        [self.entries addObject:entry];
        
        // Write to file
        NSString *csvLine = [[entry toCSVLine] stringByAppendingString:@"\n"];
        NSData *data = [csvLine dataUsingEncoding:NSUTF8StringEncoding];
        
        @try {
            [self.fileHandle writeData:data];
            [self.fileHandle synchronizeFile];
        } @catch (NSException *exception) {
            NSLog(@"[WiFiGuard] Error writing to log: %@", exception);
        }
        
        // Keep only last 10000 entries in memory
        if (self.entries.count > 10000) {
            [self.entries removeObjectAtIndex:0];
        }
    });
}

- (void)logMonitoringStart {
    [self logEvent:@"MONITORING_STARTED" details:@"User initiated monitoring"];
}

- (void)logMonitoringStop {
    [self logEvent:@"MONITORING_STOPPED" details:@"User stopped monitoring"];
}

- (void)logOwnerConfirmation {
    [self logEvent:@"OWNER_CONFIRMED" 
           details:@"User confirmed network ownership/permission for testing"];
}

- (void)logExport:(NSString *)filename {
    [self logEvent:@"DATA_EXPORTED" 
           details:[NSString stringWithFormat:@"Exported to: %@", filename]];
}

- (void)logError:(NSString *)errorDescription {
    [self logEvent:@"ERROR" details:errorDescription];
}

#pragma mark - Query

- (NSArray<WGAuditLogEntry *> *)allEntries {
    __block NSArray *result;
    dispatch_sync(self.logQueue, ^{
        result = [self.entries copy];
    });
    return result;
}

- (NSArray<WGAuditLogEntry *> *)entriesSince:(NSDate *)date {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timestamp >= %@", date];
    return [self.allEntries filteredArrayUsingPredicate:predicate];
}

- (NSArray<WGAuditLogEntry *> *)entriesOfType:(NSString *)eventType {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"eventType == %@", eventType];
    return [self.allEntries filteredArrayUsingPredicate:predicate];
}

#pragma mark - Export

- (BOOL)exportToFile:(NSString *)path error:(NSError **)error {
    NSString *csv = [self generateCSVExport];
    return [csv writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (NSString *)generateCSVExport {
    NSMutableString *csv = [NSMutableString string];
    [csv appendString:@"\"Timestamp\",\"Event Type\",\"Details\",\"Session ID\"\n"];
    
    for (WGAuditLogEntry *entry in self.allEntries) {
        [csv appendString:[entry toCSVLine]];
        [csv appendString:@"\n"];
    }
    
    return csv;
}

- (NSDictionary *)generateJSONExport {
    NSMutableArray *entriesArray = [NSMutableArray array];
    for (WGAuditLogEntry *entry in self.allEntries) {
        [entriesArray addObject:[entry toDictionary]];
    }
    
    return @{
        @"sessionId": self.sessionId,
        @"exportedAt": [[NSDate date] description],
        @"entries": entriesArray
    };
}

#pragma mark - Cleanup

- (void)clearLogs {
    dispatch_async(self.logQueue, ^{
        [self.entries removeAllObjects];
        [self logEvent:@"LOGS_CLEARED" details:@"Audit logs cleared by user"];
    });
}

- (void)pruneLogsOlderThan:(NSTimeInterval)age {
    dispatch_async(self.logQueue, ^{
        NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-age];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timestamp >= %@", cutoffDate];
        NSArray *filtered = [self.entries filteredArrayUsingPredicate:predicate];
        [self.entries setArray:[NSMutableArray arrayWithArray:filtered]];
        
        [self logEvent:@"LOGS_PRUNED" 
               details:[NSString stringWithFormat:@"Removed entries older than %.0f seconds", age]];
    });
}

@end
