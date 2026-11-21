#import "LegendGiftCodes.hpp"
#import <Security/Security.h>
#include "Digest.hpp"
#include "CoreTransaction.hpp"
#include <array>
#include <cstring>
#include <stdexcept>

namespace {
NSString* const ledgerPurpose=@"gacha-gifts/v1";
constexpr size_t tokenBody=20;
constexpr size_t maxTokenLength=128;
// SubjectPublicKeyInfo header for the P-256 public key published with Android.
constexpr std::array<uint8_t,26> p256Spki{
 0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,
 0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x42,0x00
};
struct Gift {
 NSString* identifier;
 int stars;
};
NSString* hash(const Legend::Bytes& bytes){
 auto value=Legend::sha256(bytes,{{0,bytes.size()}});
 return [NSString stringWithUTF8String:value.c_str()];
}
Gift verifiedGift(NSString* input,NSData* issuer){
 NSString* code=[[input componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
  componentsJoinedByString:@""];
 if(![code hasPrefix:@"LGA1-"]||code.length>maxTokenLength+5)
  throw std::runtime_error("Mã quà không hợp lệ.");
 NSString* encoded=[code substringFromIndex:5];
 NSCharacterSet* alphabet=[NSCharacterSet characterSetWithCharactersInString:
  @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
 if(encoded.length<36||encoded.length>124||[encoded rangeOfCharacterFromSet:alphabet.invertedSet].location!=NSNotFound)
  throw std::runtime_error("Mã quà không hợp lệ.");
 NSString* base64=[[encoded stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
  stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
 NSUInteger paddedLength=(base64.length+3)&~NSUInteger(3);
 base64=[base64 stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
 NSData* token=[[NSData alloc]initWithBase64EncodedString:base64 options:0];
 if(token.length<=tokenBody||issuer.length!=p256Spki.size()+65||
    std::memcmp(issuer.bytes,p256Spki.data(),p256Spki.size()))
  throw std::runtime_error("Mã quà hoặc khóa xác thực không hợp lệ.");
 NSData* raw=[issuer subdataWithRange:NSMakeRange(p256Spki.size(),65)];
 NSDictionary* attributes=@{(__bridge id)kSecAttrKeyType:(__bridge id)kSecAttrKeyTypeECSECPrimeRandom,
  (__bridge id)kSecAttrKeyClass:(__bridge id)kSecAttrKeyClassPublic,
  (__bridge id)kSecAttrKeySizeInBits:@256};
 SecKeyRef key=SecKeyCreateWithData((__bridge CFDataRef)raw,(__bridge CFDictionaryRef)attributes,nullptr);
 if(!key)throw std::runtime_error("Không mở được khóa xác thực mã quà.");
 constexpr char domain[]="Legend Android gift v1";
 NSMutableData* message=[NSMutableData dataWithBytes:domain length:sizeof(domain)];
 [message appendBytes:token.bytes length:tokenBody];
 NSData* signature=[token subdataWithRange:NSMakeRange(tokenBody,token.length-tokenBody)];
 bool valid=SecKeyVerifySignature(key,kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
  (__bridge CFDataRef)message,(__bridge CFDataRef)signature,nullptr);
 CFRelease(key);
 auto* bytes=static_cast<const uint8_t*>(token.bytes);
 uint32_t stars=uint32_t(bytes[0])<<24|uint32_t(bytes[1])<<16|uint32_t(bytes[2])<<8|bytes[3];
 if(!valid||stars<1||stars>Legend::Gacha::maxStars)throw std::runtime_error("Mã quà không hợp lệ.");
 Legend::Bytes nonce(bytes+4,bytes+tokenBody);
 return {[@"android/" stringByAppendingString:hash(nonce)],int(stars)};
}
}

@implementation LGGiftCodes{
 LGSaveVault* _vault;
 NSString* _path;
 NSData* _issuer;
}
- (instancetype)initWithVault:(LGSaveVault*)vault path:(NSString*)path issuer:(NSData*)issuer{
 if((self=[super init])){
  _vault=vault;
  _path=[path copy];
  _issuer=[issuer copy];
 }
 return self;
}
- (NSMutableDictionary*)readLedger{
 NSFileManager* files=NSFileManager.defaultManager;
 if(![files fileExistsAtPath:_path])return [NSMutableDictionary dictionary];
 NSError* error=nil;
 NSDictionary* attrs=[files attributesOfItemAtPath:_path error:&error];
 if(!attrs||attrs.fileSize>8*1024*1024)throw std::runtime_error("Sổ mã quà không hợp lệ.");
 NSData* sealed=[NSData dataWithContentsOfFile:_path options:0 error:&error];
 NSData* opened=sealed?[_vault open:sealed purpose:ledgerPurpose error:&error]:nil;
 id ledger=opened?[NSJSONSerialization JSONObjectWithData:opened options:NSJSONReadingMutableContainers error:&error]:nil;
 if(![ledger isKindOfClass:NSMutableDictionary.class])throw std::runtime_error("Sổ mã quà không hợp lệ.");
 return ledger;
}
- (void)writeLedger:(NSDictionary*)ledger{
 NSError* error=nil;
 NSData* content=[NSJSONSerialization dataWithJSONObject:ledger options:0 error:&error];
 if(!content||content.length>8*1024*1024)throw std::runtime_error("Không cập nhật được sổ mã quà.");
 NSData* sealed=[_vault seal:content purpose:ledgerPurpose error:&error];
 if(!sealed||![sealed writeToFile:_path options:NSDataWritingAtomic error:&error])
  throw std::runtime_error("Không ghi được sổ mã quà.");
}
- (NSInteger)redeem:(NSString*)input game:(Legend::GachaTransaction&)game
   requireNativeLoad:(BOOL)requireNativeLoad error:(NSError**)error{
 try{
  Gift gift=verifiedGift(input,_issuer);
  NSMutableDictionary* ledger=[self readLedger];
  id previous=ledger[gift.identifier];
  if(previous&&![previous isKindOfClass:NSMutableDictionary.class])
   throw std::runtime_error("Sổ mã quà không hợp lệ.");
  NSMutableDictionary* row=previous?:[NSMutableDictionary dictionary];
  ledger[gift.identifier]=row;
  if([row[@"used"] boolValue])throw std::runtime_error("Mã này đã được dùng.");
  NSString* initial=hash(game.card());
  NSString* pending=row[@"pending"];
  if(pending){
   if([pending isEqualToString:initial]){
    row[@"used"]=@YES;
    [row removeObjectsForKeys:@[@"pending",@"original"]];
    [self writeLedger:ledger];
    throw std::runtime_error("Mã này đã được dùng.");
   }
   if(![initial isEqualToString:row[@"original"]])
    throw std::runtime_error("SAVE đã đổi trong lúc đổi mã. Mã được giữ để tránh cộng hai lần.");
  }
  int balance=Legend::Gacha::redeem(game,gift.stars,requireNativeLoad,[&](const Legend::Bytes& card){
   row[@"original"]=initial;
   row[@"pending"]=hash(card);
   [self writeLedger:ledger];
  });
  row[@"used"]=@YES;
  [row removeObjectsForKeys:@[@"pending",@"original"]];
  // An authenticated pending record can recover the committed redemption if the next write fails.
  try{[self writeLedger:ledger];}catch(const std::exception&){}
  return balance;
 }catch(const Legend::RollbackFailed&){
  throw;
 }catch(const Legend::WalletRejected&){
  throw;
 }catch(const std::exception& failure){
  if(error)*error=[NSError errorWithDomain:@"LegendGiftCodes" code:1 userInfo:
   @{NSLocalizedDescriptionKey:[NSString stringWithUTF8String:failure.what()]?:@"Không đổi được mã quà."}];
  return -1;
 }
}
@end
