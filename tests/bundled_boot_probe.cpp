#include "DiscStream.hpp"
#include "GameData.hpp"
#include "PlayerCore.hpp"
#include <algorithm>
#include <cassert>
#include <fstream>
#include <iostream>
#include <stdexcept>

class ReadOnlyDisc final : public Legend::DiscStream {
 std::ifstream stream;
 uint64_t length;
public:
 explicit ReadOnlyDisc(const char* filename):stream(filename,std::ios::binary){
  if(!stream)throw std::runtime_error("missing private probe image");
  stream.seekg(0,std::ios::end);
  length=uint64_t(stream.tellg());
 }
 uint64_t size()const override{return length;}
 std::string identity()const override{
  return "c2274ec8ed4d755c96afc3307628ba1ec472d76f0d4a5c3ddd21a9cd1d3d4c15";
 }
 void readAt(uint64_t position,uint8_t* into,size_t count)override{
  stream.clear();stream.seekg(position);
  if(!stream.read(reinterpret_cast<char*>(into),count))
   throw std::runtime_error("short read in private probe image");
 }
};

int main(int argc,char** argv){
 if(argc!=3)return 2;
 auto source=std::make_shared<ReadOnlyDisc>(argv[1]);
 Legend::GameData catalog(source);
 assert(catalog.cardCount==800);
 Legend::PlayerCore core;
 std::string error;
 if(!core.open("sealed-content-no-raw-image-on-vfs",argv[2],error,source)){
  std::cerr<<error<<"\n";
  return 1;
 }
 assert(core.hasProtectedWallet());
 unsigned updates=0;
 for(int frame=0;frame<520;frame++)updates+=core.run();
 assert(updates>0);
 auto state=core.saveState();
 assert(!state.empty()&&core.loadState(state));
 assert(core.ramSnapshot().size()==0x200000&&core.memoryCard().size()==131072);
 std::cout<<"Native VFS boot and guarded state round-trip passed with "<<updates<<" video updates.\n";
}
