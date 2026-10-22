#pragma once
#include <algorithm>
namespace Legend {
struct Box{double x=0,y=0,w=0,h=0;double right()const{return x+w;}double bottom()const{return y+h;}};
struct ControllerGeometry{
 bool portrait;Box game,guide,toolbar,left,right;double width,height;
 ControllerGeometry(double w,double h,bool fusion):portrait(h>w),width(w),height(h){
  if(portrait){double gameH=std::min(w*.75,h*.40),guideH=fusion?std::min(110.,h*.14):0;game={0,0,w,gameH};toolbar={0,gameH,w,38};guide={0,toolbar.bottom(),w,guideH};double top=guide.bottom();left={0,top,w/2,h-top};right={w/2,top,w-w/2,h-top};}
  else{double preferred=std::min(std::min(220.,std::max(96.,w*.21)),w*.24),fullWidth=std::max(0.,h-36)*4/3;
   double rail=std::min(preferred,std::max(std::min(96.,w*.24),(w-fullWidth)/2)),center=w-rail*2,guideW=fusion?std::min(200.,center*.39):0;
   game={rail,0,center-guideW,h-36};guide={game.right(),0,guideW,h-36};toolbar={rail,h-36,center,36};left={0,0,rail,h};right={w-rail,0,rail,h};}
 }
 Box fittedGame()const{double h=std::min(game.h,game.w*.75),w=h*4/3;return {game.x+(game.w-w)/2,game.y+(game.h-h)/2,w,h};}
 double shoulderHeight()const{return std::min(42.,left.h*.16);}
 double selectHeight()const{return std::min(46.,left.h*.18);}
 Box shoulder(bool rhs,bool second)const{auto a=rhs?right:left;double w=(a.w-17)/2;return {a.x+6+(second?w+5:0),a.y+8,w,shoulderHeight()};}
 Box selectStart(bool rhs)const{auto a=rhs?right:left;double h=selectHeight(),w=std::min(a.w-24,92.);return {a.x+(a.w-w)/2,a.bottom()-h-12,w,h};}
 Box pad(bool rhs)const{auto a=rhs?right:left;double top=a.y+shoulderHeight()+18,bottom=selectStart(rhs).y-12-(portrait?40:0),s=std::min(a.w-12,std::max(12.,bottom-top));return {a.x+(a.w-s)/2,top+std::max(0.,bottom-top-s)*.5,s,s};}
 Box logo()const{double unit=std::min(1.,toolbar.w/270),available=std::max(0.,toolbar.w-216*unit),s=std::min(toolbar.h-4,available);return {toolbar.x+110*unit+(available-s)/2,toolbar.y+(toolbar.h-s)/2,s,s};}
 Box speed()const{if(!portrait)return {};auto p=pad(false);double h=36,bottom=selectStart(false).y-4;return {width/2-32,std::min(bottom-h,p.bottom()+8),64,h};}
};
}
