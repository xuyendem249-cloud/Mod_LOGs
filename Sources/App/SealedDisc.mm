#include "SealedDisc.hpp"
#include "GameData.hpp"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#include <algorithm>
#include <array>
#include <cstring>
#include <stdexcept>

namespace Legend {
namespace {
constexpr size_t keyPart=32;
constexpr size_t tagBytes=32,ivBytes=16;
constexpr size_t headerBytes=8+4+8+32;
constexpr size_t payloadOffset=headerBytes+tagBytes;
constexpr std::array<uint8_t,8> magic{'L','G','D','I','S','C','I',1};
constexpr char releaseSha[]="c2274ec8ed4d755c96afc3307628ba1ec472d76f0d4a5c3ddd21a9cd1d3d4c15";

uint64_t readNumber(const uint8_t* value,size_t length){
 uint64_t number=0;
 for(size_t i=0;i<length;i++)number=number<<8|value[i];
 return number;
}
std::string hex(const uint8_t* bytes,size_t length){
 static constexpr char letters[]="0123456789abcdef";
 std::string text;
 for(size_t i=0;i<length;i++){text+=letters[bytes[i]>>4];text+=letters[bytes[i]&15];}
 return text;
}
bool matchTag(const uint8_t* a,const uint8_t* b){
 unsigned diff=0;
 for(size_t i=0;i<tagBytes;i++)diff|=a[i]^b[i];
 return diff==0;
}

class SealedDisc final : public DiscStream {
 struct Page {uint64_t index=UINT64_MAX,access=0;Bytes plain;};
 std::array<Page,6> cache;
 uint64_t clock=0,plainLength=0;
 size_t chunk=0,record=0;
 std::array<uint8_t,keyPart*2> keys{};
 std::array<uint8_t,headerBytes> header{};
 std::ifstream file;
 std::mutex mutex;

 void readFile(uint64_t at,uint8_t* data,size_t size){
  file.clear();file.seekg(static_cast<std::streamoff>(at));
  file.read(reinterpret_cast<char*>(data),size);
  if(!file)throw std::runtime_error("Gói Mod 2 thiếu dữ liệu.");
 }
 const Bytes& load(uint64_t index){
  for(auto& page:cache){if(page.index==index){page.access=++clock;return page.plain;}}
  auto victim=std::min_element(cache.begin(),cache.end(),[](const Page& a,const Page& b){return a.access<b.access;});
  size_t count=std::min<uint64_t>(chunk,plainLength-index*chunk);
  size_t encrypted=(count/16+1)*16,body=ivBytes+encrypted;
  Bytes package(body+tagBytes);
  readFile(payloadOffset+index*record,package.data(),package.size());
  std::array<uint8_t,8> serial{};
  for(size_t i=0;i<serial.size();i++)serial[serial.size()-1-i]=uint8_t(index>>(i*8));
  std::array<uint8_t,tagBytes> tag{};
  CCHmacContext auth{};
  CCHmacInit(&auth,kCCHmacAlgSHA256,keys.data()+keyPart,keyPart);
  CCHmacUpdate(&auth,header.data(),header.size());
  CCHmacUpdate(&auth,serial.data(),serial.size());
  CCHmacUpdate(&auth,package.data(),body);
  CCHmacFinal(&auth,tag.data());
  if(!matchTag(tag.data(),package.data()+body))throw std::runtime_error("Không xác thực được dữ liệu Mod 2.");
  Bytes output(encrypted);
  size_t produced=0;
  CCCryptorStatus status=CCCrypt(kCCDecrypt,kCCAlgorithmAES,kCCOptionPKCS7Padding,
   keys.data(),keyPart,package.data(),package.data()+ivBytes,encrypted,output.data(),output.size(),&produced);
  if(status!=kCCSuccess||produced!=count)throw std::runtime_error("Không đọc được dữ liệu Mod 2.");
  output.resize(produced);
  victim->index=index;victim->access=++clock;victim->plain=std::move(output);
  return victim->plain;
 }
public:
 SealedDisc(const std::string& path,const uint8_t* key,size_t length):file(path,std::ios::binary){
  if(!file||length!=keys.size()||!key)throw std::runtime_error("Thiếu dữ liệu Mod 2.");
  std::copy_n(key,keys.size(),keys.begin());
  file.seekg(0,std::ios::end);
  auto physical=file.tellg();
  readFile(0,header.data(),header.size());
  std::array<uint8_t,tagBytes> given{},actual{};
  readFile(headerBytes,given.data(),given.size());
  CCHmac(kCCHmacAlgSHA256,keys.data()+keyPart,keyPart,header.data(),header.size(),actual.data());
  if(!std::equal(magic.begin(),magic.end(),header.begin())||!matchTag(given.data(),actual.data())||
     hex(header.data()+20,32)!=releaseSha)throw std::runtime_error("Gói Mod 2 không đúng phiên bản.");
  chunk=readNumber(header.data()+8,4);
  plainLength=readNumber(header.data()+12,8);
  if(chunk!=128*1024||plainLength==0||plainLength>1024ULL*1024*1024||plainLength%2352)
   throw std::runtime_error("Kích thước gói Mod 2 không hợp lệ.");
  record=ivBytes+chunk+16+tagBytes;
  uint64_t last=(plainLength-1)/chunk;
  size_t finalPlain=plainLength-last*chunk;
  uint64_t expected=payloadOffset+last*record+ivBytes+(finalPlain/16+1)*16+tagBytes;
  if(physical<0||uint64_t(physical)!=expected)throw std::runtime_error("Gói Mod 2 bị thiếu hoặc ghép thêm dữ liệu.");
 }
 uint64_t size()const override{return plainLength;}
 std::string identity()const override{return releaseSha;}
 void readAt(uint64_t offset,uint8_t* data,size_t length)override{
  if(offset>plainLength||length>plainLength-offset)throw std::out_of_range("Vùng đọc Mod 2 không hợp lệ.");
  std::lock_guard<std::mutex> lock(mutex);
  while(length){
   const auto& page=load(offset/chunk);
   size_t from=offset%chunk,n=std::min(length,page.size()-from);
   std::copy_n(page.data()+from,n,data);
   offset+=n;data+=n;length-=n;
  }
 }
};
}

std::shared_ptr<DiscStream> openSealedDisc(const std::string& path,const uint8_t* key,size_t length){
 return std::make_shared<SealedDisc>(path,key,length);
}
}
