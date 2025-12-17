/*
 * WGDataExporter.h - Data Export Module
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 * 
 * Handles CSV export with optional encryption
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class WGWiFiScanner;
@class WGARPDetector;
@class WGAuditLogger;

typedef NS_ENUM(NSInteger, WGExportFormat) {
    WGExportFormatCSV,
    WGExportFormatJSON,
    WGExportFormatEncryptedCSV,
    WGExportFormatEncryptedJSON
};

@interface WGDataExporter : NSObject

@property (nonatomic, weak) WGWiFiScanner *wifiScanner;
@property (nonatomic, weak) WGARPDetector *arpDetector;
@property (nonatomic, weak) WGAuditLogger *auditLogger;

// Initialization
- (instancetype)initWithScanner:(WGWiFiScanner *)scanner
                    arpDetector:(WGARPDetector *)detector
                    auditLogger:(WGAuditLogger *)logger;

// Export Functions
- (BOOL)exportNetworksToPath:(NSString *)path 
                      format:(WGExportFormat)format
                    password:(nullable NSString *)password
                       error:(NSError **)error;

- (BOOL)exportARPTableToPath:(NSString *)path
                      format:(WGExportFormat)format
                    password:(nullable NSString *)password
                       error:(NSError **)error;

- (BOOL)exportAnomaliesLoPath:(NSString *)path
                       format:(WGExportFormat)format
                     password:(nullable NSString *)password
                        error:(NSError **)error;

- (BOOL)exportAuditLogToPath:(NSString *)path
                      format:(WGExportFormat)format
                    password:(nullable NSString *)password
                       error:(NSError **)error;

- (BOOL)exportAllDataToPath:(NSString *)path
                   password:(nullable NSString *)password
                      error:(NSError **)error;

// Utility
- (NSString *)defaultExportDirectory;
- (NSString *)generateFilename:(NSString *)prefix extension:(NSString *)ext;
+ (BOOL)validateExportPath:(NSString *)path error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
