#import "LegendSaveVault.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>
#include <array>
#include <cstring>
#include <zlib.h>

namespace {
constexpr size_t ivSize=kCCBlockSizeAES128;
constexpr size_t keySize=kCCKeySizeAES256;
constexpr size_t tagSize=32;
constexpr size_t maximumPlaintext=64*1024*1024+4096;
constexpr std::array<uint8_t,4> version{'L','G','I',1};
constexpr size_t headerSize=version.size()+ivSize;
constexpr size_t minimumLength=headerSize+kCCBlockSizeAES128+tagSize;

NSError* Problem(NSString* description){
 return [NSError errorWithDomain:@"LegendSaveVault" code:1
  userInfo:@{NSLocalizedDescriptionKey:description}];
}
void setError(NSError** error,NSString* description){
 if(error)*error=Problem(description);
}
void authenticate(const uint8_t* key,NSData* purpose,const void* encoded,size_t count,uint8_t* tag){
 // The length prefix binds the associated data and prevents ambiguous encodings.
 uint32_t length=CFSwapInt32HostToBig(static_cast<uint32_t>(purpose.length));
 CCHmacContext digest{};
 CCHmacInit(&digest,kCCHmacAlgSHA256,key,keySize);
 CCHmacUpdate(&digest,&length,sizeof(length));
 CCHmacUpdate(&digest,purpose.bytes,purpose.length);
 CCHmacUpdate(&digest,encoded,count);
 CCHmacFinal(&digest,tag);
}
}

@implementation LGSaveVault {
 NSData* _keys;
}

#if TARGET_OS_SIMULATOR
- (instancetype)initForSimulatorSmoke{
 if(!(self=[super init]))return nil;
 NSMutableData* keys=[NSMutableData dataWithLength:keySize*2];
 if(SecRandomCopyBytes(kSecRandomDefault,keys.length,static_cast<uint8_t*>(keys.mutableBytes))!=errSecSuccess)return nil;
 _keys=[keys copy];
 return self;
}
#endif

- (NSData*)keys:(NSError**)error {
 @synchronized(self){
  if(_keys)return _keys;
  NSDictionary* item=@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
   (__bridge id)kSecAttrService:@"vn.anhchugia35.legend.save.v1",
   (__bridge id)kSecAttrAccount:@"mod2",
   (__bridge id)kSecAttrSynchronizable:@NO};
  NSMutableDictionary* query=[item mutableCopy];
  query[(__bridge id)kSecReturnData]=@YES;
  query[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
  CFTypeRef returned=nullptr;
  OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&returned);
  if(status==errSecItemNotFound){
   NSMutableData* fresh=[NSMutableData dataWithLength:keySize*2];
   if(SecRandomCopyBytes(kSecRandomDefault,fresh.length,static_cast<uint8_t*>(fresh.mutableBytes))!=errSecSuccess){
    setError(error,@"Không tạo được khóa SAVE.");
    return nil;
   }
   NSMutableDictionary* entry=[item mutableCopy];
   entry[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
   entry[(__bridge id)kSecValueData]=fresh;
   status=SecItemAdd((__bridge CFDictionaryRef)entry,nullptr);
   if(status==errSecSuccess){_keys=[fresh copy];return _keys;}
   if(status==errSecDuplicateItem)status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&returned);
  }
  id object=CFBridgingRelease(returned);
  if(status!=errSecSuccess||![object isKindOfClass:NSData.class]||[(NSData*)object length]!=keySize*2){
   setError(error,[NSString stringWithFormat:@"Không mở được khóa SAVE trên thiết bị này (%d).",status]);
   return nil;
  }
  _keys=object;
  return _keys;
 }
}

- (NSData*)seal:(NSData*)data purpose:(NSString*)purpose error:(NSError**)error {
 if(data.length>maximumPlaintext||!purpose.length||purpose.length>1024){
  setError(error,@"Dữ liệu SAVE vượt quá giới hạn.");
  return nil;
 }
 NSData* keys=[self keys:error];
 if(!keys)return nil;
 const auto* key=static_cast<const uint8_t*>(keys.bytes);
 NSMutableData* sealed=[NSMutableData dataWithLength:headerSize+data.length+kCCBlockSizeAES128+tagSize];
 auto* bytes=static_cast<uint8_t*>(sealed.mutableBytes);
 std::memcpy(bytes,version.data(),version.size());
 auto* iv=bytes+version.size();
 if(SecRandomCopyBytes(kSecRandomDefault,ivSize,iv)!=errSecSuccess){
  setError(error,@"Không tạo được dữ liệu ngẫu nhiên cho SAVE.");
  return nil;
 }
 size_t encrypted=0;
 CCCryptorStatus status=CCCrypt(kCCEncrypt,kCCAlgorithmAES,kCCOptionPKCS7Padding,key,keySize,iv,
  data.bytes,data.length,bytes+headerSize,data.length+kCCBlockSizeAES128,&encrypted);
 if(status!=kCCSuccess){
  setError(error,@"Không mã hóa được SAVE.");
  return nil;
 }
 NSData* context=[purpose dataUsingEncoding:NSUTF8StringEncoding];
 size_t used=headerSize+encrypted;
 authenticate(key+keySize,context,bytes,used,bytes+used);
 sealed.length=used+tagSize;
 return sealed;
}

