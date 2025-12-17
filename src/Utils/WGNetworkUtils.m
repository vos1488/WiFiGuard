/*
 * WGNetworkUtils.m - Network Utilities Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGNetworkUtils.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <netdb.h>

@implementation WGNetworkUtils

#pragma mark - Device Network Info

+ (NSString *)currentSSID {
    NSString *ssid = nil;
    
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (interfaces) {
        CFIndex count = CFArrayGetCount(interfaces);
        for (CFIndex i = 0; i < count; i++) {
            CFStringRef interface = CFArrayGetValueAtIndex(interfaces, i);
            CFDictionaryRef networkInfo = CNCopyCurrentNetworkInfo(interface);
            
            if (networkInfo) {
                ssid = (__bridge_transfer NSString *)CFDictionaryGetValue(networkInfo, kCNNetworkInfoKeySSID);
                CFRelease(networkInfo);
                if (ssid) break;
            }
        }
        CFRelease(interfaces);
    }
    
    return ssid;
}

+ (NSString *)currentBSSID {
    NSString *bssid = nil;
    
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (interfaces) {
        CFIndex count = CFArrayGetCount(interfaces);
        for (CFIndex i = 0; i < count; i++) {
            CFStringRef interface = CFArrayGetValueAtIndex(interfaces, i);
            CFDictionaryRef networkInfo = CNCopyCurrentNetworkInfo(interface);
            
            if (networkInfo) {
                bssid = (__bridge_transfer NSString *)CFDictionaryGetValue(networkInfo, kCNNetworkInfoKeyBSSID);
                CFRelease(networkInfo);
                if (bssid) break;
            }
        }
        CFRelease(interfaces);
    }
    
    return bssid;
}

+ (NSString *)localIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    
    if (getifaddrs(&interfaces) == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check for en0 (WiFi)
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:
                              inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return address;
}

+ (NSString *)gatewayIPAddress {
    // This is a simplified version - actual implementation would use routing table
    NSString *localIP = [self localIPAddress];
    if (!localIP) return nil;
    
    // Assume standard gateway format (x.x.x.1)
    NSArray *components = [localIP componentsSeparatedByString:@"."];
    if (components.count == 4) {
        return [NSString stringWithFormat:@"%@.%@.%@.1", 
                components[0], components[1], components[2]];
    }
    
    return nil;
}

+ (NSString *)macAddressForIP:(NSString *)ip {
    // This would read from ARP table - simplified stub
    // Actual implementation is in WGARPDetector
    return nil;
}

#pragma mark - Validation

+ (BOOL)isValidIPAddress:(NSString *)ip {
    if (!ip || ip.length == 0) return NO;
    
    struct sockaddr_in sa;
    int result = inet_pton(AF_INET, [ip UTF8String], &(sa.sin_addr));
    return result == 1;
}

+ (BOOL)isValidMACAddress:(NSString *)mac {
    if (!mac || mac.length == 0) return NO;
    
    // Expected format: XX:XX:XX:XX:XX:XX
    NSString *pattern = @"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern 
                                                                           options:0 
                                                                             error:nil];
    NSRange range = [regex rangeOfFirstMatchInString:mac options:0 range:NSMakeRange(0, mac.length)];
    return range.location != NSNotFound;
}

+ (BOOL)isPrivateIPAddress:(NSString *)ip {
    if (![self isValidIPAddress:ip]) return NO;
    
    uint32_t ipInt = [self ipAddressToInt:ip];
    
    // 10.0.0.0 - 10.255.255.255
    if ((ipInt & 0xFF000000) == 0x0A000000) return YES;
    
    // 172.16.0.0 - 172.31.255.255
    if ((ipInt & 0xFFF00000) == 0xAC100000) return YES;
    
    // 192.168.0.0 - 192.168.255.255
    if ((ipInt & 0xFFFF0000) == 0xC0A80000) return YES;
    
    return NO;
}

#pragma mark - Conversion

+ (NSString *)formatMACAddress:(NSString *)mac {
    NSString *cleaned = [[mac uppercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@":"];
    return cleaned;
}

+ (uint32_t)ipAddressToInt:(NSString *)ip {
    struct in_addr addr;
    if (inet_pton(AF_INET, [ip UTF8String], &addr) == 1) {
        return ntohl(addr.s_addr);
    }
    return 0;
}

+ (NSString *)intToIPAddress:(uint32_t)ipInt {
    struct in_addr addr;
    addr.s_addr = htonl(ipInt);
    char buffer[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &addr, buffer, sizeof(buffer));
    return [NSString stringWithUTF8String:buffer];
}

#pragma mark - Channel Info

+ (NSInteger)frequencyToChannel:(NSInteger)frequencyMHz {
    // 2.4 GHz band
    if (frequencyMHz >= 2412 && frequencyMHz <= 2484) {
        if (frequencyMHz == 2484) return 14;
        return (frequencyMHz - 2412) / 5 + 1;
    }
    
    // 5 GHz band
    if (frequencyMHz >= 5170 && frequencyMHz <= 5825) {
        return (frequencyMHz - 5000) / 5;
    }
    
    return 0;
}

+ (NSInteger)channelToFrequency:(NSInteger)channel {
    // 2.4 GHz band
    if (channel >= 1 && channel <= 13) {
        return 2412 + (channel - 1) * 5;
    }
    if (channel == 14) {
        return 2484;
    }
    
    // 5 GHz band
    if (channel >= 36 && channel <= 165) {
        return 5000 + channel * 5;
    }
    
    return 0;
}

+ (BOOL)is5GHzChannel:(NSInteger)channel {
    return channel >= 36 && channel <= 165;
}

@end
