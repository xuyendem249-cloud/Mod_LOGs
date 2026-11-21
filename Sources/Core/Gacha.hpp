#pragma once
#include "GameTransaction.hpp"
#include <functional>

namespace Legend {
class GachaTransaction : public GameTransaction {
public:
 virtual void setStars(int count)=0;
 virtual void commitCard(const Bytes& card)=0;
};
namespace Gacha {
inline constexpr size_t saveOffset=0x1d0200;
inline constexpr size_t starsOffset=0x1d07e0;
inline constexpr size_t historyOffset=0x1d07bc;
inline constexpr int maxStars=999999;
struct Result { std::vector<int> cards;int stars; };
using Journal=std::function<void(const Bytes&)>;

size_t chestOffset(int card);
int price(int quantity);
int inspect(const Bytes& ram);
Bytes savedPayload(const Bytes& card);
bool walletMatches(const Bytes& payload,const Bytes& ram);
Result draw(GachaTransaction& game,int quantity,int quotedStars,bool requireNativeLoad);
int redeem(GachaTransaction& game,int amount,bool requireNativeLoad,const Journal& journal);
}
}
