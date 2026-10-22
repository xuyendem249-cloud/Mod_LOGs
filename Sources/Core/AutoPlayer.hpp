#pragma once
#include "FusionAdvisor.hpp"
#include <optional>
#include <limits>
#include <set>
namespace Legend {
// Same read-only duel policy as Android 8 / Ver19. Outputs normal pad masks.
struct EquipRules {
 static int bonus(int id,int side,const Bytes& ram){
  auto base=u32(ram,0x1a7f8);if((base>>16)!=0x2402||u32(ram,0x1a810)!=0x08076d81)return 0;
  int standard=int16_t(base),regs[32]{};regs[7]=id;int pc=0x1db624,pending=-1;
  for(int steps=0;steps<140;steps++){
   if(pc==0x1db748)return std::max(0,regs[3]);if(pc==0x1db74c)return std::max(0,standard);
   if(!((pc>=0x1db624&&pc<0x1db748)||(pc>=0x1d4dec&&pc<0x1d4e1c)||(pc>=0x1db7f0&&pc<0x1db80c)))return 0;
   auto ins=u32(ram,pc);int op=ins>>26,rs=(ins>>21)&31,rt=(ins>>16)&31,imm=int16_t(ins),next=pc+4,branch=-1;
   if(!ins){}else if(op==9)regs[rt]=regs[rs]+imm;
   else if(op==4)branch=regs[rs]==regs[rt]?pc+4+imm*4:pc+8;
   else if(op==2)branch=((ins&0x3ffffff)<<2)&0x1fffff;
   else if(op==3&&(((ins&0x3ffffff)<<2)&0x1fffff)==0x95600){regs[3]=u16(ram,0xea004+(1-side)*0x20)/2;branch=pc+8;}
   else return 0;
   regs[0]=0;if(pending>=0)next=pending;pending=branch;pc=next;
  }return 0;
 }
};
class AutoPlayer {
public:
 static constexpr int CROSS=0,START=3,UP=4,DOWN=5,LEFT=6,RIGHT=7,CIRCLE=8,L1=10,BOARD=0x1a7ad8;
 struct Card{int id=0,record=0,col=0,flags=0,atk=0,def=0,star=0;bool down()const{return flags&0x1000;}bool defense()const{return flags&0x800;}bool available()const{return !(flags&0x4000);}};
 struct Plan{std::vector<int> slots;int result=0,atk=0,def=0,star=0,fieldCol=-1,placementCol=-1;bool fusion=false,faceDown=false,defend=false,trap=false;std::string label;};
 GameData& data;FusionAdvisor& advisor;std::optional<Plan> plan;
 int owner=-1,pulse=0,lastPhase=-1,attackCol=-1,targetCol=-1;
 uint64_t nextDecision=0,releaseAt=0,unchangedSince=0,previousSignature=uint64_t(1)<<63;
 bool stopped=false,seenDuel=false;std::string status="Chờ lượt của bạn",lastAction;
 AutoPlayer(GameData& d,FusionAdvisor& a):data(d),advisor(a){}
 static int b(const Bytes& r,int p){return r[p];}static int h(const Bytes& r,int p){return u16(r,p);}static int s(const Bytes& r,int p){return int16_t(u16(r,p));}
 uint32_t descriptor(int id,const Bytes& r)const{return id<1||id>722?0:u32(r,0x1d4244+(id-1)*4);}
 int type(int id,const Bytes& r)const{return (descriptor(id,r)>>26)&31;}
 int star(int id,int second,const Bytes& r)const{return (descriptor(id,r)>>(second?18:22))&15;}
 static int matchup(int a,int z){if(a<1||a>10||z<1||z>10||(a<=6)!=(z<=6))return 0;int base=a<=6?1:7,n=a<=6?6:4,x=a-base,y=z-base;if((x+1)%n==y)return 500;return (y+1)%n==x?-500:0;}
 int cap(const Bytes& r,bool defense)const{auto word=u32(r,defense?0x17120:0x170f4);return (word>>16)==unsigned(defense?0x2403:0x2405)?word&65535:30000;}
 int clamp(int value,const Bytes& r,bool defense)const{return std::clamp(value,0,cap(r,defense));}
 std::optional<Card> record(const Bytes& r,int index,int col)const{
  if(index<0||index>=30)return {};int p=BOARD+index*28,id=h(r,p+12),flags=h(r,p+22);if(!(flags&0x8000)||id<1||id>722)return {};
  Card c;c.id=id;c.record=index;c.col=col;c.flags=flags;c.atk=clamp(s(r,p+14)+s(r,p+18)+s(r,p+20),r,false);c.def=clamp(s(r,p+16)+s(r,p+18)+s(r,p+20),r,true);c.star=star(id,(flags&0x200)?1:0,r);return c;
 }
 std::optional<Card> grid(const Bytes& r,int row,int col)const{return record(r,b(r,0x907d8+owner*20+row*5+col),col);}
 std::vector<Card> row(const Bytes& r,int n)const{std::vector<Card> out;for(int i=0;i<5;i++)if(auto c=grid(r,n,i))out.push_back(*c);return out;}
 int place(const Bytes& r,int n)const{for(int i=0;i<5;i++)if(!grid(r,n,i))return i;return -1;}
 bool equips(int equip,int monster,const Bytes& r)const{
  if(type(equip,r)!=23||type(monster,r)>=20)return false;
  for(int p=0x17a1d8;p+4<=0x17c2d8;){int id=h(r,p),n=h(r,p+2);p+=4;if(!id)return false;if(id>722||n<1||n>722||p+n*2>0x17c2d8)return false;if(id==equip){for(int i=0;i<n;i++)if(h(r,p+i*2)==monster)return true;return false;}p+=n*2;}return false;
 }
 int bestStar(int id,int atk,int def,const std::vector<Card>& enemies,const Bytes& r)const{
  int64_t best=std::numeric_limits<int64_t>::min();int choice=0;
  for(int pick=0;pick<2;pick++){int gs=star(id,pick,r);int64_t score=0;for(const auto& e:enemies)if(!e.down()){int bonus=matchup(gs,e.star);score+=bonus;score+=atk+bonus>(e.defense()?e.def:e.atk)?2000:0;score+=def+bonus>=e.atk?500:0;}if(score>best){best=score;choice=pick;}}return choice;
 }
 bool shouldDefend(int id,int atk,int pick,const std::vector<Card>& enemies,const Bytes& r)const{int gs=star(id,pick,r);for(const auto& e:enemies)if(!e.down()&&atk+matchup(gs,e.star)>(e.defense()?e.def:e.atk))return false;return !enemies.empty();}
 Plan monster(int id,std::vector<int> slots,int atk,int def,bool fusion,const std::vector<Card>& enemies,const Bytes& r)const{Plan p;p.result=id;p.slots=std::move(slots);p.atk=atk;p.def=def;p.fusion=fusion;p.star=bestStar(id,atk,def,enemies,r);p.defend=shouldDefend(id,atk,p.star,enemies,r);p.label=fusion?"Ghép Fusion":"Hạ bài phòng thủ";return p;}
 Plan withEquips(Plan p,const DuelView& v,const Bytes& r,const FusionMap& pairs)const{
  bool usedRiryoku=false;for(const auto& hand:v.hand)if(std::find(p.slots.begin(),p.slots.end(),hand.slot)==p.slots.end()&&!pairs.count(GameData::pairKey(hand.id,p.result))&&equips(hand.id,p.result,r)){
   if(hand.id==302&&usedRiryoku)continue;int bonus=EquipRules::bonus(hand.id,owner,r);if(bonus<=0)continue;if(hand.id==302)usedRiryoku=true;p.slots.push_back(hand.slot);p.atk=clamp(p.atk+bonus,r,false);p.def=clamp(p.def+bonus,r,true);
  }
  auto enemies=row(r,1);p.star=bestStar(p.result,p.atk,p.def,enemies,r);p.defend=shouldDefend(p.result,p.atk,p.star,enemies,r);return p;
 }
 std::optional<Plan> choose(const DuelView& v,const Bytes& r){
  auto enemies=row(r,1);std::optional<Plan> best;auto pairs=GameData::decodeFusions(Bytes(r.begin()+0x17c2d8,r.begin()+0x18c2d8));
  for(const auto& f:v.rows)if(type(f.result,r)<20){auto p=withEquips(monster(f.result,f.slots,f.atk,f.def,true,enemies,r),v,r,pairs);if(!best||p.atk>best->atk||(p.atk==best->atk&&p.def>best->def)||(p.atk==best->atk&&p.def==best->def&&p.slots.size()<best->slots.size()))best=p;}
  if(best)return best;if(!v.prefix.empty())return {};
  for(const auto& hand:v.hand)if(type(hand.id,r)==23)for(const auto& c:row(r,2))if(!pairs.count(GameData::pairKey(hand.id,c.id))&&equips(hand.id,c.id,r)){
   int bonus=EquipRules::bonus(hand.id,owner,r),gain=clamp(c.atk+bonus,r,false)-c.atk;if(gain>0&&(!best||c.atk+gain>best->atk)){auto p=monster(c.id,{hand.slot},c.atk+gain,clamp(c.def+bonus,r,true),false,enemies,r);p.fieldCol=c.col;p.star=(c.flags&0x200)?1:0;p.label="Trang bị tăng ATK";best=p;}
  }
  auto rules=advisor.rules(&r);for(const auto& hand:v.hand)if(type(hand.id,r)<20){auto score=advisor.score(hand.id,{hand.slot},v,&r,rules);auto p=withEquips(monster(hand.id,{hand.slot},score.atk,score.def,false,enemies,r),v,r,pairs);if(p.slots.size()>1&&(!best||p.atk>best->atk)){p.label="Hạ bài và trang bị";best=p;}}
  if(best)return best;
  if(place(r,3)>=0)for(const auto& hand:v.hand)if(type(hand.id,r)==21){Plan p;p.slots={hand.slot};p.result=hand.id;p.trap=p.faceDown=true;p.label="Úp Trap";return p;}
  std::set<int> reserved;for(const auto& f:v.rows)for(int slot:f.slots)reserved.insert(slot);
  for(const auto& hand:v.hand)if(type(hand.id,r)<20&&!reserved.count(hand.slot)){auto score=advisor.score(hand.id,{hand.slot},v,&r,rules);if(!best||score.atk<best->atk||(score.atk==best->atk&&score.def>best->def)){best=monster(hand.id,{hand.slot},score.atk,score.def,false,enemies,r);best->defend=best->faceDown=true;}}
  if(!best)for(const auto& hand:v.hand)if(type(hand.id,r)>=20){Plan p;p.slots={hand.slot};p.result=hand.id;p.trap=p.faceDown=true;p.label="Úp bài dự phòng";best=p;break;}
  return best;
 }
 int stop(const std::string& reason){stopped=true;status=reason;pulse=0;return 0;}
 int tap(int button,uint64_t frame,const std::string& action){pulse=1<<button;releaseAt=frame+3;nextDecision=frame+12;lastAction=status=action;return pulse;}
 int navigate(const Bytes& r,int cursor,int col,int n,uint64_t frame){if(b(r,cursor+0x19)||b(r,0x9b162))return -1;int x=b(r,cursor+15),y=b(r,cursor+16);if(x>4||y>3)return -1;if(y!=n)return tap(y>n?UP:DOWN,frame,"Chọn hàng bài");if(x!=col)return tap(x>col?LEFT:RIGHT,frame,"Chọn ô bài");return 0;}
 uint64_t signature(const Bytes& r)const{uint64_t x=17;for(int p:{0x9b23a,0x9b174,0x9b1d5,0x9b254,0x9b220,0x9b162,0x9b34d})x=x*131+h(r,p);for(int i=0;i<30;i++){int p=BOARD+i*28;x=x*31+h(r,p+12);x=x*31+h(r,p+22);}int base=0xe9f10+owner*0x70;for(int p=base;p<base+0x70;p++)x=x*31+b(r,p);return x;}
 int guardianForSelected(const Bytes& r)const{int object=u32(r,0xe9ef0)&0x1fffff;if(object<0x10000||object+0x6a>=int(r.size()))return 0;auto c=record(r,b(r,object+0x6a),0);return c?bestStar(c->id,c->atk,c->def,row(r,1),r):0;}
 int hand(const Bytes& r,uint64_t frame,int state,int sub){
  int cursor=0xe9f10+owner*0x70;
  if(state==1){auto v=advisor.analyze(r);if(!v.active)return 0;
   if(!plan){plan=choose(v,r);if(!plan&&!v.prefix.empty()){int slot=v.prefix.back(),here=b(r,cursor+14);return tap(here<slot?RIGHT:here>slot?LEFT:CIRCLE,frame,"Bỏ lựa chọn để tính lại Fusion");}}
   if(!plan)return stop("Auto dừng: không có nước hạ bài hợp lệ");
   if(plan->slots.size()>1){size_t done=v.prefix.size();if(done>plan->slots.size()||!std::equal(v.prefix.begin(),v.prefix.end(),plan->slots.begin()))return stop("Auto dừng: thứ tự ghép đã thay đổi");if(done==plan->slots.size())return tap(CROSS,frame,plan->label);int slot=plan->slots[done],here=b(r,cursor+14);return tap(here<slot?RIGHT:here>slot?LEFT:UP,frame,"Chọn nguyên liệu "+std::to_string(done+1));}
   int slot=plan->slots[0],here=b(r,cursor+14);return tap(here<slot?RIGHT:here>slot?LEFT:CROSS,frame,plan->label);
  }
  if(!plan){if((state==3&&!(sub&0x70))||(state==4&&!(sub&0x40)))return tap(CIRCLE,frame,"Quay lại chọn bài");return 0;}
  if(state==3&&!(sub&0x70)){int slot=b(r,cursor+14);if(slot>4)return 0;int object=u32(r,0xea030+slot*12)&0x1fffff;if(object<0x10000||object+0x21>=int(r.size()))return 0;bool down=b(r,object+0x21)!=0;if(down!=plan->faceDown)return tap(RIGHT,frame,plan->faceDown?"Úp bài":"Mở bài trang bị");return tap(CROSS,frame,"Chọn vị trí hạ bài");}
  if(state==4&&!(sub&0x40)){int n=plan->trap?3:2,col=plan->fieldCol;if(col<0){if(plan->placementCol<0){plan->placementCol=place(r,n);if(plan->placementCol<0){std::optional<Card> weakest;for(const auto& c:row(r,n))if(!weakest||c.atk<weakest->atk)weakest=c;if(!weakest)return 0;plan->placementCol=weakest->col;}}col=plan->placementCol;}int move=navigate(r,0xe9f48+owner*0x70,col,n,frame);if(move)return std::max(0,move);return tap(CROSS,frame,plan->label);}
  return 0;
 }
 int field(const Bytes& r,uint64_t frame,int state,int sub){
  if(state==6){int move=navigate(r,0xe9f64+owner*0x70,std::max(0,targetCol),1,frame);if(move)return std::max(0,move);return tap(CROSS,frame,"Tấn công mục tiêu");}
  if(state!=3||(sub&0x40)||b(r,0x9b162))return 0;int cursor=0xe9f48+owner*0x70;if(b(r,cursor+0x19))return 0;
  auto own=row(r,2),enemies=row(r,1);std::optional<Card> attacker,target;bool cannotAttack=h(r,0x9b16c)&0x1000;int sideState=u32(r,0x9b1c8)&0x1fffff;if(sideState>=0x10000&&sideState+0x19<int(r.size())&&b(r,sideState+0x19))cannotAttack=true;
  for(const auto& c:own)if(c.available()){std::optional<Card> preferred;int margin=std::numeric_limits<int>::min();if(!cannotAttack)for(const auto& e:enemies)if(!e.down()){int delta=clamp(c.atk+matchup(c.star,e.star),r,false)-(e.defense()?e.def:e.atk);if(delta>0&&(!preferred||delta>margin)){preferred=e;margin=delta;}}
   bool canWin=!cannotAttack&&(enemies.empty()||preferred.has_value());if(canWin){if(!attacker||c.atk>attacker->atk){attacker=c;target=preferred;}}else if(!c.defense()){int move=navigate(r,cursor,c.col,2,frame);if(move)return std::max(0,move);return tap(L1,frame,"Chuyển phòng thủ");}
  }
  if(attacker){int move=navigate(r,cursor,attacker->col,2,frame);if(move)return std::max(0,move);if(attacker->defense())return tap(L1,frame,"Chuyển tấn công");attackCol=attacker->col;targetCol=target?target->col:0;return tap(CROSS,frame,enemies.empty()?"Tấn công trực tiếp":"Tấn công khi có lợi");}
  return tap(START,frame,"Kết thúc lượt");
 }
 int next(const Bytes* ram,uint64_t frame){
  if(stopped)return 0;if(frame<releaseAt)return pulse;pulse=0;if(frame<nextDecision)return 0;nextDecision=frame+8;
  if(!ram||ram->size()!=0x200000)return stop("Auto dừng: thiếu trạng thái game");const auto& r=*ram;
  bool duel=(b(r,0x9b26c)&31)==3&&b(r,0x9b26e)==0x81;
  if(!duel){if(seenDuel)return stop("Auto tắt: đã rời trận đấu");plan.reset();owner=-1;status="Chờ vào trận đấu";return 0;}seenDuel=true;
  int side=b(r,0x9b1d5),phase=h(r,0x9b23a)&15,sub=b(r,0x9b174),state=sub&15;
  if(phase>=12)return stop("Auto dừng: trận đấu đã kết thúc");
  if(side>1||b(r,0x9b360+side)!=255){plan.reset();attackCol=targetCol=-1;status="Chờ lượt của bạn";unchangedSince=frame;return 0;}
  if(owner!=side){owner=side;plan.reset();attackCol=targetCol=-1;previousSignature=uint64_t(1)<<63;}
  if(b(r,0x9b164))return stop("Auto dừng khi mở hộp thoại");auto sig=signature(r);if(sig!=previousSignature){previousSignature=sig;unchangedSince=frame;}else if(frame-unchangedSince>1800)return stop("Auto dừng: trạng thái chưa tiến triển");
  if(b(r,0x9b254)||h(r,0x9b220)){status="Chờ hiệu ứng";return 0;}
  if(phase==4&&lastPhase!=4){plan.reset();attackCol=targetCol=-1;}lastPhase=phase;
  try{if(phase==4)return hand(r,frame,state,sub);if(phase==8&&state==3&&!(sub&0x10)){int wanted=plan?plan->star:guardianForSelected(r);if(b(r,0x9b34d)!=wanted)return tap(DOWN,frame,"Chọn Guardian khắc chế");return tap(CROSS,frame,"Xác nhận Guardian");}if(phase==5)return field(r,frame,state,sub);}catch(const std::exception&){return stop("Auto dừng: không đọc được bài/trạng thái");}
  status="Chờ hoạt ảnh";return 0;
 }
};
}
