#include "BundledDiscVfs.hpp"
#include <algorithm>
#include <cstring>
#include <fstream>
#include <filesystem>
#include <limits>

struct retro_vfs_file_handle {
 std::string path;
 std::ifstream ordinary;
 std::shared_ptr<Legend::DiscStream> disc;
 int64_t length=0,position=0;
 bool cue=false;
};

namespace Legend::DiscVfs {
namespace {
constexpr char binPath[]="legend://mod2/disc.bin";
constexpr char cueText[]="FILE \"disc.bin\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n";
std::shared_ptr<DiscStream> bundled;

bool isVirtual(const char* path){return !std::strcmp(path,cuePath)||!std::strcmp(path,binPath);}
retro_vfs_file_handle* open(const char* path,unsigned mode,unsigned){
 if(!path||mode!=RETRO_VFS_FILE_ACCESS_READ)return nullptr;
 auto handle=std::make_unique<retro_vfs_file_handle>();
 handle->path=path;
 try{
  if(isVirtual(path)){
   if(!bundled)return nullptr;
   handle->cue=!std::strcmp(path,cuePath);
   handle->disc=bundled;
   handle->length=handle->cue?sizeof(cueText)-1:bundled->size();
  }else{
   std::error_code error;
   auto size=std::filesystem::file_size(path,error);
   if(error||size>std::numeric_limits<int64_t>::max())return nullptr;
   handle->ordinary.open(path,std::ios::binary);
   if(!handle->ordinary)return nullptr;
   handle->length=int64_t(size);
  }
 }catch(...){return nullptr;}
 return handle.release();
}
const char* path(retro_vfs_file_handle* file){return file->path.c_str();}
int close(retro_vfs_file_handle* file){delete file;return 0;}
int64_t size(retro_vfs_file_handle* file){return file->length;}
int64_t tell(retro_vfs_file_handle* file){return file->position;}
int64_t seek(retro_vfs_file_handle* file,int64_t offset,int origin){
 int64_t from=0;
 switch(origin){
  case RETRO_VFS_SEEK_POSITION_START:break;
  case RETRO_VFS_SEEK_POSITION_CURRENT:from=file->position;break;
  case RETRO_VFS_SEEK_POSITION_END:from=file->length;break;
  default:return -1;
 }
 if(offset<-from||offset>std::numeric_limits<int64_t>::max()-from)return -1;
 auto position=from+offset;
 if(!file->disc){
  file->ordinary.clear();
  file->ordinary.seekg(position);
  if(!file->ordinary)return -1;
 }
 file->position=position;
 return 0; // The SwanStation CD interface expects zero from a successful seek.
}
int64_t read(retro_vfs_file_handle* file,void* data,uint64_t length){
 try{
  size_t amount=std::min<uint64_t>(length,std::max<int64_t>(0,file->length-file->position));
  if(!amount)return 0;
  if(file->cue)std::memcpy(data,cueText+file->position,amount);
  else if(file->disc)file->disc->readAt(file->position,static_cast<uint8_t*>(data),amount);
  else{
   file->ordinary.read(static_cast<char*>(data),amount);
   if(file->ordinary.bad())return -1;
   amount=file->ordinary.gcount();
  }
  file->position+=amount;
  return amount;
 }catch(...){return -1;}
}
int stat64(const char* path,int64_t* length){
 if(!path)return 0;
 if(isVirtual(path)){
  if(!bundled)return 0;
  if(length)*length=!std::strcmp(path,cuePath)?sizeof(cueText)-1:bundled->size();
  return RETRO_VFS_STAT_IS_VALID;
 }
 std::error_code error;
 auto effect=std::filesystem::status(path,error);
 if(error||!std::filesystem::exists(effect))return 0;
 if(std::filesystem::is_directory(effect)){
  if(length)*length=0;
  return RETRO_VFS_STAT_IS_VALID|RETRO_VFS_STAT_IS_DIRECTORY;
 }
 auto amount=std::filesystem::file_size(path,error);
 if(error||amount>std::numeric_limits<int64_t>::max())return 0;
 if(length)*length=int64_t(amount);
 return RETRO_VFS_STAT_IS_VALID;
}
int stat(const char* path,int32_t* length){
 int64_t amount=0;
 int result=stat64(path,&amount);
 if(length)*length=static_cast<int32_t>(std::min<int64_t>(amount,INT32_MAX));
 return result;
}
retro_vfs_interface frontend=[]{
 retro_vfs_interface table{};
 table.get_path=path;
 table.open=open;
 table.close=close;
 table.size=size;
 table.tell=tell;
 table.seek=seek;
 table.read=read;
 table.stat=stat;
 table.stat_64=stat64;
 return table;
}();
}

void setDisc(std::shared_ptr<DiscStream> disc){bundled=std::move(disc);}
bool configure(retro_vfs_interface_info* info){
 if(!bundled||!info||info->required_interface_version>4)return false;
 info->iface=&frontend;
 return true;
}
}
