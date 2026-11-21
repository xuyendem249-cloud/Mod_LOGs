#include "GameData.hpp"
#include "Digest.hpp"
#include "ShiftJisTable.hpp"
#include <algorithm>
#include <cctype>
#include <regex>
#include <set>
#include <stdexcept>
namespace Legend {
namespace {
constexpr uint64_t profileOffset=0x2400000;
constexpr uint64_t artStride=7*2048;
constexpr int extendedTextFirst=759;

bool marker(const Bytes& data,size_t offset,const std::string& value){
 return offset<=data.size()&&value.size()<=data.size()-offset&&
  std::equal(value.begin(),value.end(),data.begin()+offset);
}
std::string readProfile(const Bytes& header){
 if(!marker(header,0,"FM770MRG"))return {};
 uint32_t length=u32(header,12);
 if(u32(header,8)!=16||length<2||length>2016)
  throw std::runtime_error("Header FM800 không hợp lệ");
 uint32_t crc=0xffffffff;
 for(size_t i=32;i<32+length;i++){
  crc^=header[i];
  for(int bit=0;bit<8;bit++)crc=(crc>>1)^((crc&1)?0xedb88320:0);
 }
 if((crc^0xffffffff)!=u32(header,16))
  throw std::runtime_error("Checksum FM800 không đúng");
 return std::string(header.begin()+32,header.begin()+32+length);
}
uint32_t field(const std::string& profile,const char* name,uint32_t fallback=0){
 std::regex pattern(std::string("\"")+name+"\"\\s*:\\s*(\\d+)");
 std::smatch match;
 if(!std::regex_search(profile,match,pattern))return fallback;
 auto value=std::stoull(match[1]);
 if(value>UINT32_MAX)throw std::runtime_error("Giá trị FM800 không hợp lệ");
 return uint32_t(value);
}
bool hasRelocatedDescriptions(const GameData& data){
 const ByteRange loader{0x801aef34-GameData::bias,204};
 return data.word(0x80037f1c)==0x0806bbcd&&data.word(0x80037f20)==0&&
  sha256(data.slus,{loader})=="6d98fd0de2f2626939555837ad955dbbfb1325d6216be7764a6855c1ede3826b";
}
std::string clean(std::string s,bool singleLine=false){std::string out;bool space=false;for(char c:s){if(c==0||c==' '||c=='\t'||(singleLine&&(c=='\n'||c=='\r'))){space=!out.empty();continue;}if(c=='\r')continue;if(c=='\n'){while(!out.empty()&&out.back()==' ')out.pop_back();out+='\n';space=false;continue;}if(space&&out.back()!='\n')out+=' ';space=false;out+=c;}while(!out.empty()&&std::isspace(static_cast<unsigned char>(out.back())))out.pop_back();size_t start=out.find_first_not_of(" \n\t");return start==std::string::npos?"":out.substr(start);}
}
Bytes GameData::read(unsigned lba,size_t length,uint64_t offset){
 std::lock_guard<std::mutex> lock(mutex);if(length>8*1024*1024)throw std::runtime_error("Vùng dữ liệu ISO quá lớn");Bytes out(length);size_t copied=0;uint64_t start=lba+offset/2048;size_t within=offset%2048;
 while(copied<length){size_t n=std::min<size_t>(2048-within,length-copied);uint64_t at=start*sector+skip+within;if(at>fileSize||n>fileSize-at)throw std::runtime_error("ISO bị thiếu dữ liệu");
  if(stream)stream->readAt(at,out.data()+copied,n);
  else{file.clear();file.seekg(std::streamoff(at));file.read(reinterpret_cast<char*>(out.data()+copied),std::streamsize(n));if(!file)throw std::runtime_error("Không đọc được ISO");}
  copied+=n;start++;within=0;
 }return out;
}
void GameData::walk(const std::string& prefix,unsigned lba,unsigned size,int depth){
 if(depth>8||files.size()>4096)throw std::runtime_error("Thư mục ISO không hợp lệ");Bytes b=read(lba,size);
 for(size_t p=0;p<b.size();){unsigned n=b[p];if(!n){p=(p/2048+1)*2048;continue;}if(n<34||p+n>b.size()||p+33+b[p+32]>p+n)throw std::runtime_error("Thư mục ISO bị lỗi");unsigned len=b[p+32];if(len==1&&b[p+33]<=1){p+=n;continue;}std::string title(reinterpret_cast<char*>(b.data()+p+33),len);title=title.substr(0,title.find(';'));std::transform(title.begin(),title.end(),title.begin(),[](unsigned char c){return char(std::toupper(c));});unsigned at=u32(b,p+2),length=u32(b,p+10);if(b[p+25]&2)walk(prefix+title+"/",at,length,depth+1);else files[prefix+title]={at,length};p+=n;}
}
GameData::GameData(const std::string& path):file(path,std::ios::binary){
 if(!file)throw std::runtime_error("Không mở được ISO");
 file.seekg(0,std::ios::end);fileSize=uint64_t(file.tellg());
 parse();
}
GameData::GameData(std::shared_ptr<DiscStream> source):stream(std::move(source)){
 if(!stream)throw std::runtime_error("Không mở được Mod 2");
 fileSize=stream->size();
 parse();
}
void GameData::parse(){
 bool found=false;
 for(auto layout:{std::pair<int,int>{2048,0},{2352,24},{2352,16}}){sector=layout.first;skip=layout.second;try{auto v=read(16,2048);if(v[0]==1&&std::string(reinterpret_cast<char*>(v.data()+1),5)=="CD001"){found=true;break;}}catch(const std::exception&){} }
 if(!found)throw std::runtime_error("VIP cần ISO/BIN có dữ liệu ISO9660");auto pvd=read(16,2048);walk("",u32(pvd,158),u32(pvd,166),0);
 std::pair<unsigned,unsigned> exe{};for(const auto& e:files)if(e.first.rfind("SLUS_",0)==0)exe=e.second;
 auto archive=files.find("DATA/WA_MRG.MRG");if(!exe.second||archive==files.end())throw std::runtime_error("Đĩa không có dữ liệu VIP được hỗ trợ");slus=read(exe.first,exe.second);wa=archive->second.first;
 if(slus.size()<0x1ca000)throw std::runtime_error("SLUS không đúng cấu trúc VIP");
 auto bound=word(0x8002a0b8),hi=word(0x8002cc24),lo=word(0x8002cc28);
 unsigned limit=bound&65535;
 if((bound>>16)==0x2a42&&limit>=legacyCards+1&&limit<=maximumCards+1)cardCount=limit-1;
 if((hi>>16)==0x3c03&&(lo>>16)==0x2463)statsAddress=(hi<<16)+int16_t(lo);
 auto requireExtent=[this](uint32_t address,size_t size){
  if(address<bias||address-bias>slus.size()||size>slus.size()-(address-bias))
   throw std::runtime_error("Con trỏ dữ liệu bài ngoài SLUS");
 };
 requireExtent(statsAddress,cardCount*4);
 const std::string profile=archive->second.second>=profileOffset+2048?
  readProfile(read(wa,2048,profileOffset)):std::string();
 uint32_t namesExtra=0,descriptionsExtra=0;
 if(!profile.empty()){
  if(cardCount<extendedTextFirst||field(profile,"count")!=unsigned(cardCount)||
     field(profile,"stats_address")!=statsAddress||
     field(profile,"card_text_extra_first_id")!=extendedTextFirst||
     field(profile,"card_text_extra_count")!=unsigned(cardCount-extendedTextFirst+1))
   throw std::runtime_error("Header FM800 không khớp mã game");
  size_t extraTextBytes=(cardCount-extendedTextFirst+1)*2;
  namesExtra=field(profile,"card_name_extra_table_address");
  descriptionsExtra=field(profile,"card_description_extra_table_address");
  requireExtent(namesExtra,extraTextBytes);
  requireExtent(descriptionsExtra,extraTextBytes);
  extraArt=field(profile,"art_offset");
  if(extraArt<profileOffset+2048||extraArt+(cardCount-legacyCards)*artStride>archive->second.second)
   throw std::runtime_error("Vùng ảnh FM800 không hợp lệ");
  levelsAddress=field(profile,"levels_address");
  auto count=field(profile,"fusion_count",legacyCards);
  if(count!=legacyCards&&(count!=maximumCards||cardCount!=maximumCards||word(0x80127c38)!=0x28880321))
   throw std::runtime_error("Bảng Fusion mở rộng không khớp mã game");
  fusionCount=int(count);
 }
 requireExtent(levelsAddress,cardCount+1);
 const bool relocated=hasRelocatedDescriptions(*this);
 const auto npcJump=word(0x80017acc);
 hasNpc40=npcJump>>26==2&&word(0x80000000|((npcJump&0x03ffffff)<<2))==0x24080028;
 for(int card=1;card<=cardCount;card++){
  uint32_t table=namesExtra&&card>=extendedTextFirst?
   namesExtra+(card-extendedTextFirst)*2:0x801d5800+card*2;
  names[card]=clean(rawScript(0x801d0000+u16(slus,table-bias),{}),true);
  if(names[card].empty()){
   auto number=std::to_string(card);
   names[card]="Card "+std::string(3-number.size(),'0')+number;
  }
  descriptors[card]=word(statsAddress+(card-1)*4);
  table=descriptionsExtra&&card>=extendedTextFirst?
   descriptionsExtra+(card-extendedTextFirst)*2:0x801c0200+card*2;
  auto offset=u16(slus,table-bias);
  descriptions[card]=script((relocated&&offset<0x9f4?0x801d1000:0x801c0000)+offset,{});
 }
 for(uint32_t pc=0x801db8e0;pc<0x801db970;pc+=12){uint32_t hi=word(pc),lo=word(pc+4),branch=word(pc+8);if(hi!=0x3c0d801d||(lo>>16)!=0x25ad||(branch>>16)!=0x11a2)continue;uint32_t ptr=0x801d0000+int16_t(lo);int card=int32_t(ptr-statsAddress)/4;uint32_t target=pc+12+int16_t(branch)*4,a=word(target),j=word(target+4),d=word(target+8);if(card>=1&&card<=cardCount&&(a>>16)==0x2402&&(d>>16)==0x240d&&(j>>26)==2)overrides[card]={int16_t(a),int16_t(d)};}
 const bool dropsV2=marker(slus,0x580000,"NPC8DR02");
 const bool expandedDrops=dropsV2||marker(slus,0x580000,"NPC8DR01");
 if(expandedDrops&&(cardCount!=maximumCards||slus.size()<0x594800||
    u32(slus,0x580008)!=maximumCards||u32(slus,0x58000c)!=40))
  throw std::runtime_error("Header Drop NPC mở rộng không hợp lệ");
 const int poolStart[]={0,1460,2920,4380};
 for(int npc=0;npc<40;npc++){
  npcNames[npc]=name(808+npc);
  const auto bytes=read(wa,6144,15308800ULL+npc*6144ULL);
  for(int pool=0;pool<4;pool++){
   for(int i=0;i<legacyCards;i++)pools[npc][pool][i]=u16(bytes,poolStart[pool]+i*2);
  }
  auto& deck=pools[npc][0];
  if(cardCount==maximumCards&&u32(bytes,0)==0xf17ed3c4){
   deck.fill(0);
   for(int slot=0;slot<40;slot++){
    auto card=u16(bytes,4+slot*2);
    if(card<1||card>unsigned(cardCount))throw std::runtime_error("ID Deck NPC không hợp lệ");
    deck[card-1]++;
   }
  }else if(cardCount==maximumCards&&marker(bytes,5840,"NPC8DK01")){
   for(int i=legacyCards;i<cardCount;i++)deck[i]=u16(bytes,5848+(i-legacyCards)*2);
  }
  if(expandedDrops&&(npc!=0||hasNpc40)){
   unsigned index=npc==0?39:npc-1;
   size_t record=0x580800+2048*index;
   if(u32(slus,record)!=(dropsV2?0x3844u:0x44523844u)||u32(slus,record+4)!=index+1)
    throw std::runtime_error("Bảng Drop NPC không hợp lệ");
   for(int rank=0;rank<3;rank++){
    for(int i=legacyCards;i<cardCount;i++)pools[npc][rank+1][i]=
     u16(slus,record+8+rank*156+(i-legacyCards)*2);
   }
  }
  photos[npc]=read(wa,2432,16076800ULL+npc*2432ULL);
 }
 decodeIcons(read(wa,50*2048,0x1690ULL*2048));
 for(size_t i=0;i<typeNames.size();i++)typeNames[i]=name(0x300+int(i));
 auto attrs=field(profile,"attribute_count",8)==9?9:8;
 decodeAttributes(read(wa,2048,0xb7f000),read(wa,attrs*32,0xb84e00),attrs);
}
Bytes GameData::block(uint32_t at,size_t length)const{uint32_t p=at-bias;if(p>slus.size()||length>slus.size()-p)return {};return {slus.begin()+p,slus.begin()+p+length};}
std::string GameData::glyph(unsigned code)const{size_t at=uint32_t(0x801d9000+code*4-bias);if(at+2>slus.size())return "?";uint16_t value=uint16_t((slus[at+1]<<8)|slus[at]);auto begin=std::begin(glyphTable),end=std::end(glyphTable);auto it=std::lower_bound(begin,end,value,[](const GlyphEntry& e,uint16_t v){return e.code<v;});if(it!=end&&it->code==value)return it->text;std::string s;for(int b:{slus[at+1],slus[at]})s+=b<128?char(b):'?';return s;}
std::string GameData::name(int index)const{uint32_t ptr=u16(slus,0x801d5800+index*2-bias),at=0x801d0000+ptr-bias;std::string out;for(size_t p=at;p<std::min(slus.size(),size_t(at)+512);){unsigned code=slus[p++];if(code==255)break;if(code==248&&p+1<slus.size()&&slus[p]==10){p+=2;continue;}if(code>=240&&code<=245){if(p>=slus.size())break;code=((code-240)<<8)|slus[p++];}else if(code>=240)break;out+=code?glyph(code):" ";}return clean(out,true);}
std::string GameData::script(uint32_t address,std::vector<uint32_t> seen)const{
 return clean(rawScript(address,std::move(seen)));
}
std::string GameData::rawScript(uint32_t address,std::vector<uint32_t> seen)const{
 if(!address||seen.size()>=8||std::find(seen.begin(),seen.end(),address)!=seen.end())return "";seen.push_back(address);uint32_t start=address-bias;if(start>=slus.size())return "";size_t end=std::min(slus.size(),std::min(size_t(start)+4096,size_t(start)+65536-(address&65535)));std::string out;
 for(size_t p=start;p<end;){unsigned code=slus[p++];if(code==255)break;if(code==250||code==254){out+='\n';continue;}if(code==252||code==253){if(p+2>end)break;unsigned offset=u16(slus,p);p+=2;out+=rawScript((address&0xffff0000)|offset,seen);if(code==253)break;continue;}if(code==248){if(p+2>end)break;unsigned command=slus[p++],value=slus[p++];if(command==10)continue;if(command==11){out+=" \xee\x80\x80"+std::to_string(value)+"\xee\x80\x81 ";continue;}break;}if(code>=240&&code<=245){if(p==end)break;code=((code-240)<<8)|slus[p++];}else if(code>=240)break;out+=code?glyph(code):" ";}return out;
}
uint32_t GameData::descriptor(int card,const Bytes* ram)const{
 if(card<1||card>cardCount)return 0;
 return ram?u32(*ram,(statsAddress&0x1fffff)+(card-1)*4):descriptors[card];
}
int GameData::attribute(int card,const Bytes* ram)const{if(card<0||card>cardCount)return -1;size_t at=levelsAddress+card;const auto& b=ram?*ram:slus;at=ram?at&0x1fffff:at-bias;return at<b.size()?b[at]>>4:-1;}
std::array<int,2> GameData::stats(int card,int terrain,int modifier,const Bytes* ram)const{
 if(card<1||card>cardCount)return {0,0};
 auto desc=descriptor(card,ram);
 int a=(desc&511)*10,d=((desc>>9)&511)*10;
 auto custom=overrides.find(card);
 if(custom!=overrides.end()){a=custom->second[0];d=custom->second[1];}
 unsigned type=(desc>>26)&31;
 int bonus=0;
 if(type<20&&terrain>=1&&terrain<=6){
  size_t at=0x909d4+type*6+terrain-1;
  const auto& bytes=ram?*ram:slus;
  if(!ram)at=uint32_t(at+0x80000000-bias);
  if(at<bytes.size())bonus=int8_t(bytes[at])*10;
 }
 uint32_t ac=ram?u32(*ram,0x170f4):word(0x800170f4),dc=ram?u32(*ram,0x17120):word(0x80017120);
 int capA=extraArt?65000:(ac>>16)==0x2405?ac&65535:30000;
 int capD=extraArt?65000:(dc>>16)==0x2403?dc&65535:30000;
 return {std::clamp(a+bonus+modifier,0,capA),std::clamp(d+bonus+modifier,0,capD)};
}
FusionMap GameData::decodeFusions(const Bytes& bytes,int count){
 if(bytes.size()!=65536||(count!=legacyCards&&count!=maximumCards))
  throw std::runtime_error("Bảng Fusion không hợp lệ");
 FusionMap pairs;
 for(int a=1;a<=count;a++){
  size_t cursor=u16(bytes,a*2);
  if(!cursor)continue;
  if(cursor<size_t(2*(count+1))||cursor>=bytes.size())throw std::runtime_error("Con trỏ Fusion lỗi");
  unsigned length=bytes[cursor++];
  if(!length){
   if(cursor>=bytes.size())throw std::runtime_error("Thiếu số lượng Fusion");
   length=511-bytes[cursor++];
  }
  if(cursor+length/2*5+length%2*3>bytes.size())throw std::runtime_error("Danh sách Fusion lỗi");
  for(unsigned i=0;i<length;i++){
   size_t at=cursor+i/2*5;
   unsigned group=bytes[at],other,result;
   if(i&1){
    other=((group<<4)&768)|bytes[at+3];
    result=((group<<2)&768)|bytes[at+4];
   }else{
    other=((group<<8)&768)|bytes[at+1];
    result=((group<<6)&768)|bytes[at+2];
   }
   if(other<unsigned(a)||other>unsigned(count)||result<1||result>unsigned(count))
    throw std::runtime_error("ID Fusion lỗi");
   pairs.emplace(pairKey(a,other),result);
  }
 }
 return pairs;
}
const FusionMap& GameData::fusions(int terrain){terrain=std::clamp(terrain,0,6);if(!fusionReady[terrain]){fusionMaps[terrain]=decodeFusions(read(wa,65536,0xb87800ULL+terrain*0x75800ULL),fusionCount);fusionReady[terrain]=true;}return fusionMaps[terrain];}
EquipMap GameData::equips(int terrain){
 if(terrain<0||terrain>6)throw std::runtime_error("Sân không hợp lệ");
 auto bytes=read(wa,10240,0xb85000ULL+terrain*0x75800ULL);
 EquipMap rows;
 for(size_t at=0;at+2<=bytes.size();){
  auto equip=u16(bytes,at);
  if(!equip)return rows;
  auto count=u16(bytes,at+2);
  at+=4;
  if(equip>unsigned(cardCount)||!count||at+2*count>bytes.size())break;
  std::set<int> ids;
  for(unsigned i=0;i<count;i++,at+=2){
   auto id=u16(bytes,at);
   if(id<1||id>unsigned(cardCount))throw std::runtime_error("Bảng Equip trong ISO không hợp lệ");
   ids.insert(id);
  }
  rows.emplace(equip,std::move(ids));
 }
 throw std::runtime_error("Không đọc được bảng Equip của sân đã chọn");
}
uint32_t GameData::colour(unsigned v,bool opaque){return ((opaque||v)?0xff000000:0)|(((v&31)*255/31)<<16)|((((v>>5)&31)*255/31)<<8)|((v>>10)&31)*255/31;}
std::vector<uint32_t> GameData::art(int card){
 if(card<1||card>cardCount||(card>legacyCards&&!extraArt))return {};
 auto cached=artCache.find(card);
 if(cached!=artCache.end())return cached->second;
 uint64_t offset=card<=legacyCards?legacyCards*2048ULL+(card-1)*artStride:
  extraArt+(card-legacyCards-1)*artStride;
 auto bytes=read(wa,102*96+512,offset);
 std::vector<uint32_t> pixels(102*96);
 for(size_t i=0;i<pixels.size();i++)pixels[i]=colour(u16(bytes,pixels.size()+bytes[i]*2),true);
 if(artCache.size()>=48)artCache.erase(artCache.begin());
 artCache[card]=pixels;
 return pixels;
}
std::vector<uint32_t> GameData::npcPhoto(int npc)const{const auto& b=photos[std::clamp(npc,0,39)];std::vector<uint32_t> p(48*48);for(size_t i=0;i<p.size();i++)p[i]=colour(u16(b,2304+b[i]*2),true);return p;}
unsigned GameData::bootWord(const Bytes& b,int x,int y)const{int at;if(x>=512&&x<768&&y>=248&&y<256)at=48*2048+((y-248)*256+x-512)*2;else if(x>=640&&x<832&&y>=0&&y<256)at=((x-640)/64*16+y/16)*2048+((y%16)*64+(x-640)%64)*2;else return 0;return u16(b,at);}
void GameData::decodeIcons(const Bytes& b){for(int icon=0;icon<41;icon++){int u,v,cx,cy;if(icon>=34){u=(icon*16-528)&255;v=128;cx=u==80?528:512;cy=252;}else{u=((icon&7)*16-128)&255;v=(icon&56)*2;int index=std::min(icon,24);cx=512+(index&15)*16;cy=249+(index>>4);}auto& pixels=icons[icon];pixels.resize(256);for(int y=0;y<16;y++)for(int x=0;x<16;x++){int px=u+x;unsigned packed=bootWord(b,704+px/4,v+y),entry=(packed>>((px&3)*4))&15;pixels[y*16+x]=colour(bootWord(b,cx+entry,cy),false);}}}
void GameData::decodeAttributes(const Bytes& atlas,const Bytes& palettes,int count){
 for(int attribute=0;attribute<count;attribute++){
  auto& pixels=attributeIcons[attribute];
  pixels.resize(256);
  for(int y=0;y<16;y++){
   for(int x=0;x<16;x++){
    unsigned entry=(atlas[y*128+attribute*8+x/2]>>((x&1)*4))&15;
    pixels[y*16+x]=colour(u16(palettes,attribute*32+entry*2),false);
   }
  }
 }
}
}