- (NSData*)open:(NSData*)data purpose:(NSString*)purpose error:(NSError**)error {
 if(data.length<minimumLength||data.length>maximumPlaintext+minimumLength||
    !purpose.length||purpose.length>1024||std::memcmp(data.bytes,version.data(),version.size())){
  setError(error,@"SAVE chưa đúng định dạng.");
  return nil;
 }
 NSData* keys=[self keys:error];
 if(!keys)return nil;
 auto* key=static_cast<const uint8_t*>(keys.bytes);
 auto* bytes=static_cast<const uint8_t*>(data.bytes);
 size_t used=data.length-tagSize;
 std::array<uint8_t,tagSize> expected{};
 authenticate(key+keySize,[purpose dataUsingEncoding:NSUTF8StringEncoding],bytes,used,expected.data());
 unsigned different=0;
 for(size_t i=0;i<expected.size();i++)different|=expected[i]^bytes[used+i];
 if(different){
  setError(error,@"Không xác thực được SAVE trên thiết bị này.");
  return nil;
 }
 size_t ciphertext=used-headerSize,plain=0;
 NSMutableData* output=[NSMutableData dataWithLength:ciphertext];
 CCCryptorStatus status=CCCrypt(kCCDecrypt,kCCAlgorithmAES,kCCOptionPKCS7Padding,key,keySize,
  bytes+version.size(),bytes+headerSize,ciphertext,output.mutableBytes,output.length,&plain);
 if(status!=kCCSuccess||plain>maximumPlaintext){
  setError(error,@"Không giải mã được SAVE.");
  return nil;
 }
 output.length=plain;
 return output;
}
@end

namespace {
constexpr size_t maxStateSize=64*1024*1024;
constexpr uint8_t deflated=1,stored=0;
constexpr size_t slotHeader=sizeof(uint32_t)+1;
NSData* bytesDigest(NSData* bytes){
 std::array<uint8_t,CC_SHA256_DIGEST_LENGTH> digest{};
 CC_SHA256(bytes.bytes,static_cast<CC_LONG>(bytes.length),digest.data());
 return [NSData dataWithBytes:digest.data() length:digest.size()];
}
NSData* encodeSlot(NSData* state,NSError** error){
 if(state.length==0||state.length>maxStateSize){
  setError(error,@"Kích thước slot không hợp lệ.");
  return nil;
 }
 uLongf compressed=compressBound(state.length);
 NSMutableData* payload=[NSMutableData dataWithLength:slotHeader+compressed];
 auto* bytes=static_cast<uint8_t*>(payload.mutableBytes);
 uint32_t length=CFSwapInt32HostToBig(static_cast<uint32_t>(state.length));
 std::memcpy(bytes,&length,sizeof(length));
 const auto* input=static_cast<const Bytef*>(state.bytes);
 int status=compress2(bytes+slotHeader,&compressed,input,state.length,Z_BEST_SPEED);
 if(status==Z_OK&&compressed<state.length){
  bytes[sizeof(length)]=deflated;
  payload.length=slotHeader+compressed;
 }else{
  bytes[sizeof(length)]=stored;
  std::memcpy(bytes+slotHeader,input,state.length);
  payload.length=slotHeader+state.length;
 }
 return payload;
}
NSData* decodeSlot(NSData* payload,NSError** error){
 if(payload.length<slotHeader){
  setError(error,@"Slot thiếu dữ liệu.");
  return nil;
 }
 uint32_t length=0;
 const auto* bytes=static_cast<const uint8_t*>(payload.bytes);
 std::memcpy(&length,bytes,sizeof(length));
 length=CFSwapInt32BigToHost(length);
 uint8_t codec=bytes[sizeof(length)];
 size_t packed=payload.length-slotHeader;
 if(length>0&&length<=maxStateSize){
  if(codec==stored&&packed==length)return [NSData dataWithBytes:bytes+slotHeader length:length];
  if(codec==deflated){
   NSMutableData* state=[NSMutableData dataWithLength:length];
   z_stream input{};
   input.next_in=const_cast<uint8_t*>(bytes+slotHeader);
   input.avail_in=static_cast<uInt>(packed);
   input.next_out=static_cast<Bytef*>(state.mutableBytes);
   input.avail_out=length;
   if(inflateInit(&input)==Z_OK){
    int status=inflate(&input,Z_FINISH);
    inflateEnd(&input);
    if(status==Z_STREAM_END&&input.total_out==length&&input.avail_in==0)return state;
   }
  }
 }
 setError(error,@"Dữ liệu slot không hợp lệ.");
 return nil;
}
}

@implementation LGQuickSlots {
 LGSaveVault* _vault;
 NSString* _purpose;
 NSData* _digest;
 NSData* _cachedState;
}
- (instancetype)initWithVault:(LGSaveVault*)vault{
 if((self=[super init]))_vault=vault;
 return self;
}
- (void)cache:(NSData*)state sealed:(NSData*)sealed purpose:(NSString*)purpose{
 _purpose=[purpose copy];
 _digest=bytesDigest(sealed);
 _cachedState=state;
}
- (BOOL)writeState:(NSData*)state path:(NSString*)path purpose:(NSString*)purpose error:(NSError**)error{
 NSData* payload=encodeSlot(state,error);
 NSData* sealed=payload?[_vault seal:payload purpose:purpose error:error]:nil;
 if(!sealed||![sealed writeToFile:path options:NSDataWritingAtomic error:error])return NO;
 [self cache:state sealed:sealed purpose:purpose];
 return YES;
}
- (NSData*)readState:(NSString*)path purpose:(NSString*)purpose error:(NSError**)error{
 NSDictionary* attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:error];
 if(!attrs)return nil;
 if(attrs.fileSize>maxStateSize+4096){
  setError(error,@"Kích thước slot không hợp lệ.");
  return nil;
 }
 NSData* data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
 if(!data)return nil;
 if(_cachedState&&[_purpose isEqualToString:purpose]&&[_digest isEqualToData:bytesDigest(data)])return _cachedState;
 NSData* opened=[_vault open:data purpose:purpose error:error];
 NSData* state=opened?decodeSlot(opened,error):nil;
 if(state)[self cache:state sealed:data purpose:purpose];
 return state;
}
@end
