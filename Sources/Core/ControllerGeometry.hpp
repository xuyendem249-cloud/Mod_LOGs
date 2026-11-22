#pragma once
#include <algorithm>
namespace Legend {
struct Box{
 double x=0,y=0,w=0,h=0;
 double right()const{return x+w;}
 double bottom()const{return y+h;}
};
struct ControllerGeometry{
 bool portrait;
 Box bezel,game,guide,toolbar,left,right;
 double width;
 ControllerGeometry(double w,double h,bool fusion):portrait(h>w),width(w){
  double top=std::min(3.,h*.027);
  if(portrait){
   double screenW=w-6;
   double gameH=std::min((screenW-2)*.75,h*(fusion?.35:.45))+std::min(94.,h*.19);
   bezel={3,top,screenW,gameH+2};
   game={4,top+1,screenW-2,gameH};
   double margin=w<350?8:12;
   guide={margin,bezel.bottom()+4,w-margin*2,fusion?std::min(100.,h*.13):0};
   double y=(fusion?guide.bottom():bezel.bottom())+6;
   left={0,y,w/2,h-y};
   right={w/2,y,w/2,h-y};
  }else{
   double rail=std::min(230.,w*.235);
   double x=rail-3;
   bezel={x,top,w-x*2,h-top*2};
   double inner=bezel.w-2;
   double guideW=fusion?std::min(190.,inner*.36):0;
   game={bezel.x+1,top+1,inner-guideW,bezel.h-2};
   guide={game.right(),game.y,guideW,game.h};
   double railTop=std::min(7.,h*.027);
   left={0,railTop,rail,h-railTop*2};
   right={w-rail,railTop,rail,h-railTop*2};
  }
  toolbar={game.x+4,game.bottom()-44,game.w-8,40};
 }
 Box menu()const{return {game.right()-46,game.y+4,42,42};}
 Box quickAction(int index)const{
  double w=std::min(44.,toolbar.w/4);
  double x=index<2?toolbar.x+w*index:toolbar.right()-w*(4-index);
  return {x,toolbar.y,w,toolbar.h};
 }
 Box shoulder(bool rhs,bool second)const{
  auto area=rhs?right:left;
  double margin=std::min(15.,area.w*.1),w=(area.w-margin*2-5)/2;
  return {area.x+margin+(second?w+5:0),area.y+8,w,std::min(46.,area.h*(portrait?.17:.15))};
 }
 Box selectStart(bool start)const{
  if(portrait)return footer(start?2:1);
  auto area=start?right:left;
  double w=std::min(108.,area.w*.58),h=std::min(42.,area.h*.15);
  return {area.x+(area.w-w)/2,area.bottom()-h-14,w,h};
 }
 Box leftShoulder(bool trigger)const{return shoulder(false,trigger==portrait);}
 Box pad(bool rhs)const{
  auto area=rhs?right:left;
  double top=shoulder(rhs,false).bottom()+(portrait?10:56);
  double bottom=selectStart(false).y-12;
  double size=std::min(area.w-12,std::max(0.,bottom-top));
  return {area.x+(area.w-size)/2,top+(bottom-top-size)/2,size,size};
 }
 Box logo()const{
  double size=std::min(46.,std::min(left.h*.19,left.w*.37));
  if(!portrait)return {left.right()-size-9,shoulder(false,false).bottom()+5,size,size};
  auto area=footer(3);
  return {area.x+(area.w-size)/2,area.y+(area.h-size)/2,size,size};
 }
 Box mode()const{
  if(portrait)return footer(0);
  auto select=selectStart(false);
  return {width-select.right(),shoulder(true,false).bottom()+5,select.w,select.h};
 }
private:
 Box footer(int index)const{
  double step=(width-24)/4,w=std::min(94.,step-8),h=std::min(42.,left.h*.15);
  return {12+step*index+(step-w)/2,left.bottom()-h-14,w,h};
 }
};
}
