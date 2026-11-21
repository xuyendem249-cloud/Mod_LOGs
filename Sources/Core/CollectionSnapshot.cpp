#include "CollectionSnapshot.hpp"
#include "Digest.hpp"
#include <algorithm>
#include <set>

namespace Legend {
namespace {
constexpr size_t ramSize=0x200000;
constexpr size_t saveBlockOffset=0x1d0200;
constexpr size_t saveBlockSize=0x680;
constexpr int baseCount=GameData::legacyCards;
constexpr std::array<uint32_t,5> editorSteps{
 0x800338e4,0x800338e4,0x800336f0,0x8003353c,0x800339d0
};

bool readCopyLimits(const Bytes& ram,CollectionSnapshot& view){
 std::fill_n(view.limits.begin()+1,view.count,3);
 std::fill(view.limits.begin()+17,view.limits.begin()+22,1);
 switch(view.count){
  case 800:
   return sha256(ram,{{0x128000,0x1c0}})=="470e797a025a99a0031a51c0be27a915bda6b752bc6261966a7a87d9aa26e2c0";
  case 770:
   return sha256(ram,{{0x128000,0x1b0}})=="321dd8eedfd94d0c67deef99a1db9a2eb02e08bb8e79101d45eecf7bdccd0375";
  case 758:
   return sha256(ram,{{0x127d1c,0x5c}})=="c08af2b7372dab1709848a7b60e7707b7b0a018a561990c4fcadde340fd62309";
  case baseCount:
   if(sha256(ram,{{0x60fe0,0x28},{0x61a5c,0x20},{0x6484c,0x1c},
      {0x65ba4,0x28},{0x6619c,0x28},{0x66e30,0x18}})!=
      "f7d9c27d03b7bf089d801e68f95b45b8d2ff11bc94688470f58b6d3af708eb65")return false;
   break;
  default:return false;
 }
 std::set<uint32_t> nodes;
 std::array<bool,baseCount+1> seen{};
 uint32_t node=0x80065524;
 while(node){
  size_t at=node-0x80000000u;
  if(at<0x10000||at>ram.size()-6||(at&3)||nodes.size()>=16||!nodes.insert(node).second)
   return false;
  node=u32(ram,at);
  for(at+=4;;at+=2){
   if(at>ram.size()-2)return false;
   auto entry=u16(ram,at);
   if(!entry)break;
   unsigned card=entry&1023,limit=entry>>10;
   if(card<1||card>baseCount||limit<1||limit>3||seen[card])return false;
   seen[card]=true;
   view.limits[card]=std::min(view.limits[card],int(limit));
  }
 }
 return true;
}
}

int CollectionSnapshot::editorCount(const Bytes& ram){
 if(ram.size()!=ramSize)return 0;
 auto hash=sha256(ram,{{0x31e5c,0x328},{0x32b38,0x100},{0x32c40,0x1050},{0x323f8,0x740}});
 static constexpr std::array<const char*,8> fm800{
  "09a2330032a029828d28f4812f00a2e45d9ec9643db2c6435edf355f707e5492",
  "36fc2229b79fb359930af35688b280da95e1867da7d946de7266e5689da771f8",
  "4b6975a85659fa6ebdae94b2d5a974415b4be20cfcce520731cf54a6a933293a",
  "5135f23cadd4d5b28ddb81cef9d65eef1999f5c6a9a02b699b56a81445de6dd5",
  "51a6e026ce3c1d9391f81c2203f5619438745535705d27ee41d1ed31564e3967",
  "5ea1405826284244ac5f4ed9f7493f3f7e4c865dcb368bbb3cf36c4f24ecb5a6",
  "bfa0f21bd997e2a45b835a1d5112b01cd705d6085f45728576df5eea694826bf",
  "d9c1a66ce2d58ea9aaf850dd86e50765019f4e75f0fdd9fd40413bfbe9ca65de"
 };
 if(std::any_of(fm800.begin(),fm800.end(),[&](const char* digest){return hash==digest;}))return 800;
 if(hash=="20588dc05d8efd17c46abeb87504188dab673601cb89781064cc11cdf690edfa")return 770;
 if(hash=="abfb3194d8250fb5abac529ab66075e8ef45c557c01ba1b8b992fe0d52ace7cb")return 758;
 if(hash=="367bb32af7108ecbc271628a55be7278fd100ea1e6843df98586dbe417226e48")return baseCount;
 return 0;
}

std::optional<CollectionSnapshot> CollectionSnapshot::inspect(const Bytes& ram,int count){
 if(ram.size()!=ramSize||count<baseCount||count>GameData::maximumCards)return {};
 int mode=ram[0x9b26c]&31;
 if((mode!=3&&mode!=7)||(mode==3&&ram[0x9b26e]!=0x80)||
    (mode==7&&!(ram[0x9b26c]&64))||ram[0x9b254]||u16(ram,0x9b220))return {};
 for(size_t i=0;i<editorSteps.size();i++)if(u32(ram,0x90df8+4*i)!=editorSteps[i])return {};
 if(editorCount(ram)!=count)return {};

 CollectionSnapshot view;
 view.count=count;
 size_t growth=count-baseCount;
 size_t unaligned=0x6344+growth*35;
 view.componentSize=(unaligned+3)&~size_t(3);
 view.base=u32(ram,0x9b2fc)-0x80000000u;
 if(view.base>ram.size()-view.componentSize*2||
    u32(ram,view.base)!=0x801d0200||u32(ram,view.base+view.componentSize)!=0)return {};
 view.pane=ram[view.base+view.componentSize-2];
 if(view.pane>1||u16(ram,view.base+view.componentSize-6)!=unsigned(0x8002+view.pane)||
    u16(ram,0x9b146)!=unsigned(view.pane*320))return {};
 view.deckList=view.base+0x2d50+growth*16;
 size_t rowsEnd=(count+1)*16;
 for(int list=0;list<2;list++){
  unsigned rows=list?40:count;
  size_t tail=(list?view.deckList:view.base+4)+rowsEnd;
  auto first=u16(ram,tail+12);
  if(first>rows-8||first!=u16(ram,tail+14)||u16(ram,tail+16)!=rows||
     u16(ram,tail+18)!=rows||ram[tail+23]!=list||ram[tail+24]>7)return {};
 }
 unsigned deckTotal=0,chestTotal=0;
 for(size_t slot=0;slot<view.slots.size();slot++){
  size_t at=view.deckList+slot*16;
  auto card=u16(ram,at+4);
  auto flag=ram[at+13];
  if(flag>1||(flag&&(card<1||card>unsigned(count))))return {};
  if(flag){
   view.deck[card]++;
   deckTotal++;
   view.slots[slot]=card;
  }
 }
 for(int card=1;card<=count;card++){
  view.chest[card]=ram[view.base+0x5d97+growth*33+card];
  if(view.chest[card]>250||view.deck[card]!=ram[view.base+0x5ac4+growth*32+card])return {};
  chestTotal+=view.chest[card];
 }
 if(deckTotal!=u32(ram,view.base+0x5aa0+growth*32)||chestTotal!=u32(ram,view.base+0x5a9c+growth*32))
  return {};
 std::array<bool,GameData::maximumCards+1> seen{};
 for(int i=0;i<count;i++){
  size_t at=view.base+4+i*16;
  auto card=u16(ram,at+4);
  if(card<1||card>unsigned(count)||seen[card])return {};
  seen[card]=true;
  uint8_t expected=view.chest[card]?1:view.deck[card]?0x80:0;
  if(ram[at+13]!=expected)return {};
 }
 if(!readCopyLimits(ram,view))return {};
 if(count==baseCount){
  unsigned quantity=0,weighted=0;
  for(int card=1;card<=count;card++){
   unsigned copies=view.chest[card]+view.deck[card];
   quantity+=copies;
   weighted+=card*copies;
  }
  if(quantity!=u32(ram,0x32c38)||weighted!=u32(ram,0x32c3c))return {};
 }
 view.saveBlock.assign(ram.begin()+saveBlockOffset,ram.begin()+saveBlockOffset+saveBlockSize);
 return view;
}

bool CollectionSnapshot::sameInventory(const CollectionSnapshot& other)const{
 return count==other.count&&base==other.base&&pane==other.pane&&chest==other.chest&&
  slots==other.slots&&limits==other.limits&&saveBlock==other.saveBlock;
}
}
