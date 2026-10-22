#include "AutoPlayer.hpp"
#include "PlaybackSpeed.hpp"
#include <iostream>
#include <stdexcept>
#include <limits>
using namespace Legend;
static void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
static void word(Bytes& r,size_t p,uint32_t value){for(int i=0;i<4;i++)r[p+i]=uint8_t(value>>(8*i));}
int main(){
 const char* labels[]={"1×","1.3×","1.5×","2×","2.5×","3×","4×"};
 for(size_t i=0;i<playbackSpeeds.size();i++){check(playbackSpeedText(playbackSpeeds[i])==labels[i],"speed labels");check(validPlaybackSpeed(playbackSpeeds[i])==playbackSpeeds[i],"speed roundtrip");}
 for(double value:{0.,-1.,9.,1.7,std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()})check(validPlaybackSpeed(value)==1,"invalid speed resets");
 for(int a=1;a<=10;a++)for(int b=1;b<=10;b++){check(AutoPlayer::matchup(a,b)==-AutoPlayer::matchup(b,a),"guardian inverse");if((a<=6)!=(b<=6))check(!AutoPlayer::matchup(a,b),"separate wheels");}
 check(AutoPlayer::matchup(6,1)==500&&AutoPlayer::matchup(10,7)==500,"guardian wrap");
 Bytes ram(0x200000);word(ram,0x1a7f8,0x240201f4);word(ram,0x1a810,0x08076d81);word(ram,0x1db624,0x08076dd2);word(ram,0x1db628,0x240305dc);auto before=ram;
 check(EquipRules::bonus(657,0,ram)==1500,"equip branch delay literal");check(ram==before,"equip prediction is readonly");word(ram,0x1db624,0xffffffff);check(EquipRules::bonus(657,0,ram)==0,"unknown equip code rejected");
 std::cout<<"PASS Auto Guardian/equip guards, read-only prediction, seven speed labels and invalid preferences\n";
}
