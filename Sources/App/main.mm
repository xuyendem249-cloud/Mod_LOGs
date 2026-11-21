#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuartzCore/QuartzCore.h>
#include "PlayerCore.hpp"
#include <memory>
#include <cmath>
#import "LegendViews.hpp"
#import "LegendSaveVault.h"
#import "LegendGiftCodes.hpp"
#import "LegendGachaView.hpp"
#include "SealedDisc.hpp"
#import <GameController/GameController.h>
#include "CompatibilityTables.hpp"
#include "ControllerGeometry.hpp"
#include "AutoPlayer.hpp"
#include "FusionSelection.hpp"
#include "CoreTransaction.hpp"
#include "DeckTransfer.hpp"

static UIColor* Gold(){return LGGold();}
static UIColor* Ink(){return LGInk();}
static NSString* const LGErrorDomain=@"LegendPlayer";
static NSError* Failure(NSString* text){return [NSError errorWithDomain:LGErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}

@interface LGPadButton:UIButton
@property(nonatomic) NSInteger padID;
@property(nonatomic,copy) void(^change)(BOOL);
@end
@implementation LGPadButton
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])){self.exclusiveTouch=NO;self.padID=-1;self.layer.cornerRadius=16;self.layer.borderWidth=1.4;self.layer.borderColor=Gold().CGColor;self.backgroundColor=[UIColor colorWithRed:.15 green:.13 blue:.24 alpha:1];self.titleLabel.font=[UIFont boldSystemFontOfSize:19];
 [self addTarget:self action:@selector(down) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];
 [self addTarget:self action:@selector(up) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];}return self;
}
- (void)down{if(self.change)self.change(YES);}
- (void)up{if(self.change)self.change(NO);}
- (void)setHighlighted:(BOOL)value{[super setHighlighted:value];self.backgroundColor=value?[UIColor colorWithRed:.38 green:.28 blue:.38 alpha:1]:[UIColor colorWithRed:.15 green:.13 blue:.24 alpha:1];self.layer.borderWidth=value?3:1.4;[self setNeedsDisplay];}
- (void)drawRect:(CGRect)rect {
 [super drawRect:rect];NSInteger key=self.padID;if(key<0||key>=10||key==2||key==3)return;
 CGContextRef c=UIGraphicsGetCurrentContext();CGFloat cx=CGRectGetMidX(self.bounds),cy=CGRectGetMidY(self.bounds),r=MIN(rect.size.width,rect.size.height)*.23;
 UIColor* color=key==0?[UIColor colorWithRed:.5 green:.73 blue:1 alpha:1]:key==1?[UIColor colorWithRed:.85 green:.59 blue:.85 alpha:1]:key==8?[UIColor colorWithRed:1 green:.52 blue:.57 alpha:1]:key==9?[UIColor colorWithRed:.55 green:.88 blue:.64 alpha:1]:Gold();
 CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetFillColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,MAX(2,r*.15));CGContextSetLineJoin(c,kCGLineJoinRound);
 switch(key){
 case 0:CGContextMoveToPoint(c,cx-r,cy-r);CGContextAddLineToPoint(c,cx+r,cy+r);CGContextMoveToPoint(c,cx+r,cy-r);CGContextAddLineToPoint(c,cx-r,cy+r);break;
 case 1:CGContextStrokeRect(c,CGRectMake(cx-r,cy-r,r*2,r*2));return;
 case 8:CGContextStrokeEllipseInRect(c,CGRectMake(cx-r,cy-r,r*2,r*2));return;
 case 9:CGContextMoveToPoint(c,cx,cy-r);CGContextAddLineToPoint(c,cx+r,cy+r*.8);CGContextAddLineToPoint(c,cx-r,cy+r*.8);CGContextClosePath(c);break;
 default:{CGFloat dx=key==6?-1:key==7?1:0,dy=key==4?-1:key==5?1:0;CGContextMoveToPoint(c,cx+dx*r,cy+dy*r);CGContextAddLineToPoint(c,cx-dx*r-dy*r*.75,cy-dy*r+dx*r*.75);CGContextAddLineToPoint(c,cx-dx*r+dy*r*.75,cy-dy*r-dx*r*.75);CGContextClosePath(c);CGContextFillPath(c);return;}
 }CGContextStrokePath(c);
}
@end

@interface LGDirectionPad:UIView
@property(nonatomic,copy) void(^changed)(uint16_t);
@end
@implementation LGDirectionPad
- (void)update:(NSSet<UITouch*>*)touches{CGPoint p=[touches.anyObject locationInView:self];CGFloat x=p.x/self.bounds.size.width,y=p.y/self.bounds.size.height;uint16_t mask=0;if(x>=0&&y>=0&&x<=1&&y<=1){if(x<.38)mask|=1<<6;if(x>.62)mask|=1<<7;if(y<.38)mask|=1<<4;if(y>.62)mask|=1<<5;}if(self.changed)self.changed(mask);}
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event{[self update:touches];}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event{[self update:touches];}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event{if(self.changed)self.changed(0);}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event{if(self.changed)self.changed(0);}
@end
static NSString* Digest(NSData* bytes){unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,hash);NSMutableString* out=[NSMutableString string];for(unsigned char b:hash)[out appendFormat:@"%02x",b];return out;}
static CGRect LGRect(Legend::Box b,CGPoint origin){return CGRectMake(origin.x+b.x,origin.y+b.y,b.w,b.h);}
@interface LGPlayer:UIViewController<UIDocumentPickerDelegate,UITableViewDataSource,UITableViewDelegate> {
 std::unique_ptr<Legend::PlayerCore> _core;
 dispatch_queue_t _worker;
 dispatch_queue_t _slotIO;
 BOOL _inFlight,_ready,_paused,_background,_pickingBIOS,_operation;
 double _fps,_sampleRate,_clock;
 NSString* _root;
 NSString* _gameKey;
 CADisplayLink* _displayLink;
 AVAudioEngine* _audioEngine;
 AVAudioSourceNode* _audioSource;
 UIImageView* _screen;
 LGAutoButton* _logo;
 UIButton* _speedButton;
 UIButton* _sound;
 UIButton* _mode;
 UILabel* _speedBadge;
 UIView* _bezel;
 std::atomic<bool> _autoEnabled;
 std::atomic<bool> _transactionCancelled;
 std::atomic<uint64_t> _autoGeneration;
 uint64_t _autoFrame;
 std::shared_ptr<Legend::GameData> _autoData;
 std::unique_ptr<Legend::FusionAdvisor> _autoAdvisor;
 std::unique_ptr<Legend::AutoPlayer> _auto;
 std::unique_ptr<Legend::FusionSelection> _fusionSelection;
 uint64_t _fusionTicket,_fusionFrame;
 UILabel* _placeholder;
 UILabel* _quickNotice;
 LGSaveVault* _vault;
 LGQuickSlots* _quickSlots;
 LGGiftCodes* _giftCodes;
 UIButton* _menu;
 UIButton* _save;
 UIButton* _load;
 NSMutableDictionary<NSNumber*,LGPadButton*>* _pads;
 std::shared_ptr<Legend::GameData> _data;
 std::shared_ptr<Legend::GameData> _analysisData;
 std::unique_ptr<Legend::FusionAdvisor> _advisor;
 std::shared_ptr<Legend::Bytes> _lastRam;
 Legend::DuelView _duel;
 Legend::FusionRow _selected;
 BOOL _hasSelected,_analyzing;
 dispatch_queue_t _analysis;
 NSInteger _fusionMode,_slot;
 NSUInteger _generation;
 NSUInteger _quickNoticeRevision;
 double _speed,_boostSpeed,_frameDebt,_lastSnapshot,_lastCardFlush;
 float _volume;
 BOOL _muted,_controllerEnabled;
 BOOL _triedBundled;
 bool _needsNativeLoad;
 std::atomic<int> _imageFilter;
 int _renderedFilter;
 std::vector<uint8_t> _filteredPixels;
 LGFusionOverlay* _overlay;
 UITableView* _guide;
 LGDirectionPad* _dpad;
 uint16_t _sources[3],_combined;
 UIImageView* _welcome;
 Legend::Bytes _persistedCard;

}
@end

