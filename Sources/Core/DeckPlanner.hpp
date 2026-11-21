#pragma once
#include "CollectionSnapshot.hpp"
#include <string_view>

namespace Legend {
inline constexpr std::array<std::string_view,7> deckTerrains{
 "Bình thường","Forest","Wasteland","Mountain","Sogen","Umi","Yami"
};
struct DeckPlan {
 std::array<int,40> cards{};
 std::vector<int> materials;
 int target=0,terrain=0,attack=0,defense=0;
};
DeckPlan planDeck(GameData& data,const CollectionSnapshot& inventory,int terrain);
}
