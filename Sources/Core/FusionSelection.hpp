#pragma once
#include "FusionAdvisor.hpp"

namespace Legend {
// Select the proposed route through normal controller input. Stop before confirming it.
class FusionSelection {
 std::vector<int> slots;
 std::array<int,5> cardIds{};
 int owner,cardCount;
 size_t expected;
 int attempts=0;
 uint16_t pulse=0;
 uint64_t releaseAt=0,nextDecision=0;
public:
 bool done=false,success=false;
 FusionSelection(const DuelView& view,const FusionRow& row,int count)
  :slots(row.slots),owner(view.side),cardCount(count),expected(view.prefix.size()){
  for(const auto& card:view.hand){
   if(card.slot>=0&&card.slot<int(cardIds.size()))cardIds[card.slot]=card.id;
  }
 }
 bool compatible(const DuelView& view)const{
  if(!view.active||view.side!=owner||view.prefix.size()>slots.size()||
     !std::equal(view.prefix.begin(),view.prefix.end(),slots.begin()))return false;
  return std::all_of(slots.begin(),slots.end(),[&](int slot){
   if(slot<0||slot>=int(cardIds.size()))return false;
   return std::any_of(view.hand.begin(),view.hand.end(),[&](const HandCard& card){
    return card.slot==slot&&card.id==cardIds[slot];
   });
  });
 }
 bool needsSnapshot(uint64_t frame)const{return !done&&frame>=nextDecision;}
 uint16_t next(const Bytes& snapshot,uint64_t frame){
  if(done)return 0;
  if(frame<releaseAt)return pulse;
  if(frame<nextDecision)return 0;
  auto view=FusionAdvisor::inspect(snapshot,cardCount);
  if(!compatible(view)||view.prefix.size()<expected||++attempts>40){
   done=true;
   return 0;
  }
  expected=view.prefix.size();
  if(expected==slots.size()){
   done=success=true;
   return 0;
  }
  int cursor=snapshot[0xe9f10+owner*0x70+14];
  if(cursor>4){
   done=true;
   return 0;
  }
  int target=slots[expected];
  pulse=1<<(cursor<target?7:cursor>target?6:4);
  releaseAt=frame+3;
  nextDecision=frame+12;
  return pulse;
 }
};
}
