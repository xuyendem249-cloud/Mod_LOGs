#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Local, device-bound keys for authenticated SAVE data.
@interface LGSaveVault : NSObject
- (nullable NSData*)seal:(NSData*)data
                 purpose:(NSString*)purpose
                   error:(NSError* _Nullable * _Nullable)error;
- (nullable NSData*)open:(NSData*)data
                 purpose:(NSString*)purpose
                   error:(NSError* _Nullable * _Nullable)error;
@end

/// A serial-I/O slot store. The cache is tied to the digest of the sealed file.
@interface LGQuickSlots : NSObject
- (instancetype)initWithVault:(LGSaveVault*)vault;
- (BOOL)writeState:(NSData*)state
              path:(NSString*)path
           purpose:(NSString*)purpose
             error:(NSError* _Nullable * _Nullable)error;
- (nullable NSData*)readState:(NSString*)path
                      purpose:(NSString*)purpose
                        error:(NSError* _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
