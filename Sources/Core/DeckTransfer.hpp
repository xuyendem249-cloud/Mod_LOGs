#pragma once
#include "CollectionSnapshot.hpp"
#include "GameTransaction.hpp"

namespace Legend {
void applyDeck(GameTransaction& game,const CollectionSnapshot& preview,const std::array<int,40>& cards);
}
