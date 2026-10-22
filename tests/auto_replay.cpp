#include "AutoPlayer.hpp"
#include "CompatibilityTables.hpp"
#include <iostream>
#include <memory>
#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#endif
static uint64_t read64(){uint64_t n=0;for(int i=0;i<8;i++){int c=std::cin.get();if(c<0)throw std::runtime_error("EOF");n=(n<<8)|unsigned(c);}return n;}
static void writeN(uint64_t n,int count){for(int i=count-1;i>=0;i--)std::cout.put(char(n>>(i*8)));}
int main(int argc,char** argv){
 if(argc!=2)return 2;
#ifdef _WIN32
 _setmode(_fileno(stdin),_O_BINARY);_setmode(_fileno(stdout),_O_BINARY);
#endif
 Legend::GameData data(argv[1]);Legend::FusionAdvisor advisor(data,Legend::defaultCompatibility().handSignatures);auto player=std::make_unique<Legend::AutoPlayer>(data,advisor);
 while(std::cin.peek()!=EOF){uint64_t frame=read64();if(frame==UINT64_MAX){player=std::make_unique<Legend::AutoPlayer>(data,advisor);continue;}bool present=std::cin.get()!=0;Legend::Bytes ram;if(present){ram.resize(0x200000);std::cin.read(reinterpret_cast<char*>(ram.data()),ram.size());if(!std::cin)return 3;}int mask=player->next(present?&ram:nullptr,frame);auto text=player->status+" | "+player->lastAction;writeN(mask,4);writeN(player->stopped,1);writeN(player->nextDecision,8);writeN(player->releaseAt,8);writeN(text.size(),4);std::cout.write(text.data(),text.size());std::cout.flush();}
}
