#pragma once
#import <UIKit/UIKit.h>

namespace Legend::ConsoleSkin {
UIColor* color(uint32_t argb);
void shell(CGContextRef canvas,CGRect box);
void bezel(CGContextRef canvas,CGRect box,CGFloat radius);
void well(CGContextRef canvas,CGFloat size);
void key(CGContextRef canvas,CGRect box,CGFloat radius,bool pressed,bool active);
void face(CGContextRef canvas,CGPoint center,CGFloat radius,bool pressed,uint32_t tint);
void rocker(CGContextRef canvas,CGFloat size,uint16_t held);
void quick(CGContextRef canvas,CGRect bounds,NSString* icon,bool active,bool muted);
}
