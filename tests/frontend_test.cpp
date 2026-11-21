#include "FrameAndInput.hpp"
#include "GachaPackPose.hpp"
#include <iostream>
#include <stdexcept>
using namespace Legend;
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
int main(){
  Frame f;const uint8_t pixels[]={0,0,255,0, 0,255,0,0, 255,0,0,0, 99,99,99,99, 0x56,0x34,0x12,0, 255,255,255,0, 0,0,0,0, 88,88,88,88};
  check(f.update(pixels,3,2,16,PixelFormat::XRGB8888),"valid frame");
  check(f.rgba==std::vector<uint8_t>({255,0,0,255,0,255,0,255,0,0,255,255,0x12,0x34,0x56,255,255,255,255,255,0,0,0,255}),"RGB channels, row pitch and alpha");
  auto original=f.rgba;check(!f.update(nullptr,3,2,16,PixelFormat::XRGB8888)&&f.rgba==original,"duplicate frame retained");check(!f.update(pixels,3,2,4,PixelFormat::XRGB8888),"short pitch rejected");check(!f.update(pixels,3000,2,16000,PixelFormat::XRGB8888),"oversized frame rejected");
  const uint8_t p565[]={0,0xf8,0xe0,7,0x1f,0};check(f.update(p565,3,1,6,PixelFormat::RGB565),"565 frame");check(f.rgba==std::vector<uint8_t>({255,0,0,255,0,255,0,255,0,0,255,255}),"565 primaries");
  const uint8_t p1555[]={0,0x7c,0xe0,3,0x1f,0};check(f.update(p1555,3,1,6,PixelFormat::RGB1555),"1555 frame");check(f.rgba==std::vector<uint8_t>({255,0,0,255,0,255,0,255,0,0,255,255}),"1555 primaries");
  f.width=3;f.height=3;f.rgba.resize(36);
  for(size_t i=0;i<f.rgba.size();i+=4){f.rgba[i]=88;f.rgba[i+1]=160;f.rgba[i+2]=100;f.rgba[i+3]=255;}
  f.rgba[16]=123;f.rgba[17]=16;f.rgba[18]=246;
  std::vector<uint8_t> filtered;
  f.sharpen(filtered,1);
  check(filtered[16]==140&&filtered[17]==0&&filtered[18]==255&&filtered[19]==255,"Android light sharpen");
  f.sharpen(filtered,2);
  check(filtered[16]==158&&filtered[17]==0&&filtered[18]==255&&filtered[19]==255,"Android high sharpen");
  check(std::equal(filtered.begin(),filtered.begin()+16,f.rgba.begin())&&
        std::equal(filtered.begin()+20,filtered.end(),f.rgba.begin()+20),"sharpen keeps border pixels");
  for(int halfTurn=0;halfTurn<=6;halfTurn++){
    Gacha::PackPose face(halfTurn*4.);
    check(face.face==halfTurn%3&&face.showTexture()&&face.width>.999&&face.edgeOpacity()==0,"pack face sequence");
    if(halfTurn==6)break;
    const double edgeTime=halfTurn*4.+2;
    Gacha::PackPose edge(edgeTime), before(edgeTime-.15), after(edgeTime+.15);
    check(!edge.showTexture()&&edge.edgeOpacity()>.85,"pack foil only at the edge");
    check(before.showTexture()&&after.showTexture()&&before.edgeOpacity()==0&&after.edgeOpacity()==0,"no foil stripes on pack faces");
    check(before.face==halfTurn%3&&after.face==(halfTurn+1)%3&&before.side==-after.side,"pack switches art at the edge");
  }
  constexpr uint16_t left=1<<6,up=1<<4;
  for(unsigned button=0;button<14;button++){
    uint16_t bit=1<<button;
    check(touchNeedsFeedback(0,bit),"tap produces feedback");
    check(!touchNeedsFeedback(bit,bit),"held key does not repeat feedback");
    check(!touchNeedsFeedback(bit,0),"release is silent");
  }
  check(touchNeedsFeedback(left,up)&&touchNeedsFeedback(left|up,up),"new direction produces feedback");
  check(!touchNeedsFeedback(left|1,left),"face key release does not pulse a held direction");
  Input input;for(int i=0;i<1000;i++)input.advance();input.button(0,true);input.button(0,false);check(input.mask()==1,"minimum touch pulse");for(int i=0;i<3;i++)input.advance();check(input.mask()==0,"pulse expires");input.button(4,true);input.button(8,true);check(input.mask()==((1<<4)|(1<<8)),"multitouch");input.clear();check(input.mask()==0,"rotation/background/load clear input");input.button(8,true);input.button(8,false);check(input.mask()==(1<<8),"new key after load");input.button(40,true);input.clear();check(input.mask()==0,"invalid input ignored");
  std::cout<<"PASS: RGBA 32/16-bit primaries, pitch/alpha, invalid frames, multitouch, pulse and input reset\n";
}
