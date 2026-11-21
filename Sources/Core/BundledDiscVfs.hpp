#pragma once
#include "DiscStream.hpp"
#include "libretro.h"
#include <memory>

namespace Legend::DiscVfs {
inline constexpr char cuePath[]="legend://mod2/disc.cue";
void setDisc(std::shared_ptr<DiscStream> disc);
bool configure(retro_vfs_interface_info* info);
}