@implementation LGPlayer
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{NSString* mode=NSProcessInfo.processInfo.environment[@"LEGEND_SMOKE_ORIENTATION"];return [mode isEqualToString:@"landscape"]?UIInterfaceOrientationMaskLandscapeLeft:[mode isEqualToString:@"portrait"]?UIInterfaceOrientationMaskPortrait:UIInterfaceOrientationMaskAllButUpsideDown;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (void)viewDidLoad {
 _needsNativeLoad=true;
 [super viewDidLoad];self.view=[[LGBackdrop alloc]initWithFrame:self.view.bounds];self.view.multipleTouchEnabled=YES;
 _autoEnabled.store(false);_transactionCancelled.store(false);_autoGeneration.store(0);_autoFrame=0;
 UIApplication.sharedApplication.idleTimerDisabled=YES;
 _core=std::make_unique<Legend::PlayerCore>();_worker=dispatch_queue_create("vn.anhchugia35.legend.core",DISPATCH_QUEUE_SERIAL);_fps=59.94;_sampleRate=44100;
 _analysis=dispatch_queue_create("vn.anhchugia35.legend.analysis",DISPATCH_QUEUE_SERIAL);
 _slotIO=dispatch_queue_create("vn.anhchugia35.legend.slots",DISPATCH_QUEUE_SERIAL);
 _vault=[[LGSaveVault alloc]init];_quickSlots=[[LGQuickSlots alloc]initWithVault:_vault];
 NSUserDefaults* prefs=NSUserDefaults.standardUserDefaults;_fusionMode=MAX(0,MIN(2,[prefs integerForKey:@"fusion_mode"]));_slot=MAX(1,MIN(10,[prefs integerForKey:@"save_slot"]));_speed=1;_boostSpeed=1.2;_volume=[prefs objectForKey:@"volume"]?[prefs floatForKey:@"volume"]:.8;
 _imageFilter.store(int(std::clamp<NSInteger>([prefs integerForKey:@"filter_mode"],0,2)));
 _renderedFilter=-1;
 _controllerEnabled=[prefs objectForKey:@"gamepad_enabled"]?[prefs boolForKey:@"gamepad_enabled"]:YES;
 NSString* docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;_root=[docs stringByAppendingPathComponent:@"Legend"];
 for(NSString* name in @[@"system",@"saves",@"content"]) [[NSFileManager defaultManager] createDirectoryAtPath:[_root stringByAppendingPathComponent:name] withIntermediateDirectories:YES attributes:nil error:nil];
 NSURL* issuer=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"gacha/gift_issuer.der"];
 NSData* key=[NSData dataWithContentsOfURL:issuer];
 if(key)_giftCodes=[[LGGiftCodes alloc]initWithVault:_vault
  path:[[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:@"gift-codes.sealed"]
  issuer:key];
 _bezel=[[UIView alloc]init];_bezel.backgroundColor=[UIColor colorWithWhite:.02 alpha:1];
 _bezel.layer.borderColor=[Gold() colorWithAlphaComponent:.65].CGColor;_bezel.layer.borderWidth=1;
 _bezel.userInteractionEnabled=NO;[self.view addSubview:_bezel];
 _screen=[[UIImageView alloc]init];_screen.backgroundColor=UIColor.blackColor;_screen.contentMode=UIViewContentModeScaleToFill;_screen.clipsToBounds=YES;[self.view addSubview:_screen];
 [self setImageFilter:_imageFilter.load()];
 _placeholder=[[UILabel alloc]init];_placeholder.text=@"Mở menu để nhập BIOS và chọn game";_placeholder.textColor=Gold();_placeholder.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];_placeholder.numberOfLines=0;_placeholder.textAlignment=NSTextAlignmentCenter;[_screen addSubview:_placeholder];
 _welcome=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"welcome.png"]];_welcome.contentMode=UIViewContentModeScaleAspectFit;[_screen addSubview:_welcome];
 _overlay=[[LGFusionOverlay alloc]init];[_screen addSubview:_overlay];
 _quickNotice=[[UILabel alloc]init];_quickNotice.hidden=YES;_quickNotice.userInteractionEnabled=NO;
 _quickNotice.font=[UIFont boldSystemFontOfSize:13];_quickNotice.textAlignment=NSTextAlignmentCenter;
 _quickNotice.textColor=Gold();_quickNotice.adjustsFontSizeToFitWidth=YES;
 _quickNotice.backgroundColor=[UIColor colorWithWhite:.03 alpha:.82];
 _quickNotice.layer.cornerRadius=8;_quickNotice.clipsToBounds=YES;[_screen addSubview:_quickNotice];
 _guide=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];_guide.dataSource=self;_guide.delegate=self;_guide.backgroundColor=Ink();_guide.rowHeight=UITableViewAutomaticDimension;_guide.estimatedRowHeight=100;_guide.separatorColor=[Gold()colorWithAlphaComponent:.3];[self.view addSubview:_guide];
 _menu=[self tool:@"line.3.horizontal" label:@"Menu Legend" action:@selector(menu)];
 _save=[self tool:@"square.and.arrow.down" label:@"Lưu nhanh" action:@selector(save)];
 _load=[self tool:@"doc.text.magnifyingglass" label:@"Tải nhanh" action:@selector(load)];
 _sound=[self tool:@"speaker.wave.2" label:@"Âm thanh game" action:@selector(toggleSound)];
 _mode=[[LGPadButton alloc]init];[_mode setTitle:@"MODE" forState:UIControlStateNormal];_mode.titleLabel.font=[UIFont boldSystemFontOfSize:12];
 [_mode addTarget:self action:@selector(toggleController) forControlEvents:UIControlEventTouchUpInside];
 _mode.accessibilityLabel=@"Nhận tay cầm";[self.view addSubview:_mode];[self updateModeButton];
 _logo=[[LGAutoButton alloc]initWithFrame:CGRectZero];[_logo addTarget:self action:@selector(toggleAuto) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_logo];
 _speedButton=[self tool:@"forward.fill" label:@"Tốc độ game" action:@selector(toggleSpeed)];
 _speedBadge=[[UILabel alloc]init];_speedBadge.font=[UIFont boldSystemFontOfSize:9];_speedBadge.textColor=Gold();_speedBadge.textAlignment=NSTextAlignmentCenter;_speedBadge.hidden=YES;_speedBadge.userInteractionEnabled=NO;[self.view addSubview:_speedBadge];
 _speedButton.accessibilityValue=@"1×";
 [_speedButton addGestureRecognizer:[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(speedHeld:)]];
 _pads=[NSMutableDictionary dictionary];NSArray* names=@[@"X",@"Vuông",@"Select",@"Start",@"Lên",@"Xuống",@"Trái",@"Phải",@"Tròn",@"Tam giác",@"L1",@"R1",@"L2",@"R2"];
 __weak LGPlayer* weak=self;
 for(NSInteger i=0;i<14;i++){LGPadButton* b=[[LGPadButton alloc]init];b.padID=i;b.accessibilityLabel=names[i];if(i>=10||i==2||i==3){[b setTitle:[names[i] uppercaseString] forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:12];}b.change=^(BOOL down){LGPlayer* owner=weak;if(owner&&owner->_core)[owner button:(unsigned)i down:down source:0];};_pads[@(i)]=b;[self.view addSubview:b];}
 _dpad=[[LGDirectionPad alloc]init];_dpad.backgroundColor=UIColor.clearColor;_dpad.changed=^(uint16_t mask){LGPlayer* owner=weak;if(owner){uint16_t next=(owner->_sources[0]&~uint16_t(0xf0))|mask;[owner source:0 mask:next];}};[self.view addSubview:_dpad];
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllers) name:GCControllerDidConnectNotification object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllers) name:GCControllerDidDisconnectNotification object:nil];[self controllers];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationWillResignActiveNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
 _displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];_displayLink.preferredFrameRateRange=CAFrameRateRangeMake(30,60,60);[_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (UIButton*)tool:(NSString*)symbol label:(NSString*)label action:(SEL)action{
 UIButton* button=[UIButton buttonWithType:UIButtonTypeSystem];
 button.tintColor=UIColor.whiteColor;
 button.backgroundColor=[UIColor colorWithWhite:.035 alpha:.72];
 button.layer.cornerRadius=9;
 button.layer.borderWidth=.5;
 button.layer.borderColor=[UIColor colorWithWhite:.7 alpha:.45].CGColor;
 UIImageSymbolConfiguration* icon=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
 [button setImage:[UIImage systemImageNamed:symbol withConfiguration:icon] forState:UIControlStateNormal];
 button.accessibilityLabel=label;
 [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
 [self.view addSubview:button];
 return button;
}
- (void)releaseButtons{_sources[0]=_sources[1]=_sources[2]=_combined=0;_core->input.clear();for(LGPadButton* b in _pads.allValues)b.highlighted=NO;}
- (BOOL)hasBundledGame{
 return [NSFileManager.defaultManager fileExistsAtPath:[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"mod2/content.sealed"].path];
}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self becomeFirstResponder];if(!_operation)[self resume];
 if([NSProcessInfo.processInfo.environment[@"LEGEND_SMOKE"] isEqualToString:@"1"]){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self runSmoke];});}
 else if(!_triedBundled&&[self hasBundledGame]){
  _triedBundled=YES;
  [self openBundledGame];
 }
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{[self releaseButtons];_clock=0;[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context){[self.view setNeedsLayout];} completion:nil];}
- (void)cluster:(CGRect)area right:(BOOL)right {
 CGFloat s=MIN(area.size.width,area.size.height);CGRect box=CGRectMake(CGRectGetMidX(area)-s/2,CGRectGetMidY(area)-s/2,s,s);CGFloat u=s/3;
 NSArray* ids=right?@[@9,@0,@1,@8]:@[@4,@5,@6,@7];const CGPoint points[4]={CGPointMake(1,0),CGPointMake(1,2),CGPointMake(0,1),CGPointMake(2,1)};
 for(NSUInteger i=0;i<4;i++){CGPoint p=points[i];_pads[ids[i]].frame=CGRectInset(CGRectMake(box.origin.x+p.x*u,box.origin.y+p.y*u,u,u),2,2);}
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];CGRect a=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);Legend::ControllerGeometry g(a.size.width,a.size.height,_fusionMode==2);CGPoint o=a.origin;
 _bezel.frame=LGRect(g.bezel,o);_bezel.layer.cornerRadius=g.portrait?20:17;
 _screen.frame=LGRect(g.game,o);_screen.layer.cornerRadius=_fusionMode==2&&!g.portrait?0:16;_guide.frame=LGRect(g.guide,o);_guide.hidden=_fusionMode!=2;
 _pads[@12].frame=LGRect(g.shoulder(false,false),o);_pads[@10].frame=LGRect(g.shoulder(false,true),o);_pads[@11].frame=LGRect(g.shoulder(true,false),o);_pads[@13].frame=LGRect(g.shoulder(true,true),o);
 [self cluster:LGRect(g.pad(false),o) right:NO];[self cluster:LGRect(g.pad(true),o) right:YES];_dpad.frame=LGRect(g.pad(false),o);
 _pads[@2].frame=LGRect(g.selectStart(false),o);_pads[@3].frame=LGRect(g.selectStart(true),o);_logo.frame=LGRect(g.logo(),o);_mode.frame=LGRect(g.mode(),o);
 NSArray<UIButton*>* actions=@[_speedButton,_sound,_save,_load];
 for(size_t i=0;i<actions.count;i++)actions[i].frame=CGRectInset(LGRect(g.quickAction(int(i)),o),3,4);
 _speedBadge.frame=CGRectMake(CGRectGetMinX(_speedButton.frame),CGRectGetMaxY(_speedButton.frame)-11,_speedButton.frame.size.width,10);
 _menu.frame=CGRectInset(LGRect(g.menu(),o),4,4);
 _placeholder.frame=CGRectInset(_screen.bounds,20,20);_welcome.frame=CGRectInset(_screen.bounds,10,10);_welcome.hidden=_ready;_overlay.frame=_screen.bounds;_overlay.hidden=_fusionMode==0;
 _quickNotice.frame=CGRectMake(12,8,MAX(1,_screen.bounds.size.width-60),28);
 _save.enabled=_load.enabled=_ready;_save.alpha=_load.alpha=_ready?1:.4;[self.view setNeedsDisplay];
}

