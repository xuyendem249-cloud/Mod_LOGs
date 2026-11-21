#include "DeckPlanner.hpp"
#include "Digest.hpp"
#include <iostream>
#include <numeric>
#include <stdexcept>

using namespace Legend;

namespace {
void require(bool success,const char* message){
 if(!success)throw std::runtime_error(message);
}

uint32_t word(std::istream& stream){
 uint32_t value=0;
 for(int i=0;i<4;i++){
  int next=stream.get();
  require(next!=EOF,"truncated Android inventory fixture");
  value=(value<<8)|unsigned(next);
 }
 return value;
}
}

int main(int argc,char** argv){
 try{
  require(argc==4,"usage: inventory_test ISO editor_ram Android_inventory_fixture");
  Bytes message{'a','b','c'};
  require(sha256(message,{{0,1},{1,2}})=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
   "SHA-256 provider");
  GameData data(argv[1]);
  std::ifstream snapshot(argv[2],std::ios::binary),fixture(argv[3],std::ios::binary);
  require(bool(snapshot)&&bool(fixture),"fixture");
  Bytes ram(0x200000);
  snapshot.read(reinterpret_cast<char*>(ram.data()),ram.size());
  require(bool(snapshot)&&snapshot.peek()==EOF,"RAM length");
  auto inventory=CollectionSnapshot::inspect(ram,data.cardCount);
  require(inventory.has_value(),"iOS rejected live editor");
  require(word(fixture)==unsigned(data.cardCount),"card count");
  for(auto pointer:{inventory->base,inventory->deckList,inventory->componentSize,size_t(inventory->pane)})
   require(word(fixture)==pointer,"editor layout");
  for(const auto* counts:{&inventory->chest,&inventory->deck,&inventory->limits}){
   for(int id=0;id<=data.cardCount;id++)require(word(fixture)==unsigned((*counts)[id]),"inventory count");
  }
  for(int card:inventory->slots)require(word(fixture)==unsigned(card),"deck slot");
  for(int field=0;field<7;field++){
   auto plan=planDeck(data,*inventory,field);
   require(word(fixture)==unsigned(plan.target),"plan target");
   require(word(fixture)==unsigned(plan.attack),"plan ATK");
   require(word(fixture)==unsigned(plan.defense),"plan DEF");
   require(word(fixture)==plan.materials.size(),"plan route length");
   for(int card:plan.materials)require(word(fixture)==unsigned(card),"plan material");
   for(int card:plan.cards)require(word(fixture)==unsigned(card),"plan card");
  }
  require(fixture.peek()==EOF,"fixture trailing bytes");
  ram[0x9b254]=1;
  require(!CollectionSnapshot::inspect(ram,data.cardCount),"busy editor accepted");
  ram[0x9b254]=0;
  ram[0x31e5c]^=1;
  require(!CollectionSnapshot::inspect(ram,data.cardCount),"unrecognized editor accepted");
  std::cout<<"Android inventory parity: "<<data.cardCount<<" IDs, same 40-card plan on all seven terrains\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
