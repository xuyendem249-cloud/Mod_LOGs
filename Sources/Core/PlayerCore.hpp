#pragma once
#include "FrameAndInput.hpp"
#include "AudioRing.hpp"
#include "libretro.h"
#include <string>
#include <map>

namespace Legend {
// All methods except input/AudioRing are confined to one emulation queue.
class PlayerCore {
  static PlayerCore* active;
  bool initialized=false,loaded=false,changed=false;
  PixelFormat format=PixelFormat::RGB1555;
  std::string systemPath,savePath,contentPath,gamePath,lastMessage;
  std::map<std::string,std::string> options;
  static bool environment(unsigned,void*);
  static void video(const void*,unsigned,unsigned,size_t);
  static void sample(int16_t,int16_t);
  static size_t batch(const int16_t*,size_t);
  static void poll();
  static int16_t inputState(unsigned,unsigned,unsigned,unsigned);
public:
  Input input;
  AudioRing audio;
  Frame frame;
  double fps=59.94,sampleRate=44100;
  PlayerCore();
  ~PlayerCore();
  bool open(const std::string& path,const std::string& root,std::string& error);
  bool run();
  void close();
  std::vector<uint8_t> saveState();
  bool loadState(const std::vector<uint8_t>& state);
  std::vector<uint8_t> memoryCard();
  bool setMemoryCard(const std::vector<uint8_t>& bytes);
  bool isLoaded()const{return loaded;}
};
}
