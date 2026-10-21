#pragma once
#include <array>
#include <cstdint>
#include <fstream>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>
namespace Legend {
using Bytes=std::vector<uint8_t>;
inline unsigned u16(const Bytes& b,size_t p){return p<=b.size()&&b.size()-p>=2?b[p]|unsigned(b[p+1])<<8:0;}
inline uint32_t u32(const Bytes& b,size_t p){return p<=b.size()&&b.size()-p>=4?u16(b,p)|uint32_t(u16(b,p+2))<<16:0;}
using FusionMap=std::map<int,int>;
class GameData {
 std::ifstream file;uint64_t fileSize=0;int sector=2048,skip=0;std::mutex mutex;
 std::map<std::string,std::pair<unsigned,unsigned>> files;std::map<int,std::array<int,2>> overrides;
 unsigned wa=0;std::array<Bytes,40> photos;std::array<FusionMap,7> fusionMaps;std::array<bool,7> fusionReady{};
 std::map<int,std::vector<uint32_t>> artCache;
 void walk(const std::string&,unsigned,unsigned,int);
 std::string glyph(unsigned)const;std::string name(int)const;uint32_t textAddress(int)const;
 std::string script(uint32_t,std::vector<uint32_t>)const;
 unsigned bootWord(const Bytes&,int,int)const;void decodeIcons(const Bytes&);
public:
 static constexpr uint32_t bias=0x8000f800;
 Bytes slus;
 std::array<std::string,723> names,descriptions;
 std::array<std::string,40> npcNames;
 std::array<uint32_t,723> descriptors{};
 std::array<std::array<std::array<int,722>,4>,40> pools{};
 std::array<std::vector<uint32_t>,41> icons;
 explicit GameData(const std::string& path);
 Bytes read(unsigned lba,size_t length,uint64_t offset=0);
 uint32_t word(uint32_t at)const{return u32(slus,uint32_t(at-bias));}
 Bytes block(uint32_t at,size_t length)const;
 int attribute(int card,const Bytes* ram=nullptr)const;
 std::array<int,2> stats(int card,int terrain=0,int modifier=0,const Bytes* ram=nullptr)const;
 static int pairKey(int a,int b){return (a<b?a:b)*1024+(a<b?b:a);}
 static FusionMap decodeFusions(const Bytes&);
 const FusionMap& fusions(int terrain);
 std::vector<uint32_t> art(int card);
 std::vector<uint32_t> npcPhoto(int npc)const;
 static uint32_t colour(unsigned value,bool opaque);
};
}
