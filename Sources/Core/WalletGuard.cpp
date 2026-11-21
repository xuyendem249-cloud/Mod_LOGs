#include "WalletGuard.hpp"
#include <algorithm>

namespace Legend {
WalletSignal readWallet(const uint8_t* ram,size_t size){
 if(!ram||size!=0x200000)return {};
 auto half=[&](size_t at){return uint32_t(ram[at])|uint32_t(ram[at+1])<<8;};
 auto word=[&](size_t at){return half(at)|half(at+2)<<16;};
 WalletSignal signal;
 uint32_t balance=word(Gacha::starsOffset);
 if(balance<=Gacha::maxStars)signal.stars=int(balance);
 signal.mode=ram[0x9b26c]&31;
 signal.load=ram[0x9b3fb];
 signal.credited=(half(0x9b16c)&0x2000)!=0;
 if(signal.mode==3&&!signal.credited&&half(0x9b23a)==0xe00d&&
    ram[0x9b165]==0&&word(0x9b1d8)==0x801d0200){
  auto result=word(0x9b1e8);
  if(result>=0x80010000&&result<=0x801fffc0&&!(result&3)){
   const auto* rank=ram+(result-0x80000000)+0x38;
   if(rank[0]<=4&&rank[1]<=1&&rank[2]==rank[0]+1)signal.prize=rank[2];
  }
 }
 return signal;
}
[[noreturn]] void WalletGuard::reject(){rejected=true;throw WalletRejected();}

void WalletGuard::establish(int stars){
 if(rejected||stars<0||stars>Gacha::maxStars)reject();
 expected=stars;
}
void WalletGuard::check(WalletSignal signal){
 if(rejected||expected<0||signal.stars!=expected)reject();
}
void WalletGuard::update(WalletSignal before,WalletSignal after,const uint8_t* ram,size_t size,const Bytes& savedCard){
 check(before);
 if(after.stars==expected)return;
 const bool duelReward=before.prize>0&&after.credited&&
  after.stars==std::min(Gacha::maxStars,expected+before.prize);
 const bool debit=after.stars>=0&&after.stars<expected&&
  (before.mode==10||after.mode==10||(after.stars==0&&(before.mode==9||after.mode==9)));
 bool nativeLoad=false;
 if((before.mode==0||before.mode==8)&&before.load==8&&after.load==0&&
    after.stars>=0&&ram&&size>=Gacha::saveOffset+0x600&&!savedCard.empty()){
  try{
   auto payload=Gacha::savedPayload(savedCard);
   nativeLoad=std::equal(payload.begin(),payload.end(),ram+Gacha::saveOffset);
  }catch(const std::exception&){}
 }
 if(!duelReward&&!nativeLoad&&!debit)reject();
 expected=after.stars;
}
}
