#pragma once
#include <cstddef>
#include <cstdint>
#include <string>

namespace Legend {
class DiscStream {
public:
 virtual ~DiscStream()=default;
 virtual uint64_t size()const=0;
 virtual std::string identity()const=0;
 virtual void readAt(uint64_t offset,uint8_t* data,size_t length)=0;
};
}
