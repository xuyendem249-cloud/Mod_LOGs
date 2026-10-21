#include "CompatibilityTables.hpp"
#include <cassert>
#include <iostream>
using namespace Legend;
int main(){
 auto c=defaultCompatibility();std::vector<uint8_t> ram(0x200000);auto p=c.simple.front();memcpy(ram.data()+p.at,p.before.data(),p.before.size());auto original=ram;
 c.identify("unknown");c.apply(ram.data(),ram.size());assert(ram==original);
 c.identify(*c.known.begin());c.apply(ram.data(),ram.size());assert(!memcmp(ram.data()+p.at,p.after.data(),p.after.size()));
 ram=original;ram[p.at]^=1;auto bad=ram;c.apply(ram.data(),ram.size());assert(ram==bad);
 for(const auto& group:c.groups){ram.assign(0x200000,0);for(const auto& patch:group.patches)memcpy(ram.data()+patch.at,patch.before.data(),patch.before.size());auto before=ram;
  c.apply(ram.data(),ram.size());for(const auto& patch:group.patches)assert(!memcmp(ram.data()+patch.at,patch.after.data(),patch.after.size()));for(const auto& code:group.caves)assert(!memcmp(ram.data()+code.at,code.bytes.data(),code.bytes.size()));auto after=ram;c.apply(ram.data(),ram.size());assert(ram==after);
  ram=before;ram[group.caves.front().at]=0xff;bad=ram;c.apply(ram.data(),ram.size());assert(ram==bad&&c.conflict);
  ram=before;ram[group.patches.back().at]^=1;bad=ram;c.apply(ram.data(),ram.size());assert(ram==bad);
  ram=after;for(const auto& code:group.caves)memset(ram.data()+code.at,0,code.bytes.size());c.apply(ram.data(),ram.size());assert(ram==after);
 }
 std::cout<<"PASS unknown ISO unchanged; signature guards; grouped hooks atomic; occupied caves rejected; repeat safe\n";
}
