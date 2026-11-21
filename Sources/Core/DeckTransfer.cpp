#include "DeckTransfer.hpp"
#include <algorithm>
#include <stdexcept>

namespace Legend {
namespace {
void refresh(GameTransaction& game,const CollectionSnapshot& view,const Bytes& before){
 size_t scratch=view.base+view.componentSize+0x40;
 size_t marker=scratch+0x100;
 size_t hook=0x90df8+(2+view.pane)*4;
 uint32_t address=0x80000000u+uint32_t(marker);
 uint32_t deckOffset=uint32_t(view.deckList-view.base);
 // Native interpreter callback shared with the Android editor transaction.
 const std::array<uint32_t,21> words{
  0x27bdffe8,0xafbf0014,0xafb00010,0x00808021,
  0x26040000|deckOffset,0x0c00cb12,0,
  0x26040004,0x0c00cb12,0,
  0x02002021,0x0c00c797,0,
  0x3c080000|(address>>16),0x35080000|(address&65535),
  0x24090001,0x8fb00010,0x8fbf0014,0x27bd0018,0x03e00008,0xad090000
 };
 Bytes code;
 for(uint32_t word:words){
  for(unsigned byte=0;byte<4;byte++)code.push_back(uint8_t(word>>(byte*8)));
 }
 game.write(scratch,code);
 game.writeWord(marker,0);
 game.writeWord(hook,0x80000000u+uint32_t(scratch));
 bool refreshed=false;
 for(int i=0;i<4;i++){
  game.run(1,0);
  if(game.interrupted())throw std::runtime_error("Thao tác Deck đã hủy do có phím game.");
  if(game.readByte(marker)==1){refreshed=true;break;}
 }
 if(!refreshed)throw std::runtime_error("Game chưa làm mới Chest/Deck.");
 game.write(hook,Bytes(before.begin()+hook,before.begin()+hook+4));
 game.write(scratch,Bytes(before.begin()+scratch,before.begin()+scratch+0x104));
}
}

void applyDeck(GameTransaction& game,const CollectionSnapshot& preview,const std::array<int,40>& cards){
 auto before=game.ram();
 auto view=CollectionSnapshot::inspect(before,preview.count);
 if(!view||!preview.sameInventory(*view)||game.interrupted())
  throw std::runtime_error("Chest/Deck đã thay đổi. Hãy tạo lại bộ bài.");

 std::array<int,GameData::maximumCards+1> desired{},chest{};
 std::array<size_t,GameData::maximumCards+1> rows{};
 Bytes chestBytes(view->count),deckBytes(view->count+1),deckRows(cards.size()*16);
 for(int card:cards){
  if(card<1||card>view->count||++desired[card]>view->limits[card]||
     desired[card]>view->chest[card]+view->deck[card])
   throw std::runtime_error("Bộ bài vượt số bản sở hữu hoặc giới hạn của game.");
 }
 unsigned chestTotal=0;
 for(int card=1;card<=view->count;card++){
  chest[card]=view->chest[card]+view->deck[card]-desired[card];
  if(chest[card]>250)throw std::runtime_error("Chest hết chỗ trả bài.");
  chestTotal+=chest[card];
  chestBytes[card-1]=uint8_t(chest[card]);
  deckBytes[card]=uint8_t(desired[card]);
 }
 size_t chestStart=view->base+4;
 Bytes chestRows(before.begin()+chestStart,before.begin()+chestStart+view->count*16);
 for(size_t at=0;at<chestRows.size();at+=16){
  auto card=u16(chestRows,at+4);
  rows[card]=at;
  chestRows[at+13]=chest[card]?1:desired[card]?0x80:0;
 }
 for(size_t i=0;i<cards.size();i++){
  std::copy_n(chestRows.begin()+rows[cards[i]],16,deckRows.begin()+i*16);
  deckRows[i*16+13]=1;
 }
 auto card=game.card(),state=game.checkpoint();
 if(state.empty()||card.size()!=131072)throw std::runtime_error("Không tạo được mốc khôi phục Deck.");
 size_t growth=view->count-GameData::legacyCards;
 try{
  game.write(chestStart,chestRows);
  game.write(view->deckList,deckRows);
  game.write(view->base+0x5ac4+growth*32,deckBytes);
  game.write(view->base+0x5d98+growth*33,chestBytes);
  game.writeWord(view->base+0x5a9c+growth*32,chestTotal);
  game.writeWord(view->base+0x5aa0+growth*32,cards.size());
  refresh(game,*view,before);
  auto after=game.ram();
  auto verified=CollectionSnapshot::inspect(after,view->count);
  if(!verified||verified->base!=view->base||verified->chest!=chest||verified->deck!=desired||
     verified->saveBlock!=preview.saveBlock||u32(after,0x1d5608)!=chestTotal||
     u32(after,0x1d560c)!=cards.size())
   throw std::runtime_error("Kiểm tra số lượng Chest/Deck thất bại.");
 }catch(...){
  game.restore(state,card);
  throw;
 }
}
}
