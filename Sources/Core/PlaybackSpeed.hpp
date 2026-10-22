#pragma once
#include <array>
#include <cmath>
#include <string>
#include <cstdio>
namespace Legend {
inline constexpr std::array<double,7> playbackSpeeds{1,1.3,1.5,2,2.5,3,4};
inline double validPlaybackSpeed(double value){for(double allowed:playbackSpeeds)if(std::abs(value-allowed)<.001)return allowed;return 1;}
inline std::string playbackSpeedText(double value){char text[20];std::snprintf(text,sizeof(text),"%.2g×",validPlaybackSpeed(value));return text;}
}
