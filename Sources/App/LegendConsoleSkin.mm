#import "LegendConsoleSkin.hpp"
#include <algorithm>
#include <initializer_list>
#include <cmath>

namespace Legend::ConsoleSkin {
namespace {
constexpr uint32_t ink=0xffcbd2dd,gold=0xffe2c077;
using Colors=std::initializer_list<uint32_t>;
const Colors keyWall={0xff9298a8,0xff5b546b,0xff262535,0xff15141f};
const Colors keyCap={0xff595566,0xff383545,0xff282637};
const Colors downWall={0xff323a45,0xff171d25,0xff151b21};
const Colors downCap={0xff29333e,0xff202831};
constexpr CGFloat pi=3.14159265358979323846;

UIBezierPath* rounded(CGRect box,CGFloat radius){
 return [UIBezierPath bezierPathWithRoundedRect:box cornerRadius:MAX(0,radius)];
}
void fill(CGContextRef canvas,UIBezierPath* path,uint32_t tint){
 CGContextSetFillColorWithColor(canvas,color(tint).CGColor);
 CGContextAddPath(canvas,path.CGPath);CGContextFillPath(canvas);
}
void gradient(CGContextRef canvas,UIBezierPath* path,CGPoint a,CGPoint b,Colors colors,CGFloat radius=0){
 if(CGRectIsEmpty(path.bounds))return;
 NSMutableArray* ramp=[NSMutableArray arrayWithCapacity:colors.size()];
 for(uint32_t value:colors)[ramp addObject:(__bridge id)color(value).CGColor];
 CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
 CGGradientRef g=CGGradientCreateWithColors(space,(__bridge CFArrayRef)ramp,nullptr);
 CGContextSaveGState(canvas);
 CGContextAddPath(canvas,path.CGPath);CGContextClip(canvas);
 constexpr auto extend=kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation;
 if(radius)CGContextDrawRadialGradient(canvas,g,a,0,a,radius,extend);
 else CGContextDrawLinearGradient(canvas,g,a,b,extend);
 CGContextRestoreGState(canvas);CGGradientRelease(g);CGColorSpaceRelease(space);
}
void gradRound(CGContextRef canvas,CGRect box,CGFloat radius,Colors colors){
 if(box.size.width<=0||box.size.height<=0)return;
 gradient(canvas,rounded(box,radius),box.origin,CGPointMake(box.origin.x,CGRectGetMaxY(box)),colors);
}
UIBezierPath* circle(CGPoint center,CGFloat radius){
 return [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x-radius,center.y-radius,radius*2,radius*2)];
}
UIBezierPath* cross(CGFloat size,CGFloat end,CGFloat half){
 CGFloat l=size*end,a=size*(.5-half),h=size-2*l,w=size-2*a;
 UIBezierPath* shape=rounded(CGRectMake(a,l,w,h),size*.075);
 [shape appendPath:rounded(CGRectMake(l,a,h,w),size*.075)];
 return shape;
}
void line(CGContextRef canvas,bool close,std::initializer_list<CGPoint> points){
 auto at=points.begin();CGContextMoveToPoint(canvas,at->x,at->y);
 for(++at;at!=points.end();++at)CGContextAddLineToPoint(canvas,at->x,at->y);
 if(close)CGContextClosePath(canvas);
 CGContextStrokePath(canvas);
}
}

