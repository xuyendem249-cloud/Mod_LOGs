// Legend frontend primitives. Pixels are explicit RGBA bytes, never raw ARGB memcpy.
#pragma once
#include <array>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <vector>

namespace Legend {
enum class PixelFormat { RGB1555=0, XRGB8888=1, RGB565=2 };
struct Frame {
  unsigned width=0,height=0;std::vector<uint8_t> rgba;
  bool update(const void* data,unsigned w,unsigned h,size_t pitch,PixelFormat format) {
    if(!data||reinterpret_cast<uintptr_t>(data)==static_cast<uintptr_t>(-1)||!w||!h||w>2048||h>1024)return false;
    const unsigned bytes=format==PixelFormat::XRGB8888?4:2;
    if(pitch<size_t(w)*bytes)return false;
    if(format!=PixelFormat::XRGB8888&&format!=PixelFormat::RGB565&&format!=PixelFormat::RGB1555)return false;
    rgba.resize(size_t(w)*h*4);
    for(unsigned y=0;y<h;y++)for(unsigned x=0;x<w;x++) {
      const auto* p=static_cast<const uint8_t*>(data)+size_t(y)*pitch+x*bytes;
      unsigned r,g,b;
      if(bytes==4){b=p[0];g=p[1];r=p[2];}
      else {unsigned v=p[0]|unsigned(p[1])<<8;
        if(format==PixelFormat::RGB565){r=((v>>11)&31)*255/31;g=((v>>5)&63)*255/63;b=(v&31)*255/31;}
        else {r=((v>>10)&31)*255/31;g=((v>>5)&31)*255/31;b=(v&31)*255/31;}
      }
      auto* out=rgba.data()+(size_t(y)*w+x)*4;out[0]=r;out[1]=g;out[2]=b;out[3]=255;
    }
    width=w;height=h;return true;
  }
};
class Input {
  std::mutex mutex;uint16_t held=0;uint64_t tick=0;std::array<uint64_t,16> until{};
public:
  void button(unsigned id,bool down){if(id>=16)return;std::lock_guard<std::mutex> lock(mutex);if(down){held|=uint16_t(1u<<id);until[id]=tick+3;}else held&=uint16_t(~(1u<<id));}
  uint16_t mask(){std::lock_guard<std::mutex> lock(mutex);uint16_t value=held;for(unsigned i=0;i<16;i++)if(until[i]>tick)value|=uint16_t(1u<<i);return value;}
  void advance(){std::lock_guard<std::mutex> lock(mutex);tick++;}
  void clear(){std::lock_guard<std::mutex> lock(mutex);held=0;until.fill(0);}
};
}
