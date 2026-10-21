#include "CompatibilityTables.hpp"
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
extern "C" EXPORT int legend_apply(uint8_t* ram,size_t size,const char* hash){auto c=Legend::defaultCompatibility();c.identify(hash?hash:"");c.apply(ram,size);return c.conflict?1:0;}
