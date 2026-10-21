#include "AudioRing.hpp"
#include <stdexcept>
#include <iostream>
#include <vector>
int main(){
 Legend::AudioRing ring;float l[4],r[4];ring.render(l,r,4);for(int i=0;i<4;i++)if(l[i]||r[i])throw std::runtime_error("silence");
 int16_t samples[]={32767,-32768,16384,-16384};if(ring.push(samples,2)!=2)throw std::runtime_error("push");ring.render(l,r,4);
 if(l[0]<=.99f||r[0]!=-1||l[1]!=.5f||r[1]!=-.5f||l[2]||r[3])throw std::runtime_error("channel conversion/underflow");
 ring.push(samples,2);ring.clear();ring.render(l,r,4);if(l[0]||r[0])throw std::runtime_error("clear");
 std::vector<int16_t> large(40000,100);if(ring.push(large.data(),20000)!=16384)throw std::runtime_error("capacity");
 for(int i=0;i<4096;i++)ring.render(l,r,4);if(ring.push(samples,2)!=2)throw std::runtime_error("wrap");ring.render(l,r,4);if(r[0]!=-1)throw std::runtime_error("wrap samples");
 std::cout<<"PASS: audio channels, silence, overflow, wrap, pause discard\n";
}
