/*
 * WGDataExporter.m - Data Export Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGDataExporter.h"
#import "WGWiFiScanner.h"
#import "WGARPDetector.h"
#import "WGAuditLogger.h"
#import "WGEncryption.h"

@implementation WGDataExporter

#pragma mark - Initialization

- (instancetype)initWithScanner:(WGWiFiScanner *)scanner
                    arpDetector:(WGARPDetector *)detector
                    auditLogger:(WGAuditLogger *)logger {
    self = [super init];
    if (self) {
        _wifiScanner = scanner;
        _arpDetector = detector;
        _auditLogger = logger;
    }
    return self;
}

#pragma mark - Export Networks

- (BOOL)exportNetworksToPath:(NSString *)path 
                      format:(WGExportFormat)format
                    password:(NSString *)password
                       error:(NSError **)error {
    
    NSArray *networks = [self.wifiScanner exportData];
    
    NSString *content;
    if (format == WGExportFormatCSV || format == WGExportFormatEncryptedCSV) {
        content = [self networksToCSV:networks];
    } else {
        content = [self networksToJSON:networks];
    }
    
    return [self writeContent:content 
                       toPath:path 
                    encrypted:(format == WGExportFormatEncryptedCSV || format == WGExportFormatEncryptedJSON)
                     password:password 
                        error:error];
}

- (NSString *)networksToCSV:(NSArray<NSDictionary *> *)networks {
    NSMutableString *csv = [NSMutableString string];
    
    // Header
    [csv appendString:@"SSID,BSSID,Channel,RSSI,Channel Width,Security Type,Hidden,Last Seen\n"];
    
    for (NSDictionary *network in networks) {
        NSString *ssid = [self escapeCSV:network[@"ssid"]];
        [csv appendFormat:@"%@,%@,%@,%@,%@,%@,%@,%@\n",
         ssid,
         network[@"bssid"],
         network[@"channel"],
         network[@"rssi"],
         network[@"channelWidth"],
         network[@"securityType"],
         [network[@"isHidden"] boolValue] ? @"Yes" : @"No",
         network[@"lastSeen"]];
    }
    
    return csv;
}

- (NSString *)networksToJSON:(NSArray<NSDictionary *> *)networks {
    NSDictionary *export = @{
        @"exportType": @"WiFiNetworks",
        @"exportedAt": [[NSDate date] description],
        @"networkCount": @(networks.count),
        @"networks": networks
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:export 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error) {
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Export ARP Table

- (BOOL)exportARPTableToPath:(NSString *)path
                      format:(WGExportFormat)format
                    password:(NSString *)password
                       error:(NSError **)error {
    
    NSArray *entries = [self.arpDetector exportARPTable];
    
    NSString *content;
    if (format == WGExportFormatCSV || format == WGExportFormatEncryptedCSV) {
        content = [self arpTableToCSV:entries];
    } else {
        content = [self arpTableToJSON:entries];
    }
    
    return [self writeContent:content 
                       toPath:path 
                    encrypted:(format == WGExportFormatEncryptedCSV || format == WGExportFormatEncryptedJSON)
                     password:password 
                        error:error];
}

- (NSString *)arpTableToCSV:(NSArray<NSDictionary *> *)entries {
    NSMutableString *csv = [NSMutableString string];
    
    [csv appendString:@"IP Address,MAC Address,Interface,Complete,Permanent,First Seen,Last Seen\n"];
    
    for (NSDictionary *entry in entries) {
        [csv appendFormat:@"%@,%@,%@,%@,%@,%@,%@\n",
         entry[@"ipAddress"],
         entry[@"macAddress"],
         entry[@"interface"],
         [entry[@"isComplete"] boolValue] ? @"Yes" : @"No",
         [entry[@"isPermanent"] boolValue] ? @"Yes" : @"No",
         entry[@"firstSeen"],
         entry[@"lastSeen"]];
    }
    
    return csv;
}

- (NSString *)arpTableToJSON:(NSArray<NSDictionary *> *)entries {
    NSDictionary *export = @{
        @"exportType": @"ARPTable",
        @"exportedAt": [[NSDate date] description],
        @"entryCount": @(entries.count),
        @"entries": entries
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:export 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error) {
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Export Anomalies

- (BOOL)exportAnomaliesLoPath:(NSString *)path
                       format:(WGExportFormat)format
                     password:(NSString *)password
                        error:(NSError **)error {
    
    NSArray *anomalies = [self.arpDetector exportAnomalies];
    
    NSString *content;
    if (format == WGExportFormatCSV || format == WGExportFormatEncryptedCSV) {
        content = [self anomaliesToCSV:anomalies];
    } else {
        content = [self anomaliesToJSON:anomalies];
    }
    
    return [self writeContent:content 
                       toPath:path 
                    encrypted:(format == WGExportFormatEncryptedCSV || format == WGExportFormatEncryptedJSON)
                     password:password 
                        error:error];
}

- (NSString *)anomaliesToCSV:(NSArray<NSDictionary *> *)anomalies {
    NSMutableString *csv = [NSMutableString string];
    
    [csv appendString:@"Detected At,Type,IP Address,Previous MAC,Current MAC,Severity,Details\n"];
    
    for (NSDictionary *anomaly in anomalies) {
        NSString *details = [self escapeCSV:anomaly[@"details"]];
        [csv appendFormat:@"%@,%@,%@,%@,%@,%@,%@\n",
         anomaly[@"detectedAt"],
         anomaly[@"typeName"],
         anomaly[@"ipAddress"],
         anomaly[@"previousMAC"],
         anomaly[@"currentMAC"],
         anomaly[@"severity"],
         details];
    }
    
    return csv;
}

- (NSString *)anomaliesToJSON:(NSArray<NSDictionary *> *)anomalies {
    NSDictionary *export = @{
        @"exportType": @"ARPAnomalies",
        @"exportedAt": [[NSDate date] description],
        @"anomalyCount": @(anomalies.count),
        @"anomalies": anomalies
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:export 
                                                       options:NSJSONWritingPrettyPrinted 
                                                         error:&error];
    if (error) {
        return @"{}";
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Export Audit Log

- (BOOL)exportAuditLogToPath:(NSString *)path
                      format:(WGExportFormat)format
                    password:(NSString *)password
                       error:(NSError **)error {
    
    NSString *content;
    if (format == WGExportFormatCSV || format == WGExportFormatEncryptedCSV) {
        content = [self.auditLogger generateCSVExport];
    } else {
        NSDictionary *jsonDict = [self.auditLogger generateJSONExport];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict 
                                                           options:NSJSONWritingPrettyPrinted 
                                                             error:error];
        if (*error) {
            return NO;
        }
        content = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    return [self writeContent:content 
                       toPath:path 
                    encrypted:(format == WGExportFormatEncryptedCSV || format == WGExportFormatEncryptedJSON)
                     password:password 
                        error:error];
}

#pragma mark - Export All

- (BOOL)exportAllDataToPath:(NSString *)path
                   password:(NSString *)password
                      error:(NSError **)error {
    
    // Create export directory
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    
    BOOL encrypted = (password != nil && password.length > 0);
    WGExportFormat format = encrypted ? WGExportFormatEncryptedJSON : WGExportFormatJSON;
    NSString *ext = encrypted ? @"json.enc" : @"json";
    
    // Export networks
    NSString *networksPath = [path stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"networks.%@", ext]];
    if (![self exportNetworksToPath:networksPath format:format password:password error:error]) {
        return NO;
    }
    
    // Export ARP table
    NSString *arpPath = [path stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"arp_table.%@", ext]];
    if (![self exportARPTableToPath:arpPath format:format password:password error:error]) {
        return NO;
    }
    
    // Export anomalies
    NSString *anomaliesPath = [path stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"anomalies.%@", ext]];
    if (![self exportAnomaliesLoPath:anomaliesPath format:format password:password error:error]) {
        return NO;
    }
    
    // Export audit log
    NSString *auditPath = [path stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"audit_log.%@", ext]];
    if (![self exportAuditLogToPath:auditPath format:format password:password error:error]) {
        return NO;
    }
    
    // Log export
    [self.auditLogger logExport:path];
    
    return YES;
}

#pragma mark - Utility Methods

- (BOOL)writeContent:(NSString *)content 
              toPath:(NSString *)path 
           encrypted:(BOOL)encrypted
            password:(NSString *)password
               error:(NSError **)error {
    
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    if (encrypted && password.length > 0) {
        data = [WGEncryption encryptData:data withPassword:password error:error];
        if (!data) {
            return NO;
        }
    }
    
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

- (NSString *)escapeCSV:(NSString *)value {
    if (!value) return @"";
    
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    
    if ([escaped containsString:@","] || [escaped containsString:@"\n"] || [escaped containsString:@"\""]) {
        return [NSString stringWithFormat:@"\"%@\"", escaped];
    }
    
    return escaped;
}

- (NSString *)defaultExportDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    return [documentsDir stringByAppendingPathComponent:@"WiFiGuard/Exports"];
}

- (NSString *)generateFilename:(NSString *)prefix extension:(NSString *)ext {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    return [NSString stringWithFormat:@"%@_%@.%@", prefix, timestamp, ext];
}

+ (BOOL)validateExportPath:(NSString *)path error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [path stringByDeletingLastPathComponent];
    
    if (![fm fileExistsAtPath:directory]) {
        return [fm createDirectoryAtPath:directory 
             withIntermediateDirectories:YES 
                              attributes:nil 
                                   error:error];
    }
    
    return YES;
}

@end
