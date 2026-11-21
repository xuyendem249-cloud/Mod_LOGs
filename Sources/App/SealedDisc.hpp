#pragma once
#include "DiscStream.hpp"
#include <memory>

namespace Legend {
std::shared_ptr<DiscStream> openSealedDisc(const std::string& path,const uint8_t* key,size_t length);
}
