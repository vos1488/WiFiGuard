/*
 * WGEncryption.m - Encryption Implementation
 * WiFiGuard - iOS 16.1.2 (Dopamine Rootless)
 */

#import "WGEncryption.h"
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

static const NSUInteger kSaltLength = 32;
static const NSUInteger kIVLength = 16;
static const NSUInteger kKeyLength = 32; // AES-256
static const NSUInteger kPBKDFRounds = 100000;

@implementation WGEncryption

#pragma mark - Key Derivation

+ (NSData *)deriveKeyFromPassword:(NSString *)password salt:(NSData *)salt {
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData *derivedKey = [NSMutableData dataWithLength:kKeyLength];
    
    CCKeyDerivationPBKDF(kCCPBKDF2,
                         passwordData.bytes,
                         passwordData.length,
                         salt.bytes,
                         salt.length,
                         kCCPRFHmacAlgSHA256,
                         kPBKDFRounds,
                         derivedKey.mutableBytes,
                         kKeyLength);
    
    return derivedKey;
}

+ (NSData *)generateRandomSalt {
    NSMutableData *salt = [NSMutableData dataWithLength:kSaltLength];
    int result = SecRandomCopyBytes(kSecRandomDefault, kSaltLength, salt.mutableBytes);
    if (result != 0) {
        NSLog(@"[WiFiGuard] Failed to generate random salt");
        return nil;
    }
    return salt;
}

#pragma mark - Encryption

+ (NSData *)encryptData:(NSData *)data 
           withPassword:(NSString *)password 
                  error:(NSError **)error {
    
    if (!data || !password || password.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"WGEncryptionError" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid input"}];
        }
        return nil;
    }
    
    // Generate random salt and IV
    NSData *salt = [self generateRandomSalt];
    NSMutableData *iv = [NSMutableData dataWithLength:kIVLength];
    int ivResult = SecRandomCopyBytes(kSecRandomDefault, kIVLength, iv.mutableBytes);
    if (ivResult != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"WGEncryptionError" 
                                         code:2 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate IV"}];
        }
        return nil;
    }
    
    // Derive key from password
    NSData *key = [self deriveKeyFromPassword:password salt:salt];
    
    // Prepare output buffer
    size_t bufferSize = data.length + kCCBlockSizeAES128;
    NSMutableData *cipherData = [NSMutableData dataWithLength:bufferSize];
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kKeyLength,
                                     iv.bytes,
                                     data.bytes,
                                     data.length,
                                     cipherData.mutableBytes,
                                     bufferSize,
                                     &numBytesEncrypted);
    
    if (status != kCCSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:@"WGEncryptionError" 
                                         code:status 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Encryption failed"}];
        }
        return nil;
    }
    
    cipherData.length = numBytesEncrypted;
    
    // Combine: salt + iv + ciphertext
    NSMutableData *result = [NSMutableData dataWithCapacity:salt.length + iv.length + cipherData.length];
    [result appendData:salt];
    [result appendData:iv];
    [result appendData:cipherData];
    
    return result;
}

+ (NSData *)decryptData:(NSData *)data 
           withPassword:(NSString *)password 
                  error:(NSError **)error {
    
    if (!data || data.length < kSaltLength + kIVLength || !password) {
        if (error) {
            *error = [NSError errorWithDomain:@"WGEncryptionError" 
                                         code:1 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid input"}];
        }
        return nil;
    }
    
    // Extract salt, IV, and ciphertext
    NSData *salt = [data subdataWithRange:NSMakeRange(0, kSaltLength)];
    NSData *iv = [data subdataWithRange:NSMakeRange(kSaltLength, kIVLength)];
    NSData *cipherData = [data subdataWithRange:NSMakeRange(kSaltLength + kIVLength, 
                                                            data.length - kSaltLength - kIVLength)];
    
    // Derive key
    NSData *key = [self deriveKeyFromPassword:password salt:salt];
    
    // Prepare output buffer
    size_t bufferSize = cipherData.length + kCCBlockSizeAES128;
    NSMutableData *plainData = [NSMutableData dataWithLength:bufferSize];
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kKeyLength,
                                     iv.bytes,
                                     cipherData.bytes,
                                     cipherData.length,
                                     plainData.mutableBytes,
                                     bufferSize,
                                     &numBytesDecrypted);
    
    if (status != kCCSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:@"WGEncryptionError" 
                                         code:status 
                                     userInfo:@{NSLocalizedDescriptionKey: @"Decryption failed"}];
        }
        return nil;
    }
    
    plainData.length = numBytesDecrypted;
    return plainData;
}

#pragma mark - File Encryption

+ (BOOL)encryptFile:(NSString *)inputPath 
           toOutput:(NSString *)outputPath 
       withPassword:(NSString *)password 
              error:(NSError **)error {
    
    NSData *inputData = [NSData dataWithContentsOfFile:inputPath options:0 error:error];
    if (!inputData) {
        return NO;
    }
    
    NSData *encryptedData = [self encryptData:inputData withPassword:password error:error];
    if (!encryptedData) {
        return NO;
    }
    
    return [encryptedData writeToFile:outputPath options:NSDataWritingAtomic error:error];
}

+ (BOOL)decryptFile:(NSString *)inputPath 
           toOutput:(NSString *)outputPath 
       withPassword:(NSString *)password 
              error:(NSError **)error {
    
    NSData *inputData = [NSData dataWithContentsOfFile:inputPath options:0 error:error];
    if (!inputData) {
        return NO;
    }
    
    NSData *decryptedData = [self decryptData:inputData withPassword:password error:error];
    if (!decryptedData) {
        return NO;
    }
    
    return [decryptedData writeToFile:outputPath options:NSDataWritingAtomic error:error];
}

#pragma mark - Utilities

+ (NSString *)generateRandomPassword:(NSUInteger)length {
    static NSString *charset = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*";
    
    NSMutableString *password = [NSMutableString stringWithCapacity:length];
    NSUInteger charsetLength = charset.length;
    
    for (NSUInteger i = 0; i < length; i++) {
        uint32_t randomIndex = arc4random_uniform((uint32_t)charsetLength);
        unichar c = [charset characterAtIndex:randomIndex];
        [password appendFormat:@"%C", c];
    }
    
    return password;
}

@end
