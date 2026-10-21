#pragma once
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>
namespace Legend {
inline std::vector<uint8_t> fromHex(const std::string& text){
 if(text.size()%2)throw std::runtime_error("Invalid hex");std::vector<uint8_t> out;
 auto nibble=[](char c)->unsigned{if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;throw std::runtime_error("Invalid hex");};
 for(size_t i=0;i<text.size();i+=2)out.push_back(uint8_t((nibble(text[i])<<4)|nibble(text[i+1])));return out;
}
struct RamPatch{size_t at;std::vector<uint8_t> before,after;};
struct RamCode{size_t at;std::vector<uint8_t> bytes;};
struct PatchGroup{std::vector<RamPatch> patches;std::vector<RamCode> caves;};
class ModCompatibility {
 static bool match(const uint8_t* ram,size_t size,size_t at,const std::vector<uint8_t>& bytes){return at<=size&&bytes.size()<=size-at&&!memcmp(ram+at,bytes.data(),bytes.size());}
public:
 std::set<std::string> known;std::vector<RamPatch> simple;std::vector<PatchGroup> groups;std::vector<RamCode> handSignatures;
 bool enabled=false,conflict=false;size_t applied=0;
 void identify(const std::string& sha){enabled=known.count(sha)!=0;conflict=false;applied=0;}
 void apply(uint8_t* ram,size_t size){
  if(!enabled||!ram||size<0x200000)return;
  for(const auto& p:simple)if(p.before.size()==p.after.size()&&match(ram,size,p.at,p.before)){memcpy(ram+p.at,p.after.data(),p.after.size());applied++;}
  for(const auto& g:groups){bool ok=true,needed=false;
   for(const auto& p:g.patches){if(p.before.size()!=p.after.size()){ok=false;break;}bool old=match(ram,size,p.at,p.before),next=match(ram,size,p.at,p.after);if(!old&&!next){ok=false;break;}needed|=old;}
   if(!ok)continue;
   for(const auto& c:g.caves){if(c.at>size||c.bytes.size()>size-c.at){ok=false;break;}bool same=match(ram,size,c.at,c.bytes);bool zero=std::all_of(ram+c.at,ram+c.at+c.bytes.size(),[](uint8_t b){return b==0;});if(!zero&&!same){ok=false;break;}needed|=!same;}
   if(!ok){conflict=true;continue;}
   if(needed){for(const auto& c:g.caves)memcpy(ram+c.at,c.bytes.data(),c.bytes.size());for(const auto& p:g.patches)memcpy(ram+p.at,p.after.data(),p.after.size());applied++;}
  }
 }
};
}
