/*
 * WGSecureStorage.h - Secure Storage Utilities
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGSecureStorage : NSObject

// Secure deletion
+ (BOOL)secureDeleteFile:(NSString *)path;
+ (void)secureDeleteTemporaryFiles;
+ (void)secureDeleteAllData;

// Preferences
+ (void)savePreference:(id)value forKey:(NSString *)key;
+ (nullable id)preferenceForKey:(NSString *)key;
+ (void)removePreferenceForKey:(NSString *)key;

// Owner confirmation storage
+ (void)saveOwnerConfirmation:(BOOL)confirmed;
+ (BOOL)hasOwnerConfirmation;
+ (NSDate *)ownerConfirmationDate;

@end

NS_ASSUME_NONNULL_END
