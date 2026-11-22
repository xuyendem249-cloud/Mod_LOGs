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
 ControllerGeometry g(w,h,guide);auto game=g.game;assert(inside(game,w,h));
 auto contains=[&](const Box& outer,const Box& b){return b.x>=outer.x-.001&&b.y>=outer.y-.001&&b.right()<=outer.right()+.001&&b.bottom()<=outer.bottom()+.001;};
 assert(contains(g.bezel,game)&&contains(game,g.menu()));
 assert(inside(g.logo(),w,h)&&inside(g.mode(),w,h));
 assert(!overlaps(g.logo(),g.mode()));
 for(int i=0;i<4;i++){
  auto button=g.quickAction(i);
  assert(contains(game,button)&&!overlaps(button,g.menu()));
  for(int j=0;j<i;j++)assert(!overlaps(button,g.quickAction(j)));
 }
 assert(std::abs(g.quickAction(0).x-game.x-4)<.001);
 assert(std::abs(game.right()-g.quickAction(3).right()-4)<.001);
 auto l1=g.leftShoulder(false),l2=g.leftShoulder(true);
 auto mode=g.mode(),select=g.selectStart(false),start=g.selectStart(true);
 if(g.portrait){
  assert(std::abs(game.x-4)<.001&&std::abs(w-game.right()-4)<.001);
  assert(mode.right()<=select.x&&select.right()<=start.x&&start.right()<=g.logo().x);
  assert(mode.y==select.y&&select.y==start.y);
  assert(l1.right()<=l2.x);
 }
 else{
  assert(std::abs(h-game.h-8)<.001);
  assert(g.mode().y<g.selectStart(true).y);
  assert(l2.right()<=l1.x);
 }
 for(bool rhs:{false,true}){
  auto pad=g.pad(rhs),select=g.selectStart(rhs);
  assert(inside(pad,w,h)&&inside(select,w,h));assert(!overlaps(pad,select));
  assert(!overlaps(pad,g.logo())&&!overlaps(pad,g.mode()));
  for(bool second:{false,true}){
   auto shoulder=g.shoulder(rhs,second);assert(inside(shoulder,w,h));
   assert(!overlaps(shoulder,pad)&&!overlaps(shoulder,select)&&!overlaps(shoulder,game));
  }
 }
 if(!g.portrait){ControllerGeometry other(w,h,!guide);for(bool rhs:{false,true}){assert(g.pad(rhs).x==other.pad(rhs).x&&g.pad(rhs).y==other.pad(rhs).y&&g.pad(rhs).w==other.pad(rhs).w);}}
 cases++;
}}}
std::cout<<"PASS geometry "<<cases<<" sizes/modes: Android game fill, overlay controls and stable landscape pads\n";
}
