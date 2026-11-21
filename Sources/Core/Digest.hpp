#pragma once
#include <cstddef>
#include <cstdint>
#include <initializer_list>
#include <string>
#include <vector>

namespace Legend {
struct ByteRange {
 size_t offset, length;
};
std::string sha256(const std::vector<uint8_t>& bytes, std::initializer_list<ByteRange> ranges);
}
