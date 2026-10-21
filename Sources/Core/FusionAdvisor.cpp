#include "FusionAdvisor.hpp"
#include <algorithm>
namespace Legend {
DuelView FusionAdvisor::inspect(const Bytes& ram){
 DuelView v;if(ram.size()!=0x200000)return v;
 v.duel=(ram[0x9b26c]&31)==3&&ram[0x9b26e]==0x81;if(!v.duel)return v;
 v.npc=ram[0x9b361];v.terrain=ram[0x9b364];v.side=ram[0x9b1d5];
 if(v.side>1||ram[0x9b360+v.side]!=255)return v;
 if((u16(ram,0x9b23a)&15)!=4||(ram[0x9b174]&15)!=1||ram[0x9b254]||u16(ram,0x9b220)||ram[0x9b164])return v;
 for(int i=0;i<5;i++)v.records[i]=u16(ram,0x1a7ad8+(v.side*15+i)*28+12);
 std::map<int,int> prefix;
 for(int i=0;i<5;i++){
  int h=0xea030+12*i;uint32_t pointer=u32(ram,h);if(!pointer)continue;
  unsigned obj=pointer&0x1fffff;if(obj<0x10000||obj>=0x1fff80)return {};
  int record=ram[obj+0x6a];if(record>=30)return {};
  int at=0x1a7ad8+record*28,card=u16(ram,at+12);if(card<1||card>722||!(u16(ram,at+22)&0x8000))return {};
  v.hand.push_back({i,card,record,int(int16_t(u16(ram,obj+0x30))),int(int16_t(u16(ram,obj+0x32)))});
  if(u32(ram,h+4)){int order=ram[h+9];if(order<1||order>5||prefix.count(order))return {};prefix[order]=i;}
 }
 for(size_t i=1;i<=prefix.size();i++){if(!prefix.count(int(i)))return {};v.prefix.push_back(prefix[int(i)]);}
 v.active=!v.hand.empty();return v;
}
bool FusionAdvisor::recognized(const Bytes* ram)const{
 for(const auto& s:signatures){
  bool live=ram&&s.at<=ram->size()&&s.bytes.size()<=ram->size()-s.at;
  bool empty=!live||std::all_of(ram->begin()+s.at,ram->begin()+s.at+s.bytes.size(),[](uint8_t b){return !b;});
  Bytes actual=empty?data.block(uint32_t(s.at)|0x80000000,s.bytes.size()):Bytes(ram->begin()+s.at,ram->begin()+s.at+s.bytes.size());
  if(actual!=s.bytes)return false;
 }return !signatures.empty();
}
FusionAdvisor::Rules FusionAdvisor::rules(const Bytes* ram)const{
 Rules out;if(!recognized(ram))return out;const size_t at=0x1d09e4;
 bool live=ram&&ram->size()>=at+34&&!std::all_of(ram->begin()+at,ram->begin()+at+34,[](uint8_t b){return !b;});
 Bytes table=live?Bytes(ram->begin()+at,ram->begin()+at+34):data.block(0x801d09e4,34);
 for(int i=0;i<17;i++){int entry=u16(table,i*2),card=entry&1023,attr=entry>>10;if(card<1||card>722||attr>=6)return {};out[card]={attr,card==356?0:1};}return out;
}
FusionRow FusionAdvisor::score(int card,const std::vector<int>& route,const DuelView& v,const Bytes* ram,const Rules& rules)const{
 FusionRow row;row.result=card;row.slots=route;
 const HandCard* source=nullptr;if(!route.empty())for(const auto& h:v.hand)if(h.slot==route[0])source=&h;
 auto rule=rules.find(card);
 if(source&&rule!=rules.end()){int col=source->record-v.side*15;if(col>=0&&col<5){int count=0;bool valid=true;for(int i=0;i<5;i++){int id=i==col?card:v.records[i];if(id<0||id>722){valid=false;break;}if(data.attribute(id,ram)==rule->second[0])count++;}if(valid)row.bonus=(count-rule->second[1])*500;}}
 auto stats=data.stats(card,v.terrain,row.bonus,ram),base=data.stats(card,0,row.bonus,ram);row.atk=stats[0];row.def=stats[1];row.baseAtk=base[0];row.baseDef=base[1];return row;
}
bool FusionAdvisor::stronger(const FusionRow& a,const FusionRow& b){if(a.atk!=b.atk)return a.atk>b.atk;if(a.def!=b.def)return a.def>b.def;return a.slots<b.slots;}
void FusionAdvisor::walk(int card,const std::vector<int>& route,int mask,const DuelView& v,const FusionMap& pairs,const Bytes* ram,const Rules& rules,Routes& out){
 if(route.size()>=2){auto row=score(card,route,v,ram,rules);int key=(mask<<10)|card;auto it=out.find(key);if(it==out.end()||stronger(row,it->second))out[key]=std::move(row);}
 for(const auto& h:v.hand)if(!(mask&(1<<h.slot))){auto it=pairs.find(GameData::pairKey(card,h.id));if(it!=pairs.end()){auto path=route;path.push_back(h.slot);walk(it->second,path,mask|(1<<h.slot),v,pairs,ram,rules,out);}}
}
FusionAdvisor::Routes FusionAdvisor::routes(const DuelView& v,const FusionMap& pairs,const Bytes* ram,const Rules& rules,const std::vector<int>& prefix){
 Routes out;if(prefix.empty()){for(const auto& h:v.hand)walk(h.id,{h.slot},1<<h.slot,v,pairs,ram,rules,out);}
 else{int card=0,mask=0;for(int slot:prefix){const HandCard* found=nullptr;for(const auto& h:v.hand)if(h.slot==slot)found=&h;if(!found||(mask&(1<<slot)))return {};if(!mask)card=found->id;else{auto it=pairs.find(GameData::pairKey(card,found->id));if(it==pairs.end())return {};card=it->second;}mask|=1<<slot;}walk(card,prefix,mask,v,pairs,ram,rules,out);}return out;
}
void FusionAdvisor::rank(DuelView& v,const FusionMap& pairs,const Bytes* ram){
 auto r=rules(ram);auto current=routes(v,pairs,ram,r,v.prefix);
 if(!v.prefix.empty()){auto best=routes(v,pairs,ram,r,{});for(auto& entry:current){auto it=best.find(entry.first);auto& row=entry.second;if(it!=best.end()&&(it->second.atk>row.atk||it->second.def>row.def)){row.better=it->second.slots;row.lossAtk=it->second.atk-row.atk;row.lossDef=it->second.def-row.def;}}}
 v.rows.clear();for(auto& entry:current)v.rows.push_back(std::move(entry.second));
 std::sort(v.rows.begin(),v.rows.end(),[](const FusionRow& a,const FusionRow& b){if(a.atk!=b.atk)return a.atk>b.atk;if(a.def!=b.def)return a.def>b.def;if(a.slots.size()!=b.slots.size())return a.slots.size()<b.slots.size();if(a.result!=b.result)return a.result<b.result;return a.slots<b.slots;});
}
DuelView FusionAdvisor::analyze(const Bytes& ram){auto v=inspect(ram);if(v.active)rank(v,GameData::decodeFusions(Bytes(ram.begin()+0x17c2d8,ram.begin()+0x18c2d8)),&ram);return v;}
}