UIColor* color(uint32_t argb){
 return [UIColor colorWithRed:((argb>>16)&255)/255. green:((argb>>8)&255)/255.
  blue:(argb&255)/255. alpha:(argb>>24)/255.];
}
void shell(CGContextRef canvas,CGRect box){
 CGContextSetFillColorWithColor(canvas,color(0xff101216).CGColor);CGContextFillRect(canvas,box);
 gradRound(canvas,CGRectInset(box,1,1),22,{0xffb99a72,0xff796883,0xff31283c});
 auto inner=CGRectInset(box,2.5,2.5);
 gradRound(canvas,inner,20,{0xff665570,0xff493953,0xff362d43});
 static UIImage* grain;
 static dispatch_once_t once;
 dispatch_once(&once,^{
  const unsigned size=96;
  NSMutableData* pixels=[NSMutableData dataWithLength:size*size*4];
  auto* bytes=static_cast<uint8_t*>(pixels.mutableBytes);
  uint32_t seed=21736;
  for(unsigned i=0;i<size*size;i++){
   seed=seed*1664525+1013904223;
   int value=(seed>>24)&15;
   std::fill_n(bytes+i*4,3,value>7?255:0);bytes[i*4+3]=std::abs(value-7);
  }
  auto imageSpace=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  auto provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
  auto image=CGImageCreate(size,size,8,32,size*4,imageSpace,kCGImageAlphaLast|kCGBitmapByteOrder32Big,
   provider,nullptr,false,kCGRenderingIntentDefault);
  if(image){grain=[UIImage imageWithCGImage:image];CGImageRelease(image);}
  CGDataProviderRelease(provider);CGColorSpaceRelease(imageSpace);
 });
 CGContextSaveGState(canvas);[rounded(inner,20)addClip];
 [grain drawAsPatternInRect:inner];CGContextRestoreGState(canvas);
}
void bezel(CGContextRef canvas,CGRect box,CGFloat radius){
 fill(canvas,rounded(box,radius),0xff8f7754);
 fill(canvas,rounded(CGRectInset(box,1,1),radius-1),0xff0c0e12);
}
void well(CGContextRef canvas,CGFloat size){
 CGFloat gap=size*.012,lip=gap+1.5,radius=size*.36;
 CGRect box=CGRectMake(0,0,size,size);
 gradRound(canvas,CGRectInset(box,gap,gap),radius,{0xff211c2a,0xff584a63,0xff836d59});
 gradRound(canvas,CGRectInset(box,lip,lip),radius-lip,{0xff221b2c,0xff2c2538,0xff383046});
}
void key(CGContextRef canvas,CGRect box,CGFloat radius,bool pressed,bool active){
 CGFloat depth=MIN(4,MIN(box.size.width,box.size.height)*.14);
 CGFloat shadow=depth*(pressed?.32:.82),edge=depth*.25,bevel=depth*(pressed?.54:.82),lift=pressed?depth*.40:0;
 auto shape=[&](CGFloat x,CGFloat y,CGFloat b){return CGRectMake(box.origin.x+x,box.origin.y+y,box.size.width-2*x,box.size.height-b-y);};
 fill(canvas,rounded(shape(0,depth*.44,0),radius),0xe2171b23);
 gradRound(canvas,shape(edge,edge+lift,shadow),radius-edge,
  pressed?downWall:active?Colors{0xffd6be82,0xff776040,0xff2f271b}:keyWall);
 gradRound(canvas,shape(bevel,bevel*.81+lift,shadow+bevel),radius-bevel,active?
  (pressed?Colors{0xff4f412b,0xff322b21}:Colors{0xff695637,0xff443827,0xff332b20}):(pressed?downCap:keyCap));
}
void face(CGContextRef canvas,CGPoint center,CGFloat radius,bool pressed,uint32_t tint){
 if(radius<=0)return;
 CGFloat depth=MIN(5,radius*.21);
 fill(canvas,circle({center.x,center.y+depth*.40},radius),0xff16131f);
 fill(canvas,circle({center.x,center.y+depth*.31},radius-depth*.31),0xff0d0c14);
 if(pressed)center.y+=depth*.56;
 CGFloat rim=radius-depth*.51,inner=radius-depth*1.37;
 gradient(canvas,circle(center,rim),{center.x-rim,center.y-rim},{center.x+rim,center.y+rim},
  pressed?downWall:Colors{0xffa3a2b3,0xff716a83,0xff39374c,0xff1a192a});
 gradient(canvas,circle(center,inner),{center.x-inner*.44,center.y-inner*.61},{},
  pressed?downCap:Colors{0xff5d5b73,0xff32324c,0xff1b192c},inner*1.85);
 CGContextSetStrokeColorWithColor(canvas,color((tint&0xffffff)|(pressed?0xf0000000:0x76000000)).CGColor);
 CGContextSetLineWidth(canvas,pressed?1.3:.9);CGContextSetLineCap(canvas,kCGLineCapRound);
 CGContextAddArc(canvas,center.x,center.y,inner+.38,pressed?0:199*pi/180,pressed?2*pi:323*pi/180,0);
 CGContextStrokePath(canvas);
}
void rocker(CGContextRef canvas,CGFloat size,uint16_t held){
 if(size<=0)return;
 well(canvas,size);
 auto base=cross(size,.075,.190),top=cross(size,.101,.164);
 CGContextSaveGState(canvas);CGContextTranslateCTM(canvas,0,2);
 fill(canvas,base,0xff11151b);CGContextRestoreGState(canvas);
 gradient(canvas,base,{0,0},{size,size},keyWall);
 gradient(canvas,top,{0,0},{size,size},keyCap);
 CGFloat c=size/2,offset=size*.277;
 const unsigned keys[]={4,7,5,6};
 CGContextSaveGState(canvas);[top addClip];
 for(int i=0;i<4;i++)if(held&(1<<keys[i])){
  CGContextSaveGState(canvas);
  CGContextTranslateCTM(canvas,c,c);CGContextRotateCTM(canvas,i*pi/2);
  CGContextSetFillColorWithColor(canvas,color(0x447d633a).CGColor);
  CGContextFillRect(canvas,CGRectMake(-c,-c,size,size*.35));CGContextRestoreGState(canvas);
 }
 CGContextRestoreGState(canvas);
 fill(canvas,circle({c,c},size*.071),0xff242a35);
 fill(canvas,circle({c,c+.55},size*.056),0xff39424e);
 for(int i=0;i<4;i++){
  bool pressed=(held&(1<<keys[i]))!=0;
  CGFloat r=size*.045,y=-offset+(pressed?1:0);
  CGContextSaveGState(canvas);CGContextTranslateCTM(canvas,c,c);CGContextRotateCTM(canvas,i*pi/2);
  CGContextSetFillColorWithColor(canvas,color(pressed?gold:0xffe4e8ef).CGColor);
  CGContextMoveToPoint(canvas,0,y-r);CGContextAddLineToPoint(canvas,r,y+r*.57);
  CGContextAddLineToPoint(canvas,-r,y+r*.57);CGContextClosePath(canvas);CGContextFillPath(canvas);
  CGContextRestoreGState(canvas);
 }
}
void quick(CGContextRef canvas,CGRect bounds,NSString* icon,bool active,bool muted){
 CGFloat dimension=MIN(bounds.size.width,bounds.size.height),middle=MIN(31,dimension-5);
 if(middle<=0)return;
 CGPoint center={CGRectGetMidX(bounds),CGRectGetMidY(bounds)};
 auto key=rounded(CGRectMake(center.x-middle/2,center.y-middle/2,middle,middle),8);
 fill(canvas,key,active?0xe6544333:0xbb131219);
 CGContextSetStrokeColorWithColor(canvas,color(active?0xa0d8b675:0x69756d79).CGColor);CGContextSetLineWidth(canvas,1);
 CGContextAddPath(canvas,key.CGPath);CGContextStrokePath(canvas);
 bool speed=[icon isEqualToString:@"speed"];
 CGFloat size=MIN([icon isEqualToString:@"menu"]?24:20,dimension*.56);
 if(speed&&active){center.y-=5;size=MIN(size,17);}
 CGContextSaveGState(canvas);CGContextTranslateCTM(canvas,center.x-size/2,center.y-size/2);CGContextScaleCTM(canvas,size/24,size/24);
 CGContextSetLineWidth(canvas,1.7);CGContextSetLineCap(canvas,kCGLineCapRound);CGContextSetLineJoin(canvas,kCGLineJoinRound);
 CGContextSetStrokeColorWithColor(canvas,color(active?gold:ink).CGColor);
 if(speed){
  line(canvas,true,{{3,5},{10,12},{3,19}});line(canvas,true,{{13,5},{20,12},{13,19}});
 }else if([icon isEqualToString:@"sound"]){
  line(canvas,true,{{3,9},{7,9},{12,5},{12,19},{7,15},{3,15}});
  if(muted){line(canvas,false,{{16,9},{22,15}});line(canvas,false,{{22,9},{16,15}});}
  else{
   CGContextAddArc(canvas,14,12,5,-56*pi/180,56*pi/180,0);CGContextStrokePath(canvas);
   CGContextAddArc(canvas,15,12,8,-48*pi/180,48*pi/180,0);CGContextStrokePath(canvas);
  }
 }else if([icon isEqualToString:@"save"]){
  line(canvas,true,{{4,3},{17,3},{21,7},{21,21},{3,21},{3,4}});
  line(canvas,false,{{7,3},{7,9},{16,9},{16,3}});
  line(canvas,false,{{7,21},{7,14},{17,14},{17,21}});
 }else if([icon isEqualToString:@"load"]){
  line(canvas,false,{{11,21},{4,21},{4,3},{17,3},{19,5},{19,9}});
  line(canvas,false,{{7,7},{16,7}});line(canvas,false,{{7,10},{10,10}});
  CGContextAddEllipseInRect(canvas,CGRectMake(10.5,10.5,9,9));CGContextStrokePath(canvas);
  line(canvas,false,{{18.3,18.3},{22,22}});
 }else for(int row=6;row<=18;row+=6)line(canvas,false,{{4,CGFloat(row)},{20,CGFloat(row)}});
 CGContextRestoreGState(canvas);
}
}
