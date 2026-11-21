#include "Digest.hpp"
#include <array>
#include <limits>
#include <stdexcept>

#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#elif defined(_WIN32)
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#endif

namespace Legend {
namespace {
class Hash {
#ifdef __APPLE__
 CC_SHA256_CTX context{};
public:
 Hash(){if(!CC_SHA256_Init(&context))throw std::runtime_error("SHA-256 initialization failed");}
 void update(const uint8_t* bytes,size_t size){
  if(!CC_SHA256_Update(&context,bytes,static_cast<CC_LONG>(size)))
   throw std::runtime_error("SHA-256 update failed");
 }
 void finish(uint8_t* bytes){if(!CC_SHA256_Final(bytes,&context))throw std::runtime_error("SHA-256 output failed");}
#elif defined(_WIN32)
 BCRYPT_ALG_HANDLE provider=nullptr;
 BCRYPT_HASH_HANDLE context=nullptr;
public:
 Hash(){
  if(BCryptOpenAlgorithmProvider(&provider,BCRYPT_SHA256_ALGORITHM,nullptr,0)<0)
   throw std::runtime_error("SHA-256 initialization failed");
  if(BCryptCreateHash(provider,&context,nullptr,0,nullptr,0,0)<0){
   BCryptCloseAlgorithmProvider(provider,0);
   throw std::runtime_error("SHA-256 hash allocation failed");
  }
 }
 ~Hash(){BCryptDestroyHash(context);BCryptCloseAlgorithmProvider(provider,0);}
 void update(const uint8_t* bytes,size_t size){
  if(BCryptHashData(context,const_cast<uint8_t*>(bytes),static_cast<ULONG>(size),0)<0)
   throw std::runtime_error("SHA-256 update failed");
 }
 void finish(uint8_t* bytes){if(BCryptFinishHash(context,bytes,32,0)<0)throw std::runtime_error("SHA-256 output failed");}
#endif
 Hash(const Hash&)=delete;
 Hash& operator=(const Hash&)=delete;
};
}

std::string sha256(const std::vector<uint8_t>& bytes,std::initializer_list<ByteRange> ranges){
 Hash hash;
 for(auto range:ranges){
  if(range.offset>bytes.size()||range.length>bytes.size()-range.offset||
     range.length>std::numeric_limits<uint32_t>::max())
   throw std::out_of_range("Invalid SHA-256 range");
  if(range.length)hash.update(bytes.data()+range.offset,range.length);
 }
 std::array<uint8_t,32> digest{};
 hash.finish(digest.data());
 static constexpr char hex[]="0123456789abcdef";
 std::string result;
 result.reserve(digest.size()*2);
 for(uint8_t byte:digest){
  result+=hex[byte>>4];
  result+=hex[byte&15];
 }
 return result;
}
}
