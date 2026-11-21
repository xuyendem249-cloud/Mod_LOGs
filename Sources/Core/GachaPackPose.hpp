#pragma once
#include <algorithm>
#include <cmath>

namespace Legend::Gacha {
struct PackPose {
 static constexpr double pi=3.14159265358979323846;
 double cosine,sine,width,side;
 int face;

 explicit PackPose(double elapsed) {
  double angle=std::fmod(std::max(0.,elapsed),24.)*pi/4;
  cosine=std::cos(angle);
  sine=std::sin(angle);
  width=std::abs(cosine);
  side=cosine>=0?1:-1;
  face=static_cast<int>((angle+pi/2)/pi)%3;
 }

 double edgeOpacity()const{return width<.08?220./255*(1-width/.08):0;}
 bool showTexture()const{return width>.002;}
};
}
