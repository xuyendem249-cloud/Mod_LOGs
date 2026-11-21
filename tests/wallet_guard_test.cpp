#include "WalletGuard.hpp"
#include <algorithm>
#include <iostream>
#include <string_view>

using namespace Legend;

namespace {
void check(bool success,const char* message){if(!success)throw std::runtime_error(message);}
void word(Bytes& bytes,size_t at,uint32_t value){
 for(unsigned i=0;i<4;i++)bytes[at+i]=uint8_t(value>>(i*8));
}
template<typename F> bool rejects(F call){
 try{call();}catch(const WalletRejected&){return true;}
 return false;
}
Bytes cardFor(const Bytes& ram){
 Bytes card(131072);
 card[0]='M';card[1]='C';
 constexpr size_t entry=128;
 card[entry]=0x51;
 word(card,entry+4,8192);
 card[entry+8]=card[entry+9]=0xff;
 constexpr std::string_view name="BASLUS-21211-YUGIOH";
 std::copy(name.begin(),name.end(),card.begin()+entry+10);
 for(size_t i=0;i<127;i++)card[entry+127]^=card[entry+i];
 constexpr size_t payload=8192+0x200;
 std::copy_n(ram.begin()+Gacha::saveOffset,0x600,card.begin()+payload);
 std::copy_n(ram.begin()+Gacha::saveOffset,0x600,card.begin()+payload+0x680);
 return card;
}
}

int main(){
 try{
  Bytes ram(0x200000);
  word(ram,Gacha::starsOffset,500);
  ram[0x9b26c]=3;
  ram[0x9b23a]=0x0d;ram[0x9b23b]=0xe0;
  word(ram,0x9b1d8,0x801d0200);
  word(ram,0x9b1e8,0x80010000);
  ram[0x10038]=4;ram[0x10039]=1;ram[0x1003a]=5;
  auto before=readWallet(ram.data(),ram.size());
  check(before.stars==500&&before.prize==5&&!before.credited,"native prize signal");
  word(ram,Gacha::starsOffset,505);ram[0x9b16d]=0x20;
  auto after=readWallet(ram.data(),ram.size());
  WalletGuard wallet;
  wallet.establish(500);
  wallet.update(before,after,ram.data(),ram.size(),{});
  wallet.check({505});
  wallet.update({505,10},{480,10},nullptr,0,{});
  wallet.check({480});
  check(rejects([&]{wallet.check({481});})&&wallet.blocked(),"pre-frame modification accepted");
  check(rejects([&]{wallet.establish(480);}),"tamper session was rebased");

  WalletGuard load;
  load.establish(50);
  word(ram,Gacha::starsOffset,750);
  auto card=cardFor(ram);
  load.update({50,0,8},{750,8,0},ram.data(),ram.size(),card);
  load.check({750});
  WalletGuard mismatch;
  mismatch.establish(50);
  ram[Gacha::saveOffset+7]^=1;
  check(rejects([&]{mismatch.update({50,0,8},{750,8,0},ram.data(),ram.size(),card);}),
   "mismatched save was trusted");
  WalletGuard illegal;
  illegal.establish(500);
  check(rejects([&]{illegal.update({500,3},{501,3,0,0,true},nullptr,0,{});}),"unexplained credit accepted");
  word(ram,Gacha::starsOffset,1000000);
  check(readWallet(ram.data(),ram.size()).stars==-1,"out-of-range balance accepted");
  std::cout<<"PASS wallet policy: native reward, debit, matching LOAD, tamper rejection and sticky stop\n";
 }catch(const std::exception& failure){std::cerr<<failure.what()<<'\n';return 1;}
}
