#include "FusionSelection.hpp"
#include <iostream>
#include <numeric>
#include <stdexcept>

using namespace Legend;

namespace {
void check(bool ok,const std::string& field){
 if(!ok)throw std::runtime_error(field);
}

class Fixture {
 std::ifstream stream;
public:
 explicit Fixture(const char* path):stream(path,std::ios::binary){check(bool(stream),"fixture");}
 unsigned byte(){int value=stream.get();check(value!=EOF,"fixture EOF");return unsigned(value);}
 uint32_t word(){uint32_t value=0;for(int i=0;i<4;i++)value=(value<<8)|byte();return value;}
 std::string string(){
  auto size=word();
  check(size<=4096,"fixture string size");
  std::string value(size,'\0');
  check(bool(stream.read(value.data(),size)),"fixture string");
  return value;
 }
 bool done(){return stream.peek()==EOF;}
};

void writeWord(Bytes& ram,size_t offset,uint32_t value){
 for(int i=0;i<4;i++)ram[offset+i]=uint8_t(value>>(8*i));
}
void verifyFusionSelection(){
 Bytes ram(0x200000);
 ram[0x9b26c]=3;
 ram[0x9b26e]=0x81;
 ram[0x9b360]=255;
 ram[0x9b23a]=4;
 ram[0x9b174]=1;
 for(int slot=0;slot<2;slot++){
  size_t object=0x10000+0x100*slot;
  writeWord(ram,0xea030+12*slot,0x80000000|object);
  ram[object+0x6a]=slot;
  writeWord(ram,0x1a7ad8+28*slot+12,799+slot);
  ram[0x1a7ad8+28*slot+23]=0x80;
 }
 auto view=FusionAdvisor::inspect(ram,800);
 check(view.active&&view.hand.size()==2,"800-card hand inspection");
 check(!FusionAdvisor::inspect(ram,722).active,"legacy card bound");
 FusionRow row;
 row.slots={1,0};
 FusionSelection choose(view,row,800);
 check(choose.needsSnapshot(0)&&choose.next(ram,0)==1<<7,"move right");
 check(!choose.needsSnapshot(2)&&choose.next({},2)==1<<7&&choose.next({},3)==0,"pad pulse");
 ram[0xe9f10+14]=1;
 check(choose.next(ram,12)==1<<4,"raise first");
 ram[0xea030+12+4]=1;
 ram[0xea030+12+9]=1;
 check(choose.next(ram,24)==1<<6,"move left");
 ram[0xe9f10+14]=0;
 check(choose.next(ram,36)==1<<4,"raise second");
 ram[0xea030+4]=1;
 ram[0xea030+9]=2;
 check(choose.next(ram,48)==0&&choose.done&&choose.success,"stop before confirming");

 FusionSelection stale(view,row,800);
 writeWord(ram,0x1a7ad8+28+12,798);
 check(stale.next(ram,0)==0&&stale.done&&!stale.success,"card changed after selection");
}
}

int main(int argc,char** argv){
 try{
  check(argc==3,"usage: catalog_800_test ISO Android_catalog_fixture");
  GameData data(argv[1]);
  Fixture fixture(argv[2]);
  check(data.cardCount==int(fixture.word()),"card count");
  check(data.fusionCount==int(fixture.word()),"fusion card count");
  check(data.hasNpc40==bool(fixture.byte()),"NPC 40");
  for(int id=1;id<=data.cardCount;id++){
   auto label=std::to_string(id);
   check(data.names[id]==fixture.string(),"name "+label);
   check(data.descriptions[id]==fixture.string(),"description "+label);
   check(data.attribute(id)==int(fixture.word()),"attribute "+label);
   check((data.descriptor(id)>>26)==fixture.word(),"type "+label);
   for(int terrain=0;terrain<7;terrain++){
    auto stats=data.stats(id,terrain);
    check(stats[0]==int(fixture.word()),"ATK "+label);
    check(stats[1]==int(fixture.word()),"DEF "+label);
   }
   auto art=data.art(id);
   check(art.size()==102*96,"art size "+label);
   for(auto pixel:art)check(pixel==fixture.word(),"art pixel "+label);
  }
  for(const auto& name:data.typeNames)check(name==fixture.string(),"type name");
  for(const auto& icon:data.attributeIcons){
   check(icon.size()==fixture.word(),"attribute icon size");
   for(auto pixel:icon)check(pixel==fixture.word(),"attribute icon pixel");
  }
  for(const auto& icon:data.icons)for(auto pixel:icon)check(pixel==fixture.word(),"type icon pixel");
  int fixed=0;
  for(int npc=0;npc<40;npc++){
   check(data.npcNames[npc]==fixture.string(),"NPC name");
   for(const auto& pool:data.pools[npc]){
    for(int card=0;card<data.cardCount;card++)check(pool[card]==int(fixture.word()),"NPC pool");
   }
   for(auto pixel:data.npcPhoto(npc))check(pixel==fixture.word(),"NPC portrait");
   const auto& deck=data.pools[npc][0];
   if(npc&&std::accumulate(deck.begin(),deck.end(),0)==40)fixed++;
  }
  for(int terrain=0;terrain<7;terrain++){
   const auto& pairs=data.fusions(terrain);
   check(pairs.size()==fixture.word(),"terrain fusion count");
   for(const auto& [key,id]:pairs){
    check(key==int(fixture.word()),"fusion ingredients");
    check(id==int(fixture.word()),"fusion result");
   }
  }
  check(fixture.done(),"fixture trailing bytes");
  verifyFusionSelection();
  std::cout<<"Android catalog parity: "<<data.cardCount<<" cards, "
           <<(data.hasNpc40?40:39)<<" NPCs, "<<fixed<<" fixed decks, "
           <<data.fusions(0).size()<<" neutral fusions and all seven terrain tables\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
