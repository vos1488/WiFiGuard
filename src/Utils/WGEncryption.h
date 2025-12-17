/*
 * WGEncryption.h - Encryption Utilities
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WGEncryption : NSObject

// AES-256 Encryption/Decryption
+ (nullable NSData *)encryptData:(NSData *)data 
                    withPassword:(NSString *)password 
                           error:(NSError **)error;

+ (nullable NSData *)decryptData:(NSData *)data 
                    withPassword:(NSString *)password 
                           error:(NSError **)error;

// File Encryption
+ (BOOL)encryptFile:(NSString *)inputPath 
           toOutput:(NSString *)outputPath 
       withPassword:(NSString *)password 
              error:(NSError **)error;

+ (BOOL)decryptFile:(NSString *)inputPath 
           toOutput:(NSString *)outputPath 
       withPassword:(NSString *)password 
              error:(NSError **)error;

// Key Derivation
+ (NSData *)deriveKeyFromPassword:(NSString *)password 
                             salt:(NSData *)salt;

// Utilities
+ (NSData *)generateRandomSalt;
+ (NSString *)generateRandomPassword:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