- (void)smokeProgress:(NSString*)phase{[phase writeToFile:[_root stringByAppendingPathComponent:@"smoke-progress.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];NSLog(@"Legend smoke: %@",phase);}
- (BOOL)smokeQuickSlot{
 NSMutableData* sample=[NSMutableData dataWithLength:32*1024];
 auto* contents=static_cast<uint8_t*>(sample.mutableBytes);
 for(size_t i=0;i<sample.length;i++)contents[i]=uint8_t(i%61);
 NSString* path=[NSTemporaryDirectory() stringByAppendingPathComponent:
  [NSString stringWithFormat:@"legend-smoke-%@.slot",NSUUID.UUID.UUIDString]];
 NSString* purpose=@"legend/smoke/quick-slot";
 NSError* error=nil;
 BOOL written=[_quickSlots writeState:sample path:path purpose:purpose error:&error];
 BOOL restored=written&&[[_quickSlots readState:path purpose:purpose error:&error] isEqualToData:sample];
 BOOL bound=restored&&![_quickSlots readState:path purpose:@"legend/smoke/other-slot" error:nil];
 NSMutableData* corrupted=[NSMutableData dataWithContentsOfFile:path];
 if(corrupted.length>40){
  static_cast<uint8_t*>(corrupted.mutableBytes)[25]^=1;
  [corrupted writeToFile:path atomically:YES];
 }
 BOOL rejected=corrupted.length>40&&![_quickSlots readState:path purpose:purpose error:nil];
 [NSFileManager.defaultManager removeItemAtPath:path error:nil];
 [self smokeProgress:[NSString stringWithFormat:@"slot written=%d restored=%d bound=%d rejected=%d %@",written,restored,bound,rejected,error.localizedDescription?:@""]];
 return restored&&bound&&rejected;
}
- (void)runSmoke{
 [self smokeProgress:@"request orientation"];
 NSString* mode=NSProcessInfo.processInfo.environment[@"LEGEND_SMOKE_ORIENTATION"]?:@"portrait";BOOL landscape=[mode isEqualToString:@"landscape"];UIInterfaceOrientationMask mask=landscape?UIInterfaceOrientationMaskLandscapeLeft:UIInterfaceOrientationMaskPortrait;
 [self setNeedsUpdateOfSupportedInterfaceOrientations];UIWindowScene* scene=self.view.window.windowScene;if(!scene)[UIViewController attemptRotationToDeviceOrientation];[scene requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc]initWithInterfaceOrientations:mask] errorHandler:^(NSError* error){NSLog(@"Smoke orientation: %@",error);}];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
 [self smokeProgress:@"layout"];[self.view setNeedsLayout];[self.view layoutIfNeeded];BOOL valid=self->_pads.count==14&&self->_screen.frame.size.width>0;for(LGPadButton* b in self->_pads.allValues)valid=valid&&CGRectContainsRect(self.view.bounds,b.frame)&&b.frame.size.width>0&&b.frame.size.height>0;
 BOOL portrait=self.view.bounds.size.height>self.view.bounds.size.width;
 BOOL overlay=YES;
 for(UIButton* action in @[self->_menu,self->_speedButton,self->_sound,self->_save,self->_load]){
  overlay=overlay&&CGRectContainsRect(self->_screen.frame,action.frame);
 }
 [self smokeProgress:@"speed 2"];[self setPlaybackSpeed:2];LGSettingsController* settings=[self configuredSettings];[settings loadViewIfNeeded];UITableViewCell* cell=[settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];BOOL synced=[self->_speedButton.accessibilityValue isEqualToString:@"2×"]&&[cell.detailTextLabel.text isEqualToString:@"2×"];
 [self smokeProgress:@"settings speed 3"];settings.speed=3;settings.changed(settings);cell=[settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];synced=synced&&[self->_speedButton.accessibilityValue isEqualToString:@"3×"]&&[cell.detailTextLabel.text isEqualToString:@"3×"];
 [self smokeProgress:@"core speed sync"];__block double coreSpeed=0;dispatch_sync(self->_worker,^{coreSpeed=self->_core->playbackRate();});synced=synced&&std::abs(coreSpeed-3)<.001;
 [self toggleSpeed];BOOL togglesToNormal=std::abs(self->_speed-1)<.001;
 [self toggleSpeed];BOOL togglesToBoost=std::abs(self->_speed-3)<.001;
 [self setPlaybackSpeed:1];CGRect safe=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);BOOL expanded=portrait||std::abs(self->_screen.frame.size.height-safe.size.height)<9;
 [self->_logo layoutIfNeeded];BOOL roundLogo=self->_logo.hasCircularImage&&CGRectContainsRect(safe,self->_logo.frame);self->_logo.running=YES;BOOL ringStarted=self->_logo.hasRunningAnimation&&self->_logo.currentImage!=nil;[self stopAuto];BOOL ringStopped=ringStarted&&!self->_logo.running&&!self->_logo.hasRunningAnimation;
 [self smokeProgress:@"check protected quick slot"];
 __block BOOL protectedSlot=NO;
 dispatch_sync(self->_slotIO,^{protectedSlot=[self smokeQuickSlot];});
 [self smokeProgress:@"write report"];NSDictionary* report=@{@"app_launched":@YES,@"all_14_buttons_inside_view":@(valid),@"approved_background_loaded":@([(LGBackdrop*)self.view hasApprovedArtwork]),@"game_or_bios_tested":@NO,@"orientation":mode,@"orientation_matches":@(portrait!=landscape),@"quick_icons_overlay_game":@(overlay),@"speed_text_sync":@(synced),@"speed_toggle":@(togglesToNormal&&togglesToBoost),@"speed_button_visibility":@(!self->_speedButton.hidden),@"speed_button_inside_safe_area":@(CGRectContainsRect(safe,self->_speedButton.frame)),@"landscape_game_fills_height":@(expanded),@"auto_ring_stops":@(ringStopped),@"circular_logo":@(roundLogo),@"authenticated_quick_slot":@(protectedSlot)};
 NSData* json=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];[json writeToFile:[self->_root stringByAppendingPathComponent:[NSString stringWithFormat:@"simulator_smoke-%@.json",mode]] atomically:YES];
 });
}

- (void)stopAuto{_autoEnabled.store(false);_autoGeneration.fetch_add(1);if(_core)_core->autoInput.store(0);_logo.running=NO;}
- (void)selectFusion:(NSUInteger)index{
 if(!_data||!_ready||_paused||_background||_operation||index>=_duel.rows.size())return;
 [self stopAuto];
 [self releaseButtons];
 auto choice=_duel.rows[index];
 auto data=_data;
 auto ticket=_autoGeneration.load();
 _selected=choice;_hasSelected=YES;
 [_overlay showView:_duel row:&_selected];
 [_guide reloadData];
 dispatch_async(_worker,^{
  if(ticket!=self->_autoGeneration.load()||!self->_core->isLoaded())return;
  try{
   Legend::FusionAdvisor advisor(*data,Legend::defaultCompatibility().handSignatures);
   auto view=advisor.analyze(self->_core->ramSnapshot());
   for(const auto& row:view.rows){
    if(row.result!=choice.result||row.slots!=choice.slots)continue;
    auto selection=std::make_unique<Legend::FusionSelection>(view,row,data->cardCount);
    if(!selection->compatible(view))break;
    if(ticket!=self->_autoGeneration.load())return;
    self->_fusionSelection=std::move(selection);
    self->_fusionTicket=ticket;
    self->_fusionFrame=0;
    self->_core->autoInput.store(0x10000);
    return;
   }
  }catch(const std::exception& error){NSLog(@"Legend Fusion: %s",error.what());}
  dispatch_async(dispatch_get_main_queue(),^{
   if(ticket==self->_autoGeneration.load())UIAccessibilityPostNotification(
    UIAccessibilityAnnouncementNotification,@"Tay bài đã đổi. Chọn lại công thức hiện tại.");
  });
 });
}
- (BOOL)stepFusion{
 if(!_fusionSelection)return NO;
 auto ticket=_autoGeneration.load();
 if(_fusionTicket!=ticket){
  _fusionSelection.reset();
  if(!_autoEnabled.load())_core->autoInput.store(0);
  return NO;
 }
 Legend::Bytes snapshot;
 if(_fusionSelection->needsSnapshot(_fusionFrame))snapshot=_core->ramSnapshot();
 uint16_t mask=_fusionSelection->next(snapshot,_fusionFrame++);
 if(ticket==_autoGeneration.load())_core->setAutoMask(mask);
 if(_fusionSelection->done){
  _core->autoInput.store(0);
  _fusionSelection.reset();
 }
 return YES;
}
- (void)toggleAuto{
 if(_autoEnabled.load()){[self stopAuto];return;}if(!_ready||_paused||_background||_operation||!_data){[self alert:@"Auto" text:@"Mở game được hỗ trợ trước khi bật Auto."];return;}
 auto data=_data;uint64_t ticket=_autoGeneration.fetch_add(1)+1;_autoEnabled.store(true);_logo.running=YES;[self releaseButtons];
 dispatch_async(_worker,^{if(ticket!=self->_autoGeneration.load()||!self->_autoEnabled.load())return;
  if(!self->_core->compatibility.enabled&&!self->_core->hasProtectedWallet()){self->_autoEnabled.store(false);dispatch_async(dispatch_get_main_queue(),^{if(ticket==self->_autoGeneration.load()){self->_logo.running=NO;[self alert:@"Auto" text:@"Bản game này chưa được nhận diện để dùng Auto."];}});return;}
  self->_autoData=data;self->_autoAdvisor=std::make_unique<Legend::FusionAdvisor>(*data,Legend::defaultCompatibility().handSignatures);self->_auto=std::make_unique<Legend::AutoPlayer>(*data,*self->_autoAdvisor);self->_autoFrame=0;
  if(ticket==self->_autoGeneration.load()&&self->_autoEnabled.load())self->_core->autoInput.store(0x10000);
 });
}
- (void)setPlaybackSpeed:(double)value{
 _speed=Legend::validPlaybackSpeed(value);
 if(_speed>1)_boostSpeed=_speed;
 _speedBadge.hidden=_speed<=1;
 _speedBadge.text=_speedButton.accessibilityValue=LGText(Legend::playbackSpeedText(_speed));
 _speedButton.tintColor=_speed>1?Gold():UIColor.whiteColor;
 _speedButton.imageEdgeInsets=_speed>1?UIEdgeInsetsMake(-6,0,0,0):UIEdgeInsetsZero;
 double speed=_speed;
 dispatch_async(_worker,^{self->_core->setSpeed(speed);});
}
- (void)toggleSpeed{[self setPlaybackSpeed:_speed<=1?_boostSpeed:1];}
- (void)speedHeld:(UILongPressGestureRecognizer*)gesture{
 if(gesture.state==UIGestureRecognizerStateBegan)[self chooseSpeed];
}
- (void)toggleSound{
 _muted=!_muted;
 _audioEngine.mainMixerNode.outputVolume=_muted?0:_volume;
 _sound.accessibilityValue=_muted?@"Đang tắt":@"Đang bật";
 _sound.tintColor=_muted?Gold():UIColor.whiteColor;
 UIImageSymbolConfiguration* icon=[UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
 [_sound setImage:[UIImage systemImageNamed:_muted?@"speaker.slash":@"speaker.wave.2" withConfiguration:icon] forState:UIControlStateNormal];
}
- (void)updateModeButton{
 _mode.accessibilityValue=_controllerEnabled?@"Đang bật":@"Đang tắt";
 [_mode setTitleColor:_controllerEnabled?Gold():UIColor.whiteColor forState:UIControlStateNormal];
}
- (void)toggleController{
 _controllerEnabled=!_controllerEnabled;
 [NSUserDefaults.standardUserDefaults setBool:_controllerEnabled forKey:@"gamepad_enabled"];
 if(!_controllerEnabled)[self source:1 mask:0];
 [self updateModeButton];
}
- (void)chooseSpeed{
 [self pause];UIAlertController* sheet=[UIAlertController alertControllerWithTitle:@"Tốc độ" message:nil preferredStyle:UIAlertControllerStyleActionSheet];__weak LGPlayer* weak=self;
 for(double speed:Legend::playbackSpeeds){NSString* title=LGText(Legend::playbackSpeedText(speed));if(std::abs(speed-_speed)<.001)title=[title stringByAppendingString:@" ✓"];[sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak setPlaybackSpeed:speed];[weak resumePlayback];}]];}
 [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];sheet.popoverPresentationController.sourceView=_speedButton;sheet.popoverPresentationController.sourceRect=_speedButton.bounds;[self presentViewController:sheet animated:YES completion:nil];
}

