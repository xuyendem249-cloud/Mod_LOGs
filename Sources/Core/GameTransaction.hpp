#pragma once
#include "GameData.hpp"

namespace Legend {
class GameTransaction {
public:
 virtual ~GameTransaction()=default;
 virtual Bytes ram()=0;
 virtual uint8_t readByte(size_t offset)=0;
 virtual Bytes card()=0;
 virtual Bytes checkpoint()=0;
 virtual void write(size_t offset,const Bytes& bytes)=0;
 virtual void run(unsigned frames,uint16_t mask)=0;
 virtual void restore(const Bytes& state,const Bytes& card)=0;
 virtual bool interrupted()const=0;
 void writeWord(size_t offset,uint32_t value){
  write(offset,{uint8_t(value),uint8_t(value>>8),uint8_t(value>>16),uint8_t(value>>24)});
 }
};
}
