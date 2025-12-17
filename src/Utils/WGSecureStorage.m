/*
 * WGSecureStorage.m - Secure Storage Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGSecureStorage.h"
#import <Security/Security.h>

static NSString *const kWGPreferencesKey = @"com.wifiguard.preferences";
static NSString *const kWGOwnerConfirmedKey = @"ownerConfirmed";
static NSString *const kWGOwnerConfirmDateKey = @"ownerConfirmDate";

@implementation WGSecureStorage

#pragma mark - Secure Deletion

+ (BOOL)secureDeleteFile:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:path]) {
        return YES;
    }
    
    @try {
        // Get file size
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        unsigned long long fileSize = [attrs fileSize];
        
        if (fileSize > 0) {
            // Overwrite with random data (3 passes)
            for (int pass = 0; pass < 3; pass++) {
                NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
                if (handle) {
                    NSMutableData *randomData = [NSMutableData dataWithLength:(NSUInteger)fileSize];
                    int result = SecRandomCopyBytes(kSecRandomDefault, randomData.length, randomData.mutableBytes);
                    if (result == 0) {
                        [handle writeData:randomData];
                        [handle synchronizeFile];
                    }
                    [handle closeFile];
                }
            }
        }
        
        // Delete file
        NSError *error;
        BOOL success = [fm removeItemAtPath:path error:&error];
        
        if (!success) {
            NSLog(@"[WiFiGuard] Error deleting file: %@", error);
        }
        
        return success;
        
    } @catch (NSException *exception) {
        NSLog(@"[WiFiGuard] Secure delete exception: %@", exception);
        return NO;
    }
}

+ (void)secureDeleteTemporaryFiles {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    NSString *tempDir = [documentsDir stringByAppendingPathComponent:@"WiFiGuard/Temp"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:tempDir error:nil];
    
    for (NSString *file in files) {
        NSString *fullPath = [tempDir stringByAppendingPathComponent:file];
        [self secureDeleteFile:fullPath];
    }
    
    NSLog(@"[WiFiGuard] Temporary files securely deleted");
}

+ (void)secureDeleteAllData {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    NSString *wgDir = [documentsDir stringByAppendingPathComponent:@"WiFiGuard"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:wgDir];
    NSString *file;
    
    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [wgDir stringByAppendingPathComponent:file];
        BOOL isDir;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            [self secureDeleteFile:fullPath];
        }
    }
    
    // Remove directories
    [fm removeItemAtPath:wgDir error:nil];
    
    // Clear preferences
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWGPreferencesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSLog(@"[WiFiGuard] All data securely deleted");
}

#pragma mark - Preferences

+ (NSMutableDictionary *)loadPreferences {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] objectForKey:kWGPreferencesKey];
    if (prefs) {
        return [prefs mutableCopy];
    }
    return [NSMutableDictionary dictionary];
}

+ (void)savePreferences:(NSDictionary *)prefs {
    [[NSUserDefaults standardUserDefaults] setObject:prefs forKey:kWGPreferencesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)savePreference:(id)value forKey:(NSString *)key {
    NSMutableDictionary *prefs = [self loadPreferences];
    prefs[key] = value;
    [self savePreferences:prefs];
}

+ (id)preferenceForKey:(NSString *)key {
    NSDictionary *prefs = [self loadPreferences];
    return prefs[key];
}

+ (void)removePreferenceForKey:(NSString *)key {
    NSMutableDictionary *prefs = [self loadPreferences];
    [prefs removeObjectForKey:key];
    [self savePreferences:prefs];
}

#pragma mark - Owner Confirmation

+ (void)saveOwnerConfirmation:(BOOL)confirmed {
    [self savePreference:@(confirmed) forKey:kWGOwnerConfirmedKey];
    if (confirmed) {
        [self savePreference:[NSDate date] forKey:kWGOwnerConfirmDateKey];
    }
}

+ (BOOL)hasOwnerConfirmation {
    NSNumber *confirmed = [self preferenceForKey:kWGOwnerConfirmedKey];
    return confirmed.boolValue;
}

+ (NSDate *)ownerConfirmationDate {
    return [self preferenceForKey:kWGOwnerConfirmDateKey];
}

@end
