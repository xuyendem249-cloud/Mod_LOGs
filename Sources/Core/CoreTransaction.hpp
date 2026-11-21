#pragma once
#include "GameTransaction.hpp"
#include "PlayerCore.hpp"
#include <stdexcept>

namespace Legend {
struct RollbackFailed : std::runtime_error {
 using std::runtime_error::runtime_error;
};
class CoreTransaction final : public GachaTransaction {
 PlayerCore& core;
 const std::atomic<bool>& cancelled;
 Gacha::Journal cardWriter;
public:
 CoreTransaction(PlayerCore& engine,const std::atomic<bool>& cancellation,Gacha::Journal writer={})
  :core(engine),cancelled(cancellation),cardWriter(std::move(writer)){}
 Bytes ram()override{return core.ramSnapshot();}
 uint8_t readByte(size_t offset)override{return core.readRamByte(offset);}
 Bytes card()override{return core.memoryCard();}
 Bytes checkpoint()override{return core.saveState();}
 void write(size_t offset,const Bytes& bytes)override{core.writeRam(offset,bytes);}
 void run(unsigned count,uint16_t buttons)override{
  if(interrupted())throw std::runtime_error("Thao tác đã hủy.");
  core.runTransactionFrames(count,buttons);
 }
 void restore(const Bytes& state,const Bytes& card)override{
  bool loaded=core.loadState(state);
  bool restored=core.setMemoryCard(card);
  if(!loaded||!restored)throw RollbackFailed("Không khôi phục được phiên game. Hãy mở lại game.");
 }
 bool interrupted()const override{return cancelled.load();}
 void setStars(int stars)override{core.setStarsFromTransaction(stars);}
 void commitCard(const Bytes& card)override{
  if(!cardWriter)throw std::runtime_error("Kho SAVE chưa sẵn sàng.");
  cardWriter(card);
 }
};
}
