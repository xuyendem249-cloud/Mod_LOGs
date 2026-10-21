#pragma once
#include <array>
#include <atomic>
#include <cstdint>
#include <algorithm>

namespace Legend {
// One emulation producer, one realtime audio consumer. No locks/allocations on audio thread.
class AudioRing {
  static constexpr uint64_t capacity=16384;
  std::array<std::array<int16_t,2>,capacity> samples{};
  std::atomic<uint64_t> readAt{0},writeAt{0};
  std::atomic<bool> discard{false};
public:
  size_t push(const int16_t* input,size_t frames) {
    uint64_t w=writeAt.load(std::memory_order_relaxed),r=readAt.load(std::memory_order_acquire);
    size_t count=std::min<size_t>(frames,capacity-(w-r));
    for(size_t i=0;i<count;i++)samples[(w+i)%capacity]={input[2*i],input[2*i+1]};
    writeAt.store(w+count,std::memory_order_release);return count;
  }
  void clear(){discard.store(true,std::memory_order_release);}
  void render(float* left,float* right,size_t frames) {
    uint64_t r=readAt.load(std::memory_order_relaxed),w=writeAt.load(std::memory_order_acquire);
    if(discard.exchange(false,std::memory_order_acq_rel))r=w;
    size_t count=std::min<size_t>(frames,w-r);
    for(size_t i=0;i<frames;i++) {
      left[i]=i<count?samples[(r+i)%capacity][0]/32768.0f:0;
      right[i]=i<count?samples[(r+i)%capacity][1]/32768.0f:0;
    }
    readAt.store(r+count,std::memory_order_release);
  }
};
}
