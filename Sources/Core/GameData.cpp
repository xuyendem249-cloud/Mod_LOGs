#include "GameData.hpp"
#include "ShiftJisTable.hpp"
#include <algorithm>
#include <charconv>
#include <cctype>
#include <set>
#include <stdexcept>
#include <string_view>
namespace Legend {
namespace {
constexpr uint64_t mergedHeaderOffset=0x2400000;
constexpr uint64_t cardArtStride=7*2048;
constexpr uint64_t fusionOffset=0xb87800,terrainStride=0x75800;
constexpr size_t fusionSize=65536,equipSize=5*2048;
constexpr std::string_view mergedMagic="FM770MRG";

uint32_t profileCrc(std::string_view text) {
 uint32_t crc=0xffffffff;
 for(unsigned char c:text) {
  crc^=c;
  for(int bit=0;bit<8;bit++) crc=(crc>>1)^((crc&1)?0xedb88320u:0u);
 }
 return ~crc;
}

// The merged header also contains nested metadata. Only its top-level numeric
// fields describe the locations that this reader uses.
std::map<std::string,uint32_t> profileNumbers(std::string_view text) {
 if(text.empty() || text.front()!='{' || text.back()!='}')
  throw std::runtime_error("Thông tin ISO FM770MRG không hợp lệ");
 std::map<std::string,uint32_t> values;
 int depth=0;
 bool expectKey=false;
 auto skipSpace=[&](size_t p) {
  while(p<text.size() && std::isspace(static_cast<unsigned char>(text[p]))) ++p;
  return p;
 };
 for(size_t p=0;p<text.size();++p) {
  const char c=text[p];
  if(c=='{' || c=='[') {
   ++depth;
   if(depth==1) expectKey=true;
  } else if(c=='}' || c==']') {
   --depth;
  } else if(c==',' && depth==1) {
   expectKey=true;
  } else if(c=='"') {
   const size_t start=++p;
   while(p<text.size() && text[p]!='"') {
    if(text[p]=='\\') ++p;
    ++p;
   }
   if(p>=text.size()) throw std::runtime_error("Chuỗi FM770MRG không hợp lệ");
   if(depth!=1 || !expectKey) continue;
   expectKey=false;
   const size_t colon=skipSpace(p+1);
   if(colon>=text.size() || text[colon]!=':')
    throw std::runtime_error("Khóa FM770MRG không hợp lệ");
   const size_t valueAt=skipSpace(colon+1);
   uint32_t value;
   const auto parsed=std::from_chars(text.data()+valueAt,text.data()+text.size(),value);
   const size_t after=skipSpace(size_t(parsed.ptr-text.data()));
   if(parsed.ec==std::errc{} && after<text.size() && (text[after]==',' || text[after]=='}')) {
    if(!values.emplace(std::string(text.substr(start,p-start)),value).second)
     throw std::runtime_error("Khóa FM770MRG bị lặp");
   }
  }
  if(depth<0) throw std::runtime_error("Thông tin ISO FM770MRG không hợp lệ");
 }
 if(depth!=0) throw std::runtime_error("Thông tin ISO FM770MRG không hợp lệ");
 return values;
}

// Identical to the verified 204-byte PC description helper. Match the whole
// helper before treating a low offset as a pointer into the expanded text bank.
constexpr std::string_view taggedDescriptionHelper=
 "f8ffbd270000a3af200082300300401000000000fcbb06080000000040008230260040100000000001d102342310a2002003432c2100601000000000f602432c0a0060100000000001004224401002001c80033c00026324211043000000439400000000efbb0608000000000afd4224401002001b80033ce0ee6324211043000000439400000000f409622c0b004010000000001d80023c0010422421186200580002922130a00001004224580002a20800bd27f0df0008000000000000a38f0800bd2760bb060800000000";

bool guardedDescriptionHelper(const Bytes& code) {
 constexpr std::string_view hex="0123456789abcdef";
 if(code.size()*2!=taggedDescriptionHelper.size()) return false;
 for(size_t i=0;i<code.size();++i) {
  if(hex[code[i]>>4]!=taggedDescriptionHelper[i*2] ||
     hex[code[i]&15]!=taggedDescriptionHelper[i*2+1]) return false;
 }
 return true;
}

std::string clean(std::string s,bool singleLine=false){std::string out;bool space=false;for(char c:s){if(c==0||c==' '||c=='\t'||(singleLine&&(c=='\n'||c=='\r'))){space=!out.empty();continue;}if(c=='\r')continue;if(c=='\n'){while(!out.empty()&&out.back()==' ')out.pop_back();out+='\n';space=false;continue;}if(space&&out.back()!='\n')out+=' ';space=false;out+=c;}while(!out.empty()&&std::isspace(static_cast<unsigned char>(out.back())))out.pop_back();size_t start=out.find_first_not_of(" \n\t");return start==std::string::npos?"":out.substr(start);}
}
Bytes GameData::read(unsigned lba,size_t length,uint64_t offset){
 std::lock_guard<std::mutex> lock(mutex);if(length>8*1024*1024)throw std::runtime_error("Vùng dữ liệu ISO quá lớn");Bytes out(length);size_t copied=0;uint64_t start=lba+offset/2048;size_t within=offset%2048;
 while(copied<length){size_t n=std::min<size_t>(2048-within,length-copied);uint64_t at=start*sector+skip+within;if(at>fileSize||n>fileSize-at)throw std::runtime_error("ISO bị thiếu dữ liệu");file.clear();file.seekg(std::streamoff(at));file.read(reinterpret_cast<char*>(out.data()+copied),std::streamsize(n));if(!file)throw std::runtime_error("Không đọc được ISO");copied+=n;start++;within=0;}return out;
}
void GameData::walk(const std::string& prefix,unsigned lba,unsigned size,int depth){
 if(depth>8||files.size()>4096)throw std::runtime_error("Thư mục ISO không hợp lệ");Bytes b=read(lba,size);
 for(size_t p=0;p<b.size();){unsigned n=b[p];if(!n){p=(p/2048+1)*2048;continue;}if(n<34||p+n>b.size()||p+33+b[p+32]>p+n)throw std::runtime_error("Thư mục ISO bị lỗi");unsigned len=b[p+32];if(len==1&&b[p+33]<=1){p+=n;continue;}std::string title(reinterpret_cast<char*>(b.data()+p+33),len);title=title.substr(0,title.find(';'));std::transform(title.begin(),title.end(),title.begin(),[](unsigned char c){return char(std::toupper(c));});unsigned at=u32(b,p+2),length=u32(b,p+10);if(b[p+25]&2)walk(prefix+title+"/",at,length,depth+1);else files[prefix+title]={at,length};p+=n;}
}
GameData::GameData(const std::string& path):file(path,std::ios::binary){
 if(!file)throw std::runtime_error("Không mở được ISO");file.seekg(0,std::ios::end);fileSize=uint64_t(file.tellg());bool found=false;
 for(auto layout:{std::pair<int,int>{2048,0},{2352,24},{2352,16}}){sector=layout.first;skip=layout.second;try{auto v=read(16,2048);if(v[0]==1&&std::string(reinterpret_cast<char*>(v.data()+1),5)=="CD001"){found=true;break;}}catch(const std::exception&){} }
 if(!found)throw std::runtime_error("VIP cần ISO/BIN có dữ liệu ISO9660");auto pvd=read(16,2048);walk("",u32(pvd,158),u32(pvd,166),0);
 std::pair<unsigned,unsigned> exe{};for(const auto& e:files)if(e.first.rfind("SLUS_",0)==0)exe=e.second;
 auto archive=files.find("DATA/WA_MRG.MRG");if(!exe.second||archive==files.end())throw std::runtime_error("Đĩa không có dữ liệu VIP được hỗ trợ");slus=read(exe.first,exe.second);wa=archive->second.first;
 if(slus.size()<0x1ca000)throw std::runtime_error("SLUS không đúng cấu trúc VIP");
 readCardLayout(archive->second.second);
 names.resize(cardCount+1);
 descriptions.resize(cardCount+1);
 descriptors.resize(cardCount+1);
 for(int card=1;card<=cardCount;card++) {
  names[card]=name(card,true);
  if(names[card].empty()) {
   const auto id=std::to_string(card);
   names[card]="Card "+std::string(cardCount>LegacyCards && id.size()<3?3-id.size():0,'0')+id;
  }
  descriptors[card]=word(descriptorAddress+(card-1)*4);
  descriptions[card]=clean(script(descriptionAddress(card),{}));
 }
 for(uint32_t pc=0x801db8e0;pc<0x801db970;pc+=12){uint32_t hi=word(pc),lo=word(pc+4),branch=word(pc+8);if(hi!=0x3c0d801d||(lo>>16)!=0x25ad||(branch>>16)!=0x11a2)continue;uint32_t ptr=0x801d0000+int16_t(lo);int card=int32_t(ptr-0x801d4244)/4;uint32_t target=pc+12+int16_t(branch)*4,a=word(target),j=word(target+4),d=word(target+8);if(card>=1&&card<=722&&(a>>16)==0x2402&&(d>>16)==0x240d&&(j>>26)==2)overrides[card]={int16_t(a),int16_t(d)};}
 for(int npc=0;npc<40;npc++){npcNames[npc]=name(808+npc);auto b=read(wa,6144,15308800ULL+npc*6144ULL);int starts[]={0,1460,2920,4380};for(int pool=0;pool<4;pool++)for(int i=0;i<722;i++)pools[npc][pool][i]=u16(b,starts[pool]+i*2);photos[npc]=read(wa,2432,16076800ULL+npc*2432ULL);}
 decodeIcons(read(wa,50*2048,0x1690ULL*2048));
}
void GameData::readCardLayout(unsigned archiveSize) {
 const uint32_t bound=word(0x8002a0b8);
 const int limit=bound&0xffff;
 if((bound>>16)==0x2a42 && limit>=LegacyCards+1 && limit<=MaxCards+1)
  cardCount=limit-1;

 const uint32_t hi=word(0x8002cc24), lo=word(0x8002cc28);
 if((hi>>16)==0x3c03 && (lo>>16)==0x2463) {
  const uint32_t address=(hi<<16)+int16_t(lo);
  if(address>=bias && address<=0x80200000-cardCount*4u &&
     block(address,cardCount*4u).size()==cardCount*4u) descriptorAddress=address;
 }
 taggedDescriptions=word(0x80037f1c)==0x0806bbcd && word(0x80037f20)==0 &&
                    guardedDescriptionHelper(block(0x801aef34,204));

 if(archiveSize<mergedHeaderOffset+2048) return;
 const Bytes header=read(wa,2048,mergedHeaderOffset);
 if(!std::equal(mergedMagic.begin(),mergedMagic.end(),header.begin())) return;
 const uint32_t length=u32(header,12);
 if(u32(header,8)!=16 || length<2 || length>2016)
  throw std::runtime_error("Thông tin ISO FM770MRG không hợp lệ");
 const std::string_view metadata(reinterpret_cast<const char*>(header.data()+32),length);
 if(profileCrc(metadata)!=u32(header,16))
  throw std::runtime_error("Checksum FM770MRG không đúng");
 const auto values=profileNumbers(metadata);
 auto required=[&](const char* key) {
  const auto value=values.find(key);
  if(value==values.end()) throw std::runtime_error(std::string("Thiếu trường FM770MRG ")+key);
  return value->second;
 };
 if(cardCount<759 || cardCount>800 || required("count")!=unsigned(cardCount) ||
    required("stats_address")!=descriptorAddress || required("card_text_extra_first_id")!=759 ||
    required("card_text_extra_count")!=unsigned(cardCount-758))
  throw std::runtime_error("Bảng bài FM770MRG không khớp mã game");
 extraNameAddress=required("card_name_extra_table_address");
 extraDescriptionAddress=required("card_description_extra_table_address");
 const auto textBytes=size_t(cardCount-758)*2;
 if(block(extraNameAddress,textBytes).size()!=textBytes ||
    block(extraDescriptionAddress,textBytes).size()!=textBytes)
  throw std::runtime_error("Thiếu bảng tên/mô tả FM770MRG");
 extraArtOffset=required("art_offset");
 if(extraArtOffset<mergedHeaderOffset+2048 ||
    extraArtOffset+uint64_t(cardCount-LegacyCards)*cardArtStride>archiveSize)
  throw std::runtime_error("Vùng ảnh bài FM770MRG không hợp lệ");
 const auto expandedFusion=values.find("fusion_count");
 if(expandedFusion!=values.end()) {
  if(expandedFusion->second==800 && cardCount==800 && word(0x80127c38)==0x28880321)
   fusionCount=800;
  else if(expandedFusion->second!=LegacyCards)
   throw std::runtime_error("Bảng Fusion FM770MRG không khớp mã game");
 }
}
Bytes GameData::block(uint32_t at,size_t length)const{uint32_t p=at-bias;if(p>slus.size()||length>slus.size()-p)return {};return {slus.begin()+p,slus.begin()+p+length};}
std::string GameData::glyph(unsigned code)const{size_t at=uint32_t(0x801d9000+code*4-bias);if(at+2>slus.size())return "?";uint16_t value=uint16_t((slus[at+1]<<8)|slus[at]);auto begin=std::begin(glyphTable),end=std::end(glyphTable);auto it=std::lower_bound(begin,end,value,[](const GlyphEntry& e,uint16_t v){return e.code<v;});if(it!=end&&it->code==value)return it->text;std::string s;for(int b:{slus[at+1],slus[at]})s+=b<128?char(b):'?';return s;}
std::string GameData::name(int index,bool cardContext)const{
 const uint32_t table=cardContext && extraNameAddress && index>=759
  ? extraNameAddress+(index-759)*2 : 0x801d5800+index*2;
 const uint32_t ptr=u16(slus,table-bias), at=0x801d0000+ptr-bias;
 std::string out;
 for(size_t p=at;p<std::min(slus.size(),size_t(at)+512);){unsigned code=slus[p++];if(code==255)break;if(code==248&&p+1<slus.size()&&slus[p]==10){p+=2;continue;}if(code>=240&&code<=245){if(p>=slus.size())break;code=((code-240)<<8)|slus[p++];}else if(code>=240)break;out+=code?glyph(code):" ";}
 return clean(out,true);
}
uint32_t GameData::descriptionAddress(int card)const {
 const uint32_t table=extraDescriptionAddress && card>=759
  ? extraDescriptionAddress+(card-759)*2 : 0x801c0200+card*2;
 const uint32_t offset=u16(slus,table-bias);
 if(taggedDescriptions && offset<0x9f4) return 0x801d1000+offset;
 return offset?0x801c0000+offset:0;
}
std::string GameData::script(uint32_t address,std::vector<uint32_t> seen)const{
 if(!address||seen.size()>=8||std::find(seen.begin(),seen.end(),address)!=seen.end())return "";seen.push_back(address);uint32_t start=address-bias;if(start>=slus.size())return "";size_t end=std::min(slus.size(),std::min(size_t(start)+4096,size_t(start)+65536-(address&65535)));std::string out;
 for(size_t p=start;p<end;){unsigned code=slus[p++];if(code==255)break;if(code==250||code==254){out+='\n';continue;}if(code==252||code==253){if(p+2>end)break;unsigned offset=u16(slus,p);p+=2;out+=script((address&0xffff0000)|offset,seen);if(code==253)break;continue;}if(code==248){if(p+2>end)break;unsigned command=slus[p++],value=slus[p++];if(command==10)continue;if(command==11){out+=" \xee\x80\x80"+std::to_string(value)+"\xee\x80\x81 ";continue;}break;}if(code>=240&&code<=245){if(p==end)break;code=((code-240)<<8)|slus[p++];}else if(code>=240)break;out+=code?glyph(code):" ";}return taggedDescriptions?out:clean(out);
}
uint32_t GameData::descriptor(int card,const Bytes* ram)const {
 if(card<1 || card>cardCount) return 0;
 return ram?u32(*ram,(descriptorAddress&0x1fffff)+(card-1)*4):descriptors[card];
}
int GameData::attribute(int card,const Bytes* ram)const{if(card<0||card>cardCount)return -1;size_t at=0x1d5332+card;const auto& b=ram?*ram:slus;if(!ram)at=uint32_t(at+0x80000000-bias);return at<b.size()?b[at]>>4:-1;}
std::array<int,2> GameData::stats(int card,int terrain,int modifier,const Bytes* ram)const{
 if(card<1||card>cardCount)return {0,0};uint32_t desc=descriptor(card,ram);int a=(desc&511)*10,d=((desc>>9)&511)*10;auto custom=overrides.find(card);if(custom!=overrides.end()){a=custom->second[0];d=custom->second[1];}unsigned type=(desc>>26)&31;int bonus=0;if(type<20&&terrain>=1&&terrain<=6){size_t at=0x909d4+type*6+terrain-1;const auto& b=ram?*ram:slus;if(!ram)at=uint32_t(at+0x80000000-bias);if(at<b.size())bonus=int8_t(b[at])*10;}uint32_t ac=ram?u32(*ram,0x170f4):word(0x800170f4),dc=ram?u32(*ram,0x17120):word(0x80017120);int capA=(ac>>16)==0x2405?ac&65535:30000,capD=(dc>>16)==0x2403?dc&65535:30000;return {std::clamp(a+bonus+modifier,0,capA),std::clamp(d+bonus+modifier,0,capD)};
}
FusionMap GameData::decodeFusions(const Bytes& b,int count){
 if(b.size()!=fusionSize || (count!=LegacyCards && count!=800))
  throw std::runtime_error("Bảng Fusion thiếu dữ liệu");
 FusionMap pairs;
 for(int a=1;a<=count;a++) {
  size_t p=u16(b,a*2);
  if(!p) continue;
  if(p<size_t(2*(count+1)) || p>=b.size()) throw std::runtime_error("Con trỏ Fusion lỗi");
  unsigned n=b[p++];
  if(!n) {
   if(p>=b.size()) throw std::runtime_error("Fusion lỗi");
   n=511-b[p++];
  }
  if(p+(n/2)*5+(n%2)*3>b.size()) throw std::runtime_error("Danh sách Fusion lỗi");
  for(unsigned i=0;i<n;i++){
   size_t at=p+(i/2)*5;unsigned g=b[at],other,result;
   if(i&1){other=((g<<4)&768)|b[at+3];result=((g<<2)&768)|b[at+4];}
   else{other=((g<<8)&768)|b[at+1];result=((g<<6)&768)|b[at+2];}
   if(other<unsigned(a)||other>unsigned(count)||result<1||result>unsigned(count))
    throw std::runtime_error("ID Fusion lỗi");
   pairs.emplace(pairKey(a,other),result);
  }
 }
 return pairs;
}
const FusionMap& GameData::fusions(int terrain){
 terrain=std::clamp(terrain,0,6);
 if(!fusionReady[terrain]){
  fusionMaps[terrain]=decodeFusions(read(wa,fusionSize,fusionOffset+terrain*terrainStride),fusionCount);
  fusionReady[terrain]=true;
 }
 return fusionMaps[terrain];
}
const EquipMap& GameData::equips(int terrain) {
 terrain=std::clamp(terrain,0,6);
 if(equipReady[terrain]) return equipMaps[terrain];
 const Bytes bytes=read(wa,equipSize,fusionOffset-equipSize+terrain*terrainStride);
 EquipMap entries;
 for(size_t at=0;at+2<=bytes.size();) {
  const int equip=u16(bytes,at);
  at+=2;
  if(!equip) {
   equipMaps[terrain]=std::move(entries);
   equipReady[terrain]=true;
   return equipMaps[terrain];
  }
  if(equip>cardCount || at+2>bytes.size()) break;
  const unsigned count=u16(bytes,at);
  at+=2;
  if(!count || count>(bytes.size()-at)/2) break;
  std::vector<int> targets;
  targets.reserve(count);
  for(unsigned i=0;i<count;++i) {
   const int card=u16(bytes,at+i*2);
   if(card<1 || card>cardCount) throw std::runtime_error("ID trong bảng Equip không hợp lệ");
   targets.push_back(card);
  }
  at+=count*2;
  std::sort(targets.begin(),targets.end());
  targets.erase(std::unique(targets.begin(),targets.end()),targets.end());
  entries.emplace(equip,std::move(targets));
 }
 throw std::runtime_error("Bảng Equip không hợp lệ");
}
const std::vector<Ritual>& GameData::rituals(int terrain) {
 terrain=std::clamp(terrain,0,6);
 if(ritualReady[terrain]) return ritualTables[terrain];
 const Bytes bytes=read(wa,2048,fusionOffset+fusionSize+terrain*terrainStride);
 std::vector<Ritual> entries;
 for(size_t at=0;at+2<=bytes.size();at+=10) {
  if(!u16(bytes,at)) {
   ritualTables[terrain]=std::move(entries);
   ritualReady[terrain]=true;
   return ritualTables[terrain];
  }
  if(at+10>bytes.size()) break;
  Ritual row;
  for(size_t i=0;i<row.size();++i) {
   row[i]=u16(bytes,at+i*2);
   if(row[i]<1 || row[i]>cardCount) throw std::runtime_error("ID trong bảng Ritual không hợp lệ");
  }
  entries.push_back(row);
 }
 throw std::runtime_error("Bảng Ritual không hợp lệ");
}
uint32_t GameData::colour(unsigned v,bool opaque){return ((opaque||v)?0xff000000:0)|(((v&31)*255/31)<<16)|((((v>>5)&31)*255/31)<<8)|((v>>10)&31)*255/31;}
std::vector<uint32_t> GameData::art(int card){
 if(card<1 || card>cardCount || (card>LegacyCards && !extraArtOffset)) return {};
 auto cached=artCache.find(card);
 if(cached!=artCache.end()) return cached->second;
 const uint64_t offset=card<=LegacyCards ? LegacyCards*2048ULL+(card-1)*cardArtStride
  : extraArtOffset+(card-LegacyCards-1)*cardArtStride;
 auto b=read(wa,102*96+512,offset);
 std::vector<uint32_t> pixels(102*96);
 for(size_t i=0;i<pixels.size();i++) pixels[i]=colour(u16(b,pixels.size()+b[i]*2),true);
 if(artCache.size()>=48) artCache.erase(artCache.begin());
 artCache[card]=pixels;
 return pixels;
}
std::vector<uint32_t> GameData::npcPhoto(int npc)const{const auto& b=photos[std::clamp(npc,0,39)];std::vector<uint32_t> p(48*48);for(size_t i=0;i<p.size();i++)p[i]=colour(u16(b,2304+b[i]*2),true);return p;}
unsigned GameData::bootWord(const Bytes& b,int x,int y)const{int at;if(x>=512&&x<768&&y>=248&&y<256)at=48*2048+((y-248)*256+x-512)*2;else if(x>=640&&x<832&&y>=0&&y<256)at=((x-640)/64*16+y/16)*2048+((y%16)*64+(x-640)%64)*2;else return 0;return u16(b,at);}
void GameData::decodeIcons(const Bytes& b){for(int icon=0;icon<41;icon++){int u,v,cx,cy;if(icon>=34){u=(icon*16-528)&255;v=128;cx=u==80?528:512;cy=252;}else{u=((icon&7)*16-128)&255;v=(icon&56)*2;int index=std::min(icon,24);cx=512+(index&15)*16;cy=249+(index>>4);}auto& pixels=icons[icon];pixels.resize(256);for(int y=0;y<16;y++)for(int x=0;x<16;x++){int px=u+x;unsigned packed=bootWord(b,704+px/4,v+y),entry=(packed>>((px&3)*4))&15;pixels[y*16+x]=colour(bootWord(b,cx+entry,cy),false);}}}
}
