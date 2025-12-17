/*
 * WGNetworkUtils.h - Network Utilities
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGNetworkUtils : NSObject

// Device Network Info
+ (nullable NSString *)currentSSID;
+ (nullable NSString *)currentBSSID;
+ (nullable NSString *)localIPAddress;
+ (nullable NSString *)gatewayIPAddress;
+ (nullable NSString *)macAddressForIP:(NSString *)ip;

// Validation
+ (BOOL)isValidIPAddress:(NSString *)ip;
+ (BOOL)isValidMACAddress:(NSString *)mac;
+ (BOOL)isPrivateIPAddress:(NSString *)ip;

// Conversion
+ (NSString *)formatMACAddress:(NSString *)mac;
+ (uint32_t)ipAddressToInt:(NSString *)ip;
+ (NSString *)intToIPAddress:(uint32_t)ipInt;

// Channel Info
+ (NSInteger)frequencyToChannel:(NSInteger)frequencyMHz;
+ (NSInteger)channelToFrequency:(NSInteger)channel;
+ (BOOL)is5GHzChannel:(NSInteger)channel;

@end

NS_ASSUME_NONNULL_END
