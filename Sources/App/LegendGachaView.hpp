#import <UIKit/UIKit.h>
#include "GameData.hpp"
#include <memory>

@interface LGGachaController : UIViewController
- (instancetype)initWithData:(std::shared_ptr<Legend::GameData>)game
                       stars:(NSInteger)stars
                       media:(NSURL*)media
                       queue:(dispatch_queue_t)queue;
@property(nonatomic,copy) void(^openPacks)(NSInteger quantity,NSInteger quote,
                                          void(^reply)(NSInteger stars,NSArray<NSNumber*>* cards,NSString* error));
@property(nonatomic,copy) void(^gift)(NSString* code,void(^reply)(NSInteger stars,NSString* error));
@property(nonatomic,copy) void(^closed)(void);
@end
