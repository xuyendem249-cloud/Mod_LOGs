#pragma once
#include "GameData.hpp"
#include "ModCompatibility.hpp"
namespace Legend {
struct HandCard{int slot=0,id=0,record=0,x=0,y=0;};
struct FusionRow{std::vector<int> slots,better;int result=0,atk=0,def=0,baseAtk=0,baseDef=0,bonus=0,lossAtk=0,lossDef=0;};
struct DuelView{bool duel=false,active=false;int npc=-1,side=0,terrain=0;std::vector<HandCard> hand;std::vector<FusionRow> rows;std::vector<int> prefix;std::array<int,5> records{};};
class FusionAdvisor{
 GameData& data;std::vector<RamCode> signatures;
 using Rules=std::map<int,std::array<int,2>>;
 using Routes=std::map<int,FusionRow>;
 void walk(int,const std::vector<int>&,int,const DuelView&,const FusionMap&,const Bytes*,const Rules&,Routes&);
 Routes routes(const DuelView&,const FusionMap&,const Bytes*,const Rules&,const std::vector<int>&);
public:
 FusionAdvisor(GameData& d,std::vector<RamCode> s):data(d),signatures(std::move(s)){}
 static DuelView inspect(const Bytes&);
 bool recognized(const Bytes*)const;
 Rules rules(const Bytes*)const;
 FusionRow score(int,const std::vector<int>&,const DuelView&,const Bytes*,const Rules&)const;
 static bool stronger(const FusionRow&,const FusionRow&);
 void rank(DuelView&,const FusionMap&,const Bytes*);
 DuelView analyze(const Bytes&);
};
}
