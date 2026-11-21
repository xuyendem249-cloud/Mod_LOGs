#include "Gacha.hpp"
#include "CollectionSnapshot.hpp"
#include "Digest.hpp"
#include <algorithm>
#include <cstring>
#include <random>
#include <stdexcept>

namespace Legend::Gacha {
namespace {
constexpr int cards=GameData::maximumCards;
constexpr size_t menuSelection=0x184594,menuFlags=0x184597,savePhase=0x9b3eb;
constexpr size_t saveSize=0x600;
constexpr char menuPrompt[]="LOAD trong game rồi về menu chính để mở BOX.";
constexpr char saveName[]="BASLUS-21211-YUGIOH";
constexpr std::array<int,5> menuItems{5,6,7,8,10};
constexpr std::array<std::array<int,4>,5> neighbors{{
 {5,6,5,10},{5,6,6,8},{7,8,10,7},{7,8,6,8},{10,8,5,7}
}};

int index(int item){return std::distance(menuItems.begin(),std::find(menuItems.begin(),menuItems.end(),item));}

bool sameBytes(const Bytes& a,size_t first,const Bytes& b,size_t second,size_t count){
 return first<=a.size()&&second<=b.size()&&count<=a.size()-first&&count<=b.size()-second&&
  std::equal(a.begin()+first,a.begin()+first+count,b.begin()+second);
}
void navigate(GachaTransaction& game,int target){
 int start=index(game.readByte(menuSelection)),destination=index(target);
 if(start>=int(menuItems.size())||destination>=int(menuItems.size()))throw std::runtime_error(menuPrompt);
 std::array<int,5> previous{},buttons{},queue{};
 previous.fill(-1);
 previous[start]=start;
 queue[0]=start;
 for(int next=0,end=1;next<end&&previous[destination]<0;next++){
  int row=queue[next];
  for(int direction=0;direction<4;direction++){
   int node=index(neighbors[row][direction]);
   if(previous[node]>=0)continue;
   previous[node]=row;
   buttons[node]=4+direction;
   queue[end++]=node;
  }
 }
 if(previous[destination]<0)throw std::runtime_error("Không tìm được đường tới nút SAVE.");
 std::vector<int> path;
 for(int i=destination;i!=start;i=previous[i])path.push_back(buttons[i]);
 for(auto step=path.rbegin();step!=path.rend();step++){
  game.run(4,1<<*step);
  game.run(16,0);
 }
 if(game.readByte(menuSelection)!=target)throw std::runtime_error("Menu đang chuyển, đã hủy lượt mở.");
}
void waitFor(GachaTransaction& game,size_t address,uint8_t expected,int limit){
 for(int i=0;i<limit&&!game.interrupted();i++){
  if(game.readByte(address)==expected)return;
  game.run(1,0);
 }
 throw std::runtime_error("SAVE chưa hoàn tất. Lượt mở đã hủy.");
}
void save(GachaTransaction& game,const Bytes& wanted,const Bytes& oldCard,const Journal& journal){
 int original=wanted[menuSelection];
 navigate(game,10);
 game.run(4,1);
 waitFor(game,savePhase,0x80,180);
 game.run(2,0);
 game.run(4,1);
 waitFor(game,savePhase,0xc7,420);
 game.run(2,0);
 game.run(4,1);
 waitFor(game,savePhase,0x0a,900);
 game.run(4,0);
 auto current=game.card();
 auto stored=savedPayload(current);
 const std::array<ByteRange,4> ranges{{{0,0x340},{0x380,0x6c},{0x400,4},{0x40c,0x1f4}}};
 for(auto range:ranges){
  if(!sameBytes(stored,range.offset,wanted,saveOffset+range.offset,range.length))
   throw std::runtime_error("SAVE chưa ghi đủ tiến trình. Lượt mở đã hủy.");
 }
 if(current==oldCard)throw std::runtime_error("Thẻ nhớ chưa nhận thay đổi.");
 game.run(4,1);
 waitFor(game,0x18459a,0,180);
 navigate(game,original);
 game.run(2,0);
 inspect(game.ram());
 if(game.interrupted())throw std::runtime_error("Lượt mở đã hủy.");
 if(journal)journal(current);
 game.commitCard(current);
}
void checkReady(GachaTransaction& game,const Bytes& ram,const Bytes& oldCard,bool requireNativeLoad){
 auto payload=savedPayload(oldCard);
 if(requireNativeLoad&&!walletMatches(payload,ram))
  throw std::runtime_error("Hãy LOAD trong game trước khi dùng Gacha.");
 if(game.interrupted())throw std::runtime_error("Hãy nhả các nút điều khiển.");
}
}

size_t chestOffset(int card){
 // FM800 stores the appended IDs across three short gaps in the save.
 return card<=723?saveOffset+0x4f+card:
  0x1d0580+card-724+(card>=749)+(card>=759)+(card>=771);
}
int price(int quantity){
 switch(quantity){case 1:return 50;case 5:return 240;case 10:return 450;}
 throw std::invalid_argument("Số túi không hợp lệ.");
}
int inspect(const Bytes& ram){
 if(ram.size()!=0x200000||CollectionSnapshot::editorCount(ram)!=cards||u32(ram,0x2a0b8)!=0x2a420321)
  throw std::runtime_error("Gacha cần MOD2 800 lá với bộ lưu đã được kiểm chứng.");
 int mode=ram[0x9b26c]&31;
 if((mode!=0&&mode!=8)||ram[0x9b254]||u16(ram,0x9b220)||ram[menuFlags]!=0x80||
    index(ram[menuSelection])>=int(menuItems.size())||
    sha256(ram,{{0x180390,0x80}})!="c97fd67b4619785e550d5f33c6df03ba1705aa8b38f73e8c9f566ab6df94334b")
  throw std::runtime_error(menuPrompt);
 for(size_t at=menuFlags+1;at<0x18459e;at++)if(ram[at])throw std::runtime_error(menuPrompt);
 for(size_t at=0x184568;at<menuSelection;at+=4){
  auto ptr=u32(ram,at);
  if(ptr<0x80010000||ptr>0x801fff90||(ptr&3))throw std::runtime_error(menuPrompt);
 }
 for(int slot=0;slot<40;slot++){
  auto card=u16(ram,saveOffset+slot*2);
  if(card<1||card>cards)throw std::runtime_error(menuPrompt);
 }
 auto stars=u32(ram,starsOffset);
 if(stars>maxStars)throw std::runtime_error("Số sao chưa hợp lệ. Hãy LOAD trong game.");
 for(int id=1;id<=cards;id++){
  if(ram[chestOffset(id)]>250)throw std::runtime_error("Số bài trong Chest chưa hợp lệ.");
 }
 return int(stars);
}
Bytes savedPayload(const Bytes& card){
 if(card.size()!=131072||card[0]!='M'||card[1]!='C')
  throw std::runtime_error("Cần thẻ nhớ đã SAVE trong game.");
 size_t payload=0;
 for(size_t block=1;block<16;block++){
  size_t entry=block*128;
  uint8_t checksum=0;
  for(size_t i=0;i<127;i++)checksum^=card[entry+i];
  if(checksum!=card[entry+127])throw std::runtime_error("Thẻ nhớ có mục thư mục bị lỗi.");
  if(card[entry]!=0x51||std::memcmp(card.data()+entry+10,saveName,sizeof(saveName)-1))continue;
  if(payload||u32(card,entry+4)!=8192||u16(card,entry+8)!=0xffff)
   throw std::runtime_error("Thẻ nhớ có nhiều bộ lưu hoặc bộ lưu khác bố cục.");
  payload=8192*block+0x200;
 }
 if(!payload||!sameBytes(card,payload,card,payload+0x680,saveSize))
  throw std::runtime_error("Hãy SAVE rồi LOAD tiến trình trong game trước khi mở Gacha.");
 return {card.begin()+payload,card.begin()+payload+saveSize};
}
bool walletMatches(const Bytes& payload,const Bytes& ram){
 if(payload.size()!=saveSize||ram.size()!=0x200000||
    u32(payload,starsOffset-saveOffset)!=u32(ram,starsOffset))return false;
 for(int id=1;id<=cards;id++)if(payload[chestOffset(id)-saveOffset]!=ram[chestOffset(id)])return false;
 return true;
}
Result draw(GachaTransaction& game,int quantity,int quotedStars,bool requireNativeLoad){
 auto before=game.ram(),oldCard=game.card();
 int stars=inspect(before),fee=price(quantity);
 if(stars!=quotedStars)throw std::runtime_error("Số sao đã đổi. Hãy mở lại Gacha.");
 if(stars<fee)throw std::runtime_error("Cần "+std::to_string(fee)+" sao để mở x"+std::to_string(quantity)+".");
 checkReady(game,before,oldCard,requireNativeLoad);
 auto historyCode=sha256(before,{{0x32370,0x88}});
 if(sha256(before,{{0x218cc,0x24}})!="17c0d9daf91b20b26c6464d3c38ade6d89d5fa1d6a51762a1b650c3d870aeb4c"||
    (historyCode!="7df8640d00d696b346805e96a2dc5c4055449bd1febb981e27862e20b1d1a3cd"&&
     historyCode!="20f526a7b450b4c21c2dd14556f7d924c3583a3dabb0e0f2c5749901216d1c16"))
  throw std::runtime_error("Chưa xác minh được bộ lọc NEW của ISO này.");
 Bytes history(before.begin()+historyOffset,before.begin()+historyOffset+32);
 for(size_t i=0;i<history.size();i+=2){
  if(u16(history,i)>cards)throw std::runtime_error("Lịch sử NEW chưa hợp lệ.");
 }
 std::random_device random;
 std::uniform_int_distribution<int> roll(1,cards);
 Result rewards{{},stars-fee};
 std::array<int,cards+1> copies{};
 for(int i=0;i<quantity;i++){
  int id=roll(random);
  rewards.cards.push_back(id);
  if(before[chestOffset(id)]+(++copies[id])>250)
   throw std::runtime_error("Chest của ID "+std::to_string(id)+" đã đầy. Lượt mở đã hủy.");
  std::move_backward(history.begin(),history.end()-2,history.end());
  history[0]=uint8_t(id);
  history[1]=uint8_t(id>>8);
 }
 auto checkpoint=game.checkpoint();
 if(checkpoint.empty())throw std::runtime_error("Không tạo được mốc khôi phục.");
 try{
  game.setStars(rewards.stars);
  for(int id=1;id<=cards;id++){
   if(copies[id])game.write(chestOffset(id),{uint8_t(before[chestOffset(id)]+copies[id])});
  }
  game.write(historyOffset,history);
  const auto wanted=game.ram();
  if(wanted.size()!=before.size()||u32(wanted,starsOffset)!=unsigned(rewards.stars)||
     !sameBytes(wanted,historyOffset,history,0,history.size()))
   throw std::runtime_error("Core chưa ghi đủ sao và lịch sử mới.");
  for(int id=1;id<=cards;id++){
   if(wanted[chestOffset(id)]!=before[chestOffset(id)]+copies[id])
    throw std::runtime_error("Core chưa ghi đủ số bài.");
  }
  save(game,wanted,oldCard,{});
  return rewards;
 }catch(...){
  game.restore(checkpoint,oldCard);
  throw;
 }
}
int redeem(GachaTransaction& game,int amount,bool requireNativeLoad,const Journal& journal){
 auto before=game.ram(),oldCard=game.card();
 int stars=inspect(before);
 if(amount<1||amount>maxStars-stars)throw std::runtime_error("Mã sao không hợp lệ hoặc vượt giới hạn 999.999.");
 checkReady(game,before,oldCard,requireNativeLoad);
 auto checkpoint=game.checkpoint();
 if(checkpoint.empty())throw std::runtime_error("Không tạo được mốc khôi phục.");
 try{
  int next=stars+amount;
  game.setStars(next);
  auto wanted=game.ram();
  if(inspect(wanted)!=next)throw std::runtime_error("Game chưa nhận sao.");
  save(game,wanted,oldCard,journal);
  return next;
 }catch(...){
  game.restore(checkpoint,oldCard);
  throw;
 }
}
}
