#include "libretro.h"
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <map>
#include <string>

namespace {
std::string systemPath,savePath,contentPath;
std::map<std::string,std::string> options={
 {"swanstation_GPU_Renderer","Software"},{"swanstation_GPU_UseThread","false"},
 {"swanstation_CPU_ExecutionMode","Interpreter"},{"swanstation_GPU_ResolutionScale","1"},
 {"swanstation_GPU_TrueColor","false"},{"swanstation_GPU_TextureFilter","Nearest"},
 {"swanstation_GPU_PGXPEnable","false"},{"swanstation_GPU_WidescreenHack","false"},
 {"swanstation_MemoryCards_Card1Type","Libretro"},{"swanstation_MemoryCards_Card2Type","None"}};
void logMessage(retro_log_level,const char* format,...){va_list args;va_start(args,format);vfprintf(stderr,format,args);va_end(args);}
bool environment(unsigned cmd,void* data){switch(cmd&0xffff){
 case RETRO_ENVIRONMENT_GET_CAN_DUPE:*static_cast<bool*>(data)=true;return true;
 case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:return *static_cast<unsigned*>(data)<=2;
 case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:*static_cast<const char**>(data)=systemPath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:*static_cast<const char**>(data)=savePath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY:*static_cast<const char**>(data)=contentPath.c_str();return true;
 case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:*static_cast<unsigned*>(data)=0;return true;
 case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:static_cast<retro_log_callback*>(data)->log=logMessage;return true;
 case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:*static_cast<bool*>(data)=false;return true;
 case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS&0xffff:return true;
 case RETRO_ENVIRONMENT_GET_VARIABLE:{auto* variable=static_cast<retro_variable*>(data);auto i=options.find(variable->key);variable->value=i==options.end()?nullptr:i->second.c_str();return variable->value!=nullptr;}
 case RETRO_ENVIRONMENT_SET_VARIABLES:{for(auto* variable=static_cast<retro_variable*>(data);variable&&variable->key;variable++){if(options.count(variable->key)||!variable->value)continue;std::string values=variable->value;size_t start=values.find(';');if(start==std::string::npos)continue;start=values.find_first_not_of(' ',start+1);if(start!=std::string::npos)options[variable->key]=values.substr(start,values.find('|',start)-start);}return true;}
 case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:return true;
 default:return false;
}}
void video(const void*,unsigned,unsigned,size_t){} void audio(int16_t,int16_t){} size_t batch(const int16_t*,size_t frames){return frames;}void poll(){}int16_t input(unsigned,unsigned,unsigned,unsigned){return 0;}
}
int main(int argc,char** argv){
 if(argc!=2){std::cerr<<"Usage: core_probe temporary-directory\n";return 2;}
 auto root=std::filesystem::path(argv[1]);systemPath=(root/"system").string();savePath=(root/"saves").string();contentPath=(root/"content").string();for(auto& path:{systemPath,savePath,contentPath})std::filesystem::create_directories(path);
 retro_system_info info{};retro_get_system_info(&info);if(!info.library_name||!info.library_version||std::strcmp(info.library_name,"SwanStation")){std::cerr<<"Unexpected core identity\n";return 3;}
 if(retro_api_version()!=RETRO_API_VERSION){std::cerr<<"Libretro ABI mismatch\n";return 4;}
 retro_set_environment(environment);retro_set_video_refresh(video);retro_set_audio_sample(audio);retro_set_audio_sample_batch(batch);retro_set_input_poll(poll);retro_set_input_state(input);retro_init();retro_deinit();
 std::cout<<"PASS: "<<info.library_name<<" "<<info.library_version<<" libretro API/init/deinit (no game or BIOS loaded)\n";
}
