#include "DeckPlanner.hpp"
#include <algorithm>
#include <regex>
#include <stdexcept>
#include <tuple>
#include <unordered_set>

namespace Legend {
namespace {
constexpr size_t idTable=GameData::maximumCards+1;
constexpr std::array<std::string_view,20> tribes{
 "dragon","spellcaster","zombie","warrior","beast warrior","beast","winged beast",
 "fiend","fairy","insect","dinosaur","reptile","fish","sea serpent","machine",
 "thunder","aqua","pyro","rock","plant"
};
struct Edge { int previous,leaf; };
struct Route { int result;std::vector<int> cards; };
bool contains(const std::string& text,std::initializer_list<std::string_view> words){
 return std::any_of(words.begin(),words.end(),[&](auto word){return text.find(word)!=std::string::npos;});
}
std::string normalized(const std::string& source){
 std::string text;
 bool pending=false;
 for(char letter:source){
  if(letter>='A'&&letter<='Z')letter=letter-'A'+'a';
  if((letter>='a'&&letter<='z')||(letter>='0'&&letter<='9')){
   if(pending)text+=' ';
   pending=false;
   text+=letter;
  }else pending=!text.empty();
 }
 return text;
}
class Planner {
 GameData& data;
 const FusionMap& pairs;
 EquipMap equips;
 int terrain,room=40;
 std::array<int,idTable> cap{},chosen{},attack{},defense{},type{},depth{},used{};
 std::array<std::vector<Edge>,idTable> inverse;
 std::unordered_set<uint64_t> dead;

 int add(int card,int number){
  int amount=std::max(0,std::min({room,number,cap[card]-chosen[card]}));
  chosen[card]+=amount;
  room-=amount;
  return amount;
 }
 int missing(const std::vector<int>& route)const{
  int cost=0;
  for(size_t i=0;i<route.size();i++){
   int copies=std::count(route.begin(),route.begin()+i+1,route[i]);
   if(copies>chosen[route[i]])cost++;
  }
  return cost;
 }
 void insert(const std::vector<int>& route){
  for(size_t i=0;i<route.size();i++){
   int copies=std::count(route.begin(),route.begin()+i+1,route[i]);
   add(route[i],copies-chosen[route[i]]);
  }
 }
 bool solve(int result,std::vector<int>& cards,size_t length){
  if(depth[result]>int(length))return false;
  if(length==1){
   if(used[result]>=cap[result])return false;
   cards[0]=result;
   return true;
  }
  std::vector<int> leaves(cards.begin()+length,cards.end());
  std::sort(leaves.begin(),leaves.end());
  uint64_t key=(result<<3)|length;
  for(int leaf:leaves)key=(key<<10)|leaf;
  if(dead.count(key))return false;
  for(auto edge:inverse[result]){
   if(used[edge.leaf]>=cap[edge.leaf])continue;
   used[edge.leaf]++;
   cards[length-1]=edge.leaf;
   bool solved=solve(edge.previous,cards,length-1);
   used[edge.leaf]--;
   if(solved)return true;
  }
  if(dead.size()<120000)dead.insert(key);
  return false;
 }
 void chains(const std::vector<Route>& options,int reserve){
  while(room>reserve){
   const Route* best=nullptr;
   int bestCost=0;
   for(const auto& route:options){
    int cost=missing(route.cards);
    if(!cost||cost>room-reserve)continue;
    if(!best||attack[route.result]>attack[best->result]||
       (attack[route.result]==attack[best->result]&&cost<bestCost)){
     best=&route;
     bestCost=cost;
    }
   }
   if(!best)break;
   insert(best->cards);
  }
 }
 int supportScore(int card,int target)const{
  int kind=type[card];
  if(kind==23){
   auto row=equips.find(card);
   return row!=equips.end()&&row->second.count(target)?1400:0;
  }
  if(kind!=20&&kind!=21)return 0;
  auto text=normalized(data.descriptions[card]);
  auto words=" "+text+" ";
  bool mentioned=false,matches=false;
  for(size_t i=0;i<tribes.size();i++){
   if(words.find(" "+std::string(tribes[i])+" ")==std::string::npos)continue;
   mentioned=true;
   if(int(i)==type[target])matches=true;
  }
  static const std::regex selfDestructive(
   "(?:destroy|destroys|destroyed) all monsters|(?:destroy|sacrifice|tribute) (?:your|one of your)");
  if((mentioned&&!matches)||std::regex_search(text,selfDestructive))return 0;
  int value=0;
  if(contains(text,{"opponent"})&&contains(text,{"destroy","negate","prevent","cannot attack","stop"}))value+=900;
  if(contains(text,{"gain","recover","restore","heal"})&&contains(text,{"life point"," lp"}))value+=450;
  if(contains(text,{"increase","raise","boost","gain"})&&contains(text,{"attack"," atk","defense"," def"}))
   value+=mentioned?650:350;
  if(contains(text,{"protect","immune","cannot be destroyed"}))value+=600;
  if(contains(text,{"draw"})&&contains(text,{"card"}))value+=400;
  return value&&kind==21?value+80:value;
 }
 auto strength(int card)const{return std::make_tuple(-attack[card],-defense[card],card);}

public:
 Planner(GameData& catalog,const CollectionSnapshot& inventory,int field)
  :data(catalog),pairs(data.fusions(field)),equips(data.equips(field)),terrain(field){
  depth.fill(99);
  int available=0;
  for(int card=1;card<=data.cardCount;card++){
   int owned=inventory.deck[card]+inventory.chest[card];
   cap[card]=std::min(owned,inventory.limits[card]);
   chosen[card]=std::max(0,owned-250);
   if(chosen[card]>cap[card])throw std::runtime_error("Chest không còn chỗ trả bài.");
   room-=chosen[card];
   available+=cap[card];
   type[card]=data.descriptor(card)>>26;
   auto values=data.stats(card,terrain);
   attack[card]=values[0];
   defense[card]=values[1];
   if(cap[card]&&type[card]<20)depth[card]=1;
  }
  if(room<0||available<40)throw std::runtime_error("Chưa đủ 40 lá hợp lệ theo giới hạn của game.");
  for(const auto& [key,result]:pairs){
   int first=key/1024,second=key%1024;
   if(type[first]>=20||type[second]>=20||type[result]>=20)continue;
   if(cap[first])inverse[result].push_back({second,first});
   if(first!=second&&cap[second])inverse[result].push_back({first,second});
  }
  for(int length=2;length<=5;length++){
   for(int result=1;result<=data.cardCount;result++){
    if(depth[result]>length&&std::any_of(inverse[result].begin(),inverse[result].end(),
        [&](Edge edge){return depth[edge.previous]<length;}))depth[result]=length;
   }
  }
  for(auto& edges:inverse){
   std::sort(edges.begin(),edges.end(),[&](Edge a,Edge b){
    return std::make_tuple(depth[a.previous],-attack[a.leaf],a.previous,a.leaf)<
     std::make_tuple(depth[b.previous],-attack[b.leaf],b.previous,b.leaf);
   });
  }
 }

