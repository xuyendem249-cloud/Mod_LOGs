#include "PlayerCore.hpp"
#include "CompatibilityTables.hpp"
#include <cstdarg>
#include <cstdio>
#include <filesystem>
#include <cmath>

namespace Legend {
PlayerCore* PlayerCore::active=nullptr;
namespace {void logCore(retro_log_level,const char* format,...){va_list args;va_start(args,format);vfprintf(stderr,format,args);va_end(args);}}
PlayerCore::PlayerCore():options{
 {"swanstation_GPU_Renderer","Software"},{"swanstation_GPU_UseThread","false"},
 {"swanstation_CPU_ExecutionMode","Interpreter"},{"swanstation_Console_Region","Auto"},
 {"swanstation_BIOS_PathNTSCU","scph1001.bin"},{"swanstation_BIOS_PathNTSCJ","scph1001.bin"},
 {"swanstation_BIOS_PathPAL","scph1001.bin"},{"swanstation_BIOS_PatchFastBoot","false"},
 {"swanstation_MemoryCards_Card1Type","Libretro"},{"swanstation_MemoryCards_Card2Type","None"},
 {"swanstation_GPU_ResolutionScale","1"},{"swanstation_GPU_TrueColor","false"},
 {"swanstation_GPU_TextureFilter","Nearest"},{"swanstation_GPU_PGXPEnable","false"},
 {"swanstation_GPU_WidescreenHack","false"}}{compatibility=defaultCompatibility();}
PlayerCore::~PlayerCore(){close();}
bool PlayerCore::environment(unsigned cmd,void* data){if(!active)return false;auto& p=*active;switch(cmd&0xffff){
 case RETRO_ENVIRONMENT_GET_CAN_DUPE:*static_cast<bool*>(data)=true;return true;
 case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:{unsigned v=*static_cast<unsigned*>(data);if(v>2)return false;p.format=static_cast<PixelFormat>(v);return true;}
 case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:*static_cast<const char**>(data)=p.systemPath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:*static_cast<const char**>(data)=p.savePath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY:*static_cast<const char**>(data)=p.contentPath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:static_cast<retro_log_callback*>(data)->log=logCore;return true;
 case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:*static_cast<unsigned*>(data)=0;return true;
 case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:*static_cast<bool*>(data)=false;return true;
 case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS&0xffff:return true;
 case RETRO_ENVIRONMENT_GET_VARIABLE:{auto* v=static_cast<retro_variable*>(data);auto it=p.options.find(v->key);v->value=it==p.options.end()?nullptr:it->second.c_str();return v->value!=nullptr;}
 case RETRO_ENVIRONMENT_SET_VARIABLES:{for(auto* v=static_cast<retro_variable*>(data);v&&v->key;v++){if(p.options.count(v->key)||!v->value)continue;std::string s=v->value;auto start=s.find(';');if(start==std::string::npos)continue;start=s.find_first_not_of(' ',start+1);if(start!=std::string::npos)p.options[v->key]=s.substr(start,s.find('|',start)-start);}return true;}
 case RETRO_ENVIRONMENT_SET_MESSAGE:{auto* m=static_cast<retro_message*>(data);p.lastMessage=m->msg?m->msg:"";return true;}
 case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:case RETRO_ENVIRONMENT_SET_GEOMETRY:return true;
 default:return false;
}}
void PlayerCore::video(const void* data,unsigned w,unsigned h,size_t pitch){if(active&&active->frame.update(data,w,h,pitch,active->format))active->changed=true;}
void PlayerCore::sample(int16_t l,int16_t r){int16_t pair[]={l,r};batch(pair,1);}
size_t PlayerCore::batch(const int16_t* data,size_t count){if(active&&data){auto& p=*active;if(p.speed==1)p.audio.push(data,count);else for(size_t i=0;i<count;i++){p.audioPosition+=1;if(p.audioPosition>=p.speed){p.audioPosition-=p.speed;p.audio.push(data+i*2,1);}}}return count;}
void PlayerCore::poll(){}
int16_t PlayerCore::inputState(unsigned port,unsigned device,unsigned index,unsigned id){
 if(!active||port||index||(device&255)!=RETRO_DEVICE_JOYPAD)return 0;
 auto automatic=active->autoInput.load();uint16_t mask=(automatic&0x10000)?uint16_t(automatic):active->input.mask();return id==RETRO_DEVICE_ID_JOYPAD_MASK?static_cast<int16_t>(mask):id<16?static_cast<int16_t>((mask>>id)&1):0;
}
bool PlayerCore::open(const std::string& path,const std::string& root,std::string& error){
 close();if(active&&active!=this){error="Core đang được sử dụng.";return false;}
 systemPath=(std::filesystem::path(root)/"system").string();savePath=(std::filesystem::path(root)/"saves").string();contentPath=std::filesystem::path(path).parent_path().string();gamePath=path;
 active=this;lastMessage.clear();format=PixelFormat::RGB1555;
 compatibility.identify(std::filesystem::path(path).stem().string());audioPosition=0;
 retro_set_environment(environment);retro_set_video_refresh(video);retro_set_audio_sample(sample);retro_set_audio_sample_batch(batch);retro_set_input_poll(poll);retro_set_input_state(inputState);retro_init();initialized=true;
 retro_game_info game{gamePath.c_str(),nullptr,0,nullptr};loaded=retro_load_game(&game);
 if(!loaded){error=lastMessage.empty()?"Không mở được game. Kiểm tra BIOS và file ISO.":lastMessage;close();return false;}
 retro_set_controller_port_device(0,RETRO_DEVICE_JOYPAD);retro_system_av_info av{};retro_get_system_av_info(&av);
 fps=std::isfinite(av.timing.fps)&&av.timing.fps>=20&&av.timing.fps<=120?av.timing.fps:59.94;
 sampleRate=std::isfinite(av.timing.sample_rate)&&av.timing.sample_rate>=8000&&av.timing.sample_rate<=192000?av.timing.sample_rate:44100;
 return true;
}
bool PlayerCore::run(){if(!loaded)return false;changed=false;compatibility.apply(static_cast<uint8_t*>(retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM)),retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM));retro_run();input.advance();return changed;}
void PlayerCore::close(){autoInput.store(0);input.clear();audio.clear();if(loaded){retro_unload_game();loaded=false;}if(initialized){retro_deinit();initialized=false;}if(active==this)active=nullptr;frame=Frame{};}
std::vector<uint8_t> PlayerCore::saveState(){if(!loaded)return {};size_t n=retro_serialize_size();if(!n||n>64*1024*1024)return {};std::vector<uint8_t> v(n);if(!retro_serialize(v.data(),v.size()))v.clear();return v;}
bool PlayerCore::loadState(const std::vector<uint8_t>& v){if(!loaded||v.empty()||v.size()>64*1024*1024)return false;input.clear();audio.clear();return retro_unserialize(v.data(),v.size());}
std::vector<uint8_t> PlayerCore::memoryCard(){if(!loaded)return {};auto* p=static_cast<uint8_t*>(retro_get_memory_data(RETRO_MEMORY_SAVE_RAM));size_t n=retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);if(!p||n!=131072)return {};return {p,p+n};}
bool PlayerCore::setMemoryCard(const std::vector<uint8_t>& v){if(!loaded||v.size()!=131072||retro_get_memory_size(RETRO_MEMORY_SAVE_RAM)!=v.size())return false;void* p=retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);if(!p)return false;memcpy(p,v.data(),v.size());return true;}
std::vector<uint8_t> PlayerCore::ramSnapshot(){if(!loaded)return {};auto* p=static_cast<uint8_t*>(retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM));size_t n=retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM);if(!p||n!=0x200000)return {};return {p,p+n};}
void PlayerCore::reset(){if(loaded){input.clear();audio.clear();retro_reset();}}
std::string PlayerCore::coreVersion()const{retro_system_info info{};retro_get_system_info(&info);return std::string(info.library_name?info.library_name:"")+":"+(info.library_version?info.library_version:"");}
}
