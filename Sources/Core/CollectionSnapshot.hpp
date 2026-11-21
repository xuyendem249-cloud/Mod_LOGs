#pragma once
#include "GameData.hpp"
#include <optional>

namespace Legend {
struct CollectionSnapshot {
 int count=0;
 size_t base=0,deckList=0,componentSize=0;
 int pane=0;
 std::array<int,GameData::maximumCards+1> chest{},deck{},limits{};
 std::array<int,40> slots{};
 Bytes saveBlock;

 static int editorCount(const Bytes& ram);
 static std::optional<CollectionSnapshot> inspect(const Bytes& ram,int count);
 bool sameInventory(const CollectionSnapshot& other)const;
};
}
