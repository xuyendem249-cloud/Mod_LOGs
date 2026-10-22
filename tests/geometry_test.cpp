#include "ControllerGeometry.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace Legend;
static bool inside(const Box& b,double w,double h){return b.x>=0&&b.y>=0&&b.w>0&&b.h>0&&b.right()<=w+.001&&b.bottom()<=h+.001;}
static bool overlaps(const Box& a,const Box& b){return a.x<b.right()-.001&&a.right()>b.x+.001&&a.y<b.bottom()-.001&&a.bottom()>b.y+.001;}
int main(){int cases=0;
for(double w:{320.,360.,390.,430.,600.,768.,844.,1024.,1194.}){
for(double h:{300.,340.,390.,600.,720.,780.,1000.}){
for(bool guide:{false,true}){
 ControllerGeometry g(w,h,guide);auto game=g.fittedGame();assert(inside(game,w,h));assert(std::abs(game.w/game.h-4./3)<.0001);assert(!overlaps(game,g.toolbar));
 assert(inside(g.logo(),w,h));assert(g.logo().y>=g.toolbar.y&&g.logo().bottom()<=g.toolbar.bottom()+.001);
 if(g.portrait){assert(inside(g.speed(),w,h));for(bool rhs:{false,true}){assert(!overlaps(g.speed(),g.pad(rhs)));assert(!overlaps(g.speed(),g.selectStart(rhs)));}}
 if(!g.portrait&&!guide&&w-192>=(h-36)*4/3){assert(std::abs(game.y)<.001);assert(std::abs(game.bottom()-g.toolbar.y)<.001);}
 for(bool rhs:{false,true}){auto pad=g.pad(rhs),select=g.selectStart(rhs);assert(inside(pad,w,h)&&inside(select,w,h));assert(!overlaps(pad,select)&&!overlaps(pad,game));for(bool second:{false,true}){auto s=g.shoulder(rhs,second);assert(inside(s,w,h));assert(!overlaps(s,pad)&&!overlaps(s,select)&&!overlaps(s,game));}}
 if(w>h){ControllerGeometry other(w,h,!guide);for(bool rhs:{false,true}){assert(g.pad(rhs).x==other.pad(rhs).x&&g.pad(rhs).y==other.pad(rhs).y&&g.pad(rhs).w==other.pad(rhs).w);}}
 cases++;
}}}
std::cout<<"PASS geometry "<<cases<<" sizes/modes: safe controls, 4:3, no overlap, landscape controls stable\n";
}
