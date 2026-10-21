#include "GameData.hpp"
#include "FusionAdvisor.hpp"
#include "CompatibilityTables.hpp"
#include <iostream>
#include <stdexcept>
using namespace Legend;
static void check(bool ok,const std::string& message){if(!ok)throw std::runtime_error(message);}
struct Reader{std::ifstream f;explicit Reader(const char* path):f(path,std::ios::binary){check(bool(f),"fixture open");}uint32_t integer(){uint8_t b[4];f.read((char*)b,4);check(bool(f),"fixture EOF");return uint32_t(b[0])<<24|uint32_t(b[1])<<16|uint32_t(b[2])<<8|b[3];}Bytes bytes(size_t n){check(n<=8*1024*1024,"fixture size");Bytes b(n);f.read((char*)b.data(),n);check(bool(f),"fixture bytes");return b;}std::string string(){auto b=bytes(integer());return {b.begin(),b.end()};}};
int main(int argc,char** argv){try{
 check(argc==3,"usage: parity_test ISO private_fixture");GameData data(argv[1]);Reader f(argv[2]);check(f.integer()==0x4c474e44,"magic");size_t pixels=0;
 for(int id=1;id<=722;id++){auto name=f.string(),description=f.string();check(data.names[id]==name,"name "+std::to_string(id));check(data.descriptions[id]==description,"description "+std::to_string(id)+": "+data.descriptions[id]+" != "+description);for(int t=0;t<7;t++){auto s=data.stats(id,t);int a=f.integer(),d=f.integer();check(s[0]==a&&s[1]==d,"stats "+std::to_string(id));}}
 for(int n=0;n<40;n++){check(data.npcNames[n]==f.string(),"npc name");for(int p=0;p<4;p++)for(int c=0;c<722;c++)check(data.pools[n][p][c]==int(f.integer()),"pool");for(auto x:data.npcPhoto(n)){check(x==f.integer(),"npc pixel");pixels++;}}
 for(const auto& icon:data.icons)for(auto x:icon){check(x==f.integer(),"icon");pixels++;}
 int arts=f.integer();for(int i=0;i<arts;i++){int id=f.integer();for(auto x:data.art(id)){check(x==f.integer(),"art");pixels++;}}
 for(int t=0;t<7;t++){const auto& pairs=data.fusions(t);int count=f.integer();check(pairs.size()==size_t(count),"fusion count");for(int i=0;i<count;i++){int a=f.integer(),b=f.integer(),r=f.integer();auto it=pairs.find(GameData::pairKey(a,b));check(it!=pairs.end()&&it->second==r,"fusion pair");}}
 std::vector<RamCode> signatures;int n=f.integer();for(int i=0;i<n;i++){size_t at=f.integer(),length=f.integer();signatures.push_back({at,f.bytes(length)});}FusionAdvisor advisor(data,signatures);int cases=f.integer();
 for(int i=0;i<cases;i++){DuelView v;v.side=f.integer();int first=f.integer(),result=f.integer(),bonus=int32_t(f.integer());for(int c=0;c<5;c++){int id=f.integer();v.records[c]=id;v.hand.push_back({4-c,id,v.side*15+c,0,0});}check(advisor.score(result,{4-first},v,nullptr,advisor.rules(nullptr)).bonus==bonus,"bonus case "+std::to_string(i));}
 auto ram=f.bytes(0x200000);auto view=advisor.analyze(ram);check(view.active,"RAM active");check(view.rows.size()==f.integer(),"RAM route count");for(const auto& row:view.rows){check(row.slots.size()==f.integer(),"route size");for(int s:row.slots)check(s==int(f.integer()),"route slot");for(int x:{row.result,row.atk,row.def,row.baseAtk,row.baseDef,row.bonus})check(x==int32_t(f.integer()),"route score");}
 DuelView v;int ids[]={40,40,101,133,66};for(int i=0;i<5;i++){v.records[i]=ids[i];v.hand.push_back({i,ids[i],i,0,0});}advisor.rank(v,data.fusions(0),nullptr);bool strong=false;for(const auto& row:v.rows)if(row.result==473&&row.slots==std::vector<int>{4,0,1})strong=row.atk==4950&&row.def==4200;check(strong,"strong order");v.prefix={0};advisor.rank(v,data.fusions(0),nullptr);bool weak=false;for(const auto& row:v.rows)if(row.result==473&&row.slots==std::vector<int>{0,4,1})weak=row.atk==4450&&row.lossAtk==500&&row.better==std::vector<int>{4,0,1};check(weak,"prefix warning");check(f.f.peek()==EOF,"unused fixture");
 std::cout<<"PASS cards=722 terrain_stats=5054 NPCs=40 pools=115520 pixels="<<pixels<<" bonus_cases="<<cases<<" fusion_tables=7 RAM_routes="<<view.rows.size()<<" order_4950=true warning_500=true\n";
 }catch(const std::exception& e){std::cerr<<"FAIL "<<e.what()<<"\n";return 1;}}
