#include "DeckPlanner.hpp"
#include "DeckTransfer.hpp"
#include "Gacha.hpp"
#include <algorithm>
#include <stdexcept>

using namespace Legend;

enum ProbeData { Ram, Card, State };
struct ProbeCallbacks {
 size_t (*read)(int,uint8_t*,size_t);
 void (*write)(size_t,const uint8_t*,size_t);
 void (*run)(unsigned,uint16_t);
 void (*restore)(const uint8_t*,size_t,const uint8_t*,size_t);
 int (*cancelled)();
 int (*commit)(const uint8_t*,size_t);
};

namespace {
class Probe final : public GachaTransaction {
 const ProbeCallbacks& cb;
 Bytes data(int kind,size_t capacity){
  Bytes bytes(capacity);
  size_t used=cb.read(kind,bytes.data(),bytes.size());
  if(!used||used>bytes.size())throw std::runtime_error("Could not capture native test buffer");
  bytes.resize(used);
  return bytes;
 }
public:
 explicit Probe(const ProbeCallbacks& interface):cb(interface){}
 Bytes ram()override{return data(Ram,0x200000);}
 Bytes card()override{return data(Card,131072);}
 Bytes checkpoint()override{return data(State,16*1024*1024);}
 uint8_t readByte(size_t offset)override{return ram().at(offset);}
 void write(size_t offset,const Bytes& bytes)override{cb.write(offset,bytes.data(),bytes.size());}
 void run(unsigned frames,uint16_t mask)override{cb.run(frames,mask);}
 void restore(const Bytes& state,const Bytes& card)override{cb.restore(state.data(),state.size(),card.data(),card.size());}
 bool interrupted()const override{return cb.cancelled()!=0;}
 void setStars(int stars)override{writeWord(Gacha::starsOffset,stars);}
 void commitCard(const Bytes& bytes)override{
  if(cb.commit(bytes.data(),bytes.size())!=0)throw std::runtime_error("Private card write failure");
 }
};
template<typename Run> int check(Run run,char* problem,size_t capacity){
 try{run();return 0;}catch(const std::exception& e){
  if(capacity){
   std::string message=e.what();
   auto len=std::min(message.size(),capacity-1);
   std::copy_n(message.begin(),len,problem);
   problem[len]=0;
  }
  return 1;
 }
}
}

extern "C" __declspec(dllexport) int replay_deck_transfer(const ProbeCallbacks* interface,
 const char* disc,int terrain,int* chosen,char* problem,size_t capacity){
 return check([&]{
  Probe game(*interface);
  GameData source(disc);
  auto snapshot=CollectionSnapshot::inspect(game.ram(),source.cardCount);
  if(!snapshot)throw std::runtime_error("Native editor was not settled");
  auto plan=planDeck(source,*snapshot,terrain);
  applyDeck(game,*snapshot,plan.cards);
  std::copy(plan.cards.begin(),plan.cards.end(),chosen);
 },problem,capacity);
}

extern "C" __declspec(dllexport) int replay_gacha(const ProbeCallbacks* interface,
 int packs,int amount,int* stars,int* rewards,char* problem,size_t capacity){
 return check([&]{
  Probe game(*interface);
  if(!packs){
   *stars=Gacha::redeem(game,amount,true,[](const Bytes& card){Gacha::savedPayload(card);});
   return;
  }
  auto before=Gacha::inspect(game.ram());
  auto result=Gacha::draw(game,packs,before,true);
  *stars=result.stars;
  std::copy(result.cards.begin(),result.cards.end(),rewards);
  if(!Gacha::walletMatches(Gacha::savedPayload(game.card()),game.ram()))
   throw std::runtime_error("Native Chest or wallet differs from saved payload");
 },problem,capacity);
}