- (void)alert:(NSString*)title text:(NSString*)text{UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];__weak LGPlayer* weak=self;[a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];[self presentViewController:a animated:YES completion:nil];}
- (void)menu {
 [self pause];UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Yu-Gi-Oh! FM: Legend" message:nil preferredStyle:UIAlertControllerStyleActionSheet];__weak LGPlayer* weak=self;
 BOOL bundled=[self hasBundledGame];
 [a addAction:[UIAlertAction actionWithTitle:bundled?@"Mở Mod 2":@"Mở game ISO / BIN / IMG"
  style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){if(bundled)[weak openBundledGame];else [weak pick:NO];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"VIP" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak vipMenu];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Gacha" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak showGacha];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Cài Đặt" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak settings];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];
 a.popoverPresentationController.sourceView=_menu;a.popoverPresentationController.sourceRect=_menu.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (void)vipMenu{
 UIAlertController* sheet=[UIAlertController alertControllerWithTitle:@"VIP" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 __weak LGPlayer* weak=self;
 [sheet addAction:[UIAlertAction actionWithTitle:@"Deck/DropList" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak showVIP];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Chest / Deck" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak showCollection];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Hướng dẫn Fusion" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak cycleFusion];[weak resumePlayback];}]];
 [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];
 sheet.popoverPresentationController.sourceView=_menu;sheet.popoverPresentationController.sourceRect=_menu.bounds;
 [self presentViewController:sheet animated:YES completion:nil];
}

