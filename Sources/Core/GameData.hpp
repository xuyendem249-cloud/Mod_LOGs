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
using EquipMap=std::map<int,std::vector<int>>;
using Ritual=std::array<int,5>;
class GameData {
 static constexpr int LegacyCards=722;
 static constexpr int MaxCards=1023;
 std::ifstream file;uint64_t fileSize=0;int sector=2048,skip=0;std::mutex mutex;
 std::map<std::string,std::pair<unsigned,unsigned>> files;std::map<int,std::array<int,2>> overrides;
 unsigned wa=0;std::array<Bytes,40> photos;std::array<FusionMap,7> fusionMaps;std::array<bool,7> fusionReady{};
 std::array<EquipMap,7> equipMaps;
 std::array<std::vector<Ritual>,7> ritualTables;
 std::array<bool,7> equipReady{}, ritualReady{};
 int cardCount=LegacyCards,fusionCount=LegacyCards;
 uint32_t descriptorAddress=0x801d4244,extraNameAddress=0,extraDescriptionAddress=0;
 uint64_t extraArtOffset=0;
 bool taggedDescriptions=false;
 std::map<int,std::vector<uint32_t>> artCache;
 void walk(const std::string&,unsigned,unsigned,int);
 void readCardLayout(unsigned archiveSize);
 std::string glyph(unsigned)const;std::string name(int,bool cardContext=false)const;
 uint32_t descriptionAddress(int)const;
 std::string script(uint32_t,std::vector<uint32_t>)const;
 unsigned bootWord(const Bytes&,int,int)const;void decodeIcons(const Bytes&);
public:
 static constexpr uint32_t bias=0x8000f800;
 Bytes slus;
 std::vector<std::string> names,descriptions;
 std::array<std::string,40> npcNames;
 std::vector<uint32_t> descriptors;
 std::array<std::array<std::array<int,722>,4>,40> pools{};
 std::array<std::vector<uint32_t>,41> icons;
 explicit GameData(const std::string& path);
 Bytes read(unsigned lba,size_t length,uint64_t offset=0);
 uint32_t word(uint32_t at)const{return u32(slus,uint32_t(at-bias));}
 Bytes block(uint32_t at,size_t length)const;
 int cards()const{return cardCount;}
 int fusionCards()const{return fusionCount;}
 uint32_t descriptor(int card,const Bytes* ram=nullptr)const;
 int attribute(int card,const Bytes* ram=nullptr)const;
 std::array<int,2> stats(int card,int terrain=0,int modifier=0,const Bytes* ram=nullptr)const;
 static int pairKey(int a,int b){return (a<b?a:b)*1024+(a<b?b:a);}
 static FusionMap decodeFusions(const Bytes&,int count=LegacyCards);
 const FusionMap& fusions(int terrain);
 const EquipMap& equips(int terrain);
 const std::vector<Ritual>& rituals(int terrain);
 std::vector<uint32_t> art(int card);
 std::vector<uint32_t> npcPhoto(int npc)const;
 static uint32_t colour(unsigned value,bool opaque);
};
}
