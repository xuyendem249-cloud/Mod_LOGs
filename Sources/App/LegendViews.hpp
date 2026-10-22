#pragma once
#import <UIKit/UIKit.h>
#include "FusionAdvisor.hpp"
#include "PlaybackSpeed.hpp"
#include <memory>
UIColor* LGGold();
UIColor* LGInk();
UIImage* LGPixels(const std::vector<uint32_t>&,int,int);
NSString* LGText(const std::string&);
NSString* LGOrder(const std::vector<int>&);
NSAttributedString* LGDescription(Legend::GameData&,int);
@interface LGBackdrop:UIView
@property(nonatomic,readonly) BOOL hasApprovedArtwork;
@end
@interface LGAutoButton:UIButton
@property(nonatomic) BOOL running;
@property(nonatomic,readonly) BOOL hasRunningAnimation;
@property(nonatomic,readonly) BOOL hasCircularImage;
@end
@interface LGFusionOverlay:UIView
- (void)showView:(const Legend::DuelView&)view row:(const Legend::FusionRow*)row;
@end
@interface LGVipController:UIViewController<UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate>
- (instancetype)initWithData:(std::shared_ptr<Legend::GameData>)data queue:(dispatch_queue_t)queue ram:(std::shared_ptr<Legend::Bytes>)ram;
@property(nonatomic,copy) void(^closed)(void);
@end
@interface LGSettingsController:UITableViewController
@property(nonatomic) NSInteger fusionMode,slot;
@property(nonatomic) double speed;
@property(nonatomic) float volume;
@property(nonatomic,copy) void(^changed)(LGSettingsController*);
@property(nonatomic,copy) void(^command)(NSString*);
@property(nonatomic,copy) void(^closed)(void);
@end