- (void)pick:(BOOL)bios{
 [self pause];
 _pickingBIOS=bios;
 _operation=YES;
 UIDocumentPickerViewController* picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeData] asCopy:NO];
 picker.delegate=self;
 picker.allowsMultipleSelection=NO;
 [self presentViewController:picker animated:YES completion:nil];
}
- (void)openBundledGame{
 if(_operation)return;
 [self pause];
 _operation=YES;
 _menu.enabled=NO;
 _placeholder.hidden=NO;
 _placeholder.text=@"Đang mở Mod 2…";
 NSUInteger generation=++_generation;
 _lastRam.reset();
 _data.reset();
 _hasSelected=NO;
 _duel={};
 [self->_overlay showView:_duel row:nullptr];
 dispatch_async(_worker,^{
  NSString* failure=nil;
  std::shared_ptr<Legend::GameData> catalog;
  try{
   [self persistCard];
   NSURL* media=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"mod2" isDirectory:YES];
   NSData* key=[NSData dataWithContentsOfURL:[media URLByAppendingPathComponent:@"content.key"]];
   auto* bytes=static_cast<const uint8_t*>(key.bytes);
   NSString* discPath=[media URLByAppendingPathComponent:@"content.sealed"].path;
   auto disc=Legend::openSealedDisc(discPath.UTF8String,bytes,key.length);
   catalog=std::make_shared<Legend::GameData>(disc);
   if(catalog->cardCount!=800)throw std::runtime_error("Dữ liệu Mod 2 không đúng phiên bản.");
   NSString* identity=LGText(disc->identity());
   NSData* manifest=[NSData dataWithContentsOfURL:[media URLByAppendingPathComponent:@"manifest.json"]];
   id record=manifest?[NSJSONSerialization JSONObjectWithData:manifest options:0 error:nil]:nil;
   NSDictionary* metadata=[record isKindOfClass:NSDictionary.class]?record:nil;
   NSData* bios=[NSData dataWithContentsOfURL:[media URLByAppendingPathComponent:@"ps1.rom"]];
   if(bios.length!=524288||![metadata[@"bios_sha256"] isEqual:Digest(bios)])
    throw std::runtime_error("BIOS đi kèm không hợp lệ.");
   NSFileManager* files=NSFileManager.defaultManager;
   NSURL* support=[[files URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
    URLByAppendingPathComponent:@"LegendCore" isDirectory:YES];
   NSURL* system=[support URLByAppendingPathComponent:@"system" isDirectory:YES];
   NSURL* saves=[support URLByAppendingPathComponent:@"saves" isDirectory:YES];
   NSError* error=nil;
   BOOL ready=[files createDirectoryAtURL:system withIntermediateDirectories:YES attributes:nil error:&error]&&
    [files createDirectoryAtURL:saves withIntermediateDirectories:YES attributes:nil error:&error]&&
    [bios writeToURL:[system URLByAppendingPathComponent:@"scph1001.bin"] options:NSDataWritingAtomic error:&error];
   if(!ready)throw std::runtime_error(error.localizedDescription.UTF8String?:"Không chuẩn bị được Mod 2.");
   NSData* card=[self readCardForKey:identity error:&error];
   if(error)throw std::runtime_error(error.localizedDescription.UTF8String?:"Không đọc được thẻ nhớ.");
   std::string detail;
   if(!self->_core->open(discPath.UTF8String,support.path.UTF8String,detail,std::move(disc)))
    throw std::runtime_error(detail);
   self->_gameKey=identity;
   self->_needsNativeLoad=true;
   self->_persistedCard.clear();
   self->_core->setSpeed(self->_speed);
   if(card){
    const auto* saved=static_cast<const uint8_t*>(card.bytes);
    if(!self->_core->setMemoryCard({saved,saved+card.length}))
     throw std::runtime_error("Core không nhận được thẻ nhớ.");
    if([files fileExistsAtPath:[self cardPathForKey:identity extension:@"sealed"]])
     self->_persistedCard.assign(saved,saved+card.length);
    else [self persistCard];
   }
  }catch(const std::exception& problem){
   failure=LGText(problem.what());
   catalog.reset();
   self->_gameKey=nil;
   self->_core->close();
  }
  double fps=self->_core->fps,rate=self->_core->sampleRate;
  dispatch_async(self->_analysis,^{
   self->_advisor.reset();
   self->_analysisData=catalog;
   if(catalog)self->_advisor=std::make_unique<Legend::FusionAdvisor>(*catalog,Legend::defaultCompatibility().handSignatures);
   dispatch_async(dispatch_get_main_queue(),^{
    if(generation!=self->_generation)return;
    self->_operation=NO;
    self->_menu.enabled=YES;
    self->_data=catalog;
    self->_ready=catalog!=nullptr;
    self->_placeholder.hidden=self->_ready;
    self->_fps=fps;self->_sampleRate=rate;
    [self->_audioEngine stop];self->_audioEngine=nil;self->_audioSource=nil;self->_screen.image=nil;
    [self.view setNeedsLayout];
    if(failure){self->_placeholder.text=@"Mở Mod 2 từ menu";[self alert:@"Không mở được Mod 2" text:failure];}
    else{[self preloadQuickSlot:self->_slot];[self resume];}
   });
  });
 });
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller{_operation=NO;[self resumePlayback];}
- (NSString*)importURL:(NSURL*)url bios:(BOOL)bios error:(NSError**)error {
 NSFileManager* fm=NSFileManager.defaultManager;NSString* ext=url.pathExtension.lowercaseString;if(!bios&&![@[@"iso",@"bin",@"img"] containsObject:ext]){*error=Failure(@"Hỗ trợ ISO, BIN và IMG một track. Hãy chọn bản ISO của mod.");return nil;}
 BOOL scoped=[url startAccessingSecurityScopedResource];__block NSString* result=nil;__block NSError* copyError=nil;
 NSFileCoordinator* coordinator=[[NSFileCoordinator alloc]init];NSError* coordinateError=nil;
 [coordinator coordinateReadingItemAtURL:url options:0 error:&coordinateError byAccessor:^(NSURL* location){
  NSString* stage=[[_root stringByAppendingPathComponent:@"content"] stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"import"]];
  if(![fm copyItemAtURL:location toURL:[NSURL fileURLWithPath:stage] error:&copyError])return;
  NSDictionary* attrs=[fm attributesOfItemAtPath:stage error:&copyError];unsigned long long size=[attrs fileSize];
  if(bios&&size!=524288){copyError=Failure(@"BIOS cần có kích thước 512 KB (524288 byte).");[fm removeItemAtPath:stage error:nil];return;}
  NSString* target=nil;
  if(bios)target=[[_root stringByAppendingPathComponent:@"system"] stringByAppendingPathComponent:@"scph1001.bin"];
  else{NSFileHandle* handle=[NSFileHandle fileHandleForReadingAtPath:stage];if(!handle){copyError=Failure(@"Không đọc được file game.");[fm removeItemAtPath:stage error:nil];return;}CC_SHA256_CTX hash;CC_SHA256_Init(&hash);for(;;){NSData* data=[handle readDataOfLength:1024*1024];if(!data.length)break;CC_SHA256_Update(&hash,data.bytes,(CC_LONG)data.length);}[handle closeFile];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&hash);NSMutableString* key=[NSMutableString string];for(unsigned char b:digest)[key appendFormat:@"%02x",b];target=[[_root stringByAppendingPathComponent:@"content"] stringByAppendingPathComponent:[key stringByAppendingPathExtension:ext]];}
  if([fm fileExistsAtPath:target]){if(bios){if(![fm replaceItemAtURL:[NSURL fileURLWithPath:target] withItemAtURL:[NSURL fileURLWithPath:stage] backupItemName:nil options:0 resultingItemURL:nil error:&copyError])return;}else [fm removeItemAtPath:stage error:nil];}
  else if(![fm moveItemAtPath:stage toPath:target error:&copyError])return;
  result=target;
 }];if(scoped)[url stopAccessingSecurityScopedResource];*error=coordinateError?:copyError;return result;
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
 if(!urls.count){_operation=NO;[self resume];return;}BOOL bios=_pickingBIOS;NSURL* url=urls.firstObject;[self pause];_operation=YES;_menu.enabled=NO;_placeholder.hidden=NO;_placeholder.text=@"Đang nhập file…";NSUInteger generation=_generation;if(!bios){generation=++_generation;_data.reset();_lastRam.reset();_duel={};_hasSelected=NO;dispatch_async(_analysis,^{self->_advisor.reset();self->_analysisData.reset();});}
 dispatch_async(_worker,^{NSError* error=nil;NSString* file=[self importURL:url bios:bios error:&error];BOOL success=file!=nil;
  if(success&&!bios){
   [self persistCard];
   NSString* key=file.lastPathComponent.stringByDeletingPathExtension;
   NSData* card=[self readCardForKey:key error:&error];
   std::string problem;
   success=!error&&self->_core->open(file.UTF8String,self->_root.UTF8String,problem);
   if(!success&&!error)error=Failure(LGText(problem));
   if(success){
    self->_gameKey=key;
    self->_needsNativeLoad=true;
    self->_persistedCard.clear();
    self->_core->setSpeed(self->_speed);
    if(card){
     const auto* bytes=static_cast<const uint8_t*>(card.bytes);
     success=self->_core->setMemoryCard({bytes,bytes+card.length});
     if(!success){
      self->_gameKey=nil;
      self->_core->close();
      error=Failure(@"Core không nhận được thẻ nhớ.");
     }else if([NSFileManager.defaultManager fileExistsAtPath:[self cardPathForKey:key extension:@"sealed"]]){
      self->_persistedCard.assign(bytes,bytes+card.length);
     }else{
      [self persistCard];
     }
    }
   }
  }
  if(success&&!bios){dispatch_async(self->_analysis,^{std::shared_ptr<Legend::GameData> data;try{data=std::make_shared<Legend::GameData>(file.UTF8String);}catch(const std::exception& e){NSLog(@"Legend VIP: %s",e.what());}self->_advisor.reset();self->_analysisData=data;if(data)self->_advisor=std::make_unique<Legend::FusionAdvisor>(*data,Legend::defaultCompatibility().handSignatures);dispatch_async(dispatch_get_main_queue(),^{if(generation!=self->_generation)return;self->_data=data;[self->_guide reloadData];});});}
  double fps=self->_core->fps,rate=self->_core->sampleRate;BOOL loaded=self->_core->isLoaded();
  dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;self->_menu.enabled=YES;self->_ready=loaded;self->_fps=fps;self->_sampleRate=rate;self->_placeholder.hidden=loaded;if(!bios){self->_hasSelected=NO;self->_duel={};[self->_overlay showView:self->_duel row:nullptr];[self->_audioEngine stop];self->_audioEngine=nil;self->_audioSource=nil;self->_screen.image=nil;}[self.view setNeedsLayout];
   if(!success){self->_placeholder.text=@"LEGEND\n\nMở menu để nhập BIOS và chọn game";[self alert:@"Không nhập được file" text:error.localizedDescription?:@"Lỗi đọc file."];}
   else if(bios){self->_placeholder.text=@"LEGEND\n\nĐã nhập BIOS · Chọn Mở game trong menu";[self alert:@"Đã nhập BIOS" text:@"Chọn Mở game trong menu để bắt đầu. BIOS mới sẽ được dùng khi mở game lại."];}
   if(success){if(!bios)[self preloadQuickSlot:self->_slot];[self resume];}
  });
 });
}
- (NSString*)cardPathForKey:(NSString*)key extension:(NSString*)extension{
 return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[key stringByAppendingPathExtension:extension]];
}
- (NSData*)readCardForKey:(NSString*)key error:(NSError**)error{
 NSFileManager* files=NSFileManager.defaultManager;
 NSString* path=[self cardPathForKey:key extension:@"sealed"];
 NSData* card=nil;
 if([files fileExistsAtPath:path]){
  NSDictionary* attrs=[files attributesOfItemAtPath:path error:error];
  if(!attrs)return nil;
  if(attrs.fileSize>131072+4096){*error=Failure(@"Kích thước thẻ nhớ không hợp lệ.");return nil;}
  NSData* sealed=[NSData dataWithContentsOfFile:path options:0 error:error];
  if(!sealed)return nil;
  card=[_vault open:sealed purpose:[@"card/" stringByAppendingString:key] error:error];
  if(!card)return nil;
 }else{
  NSString* legacy=[self cardPathForKey:key extension:@"mcr"];
  if(![files fileExistsAtPath:legacy])return nil;
  NSDictionary* attrs=[files attributesOfItemAtPath:legacy error:error];
  if(!attrs)return nil;
  if(attrs.fileSize!=131072){*error=Failure(@"Thẻ nhớ cũ không hợp lệ.");return nil;}
  card=[NSData dataWithContentsOfFile:legacy options:0 error:error];
  if(!card)return nil;
 }
 if(card.length!=131072||std::memcmp(card.bytes,"MC",2)){
  *error=Failure(@"Thẻ nhớ không hợp lệ.");
  return nil;
 }
 return card;
}
- (BOOL)commitCard:(const Legend::Bytes&)card error:(NSError**)error{
 if(!_gameKey||card.size()!=131072||card[0]!='M'||card[1]!='C'){
  *error=Failure(@"Thẻ nhớ không hợp lệ.");
  return NO;
 }
 _core->checkWallet();
 if(card==_persistedCard)return YES;
 NSData* bytes=[NSData dataWithBytes:card.data() length:card.size()];
 NSData* sealed=[_vault seal:bytes purpose:[@"card/" stringByAppendingString:_gameKey] error:error];
 if(!sealed)return NO;
 NSString* path=[self cardPathForKey:_gameKey extension:@"sealed"];
 if(![sealed writeToFile:path options:NSDataWritingAtomic error:error])return NO;
 _persistedCard=card;
 _core->confirmMemoryCard(card);
 NSString* legacy=[self cardPathForKey:_gameKey extension:@"mcr"];
 NSFileManager* files=NSFileManager.defaultManager;
 if([files fileExistsAtPath:legacy]){
  NSString* archive=[legacy stringByAppendingString:@".legacy"];
  if(![files fileExistsAtPath:archive])[files moveItemAtPath:legacy toPath:archive error:nil];
 }
 return YES;
}
- (NSString*)statePath:(NSInteger)slot{return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_slot%02ld.state",_gameKey,(long)slot]];}
- (void)persistCard{
 if(!_gameKey||!_core->isLoaded())return;
 try{
  _core->checkWallet();
  auto bytes=_core->memoryCard();
  if(bytes.empty())return;
  NSError* error=nil;
  if(![self commitCard:bytes error:&error])NSLog(@"Legend card: %@",error);
 }catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];}
}
- (void)rejectWallet:(NSString*)message{
 _gameKey=nil;
 _persistedCard.clear();
 _fusionSelection.reset();
 _core->close();
 dispatch_async(dispatch_get_main_queue(),^{
  ++self->_generation;
  self->_ready=NO;
  self->_operation=NO;
  self->_inFlight=NO;
  self->_analyzing=NO;
  self->_lastRam.reset();
  [self pause];
  self->_screen.image=nil;
  [self.view setNeedsLayout];
  if(self.presentedViewController)[self dismissViewControllerAnimated:NO completion:^{
   [self alert:@"Phiên game đã dừng" text:message];
  }];
  else [self alert:@"Phiên game đã dừng" text:message];
 });
}
- (NSString*)sealedSlotPath:(NSInteger)slot{return [[[self statePath:slot] stringByDeletingPathExtension] stringByAppendingPathExtension:@"slot"];}
- (NSString*)slotPurpose:(NSInteger)slot version:(NSString*)version{
 return [NSString stringWithFormat:@"slot/v1/%@/%ld/%@",_gameKey,(long)slot,version];
}
- (void)quickStatus:(NSString*)status{
 _quickNotice.text=status;
 _quickNotice.hidden=NO;
 UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,status);
 NSUInteger revision=++_quickNoticeRevision;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,static_cast<int64_t>(1.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
  if(revision==self->_quickNoticeRevision)self->_quickNotice.hidden=YES;
 });
}
- (void)preloadQuickSlot:(NSInteger)slot{
 dispatch_async(_worker,^{
  if(!self->_gameKey||!self->_core->isLoaded())return;
  NSString* path=[self sealedSlotPath:slot];
  NSString* purpose=[self slotPurpose:slot version:LGText(self->_core->coreVersion())];
  dispatch_async(self->_slotIO,^{
   if([NSFileManager.defaultManager fileExistsAtPath:path])
    [self->_quickSlots readState:path purpose:purpose error:nil];
  });
 });
}
- (NSData*)legacySlot:(NSString*)path key:(NSString*)gameKey version:(NSString*)version slot:(NSInteger)slot{
 NSData* bytes=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
 BOOL didUseOriginal=NO;
 if(!bytes&&slot==1){
  NSString* original=[[path stringByDeletingLastPathComponent]
   stringByAppendingPathComponent:[gameKey stringByAppendingPathExtension:@"state"]];
  bytes=[NSData dataWithContentsOfFile:original options:NSDataReadingMappedIfSafe error:nil];
  didUseOriginal=bytes!=nil;
 }
 if(!bytes.length||bytes.length>64*1024*1024)return nil;
 if(didUseOriginal)return bytes;
 NSData* meta=[NSData dataWithContentsOfFile:[path stringByAppendingString:@".json"]];
 if(!meta)return nil;
 id record=[NSJSONSerialization JSONObjectWithData:meta options:0 error:nil];
 if(![record isKindOfClass:NSDictionary.class])return nil;
 NSDictionary* metadata=record;
 if(![metadata[@"game_sha256"]isEqual:gameKey]||![metadata[@"version"]isEqual:version]||
    ![metadata[@"state_sha256"]isEqual:Digest(bytes)])return nil;
 return bytes;
}
- (void)save{
 if(!_ready||_operation)return;
 [self stopAuto];
 _operation=YES;
 NSInteger slot=_slot;
 NSUInteger generation=_generation;
 dispatch_async(_worker,^{
  try{self->_core->checkWallet();}
  catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
  auto state=self->_core->saveState();
  NSData* bytes=state.empty()?nil:[NSData dataWithBytes:state.data() length:state.size()];
  if(bytes){
   NSString* path=[self sealedSlotPath:slot];
   NSString* purpose=[self slotPurpose:slot version:LGText(self->_core->coreVersion())];
   [self persistCard];
   if(!self->_core->isLoaded())return;
   dispatch_async(self->_slotIO,^{
    NSError* error=nil;
    BOOL ok=[self->_quickSlots writeState:bytes path:path purpose:purpose error:&error];
    dispatch_async(dispatch_get_main_queue(),^{
     if(generation!=self->_generation)return;
     if(ok)[self quickStatus:[NSString stringWithFormat:@"Đã lưu slot %ld",(long)slot]];
     else [self alert:@"Không lưu được" text:error.localizedDescription?:@"Không ghi được slot."];
    });
   });
  }
  dispatch_async(dispatch_get_main_queue(),^{
   self->_operation=NO;
   if(!bytes)[self alert:@"Không lưu được" text:@"Core không tạo được save."];
  });
 });
}
- (void)load{
 if(!_ready||_operation)return;
 [self pause];
 ++_generation;
 _lastRam.reset();
 _operation=YES;
 NSInteger slot=_slot;
 dispatch_async(_worker,^{
  try{self->_core->checkWallet();}
  catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
  NSString* path=[self sealedSlotPath:slot],*oldPath=[self statePath:slot];
  NSString* identity=self->_gameKey,*version=LGText(self->_core->coreVersion());
  NSString* purpose=[self slotPurpose:slot version:version];
  BOOL allowLegacy=!self->_core->hasProtectedWallet();
  dispatch_async(self->_slotIO,^{
   NSError* error=nil;
   NSData* state=[NSFileManager.defaultManager fileExistsAtPath:path]?
    [self->_quickSlots readState:path purpose:purpose error:&error]:
    (allowLegacy?[self legacySlot:oldPath key:identity version:version slot:slot]:nil);
   dispatch_async(self->_worker,^{
    BOOL ok=NO,fatal=NO;
    try{self->_core->checkWallet();if(state){
     auto checkpoint=self->_core->saveState();
     auto card=self->_core->memoryCard();
     const auto* bytes=static_cast<const uint8_t*>(state.bytes);
     if(!checkpoint.empty()&&card.size()==131072){
      ok=self->_core->loadState({bytes,bytes+state.length})&&self->_core->setMemoryCard(card);
      if(ok)self->_needsNativeLoad=true;
      if(!ok){
       bool restored=self->_core->loadState(checkpoint);
       bool cardRestored=self->_core->setMemoryCard(card);
       fatal=!restored||!cardRestored;
       if(fatal){self->_gameKey=nil;self->_core->close();}
      }
     }
    }}catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
    dispatch_async(dispatch_get_main_queue(),^{
     self->_operation=NO;
     if(fatal)self->_ready=NO;
     [self releaseButtons];
     self->_hasSelected=NO;
     self->_duel={};
     [self->_overlay showView:self->_duel row:nullptr];
     if(ok){[self quickStatus:[NSString stringWithFormat:@"Đã tải slot %ld",(long)slot]];[self resume];}
     else [self alert:@"Chưa tải được slot" text:error.localizedDescription?:@"Slot trống, sai phiên bản hoặc không hợp lệ."];
    });
   });
  });
 });
}

