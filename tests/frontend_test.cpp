#include "FrameAndInput.hpp"
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
  Input input;for(int i=0;i<1000;i++)input.advance();input.button(0,true);input.button(0,false);check(input.mask()==1,"minimum touch pulse");for(int i=0;i<3;i++)input.advance();check(input.mask()==0,"pulse expires");input.button(4,true);input.button(8,true);check(input.mask()==((1<<4)|(1<<8)),"multitouch");input.clear();check(input.mask()==0,"rotation/background/load clear input");input.button(8,true);input.button(8,false);check(input.mask()==(1<<8),"new key after load");input.button(40,true);input.clear();check(input.mask()==0,"invalid input ignored");
  std::cout<<"PASS: RGBA 32/16-bit primaries, pitch/alpha, invalid frames, multitouch, pulse and input reset\n";
}
