#import "LegendSaveVault.h"
#include "Gacha.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface LGGiftCodes : NSObject
- (instancetype)initWithVault:(LGSaveVault*)vault path:(NSString*)path issuer:(NSData*)issuer;
- (NSInteger)redeem:(NSString*)input game:(Legend::GachaTransaction&)game
   requireNativeLoad:(BOOL)requireNativeLoad error:(NSError* _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