- (void)pause{[self stopAuto];_paused=YES;_clock=0;[self releaseButtons];[_audioEngine pause];_core->audio.clear();}
- (void)resume{if(self.presentedViewController)return;[self resumePlayback];}
- (void)resumePlayback{if(!_ready||_background||_operation)return;_paused=NO;_clock=0;_frameDebt=0;NSError* error=nil;if(!_audioEngine)[self startAudio:&error];else [_audioEngine startAndReturnError:&error];if(error)NSLog(@"Legend audio: %@",error);}
- (void)background{_background=YES;_transactionCancelled.store(true);[self pause];dispatch_async(_worker,^{[self persistCard];});}
- (void)foreground{_background=NO;[self resume];}
- (void)audioInterrupted:(NSNotification*)note{NSNumber* type=note.userInfo[AVAudioSessionInterruptionTypeKey];if(type.unsignedIntegerValue==AVAudioSessionInterruptionTypeBegan)[self pause];else [self resume];}
- (void)startAudio:(NSError**)error {
 AVAudioSession* session=AVAudioSession.sharedInstance;if(![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:error])return;if(![session setActive:YES error:error])return;
 _audioEngine=[[AVAudioEngine alloc]init];AVAudioFormat* format=[[AVAudioFormat alloc]initStandardFormatWithSampleRate:_sampleRate channels:2];Legend::AudioRing* ring=&_core->audio;
 _audioSource=[[AVAudioSourceNode alloc]initWithFormat:format renderBlock:^OSStatus(BOOL* silence,const AudioTimeStamp* timestamp,AVAudioFrameCount frames,AudioBufferList* buffers){
  if(buffers->mNumberBuffers!=2||!buffers->mBuffers[0].mData||!buffers->mBuffers[1].mData){for(UInt32 i=0;i<buffers->mNumberBuffers;i++)if(buffers->mBuffers[i].mData)memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);*silence=YES;return noErr;}
  ring->render(static_cast<float*>(buffers->mBuffers[0].mData),static_cast<float*>(buffers->mBuffers[1].mData),frames);*silence=NO;return noErr;
 }];[_audioEngine attachNode:_audioSource];[_audioEngine connect:_audioSource to:_audioEngine.mainMixerNode format:format];_audioEngine.mainMixerNode.outputVolume=_muted?0:_volume;[_audioEngine startAndReturnError:error];
}
- (void)source:(unsigned)source mask:(uint16_t)mask{
 if(source>=3)return;if(source==1&&!_controllerEnabled)mask=0;if(mask&~_sources[source])[self stopAuto];if(_paused||_background||!_ready)mask=0;_sources[source]=mask;uint16_t next=_sources[0]|_sources[1]|_sources[2];for(unsigned i=0;i<14;i++)if((next^_combined)&(1<<i)){_core->input.button(i,(next&(1<<i))!=0);_pads[@(i)].highlighted=(next&(1<<i))!=0;}_combined=next;
}
- (void)button:(unsigned)id down:(BOOL)down source:(unsigned)source{if(source<3&&id<14)[self source:source mask:down?(_sources[source]|(1<<id)):(_sources[source]&~(1<<id))];}
- (void)controllers{
 __weak LGPlayer* weak=self;[self source:1 mask:0];
 for(GCController* controller in GCController.controllers){controller.handlerQueue=dispatch_get_main_queue();GCExtendedGamepad* pad=controller.extendedGamepad;if(!pad)continue;
  pad.valueChangedHandler=^(GCExtendedGamepad* p,GCControllerElement* element){LGPlayer* owner=weak;if(!owner)return;uint16_t mask=0;const unsigned ids[]={0,8,1,9,10,11,12,13};GCControllerButtonInput* buttons[]={p.buttonA,p.buttonB,p.buttonX,p.buttonY,p.leftShoulder,p.rightShoulder,p.leftTrigger,p.rightTrigger};for(unsigned i=0;i<8;i++)if(buttons[i].pressed)mask|=1<<ids[i];if(p.buttonOptions.pressed)mask|=1<<2;if(p.buttonMenu.pressed)mask|=1<<3;float x=p.dpad.xAxis.value,y=p.dpad.yAxis.value;if(fabs(p.leftThumbstick.xAxis.value)>fabs(x))x=p.leftThumbstick.xAxis.value;if(fabs(p.leftThumbstick.yAxis.value)>fabs(y))y=p.leftThumbstick.yAxis.value;if(x<-.4)mask|=1<<6;if(x>.4)mask|=1<<7;if(y>.4)mask|=1<<4;if(y<-.4)mask|=1<<5;[owner source:1 mask:mask];};
 }
}
- (BOOL)canBecomeFirstResponder{return YES;}
- (int)keyID:(UIKey*)key{switch(key.keyCode){case UIKeyboardHIDUsageKeyboardW:case UIKeyboardHIDUsageKeyboardUpArrow:return 4;case UIKeyboardHIDUsageKeyboardS:case UIKeyboardHIDUsageKeyboardDownArrow:return 5;case UIKeyboardHIDUsageKeyboardA:case UIKeyboardHIDUsageKeyboardLeftArrow:return 6;case UIKeyboardHIDUsageKeyboardD:case UIKeyboardHIDUsageKeyboardRightArrow:return 7;case UIKeyboardHIDUsageKeyboardK:return 0;case UIKeyboardHIDUsageKeyboardL:return 8;case UIKeyboardHIDUsageKeyboardJ:return 1;case UIKeyboardHIDUsageKeyboardI:return 9;case UIKeyboardHIDUsageKeyboardQ:return 10;case UIKeyboardHIDUsageKeyboardE:return 11;case UIKeyboardHIDUsageKeyboard1:return 12;case UIKeyboardHIDUsageKeyboard3:return 13;case UIKeyboardHIDUsageKeyboardC:return 2;case UIKeyboardHIDUsageKeyboardV:return 3;default:return -1;}}
- (void)pressesBegan:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event{
 BOOL handled=NO;
 for(UIPress* press in presses){
  UIKeyboardHIDUsage key=press.key.keyCode;
  if(key==UIKeyboardHIDUsageKeyboardF11){if(!_paused)[self save];handled=YES;}
  else if(key==UIKeyboardHIDUsageKeyboardF12){if(!_paused)[self load];handled=YES;}
  else if(key>=UIKeyboardHIDUsageKeyboardF1&&key<=UIKeyboardHIDUsageKeyboardF10){
   [self selectFusion:key-UIKeyboardHIDUsageKeyboardF1];handled=YES;
  }else{
   int id=[self keyID:press.key];
   if(id>=0){[self button:id down:YES source:2];handled=YES;}
  }
 }
 if(!handled)[super pressesBegan:presses withEvent:event];
}
- (void)pressesEnded:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event{BOOL handled=NO;for(UIPress* press in presses){int id=[self keyID:press.key];if(id>=0){[self button:id down:NO source:2];handled=YES;}}if(!handled)[super pressesEnded:presses withEvent:event];}
- (void)pressesCancelled:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event{[self pressesEnded:presses withEvent:event];}
- (void)cycleFusion{_fusionMode=(_fusionMode+1)%3;[NSUserDefaults.standardUserDefaults setInteger:_fusionMode forKey:@"fusion_mode"];[self advice:_duel];[self.view setNeedsLayout];}
- (void)advice:(const Legend::DuelView&)view{
 auto previous=_selected;BOOL had=_hasSelected;_duel=view;_hasSelected=NO;for(const auto& row:_duel.rows)if(had&&row.result==previous.result&&row.slots==previous.slots){_selected=row;_hasSelected=YES;break;}if(!_hasSelected&&!_duel.rows.empty()){_selected=_duel.rows.front();_hasSelected=YES;}
 [_overlay showView:_duel row:_hasSelected?&_selected:nullptr];if(_fusionMode==2){CGPoint offset=_guide.contentOffset;[_guide reloadData];[_guide layoutIfNeeded];offset.y=MAX(0,MIN(offset.y,_guide.contentSize.height-_guide.bounds.size.height));_guide.contentOffset=offset;}
}
- (NSInteger)tableView:(UITableView*)table numberOfRowsInSection:(NSInteger)section{return MAX(size_t(1),_duel.rows.size());}
- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)path{
 UITableViewCell* cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.backgroundColor=Ink();cell.textLabel.textColor=Gold();cell.textLabel.font=[UIFont boldSystemFontOfSize:12];cell.textLabel.numberOfLines=0;cell.detailTextLabel.textColor=UIColor.whiteColor;cell.detailTextLabel.font=[UIFont systemFontOfSize:11];cell.detailTextLabel.numberOfLines=0;
 if(_duel.rows.empty()){cell.textLabel.text=@"HƯỚNG DẪN FUSION · VIP";cell.detailTextLabel.text=!_ready?@"Mở game để xem gợi ý.":!_duel.duel?@"Chưa ở trong trận đấu":!_duel.active?@"Đang chờ lượt của bạn…":@"Chưa có Fusion với các lá / thứ tự đang chọn.";return cell;}
 const auto& r=_duel.rows[path.row];NSString* name=_data?LGText(_data->names[r.result]):@"";cell.textLabel.text=[NSString stringWithFormat:@"%@\n[%03d] %@",LGOrder(r.slots),r.result,name];NSMutableAttributedString* detail=[[NSMutableAttributedString alloc]init];NSString* a=[NSString stringWithFormat:@"ATK %d",r.atk];NSString* d=[NSString stringWithFormat:@" / DEF %d",r.def];[detail appendAttributedString:[[NSAttributedString alloc]initWithString:a attributes:@{NSForegroundColorAttributeName:r.atk>r.baseAtk?UIColor.systemGreenColor:UIColor.whiteColor}]];[detail appendAttributedString:[[NSAttributedString alloc]initWithString:d attributes:@{NSForegroundColorAttributeName:r.def>r.baseDef?UIColor.systemGreenColor:UIColor.whiteColor}]];
 if(r.bonus)[detail appendAttributedString:[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"\nHiệu ứng trên tay: %+d A/D",r.bonus]]];if(!r.better.empty())[detail appendAttributedString:[[NSAttributedString alloc]initWithString:[NSString stringWithFormat:@"\nĐổi: %@ (ATK %+d / DEF %+d). Hạ bài đã nâng để chọn lại.",LGOrder(r.better),r.lossAtk,r.lossDef] attributes:@{NSForegroundColorAttributeName:UIColor.systemOrangeColor}]];cell.detailTextLabel.attributedText=detail;cell.accessoryType=_hasSelected&&r.slots==_selected.slots&&r.result==_selected.result?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return cell;
}
- (void)tableView:(UITableView*)table didSelectRowAtIndexPath:(NSIndexPath*)path{[self selectFusion:path.row];}
- (CGFloat)tableView:(UITableView*)table heightForRowAtIndexPath:(NSIndexPath*)path{UITableViewCell* cell=[self tableView:table cellForRowAtIndexPath:path];CGFloat width=MAX(30,table.bounds.size.width-44);return MAX(64,24+[cell.textLabel sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)].height+[cell.detailTextLabel sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)].height);}
- (void)showVIP{[self pause];if(!_data){[self alert:@"VIP" text:@"Mở game có dữ liệu VIP trước. Nếu vừa mở, chờ đọc dữ liệu một lát."];return;}LGVipController* vip=[[LGVipController alloc]initWithData:_data queue:_analysis ram:_lastRam];__weak LGPlayer* weak=self;vip.closed=^{[weak resumePlayback];};[self presentViewController:vip animated:YES completion:nil];}
- (void)showGacha{
 [self pause];
 if(!_ready||!_data||_data->cardCount!=800||_operation){
  [self alert:@"Gacha" text:@"Hãy mở Mod 2 và LOAD trong game."];
  return;
 }
 NSURL* media=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"gacha" isDirectory:YES];
 if(![NSFileManager.defaultManager fileExistsAtPath:[media URLByAppendingPathComponent:@"open.mp4"].path]){
  [self alert:@"Gacha" text:@"Bản kiểm thử này chưa có tài nguyên Gacha."];
  return;
 }
 auto game=_data;
 auto generation=_generation;
 dispatch_async(_worker,^{
  NSInteger stars=-1;
  NSString* message=nil;
  try{
   if(!self->_core->hasProtectedWallet())throw std::runtime_error("Hãy mở bản Mod 2 được hỗ trợ.");
   self->_core->checkWallet();
   auto ram=self->_core->ramSnapshot();
   stars=Legend::Gacha::inspect(ram);
   auto saved=Legend::Gacha::savedPayload(self->_core->memoryCard());
   if(self->_needsNativeLoad&&!Legend::Gacha::walletMatches(saved,ram))
    throw std::runtime_error("Hãy LOAD trong game trước khi mở Gacha.");
   self->_needsNativeLoad=false;
  }catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
  catch(const std::exception& failure){message=LGText(failure.what());}
  dispatch_async(dispatch_get_main_queue(),^{
   if(generation!=self->_generation||self->_background)return;
   if(message){[self alert:@"Gacha" text:message];return;}
   LGGachaController* scene=[[LGGachaController alloc]initWithData:game stars:stars media:media queue:self->_analysis];
   __weak LGPlayer* weak=self;
   scene.closed=^{[weak resumePlayback];};
   scene.openPacks=^(NSInteger quantity,NSInteger quote,void(^reply)(NSInteger,NSArray<NSNumber*>*,NSString*)){
    [weak gachaAction:quantity quoted:quote code:nil reply:reply];
   };
   scene.gift=^(NSString* code,void(^reply)(NSInteger,NSString*)){
    [weak gachaAction:0 quoted:0 code:code reply:^(NSInteger stars,NSArray<NSNumber*>* cards,NSString* error){reply(stars,error);}];
   };
   [self presentViewController:scene animated:YES completion:nil];
  });
 });
}
- (void)gachaAction:(NSInteger)quantity quoted:(NSInteger)quote code:(NSString*)code
              reply:(void(^)(NSInteger,NSArray<NSNumber*>*,NSString*))reply{
 if(!_ready||_operation||_background){reply(-1,nil,@"Game đang chuyển màn hình.");return;}
 _operation=YES;
 _transactionCancelled.store(false);
 dispatch_async(_worker,^{
  NSString* message=nil;
  NSInteger stars=-1;
  NSMutableArray<NSNumber*>* cards=[NSMutableArray array];
  try{
   self->_core->checkWallet();
   if(!self->_core->hasProtectedWallet())throw std::runtime_error("Hãy mở bản Mod 2 được hỗ trợ.");
   Legend::CoreTransaction transaction(*self->_core,self->_transactionCancelled,[self](const Legend::Bytes& card){
    NSError* error=nil;
    if(![self commitCard:card error:&error])
     throw std::runtime_error(error.localizedDescription.UTF8String?:"Không ghi được SAVE.");
   });
   if(quantity){
    auto result=Legend::Gacha::draw(transaction,int(quantity),int(quote),self->_needsNativeLoad);
    stars=result.stars;
    for(int id:result.cards)[cards addObject:@(id)];
   }else{
    if(!self->_giftCodes)throw std::runtime_error("Khóa xác thực mã quà chưa sẵn sàng.");
    NSError* error=nil;
    stars=[self->_giftCodes redeem:code game:transaction requireNativeLoad:self->_needsNativeLoad error:&error];
    if(stars<0)message=error.localizedDescription?:@"Không đổi được mã quà.";
   }
   if(!message)self->_needsNativeLoad=false;
  }catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
  catch(const Legend::RollbackFailed& failure){[self rejectWallet:LGText(failure.what())];return;}
  catch(const std::exception& failure){message=LGText(failure.what());}
  dispatch_async(dispatch_get_main_queue(),^{
   self->_operation=NO;
   reply(stars,cards,message);
  });
 });
}
- (void)showCollection{
 [self pause];
 if(!_ready||!_data||_operation){
  [self alert:@"Chest / Deck" text:@"Hãy mở game và vào Chest / Build Deck."];
  return;
 }
 auto data=_data;
 auto generation=_generation;
 dispatch_async(_worker,^{
  std::optional<Legend::CollectionSnapshot> snapshot;
  try{snapshot=Legend::CollectionSnapshot::inspect(self->_core->ramSnapshot(),data->cardCount);}
  catch(const std::exception& error){NSLog(@"Legend Chest / Deck: %s",error.what());}
  dispatch_async(dispatch_get_main_queue(),^{
   if(generation!=self->_generation||self->_background)return;
   if(!snapshot){
    [self alert:@"Chest / Deck" text:@"Hãy mở Chest / Build Deck và đợi màn hình ổn định."];
    return;
   }
   LGCollectionController* collection=[[LGCollectionController alloc]initWithData:data snapshot:*snapshot queue:self->_analysis];
   __weak LGPlayer* weak=self;
   collection.closed=^{[weak resumePlayback];};
   collection.applyPlan=^(const Legend::DeckPlan& plan,void(^finished)(NSString*)){
    [weak applyCollection:*snapshot plan:plan completion:finished];
   };
   UINavigationController* navigation=[[UINavigationController alloc]initWithRootViewController:collection];
   navigation.modalPresentationStyle=UIModalPresentationFullScreen;
   navigation.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
   [self presentViewController:navigation animated:YES completion:nil];
  });
 });
}
- (void)applyCollection:(const Legend::CollectionSnapshot&)snapshot plan:(const Legend::DeckPlan&)choice
             completion:(void(^)(NSString*))completion{
 if(!_ready||_operation||_background){completion(@"Game đang chuyển màn hình.");return;}
 [self pause];
 _operation=YES;
 _transactionCancelled.store(false);
 Legend::CollectionSnapshot inventory=snapshot;
 auto cards=choice.cards;
 dispatch_async(_worker,^{
  NSString* error=nil;
  BOOL fatal=NO;
  try{
   Legend::CoreTransaction transaction(*self->_core,self->_transactionCancelled);
   Legend::applyDeck(transaction,inventory,cards);
  }catch(const Legend::WalletRejected& problem){
   [self rejectWallet:LGText(problem.what())];
   return;
  }catch(const Legend::RollbackFailed& problem){
   self->_gameKey=nil;
   self->_core->close();
   error=LGText(problem.what());
   fatal=YES;
  }catch(const std::exception& problem){error=LGText(problem.what());}
  dispatch_async(dispatch_get_main_queue(),^{
   self->_operation=NO;
   if(fatal)self->_ready=NO;
   completion(error);
   if(!error)UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
    @"Đã xếp 40 lá. Thoát Chest / Deck trong game để nhận bộ bài.");
  });
 });
}
- (LGSettingsController*)configuredSettings{
 LGSettingsController* settings=[[LGSettingsController alloc]initWithStyle:UITableViewStyleInsetGrouped];settings.fusionMode=_fusionMode;settings.slot=_slot;settings.speed=_speed;settings.volume=_volume;settings.bundledGame=[self hasBundledGame];settings.imageFilter=_imageFilter.load();__weak LGPlayer* weak=self;
 settings.changed=^(LGSettingsController* s){LGPlayer* owner=weak;if(!owner)return;owner->_fusionMode=s.fusionMode;BOOL slotChanged=owner->_slot!=s.slot;owner->_slot=s.slot;[owner setPlaybackSpeed:s.speed];[owner setImageFilter:int(s.imageFilter)];owner->_volume=s.volume;owner->_audioEngine.mainMixerNode.outputVolume=owner->_muted?0:s.volume;NSUserDefaults* p=NSUserDefaults.standardUserDefaults;[p setInteger:s.fusionMode forKey:@"fusion_mode"];[p setInteger:s.slot forKey:@"save_slot"];[p setFloat:s.volume forKey:@"volume"];if(slotChanged)[owner preloadQuickSlot:s.slot];[owner.view setNeedsLayout];};
 settings.closed=^{[weak resumePlayback];};settings.command=^(NSString* command){[weak command:command];};return settings;
}
- (void)setImageFilter:(int)mode{
 _imageFilter.store(mode);
 _screen.layer.magnificationFilter=mode?kCAFilterLinear:kCAFilterNearest;
 _screen.layer.minificationFilter=mode?kCAFilterLinear:kCAFilterNearest;
 [NSUserDefaults.standardUserDefaults setInteger:mode forKey:@"filter_mode"];
}
- (UIImage*)frameImageIfChanged:(BOOL)changed{
 auto& frame=_core->frame;
 int mode=_imageFilter.load();
 if(frame.rgba.empty()||(!changed&&mode==_renderedFilter))return nil;
 _renderedFilter=mode;
 if(mode)frame.sharpen(_filteredPixels,mode);
 const auto& pixels=mode?_filteredPixels:frame.rgba;
 NSData* bytes=[NSData dataWithBytes:pixels.data() length:pixels.size()];
 CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)bytes);
 CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
 CGImageRef cg=CGImageCreate(frame.width,frame.height,8,32,frame.width*4,space,
  kCGImageAlphaLast|kCGBitmapByteOrder32Big,provider,NULL,NO,kCGRenderingIntentDefault);
 UIImage* image=cg?[UIImage imageWithCGImage:cg]:nil;
 if(cg)CGImageRelease(cg);
 CGColorSpaceRelease(space);
 CGDataProviderRelease(provider);
 return image;
}
- (void)settings{
 [self pause];LGSettingsController* settings=[self configuredSettings];UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:settings];nav.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;nav.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:nav animated:YES completion:nil];
}
- (void)command:(NSString*)command{
 if([command isEqualToString:@"bios"]){[self pick:YES];return;}if([command isEqualToString:@"license"]){NSString* path=[NSBundle.mainBundle pathForResource:@"LICENSES" ofType:@"txt"];NSString* text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]?:@"SwanStation — GPLv3\nMã nguồn: https://github.com/xuyendem249-cloud/Mod_LOGs";UIViewController* vc=[[UIViewController alloc]init];vc.title=@"Mã nguồn & giấy phép";UITextView* view=[[UITextView alloc]init];view.text=text;view.editable=NO;view.backgroundColor=Ink();view.textColor=UIColor.whiteColor;view.font=[UIFont systemFontOfSize:13];vc.view=view;vc.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Đóng" style:UIBarButtonItemStyleDone target:self action:@selector(closeDocument)];UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:vc];nav.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:nav animated:YES completion:nil];return;}
 if(!_ready){[self alert:@"Chưa mở game" text:@"Hãy mở đúng game trước."];return;}
 if([command isEqualToString:@"reset"])[self confirm:@"Khởi động lại game?" text:@"Thẻ nhớ được lưu trước khi khởi động lại. Tiến trình chưa lưu trong game sẽ mất." action:^{++self->_generation;self->_lastRam.reset();self->_operation=YES;dispatch_async(self->_worker,^{[self persistCard];try{self->_core->reset();self->_needsNativeLoad=true;}catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;self->_duel={};self->_hasSelected=NO;[self->_overlay showView:self->_duel row:nullptr];[self resumePlayback];});});}];
}
- (void)closeDocument{[self dismissViewControllerAnimated:YES completion:^{[self resumePlayback];}];}
- (void)confirm:(NSString*)title text:(NSString*)text action:(void(^)(void))callback{UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[self resumePlayback];}]];[a addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){callback();}]];[self presentViewController:a animated:YES completion:nil];}
- (void)tick:(CADisplayLink*)link {
 if(!_ready||_paused||_background||_inFlight)return;double now=link.timestamp;if(!_clock)_clock=now-1.0/_fps;double elapsed=std::clamp(now-_clock,0.,.1);_clock=now;_frameDebt+=elapsed*_fps*_speed;int count=MIN(8,int(_frameDebt));if(count<1)return;_frameDebt-=count;_inFlight=YES;NSUInteger generation=_generation;BOOL snapshot=!_analyzing&&now-_lastSnapshot>=.15;if(snapshot){_analyzing=YES;_lastSnapshot=now;}
 dispatch_async(_worker,^{BOOL changed=NO;try{for(int i=0;i<count;i++){
 if(![self stepFusion]&&self->_autoEnabled.load()&&self->_auto){uint64_t ticket=self->_autoGeneration.load();Legend::Bytes ram;const Legend::Bytes* snapshot=nullptr;if(self->_autoFrame>=self->_auto->nextDecision&&self->_autoFrame>=self->_auto->releaseAt){ram=self->_core->ramSnapshot();snapshot=&ram;}int mask=self->_auto->next(snapshot,self->_autoFrame++);
  if(ticket==self->_autoGeneration.load()&&self->_autoEnabled.load()){self->_core->setAutoMask(mask);if(self->_auto->stopped){self->_autoEnabled.store(false);self->_core->autoInput.store(0);dispatch_async(dispatch_get_main_queue(),^{if(ticket==self->_autoGeneration.load()){self->_logo.running=NO;UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,@"Auto đã tắt");}});}}
 }
 changed=self->_core->run()||changed;}}catch(const Legend::WalletRejected& failure){[self rejectWallet:LGText(failure.what())];return;}
  UIImage* image=[self frameImageIfChanged:changed];
  if(now-self->_lastCardFlush>=10){[self persistCard];self->_lastCardFlush=now;}
  if(snapshot){auto ram=std::make_shared<Legend::Bytes>(self->_core->ramSnapshot());dispatch_async(self->_analysis,^{Legend::DuelView view;try{if(self->_advisor)view=self->_advisor->analyze(*ram);}catch(const std::exception& e){NSLog(@"Legend Fusion: %s",e.what());}dispatch_async(dispatch_get_main_queue(),^{self->_analyzing=NO;if(generation==self->_generation){self->_lastRam=ram;[self advice:view];}});});}
  dispatch_async(dispatch_get_main_queue(),^{if(generation==self->_generation&&image)self->_screen.image=image;self->_inFlight=NO;});
 });
}


@end

@interface LGApp:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow* window;
@end
@implementation LGApp
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options{self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[[LGPlayer alloc]init];[self.window makeKeyAndVisible];return YES;}
@end
int main(int argc,char** argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(LGApp.class));}}