 DeckPlan build(const std::array<int,40>& current){
  std::vector<int> monsters,targets;
  for(int id=1;id<=data.cardCount;id++){
   if(cap[id]&&type[id]<20)monsters.push_back(id);
   if(!inverse[id].empty())targets.push_back(id);
  }
  if(monsters.empty())throw std::runtime_error("Chest chưa có quái thú để tự soạn Deck.");
  auto stronger=[&](int a,int b){return strength(a)<strength(b);};
  std::sort(monsters.begin(),monsters.end(),stronger);
  std::sort(targets.begin(),targets.end(),stronger);
  std::vector<Route> options;
  for(int result:targets){
   for(int length=2;length<=5;length++){
    std::vector<int> cards(length);
    if(!solve(result,cards,length))continue;
    if(missing(cards)<=room)options.push_back({result,std::move(cards)});
    break;
   }
   if(options.size()==48)break;
  }
  DeckPlan plan;
  plan.terrain=terrain;
  plan.target=monsters.front();
  if(options.empty())add(plan.target,cap[plan.target]);
  else{
   plan.target=options.front().result;
   plan.materials=options.front().cards;
   insert(plan.materials);
   for(int card:plan.materials)add(card,cap[card]);
   chains(options,14);
  }
  std::vector<int> support;
  std::array<int,idTable> scores{};
  for(int card=1;card<=data.cardCount;card++){
   if(!cap[card])continue;
   scores[card]=supportScore(card,plan.target);
   if(scores[card])support.push_back(card);
  }
  std::sort(support.begin(),support.end(),[&](int a,int b){
   return std::make_pair(-scores[a],a)<std::make_pair(-scores[b],b);
  });
  std::array<int,4> budgets{5,4,0,5};
  for(int quota:{2,3}){
   for(int card:support){
    auto& budget=budgets[type[card]-20];
    budget-=add(card,std::min(quota,budget));
   }
  }
  chains(options,0);
  std::array<int,idTable> priority{};
  for(const auto& option:options){
   for(int card:option.cards)priority[card]=std::max(priority[card],attack[option.result]);
  }
  std::sort(monsters.begin(),monsters.end(),[&](int a,int b){
   return std::make_pair(-priority[a],strength(a))<std::make_pair(-priority[b],strength(b));
  });
  for(int card:monsters)add(card,cap[card]);
  for(int card:support)add(card,cap[card]);
  for(int card:current)if(card>0)add(card,1);
  for(int card=1;card<=data.cardCount;card++)add(card,cap[card]);

  int result=plan.materials.empty()?plan.target:plan.materials.front();
  for(size_t i=1;i<plan.materials.size();i++){
   auto entry=pairs.find(GameData::pairKey(result,plan.materials[i]));
   result=entry==pairs.end()?0:entry->second;
  }
  if(room||result!=plan.target||missing(plan.materials))
   throw std::runtime_error("Không tìm được bộ Deck hợp lệ.");
  std::vector<int> ordered;
  for(int id=1;id<=data.cardCount;id++)if(chosen[id])ordered.push_back(id);
  std::sort(ordered.begin(),ordered.end(),[&](int a,int b){
   return std::make_pair(type[a],strength(a))<std::make_pair(type[b],strength(b));
  });
  auto next=plan.cards.begin();
  for(int card:ordered)next=std::fill_n(next,chosen[card],card);
  plan.attack=attack[plan.target];
  plan.defense=defense[plan.target];
  return plan;
 }
};
}

DeckPlan planDeck(GameData& data,const CollectionSnapshot& inventory,int terrain){
 if(terrain<0||size_t(terrain)>=deckTerrains.size())throw std::runtime_error("Sân không hợp lệ.");
 if(inventory.count!=data.cardCount)throw std::runtime_error("Kho bài và game hiện tại không khớp.");
 return Planner(data,inventory,terrain).build(inventory.slots);
}
}
