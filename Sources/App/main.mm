#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuartzCore/QuartzCore.h>
#include "PlayerCore.hpp"
#include <memory>
#include <cmath>
#import "LegendViews.hpp"
#import <GameController/GameController.h>
#include "CompatibilityTables.hpp"
#include "ControllerGeometry.hpp"

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
 [super drawRect:rect];NSInteger key=self.padID;if(key<0||key>=10)return;
 CGContextRef c=UIGraphicsGetCurrentContext();CGFloat cx=CGRectGetMidX(self.bounds),cy=CGRectGetMidY(self.bounds),r=MIN(rect.size.width,rect.size.height)*.23;
 UIColor* color=key==0?[UIColor colorWithRed:.5 green:.73 blue:1 alpha:1]:key==1?[UIColor colorWithRed:.85 green:.59 blue:.85 alpha:1]:key==8?[UIColor colorWithRed:1 green:.52 blue:.57 alpha:1]:key==9?[UIColor colorWithRed:.55 green:.88 blue:.64 alpha:1]:Gold();
 CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetFillColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,MAX(2,r*.15));CGContextSetLineJoin(c,kCGLineJoinRound);
 switch(key){
 case 0:CGContextMoveToPoint(c,cx-r,cy-r);CGContextAddLineToPoint(c,cx+r,cy+r);CGContextMoveToPoint(c,cx+r,cy-r);CGContextAddLineToPoint(c,cx-r,cy+r);break;
 case 1:CGContextStrokeRect(c,CGRectMake(cx-r,cy-r,r*2,r*2));return;
 case 2:CGContextFillRect(c,CGRectMake(cx-r,cy-2,r*2,4));return;
 case 3:CGContextMoveToPoint(c,cx-r*.65,cy-r);CGContextAddLineToPoint(c,cx+r,cy);CGContextAddLineToPoint(c,cx-r*.65,cy+r);CGContextClosePath(c);break;
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
 BOOL _inFlight,_ready,_paused,_background,_pickingBIOS,_operation;
 double _fps,_sampleRate,_clock;
 NSString* _root;
 NSString* _gameKey;
 CADisplayLink* _displayLink;
 AVAudioEngine* _audioEngine;
 AVAudioSourceNode* _audioSource;
 UIImageView* _screen;
 UIImageView* _logo;
 UILabel* _placeholder;
 UILabel* _credit;
 UIView* _toolbar;
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
 NSInteger _fusionMode,_slot,_pickMode;
 NSUInteger _generation;
 double _speed,_frameDebt,_lastSnapshot,_lastCardFlush;
 float _volume;
 UIButton* _fusion;
 LGFusionOverlay* _overlay;
 UITableView* _guide;
 LGDirectionPad* _dpad;
 uint16_t _sources[3],_combined;
 UIImageView* _welcome;

}
@end

@implementation LGPlayer
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskAllButUpsideDown;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (void)viewDidLoad {
 [super viewDidLoad];self.view=[[LGBackdrop alloc]initWithFrame:self.view.bounds];self.view.multipleTouchEnabled=YES;
 UIApplication.sharedApplication.idleTimerDisabled=YES;
 _core=std::make_unique<Legend::PlayerCore>();_worker=dispatch_queue_create("vn.anhchugia35.legend.core",DISPATCH_QUEUE_SERIAL);_fps=59.94;_sampleRate=44100;
 _analysis=dispatch_queue_create("vn.anhchugia35.legend.analysis",DISPATCH_QUEUE_SERIAL);
 NSUserDefaults* prefs=NSUserDefaults.standardUserDefaults;_fusionMode=MAX(0,MIN(2,[prefs integerForKey:@"fusion_mode"]));_slot=MAX(1,MIN(10,[prefs integerForKey:@"save_slot"]));_speed=[prefs doubleForKey:@"speed"];if(_speed<1||_speed>4)_speed=1;_volume=[prefs objectForKey:@"volume"]?[prefs floatForKey:@"volume"]:.8;
 NSString* docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;_root=[docs stringByAppendingPathComponent:@"Legend"];
 for(NSString* name in @[@"system",@"saves",@"content"]) [[NSFileManager defaultManager] createDirectoryAtPath:[_root stringByAppendingPathComponent:name] withIntermediateDirectories:YES attributes:nil error:nil];
 _screen=[[UIImageView alloc]init];_screen.backgroundColor=UIColor.blackColor;_screen.contentMode=UIViewContentModeScaleToFill;_screen.layer.magnificationFilter=kCAFilterNearest;_screen.clipsToBounds=YES;[self.view addSubview:_screen];
 _placeholder=[[UILabel alloc]init];_placeholder.text=@"LEGEND\n\nMở menu ☰ để nhập BIOS và chọn game\nLegend Player iOS 0.3.1";_placeholder.textColor=Gold();_placeholder.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];_placeholder.numberOfLines=0;_placeholder.textAlignment=NSTextAlignmentCenter;[_screen addSubview:_placeholder];
 _welcome=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"welcome.png"]];_welcome.contentMode=UIViewContentModeScaleAspectFit;[_screen addSubview:_welcome];
 _overlay=[[LGFusionOverlay alloc]init];[_screen addSubview:_overlay];
 _guide=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];_guide.dataSource=self;_guide.delegate=self;_guide.backgroundColor=Ink();_guide.rowHeight=UITableViewAutomaticDimension;_guide.estimatedRowHeight=100;_guide.separatorColor=[Gold()colorWithAlphaComponent:.3];[self.view addSubview:_guide];
 _toolbar=[[UIView alloc]init];[self.view addSubview:_toolbar];
 _menu=[self tool:@"☰" action:@selector(menu)];_menu.accessibilityLabel=@"Menu";_save=[self tool:@"Lưu" action:@selector(save)];_load=[self tool:@"Tải" action:@selector(load)];_fusion=[self tool:@"Fusion" action:@selector(cycleFusion)];_fusion.titleLabel.font=[UIFont boldSystemFontOfSize:11];
 _credit=[[UILabel alloc]init];_credit.text=@"By AnhChuGia35";_credit.textColor=[Gold() colorWithAlphaComponent:.8];_credit.font=[UIFont systemFontOfSize:10];_credit.textAlignment=NSTextAlignmentCenter;[_toolbar addSubview:_credit];
 _logo=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"AppLogo.png"]];_logo.contentMode=UIViewContentModeScaleAspectFit;[self.view addSubview:_logo];
 _pads=[NSMutableDictionary dictionary];NSArray* names=@[@"X",@"Vuông",@"Select",@"Start",@"Lên",@"Xuống",@"Trái",@"Phải",@"Tròn",@"Tam giác",@"L1",@"R1",@"L2",@"R2"];
 __weak LGPlayer* weak=self;
 for(NSInteger i=0;i<14;i++){LGPadButton* b=[[LGPadButton alloc]init];b.padID=i;b.accessibilityLabel=names[i];if(i>=10)[b setTitle:names[i] forState:UIControlStateNormal];b.change=^(BOOL down){LGPlayer* owner=weak;if(owner&&owner->_core)[owner button:(unsigned)i down:down source:0];};_pads[@(i)]=b;[self.view addSubview:b];}
 _dpad=[[LGDirectionPad alloc]init];_dpad.backgroundColor=UIColor.clearColor;_dpad.changed=^(uint16_t mask){LGPlayer* owner=weak;if(owner){uint16_t next=(owner->_sources[0]&~uint16_t(0xf0))|mask;[owner source:0 mask:next];}};[self.view addSubview:_dpad];
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllers) name:GCControllerDidConnectNotification object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllers) name:GCControllerDidDisconnectNotification object:nil];[self controllers];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationWillResignActiveNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
 _displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];_displayLink.preferredFrameRateRange=CAFrameRateRangeMake(30,60,60);[_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (UIButton*)tool:(NSString*)title action:(SEL)action{LGPadButton* b=[[LGPadButton alloc]init];[b setTitle:title forState:UIControlStateNormal];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[_toolbar addSubview:b];return b;}
- (void)releaseButtons{_sources[0]=_sources[1]=_sources[2]=_combined=0;_core->input.clear();for(LGPadButton* b in _pads.allValues)b.highlighted=NO;}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self becomeFirstResponder];if(!_operation)[self resume];
 if([NSProcessInfo.processInfo.environment[@"LEGEND_SMOKE"] isEqualToString:@"1"]){[self.view layoutIfNeeded];BOOL valid=_pads.count==14&&_screen.frame.size.width>0&&_screen.frame.size.height>0;for(LGPadButton* b in _pads.allValues)valid=valid&&CGRectContainsRect(self.view.bounds,b.frame)&&b.frame.size.width>0&&b.frame.size.height>0;
 NSDictionary* report=@{@"app_launched":@YES,@"all_14_buttons_inside_view":@(valid),@"game_or_bios_tested":@NO};NSData* json=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];[json writeToFile:[_root stringByAppendingPathComponent:@"simulator_smoke.json"] atomically:YES];}
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{[self releaseButtons];_clock=0;[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context){[self.view setNeedsLayout];} completion:nil];}
- (void)cluster:(CGRect)area right:(BOOL)right {
 CGFloat s=MIN(area.size.width,area.size.height);CGRect box=CGRectMake(CGRectGetMidX(area)-s/2,CGRectGetMidY(area)-s/2,s,s);CGFloat u=s/3;
 NSArray* ids=right?@[@9,@0,@1,@8]:@[@4,@5,@6,@7];const CGPoint points[4]={CGPointMake(1,0),CGPointMake(1,2),CGPointMake(0,1),CGPointMake(2,1)};
 for(NSUInteger i=0;i<4;i++){CGPoint p=points[i];_pads[ids[i]].frame=CGRectInset(CGRectMake(box.origin.x+p.x*u,box.origin.y+p.y*u,u,u),2,2);}
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];CGRect a=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);Legend::ControllerGeometry g(a.size.width,a.size.height,_fusionMode==2);CGPoint o=a.origin;
 _screen.frame=LGRect(g.fittedGame(),o);_guide.frame=LGRect(g.guide,o);_guide.hidden=_fusionMode!=2;_toolbar.frame=LGRect(g.toolbar,o);
 _pads[@10].frame=LGRect(g.shoulder(false,false),o);_pads[@12].frame=LGRect(g.shoulder(false,true),o);_pads[@13].frame=LGRect(g.shoulder(true,false),o);_pads[@11].frame=LGRect(g.shoulder(true,true),o);
 [self cluster:LGRect(g.pad(false),o) right:NO];[self cluster:LGRect(g.pad(true),o) right:YES];_dpad.frame=LGRect(g.pad(false),o);
 _pads[@2].frame=LGRect(g.selectStart(false),o);_pads[@3].frame=LGRect(g.selectStart(true),o);_logo.frame=LGRect(g.logo(),o);
 _placeholder.frame=CGRectInset(_screen.bounds,20,20);_welcome.frame=CGRectInset(_screen.bounds,10,10);_welcome.hidden=_ready;_overlay.frame=_screen.bounds;_overlay.hidden=_fusionMode==0;
 CGFloat tw=_toolbar.bounds.size.width,th=_toolbar.bounds.size.height;_menu.frame=CGRectMake(1,1,38,th-2);_fusion.frame=CGRectMake(42,1,66,th-2);_load.frame=CGRectMake(tw-51,1,50,th-2);_save.frame=CGRectMake(tw-104,1,50,th-2);_save.titleLabel.font=_load.titleLabel.font=[UIFont systemFontOfSize:12];_credit.frame=CGRectMake(110,22,MAX(0,tw-216),13);_credit.hidden=tw<280;
 [_fusion setTitle:_fusionMode==0?@"Fusion: Tắt":_fusionMode==1?@"Fusion: Số":@"Fusion: VIP" forState:0];[_fusion setTitleColor:_fusionMode?Gold():UIColor.whiteColor forState:0];_fusion.accessibilityLabel=@[@"Fusion tắt",@"Fusion chỉ đánh số thứ tự",@"Fusion số và bảng hướng dẫn"][_fusionMode];
 _save.enabled=_load.enabled=_ready;_save.alpha=_load.alpha=_ready?1:.4;[self.view setNeedsDisplay];
}

- (void)alert:(NSString*)title text:(NSString*)text{UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];__weak LGPlayer* weak=self;[a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];[self presentViewController:a animated:YES completion:nil];}
- (void)menu {
 [self pause];UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Legend Player" message:nil preferredStyle:UIAlertControllerStyleActionSheet];__weak LGPlayer* weak=self;
 [a addAction:[UIAlertAction actionWithTitle:@"Mở game ISO / BIN / IMG" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak pick:NO];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"VIP · Deck / Drop / Fusion" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak showVIP];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Cấu hình" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak settings];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];
 a.popoverPresentationController.sourceView=_menu;a.popoverPresentationController.sourceRect=_menu.bounds;[self presentViewController:a animated:YES completion:nil];
}

- (void)pick:(BOOL)bios{_pickMode=bios?1:0;[self pickMode:_pickMode];}
- (void)pickMode:(NSInteger)mode{[self pause];_pickMode=mode;_pickingBIOS=mode==1;_operation=YES;UIDocumentPickerViewController* picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeData] asCopy:NO];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];}
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
 if(_pickMode==3){_operation=NO;[self resumePlayback];return;}
 if(_pickMode==2){[self importCardURL:urls.firstObject];return;}
 if(!urls.count){_operation=NO;[self resume];return;}BOOL bios=_pickingBIOS;NSURL* url=urls.firstObject;[self pause];_operation=YES;_menu.enabled=NO;_placeholder.hidden=NO;_placeholder.text=@"Đang nhập file…";NSUInteger generation=_generation;if(!bios){generation=++_generation;_data.reset();_lastRam.reset();_duel={};_hasSelected=NO;dispatch_async(_analysis,^{self->_advisor.reset();self->_analysisData.reset();});}
 dispatch_async(_worker,^{NSError* error=nil;NSString* file=[self importURL:url bios:bios error:&error];BOOL success=file!=nil;
  if(success&&!bios){[self persistCard];NSString* key=file.lastPathComponent.stringByDeletingPathExtension;NSString* cardFile=[[self->_root stringByAppendingPathComponent:@"saves"]stringByAppendingPathComponent:[key stringByAppendingPathExtension:@"mcr"]];NSData* oldCard=[NSData dataWithContentsOfFile:cardFile];BOOL cardValid=![NSFileManager.defaultManager fileExistsAtPath:cardFile]||(oldCard.length==131072&&((const uint8_t*)oldCard.bytes)[0]=='M'&&((const uint8_t*)oldCard.bytes)[1]=='C');std::string problem;if(!cardValid)problem="Thẻ nhớ cũ không hợp lệ. Giữ nguyên file để khôi phục.";success=cardValid&&self->_core->open(file.UTF8String,self->_root.UTF8String,problem);if(!success)error=Failure([NSString stringWithUTF8String:problem.c_str()]);else{self->_gameKey=file.lastPathComponent.stringByDeletingPathExtension;self->_core->setSpeed(self->_speed);NSData* card=[NSData dataWithContentsOfFile:[self cardPath]];if(card.length==131072){const auto* b=static_cast<const uint8_t*>(card.bytes);self->_core->setMemoryCard({b,b+card.length});}}}
  if(success&&!bios){dispatch_async(self->_analysis,^{std::shared_ptr<Legend::GameData> data;try{data=std::make_shared<Legend::GameData>(file.UTF8String);}catch(const std::exception& e){NSLog(@"Legend VIP: %s",e.what());}self->_advisor.reset();self->_analysisData=data;if(data)self->_advisor=std::make_unique<Legend::FusionAdvisor>(*data,Legend::defaultCompatibility().handSignatures);dispatch_async(dispatch_get_main_queue(),^{if(generation!=self->_generation)return;self->_data=data;[self->_guide reloadData];});});}
  double fps=self->_core->fps,rate=self->_core->sampleRate;BOOL loaded=self->_core->isLoaded();
  dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;self->_menu.enabled=YES;self->_ready=loaded;self->_fps=fps;self->_sampleRate=rate;self->_placeholder.hidden=loaded;if(!bios){self->_hasSelected=NO;self->_duel={};[self->_overlay showView:self->_duel row:nullptr];[self->_audioEngine stop];self->_audioEngine=nil;self->_audioSource=nil;self->_screen.image=nil;}[self.view setNeedsLayout];
   if(!success){self->_placeholder.text=@"LEGEND\n\nMở menu để nhập BIOS và chọn game";[self alert:@"Không nhập được file" text:error.localizedDescription?:@"Lỗi đọc file."];}
   else if(bios){self->_placeholder.text=@"LEGEND\n\nĐã nhập BIOS · Chọn Mở game trong menu";[self alert:@"Đã nhập BIOS" text:@"Chọn Mở game trong menu để bắt đầu. BIOS mới sẽ được dùng khi mở game lại."];}
   if(success)[self resume];
  });
 });
}
- (NSString*)cardPath{return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[_gameKey stringByAppendingPathExtension:@"mcr"]];}
- (NSString*)statePath:(NSInteger)slot{return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_slot%02ld.state",_gameKey,(long)slot]];}
- (void)persistCard{if(!_gameKey)return;auto bytes=_core->memoryCard();if(bytes.empty())return;NSData* data=[NSData dataWithBytes:bytes.data() length:bytes.size()];NSError* error=nil;if(![data writeToFile:[self cardPath] options:NSDataWritingAtomic error:&error])NSLog(@"Legend card: %@",error);}
- (BOOL)backup:(NSString*)path{if(![NSFileManager.defaultManager fileExistsAtPath:path])return YES;NSData* old=[NSData dataWithContentsOfFile:path];return old&&[old writeToFile:[path stringByAppendingString:@".bak"] options:NSDataWritingAtomic error:nil];}
- (void)save{
 if(!_ready||_operation)return;[self pause];_operation=YES;NSInteger slot=_slot;dispatch_async(_worker,^{auto state=self->_core->saveState();NSData* bytes=state.empty()?nil:[NSData dataWithBytes:state.data() length:state.size()];NSString* path=[self statePath:slot];NSString* meta=[path stringByAppendingString:@".json"];NSError* error=nil;BOOL ok=bytes!=nil;
 if(ok){NSDictionary* record=@{@"game_sha256":self->_gameKey,@"state_sha256":Digest(bytes),@"version":LGText(self->_core->coreVersion()),@"slot":@(slot),@"created":@(NSDate.date.timeIntervalSince1970)};NSData* json=[NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted error:&error];ok=[self backup:path]&&[self backup:meta]&&json&&[bytes writeToFile:path options:NSDataWritingAtomic error:&error]&&[json writeToFile:meta options:NSDataWritingAtomic error:&error];}[self persistCard];dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;[self alert:ok?@"Đã lưu nhanh":@"Không lưu được" text:ok?[NSString stringWithFormat:@"Slot %ld · riêng cho game này",(long)slot]:error.localizedDescription?:@"Core không tạo được save."];});});
}
- (void)load{
 if(!_ready||_operation)return;[self pause];++_generation;_lastRam.reset();_operation=YES;NSInteger slot=_slot;dispatch_async(_worker,^{NSString* path=[self statePath:slot];BOOL legacy=NO;NSData* bytes=[NSData dataWithContentsOfFile:path];if(!bytes&&slot==1){path=[[self->_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[self->_gameKey stringByAppendingPathExtension:@"state"]];bytes=[NSData dataWithContentsOfFile:path];legacy=bytes!=nil;}
 NSDictionary* meta=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[path stringByAppendingString:@".json"]]?:[NSData data] options:0 error:nil];BOOL valid=legacy||([meta[@"game_sha256"]isEqualToString:self->_gameKey]&&[meta[@"version"]isEqualToString:LGText(self->_core->coreVersion())]&&[meta[@"state_sha256"]isEqualToString:Digest(bytes?:[NSData data])]);BOOL ok=NO;if(valid&&bytes.length&&bytes.length<=64*1024*1024){const auto* p=static_cast<const uint8_t*>(bytes.bytes);ok=self->_core->loadState({p,p+bytes.length});}dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;[self releaseButtons];self->_hasSelected=NO;self->_duel={};[self->_overlay showView:self->_duel row:nullptr];if(ok)[self resume];else [self alert:@"Chưa tải được slot" text:@"Slot trống, khác phiên bản core hoặc checksum không đúng. Bản lưu cũ vẫn được giữ nguyên."];});});
}

- (void)pause{_paused=YES;_clock=0;[self releaseButtons];[_audioEngine pause];_core->audio.clear();}
- (void)resume{if(self.presentedViewController)return;[self resumePlayback];}
- (void)resumePlayback{if(!_ready||_background||_operation)return;_paused=NO;_clock=0;_frameDebt=0;NSError* error=nil;if(!_audioEngine)[self startAudio:&error];else [_audioEngine startAndReturnError:&error];if(error)NSLog(@"Legend audio: %@",error);}
- (void)background{_background=YES;[self pause];dispatch_async(_worker,^{[self persistCard];});}
- (void)foreground{_background=NO;[self resume];}
- (void)audioInterrupted:(NSNotification*)note{NSNumber* type=note.userInfo[AVAudioSessionInterruptionTypeKey];if(type.unsignedIntegerValue==AVAudioSessionInterruptionTypeBegan)[self pause];else [self resume];}
- (void)startAudio:(NSError**)error {
 AVAudioSession* session=AVAudioSession.sharedInstance;if(![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:error])return;if(![session setActive:YES error:error])return;
 _audioEngine=[[AVAudioEngine alloc]init];AVAudioFormat* format=[[AVAudioFormat alloc]initStandardFormatWithSampleRate:_sampleRate channels:2];Legend::AudioRing* ring=&_core->audio;
 _audioSource=[[AVAudioSourceNode alloc]initWithFormat:format renderBlock:^OSStatus(BOOL* silence,const AudioTimeStamp* timestamp,AVAudioFrameCount frames,AudioBufferList* buffers){
  if(buffers->mNumberBuffers!=2||!buffers->mBuffers[0].mData||!buffers->mBuffers[1].mData){for(UInt32 i=0;i<buffers->mNumberBuffers;i++)if(buffers->mBuffers[i].mData)memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);*silence=YES;return noErr;}
  ring->render(static_cast<float*>(buffers->mBuffers[0].mData),static_cast<float*>(buffers->mBuffers[1].mData),frames);*silence=NO;return noErr;
 }];[_audioEngine attachNode:_audioSource];[_audioEngine connect:_audioSource to:_audioEngine.mainMixerNode format:format];_audioEngine.mainMixerNode.outputVolume=_volume;[_audioEngine startAndReturnError:error];
}
- (void)source:(unsigned)source mask:(uint16_t)mask{
 if(source>=3)return;if(_paused||_background||!_ready)mask=0;_sources[source]=mask;uint16_t next=_sources[0]|_sources[1]|_sources[2];for(unsigned i=0;i<14;i++)if((next^_combined)&(1<<i)){_core->input.button(i,(next&(1<<i))!=0);_pads[@(i)].highlighted=(next&(1<<i))!=0;}_combined=next;
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
- (void)pressesBegan:(NSSet<UIPress*>*)presses withEvent:(UIPressesEvent*)event{BOOL handled=NO;for(UIPress* press in presses){if(press.key.keyCode==UIKeyboardHIDUsageKeyboardF1){if(!_paused)[self save];handled=YES;}else if(press.key.keyCode==UIKeyboardHIDUsageKeyboardF3){if(!_paused)[self load];handled=YES;}else{int id=[self keyID:press.key];if(id>=0){[self button:id down:YES source:2];handled=YES;}}}if(!handled)[super pressesBegan:presses withEvent:event];}
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
- (void)tableView:(UITableView*)table didSelectRowAtIndexPath:(NSIndexPath*)path{if(path.row<NSInteger(_duel.rows.size())){_selected=_duel.rows[path.row];_hasSelected=YES;[_overlay showView:_duel row:&_selected];[_guide reloadData];}}
- (CGFloat)tableView:(UITableView*)table heightForRowAtIndexPath:(NSIndexPath*)path{UITableViewCell* cell=[self tableView:table cellForRowAtIndexPath:path];CGFloat width=MAX(30,table.bounds.size.width-44);return MAX(64,24+[cell.textLabel sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)].height+[cell.detailTextLabel sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)].height);}
- (void)showVIP{[self pause];if(!_data){[self alert:@"VIP" text:@"Mở game có dữ liệu VIP trước. Nếu vừa mở, chờ đọc dữ liệu một lát."];return;}LGVipController* vip=[[LGVipController alloc]initWithData:_data queue:_analysis ram:_lastRam];__weak LGPlayer* weak=self;vip.closed=^{[weak resumePlayback];};[self presentViewController:vip animated:YES completion:nil];}
- (void)settings{
 [self pause];LGSettingsController* settings=[[LGSettingsController alloc]initWithStyle:UITableViewStyleInsetGrouped];settings.fusionMode=_fusionMode;settings.slot=_slot;settings.speed=_speed;settings.volume=_volume;__weak LGPlayer* weak=self;
 settings.changed=^(LGSettingsController* s){LGPlayer* owner=weak;if(!owner)return;owner->_fusionMode=s.fusionMode;owner->_slot=s.slot;double speed=s.speed;owner->_speed=speed;owner->_volume=s.volume;owner->_audioEngine.mainMixerNode.outputVolume=s.volume;NSUserDefaults* p=NSUserDefaults.standardUserDefaults;[p setInteger:s.fusionMode forKey:@"fusion_mode"];[p setInteger:s.slot forKey:@"save_slot"];[p setDouble:s.speed forKey:@"speed"];[p setFloat:s.volume forKey:@"volume"];dispatch_async(owner->_worker,^{owner->_core->setSpeed(speed);});[owner.view setNeedsLayout];};
 settings.closed=^{[weak resumePlayback];};settings.command=^(NSString* command){[weak command:command];};UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:settings];nav.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;nav.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:nav animated:YES completion:nil];
}
- (void)command:(NSString*)command{
 if([command isEqualToString:@"bios"]){[self pick:YES];return;}if([command isEqualToString:@"license"]){NSString* path=[NSBundle.mainBundle pathForResource:@"LICENSES" ofType:@"txt"];NSString* text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]?:@"SwanStation — GPLv3\nMã nguồn: https://github.com/xuyendem249-cloud/Mod_LOGs";UIViewController* vc=[[UIViewController alloc]init];vc.title=@"Mã nguồn & giấy phép";UITextView* view=[[UITextView alloc]init];view.text=text;view.editable=NO;view.backgroundColor=Ink();view.textColor=UIColor.whiteColor;view.font=[UIFont systemFontOfSize:13];vc.view=view;vc.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Đóng" style:UIBarButtonItemStyleDone target:self action:@selector(closeDocument)];UINavigationController* nav=[[UINavigationController alloc]initWithRootViewController:vc];nav.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:nav animated:YES completion:nil];return;}
 if(!_ready){[self alert:@"Chưa mở game" text:@"Hãy mở đúng game trước."];return;}if([command isEqualToString:@"save"]){[self save];return;}if([command isEqualToString:@"load"]){[self load];return;}if([command isEqualToString:@"cardIn"]){[self confirm:@"Nhập thẻ nhớ?" text:@"Sao lưu thẻ hiện tại rồi thay bằng file RAW 128 KB. Game sẽ khởi động lại." action:^{[self pickMode:2];}];return;}if([command isEqualToString:@"cardOut"]){[self exportCard];return;}
 if([command isEqualToString:@"reset"])[self confirm:@"Khởi động lại game?" text:@"Thẻ nhớ được lưu trước khi khởi động lại. Tiến trình chưa lưu trong game sẽ mất." action:^{++self->_generation;self->_lastRam.reset();self->_operation=YES;dispatch_async(self->_worker,^{[self persistCard];self->_core->reset();dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;self->_duel={};self->_hasSelected=NO;[self->_overlay showView:self->_duel row:nullptr];[self resumePlayback];});});}];
}
- (void)closeDocument{[self dismissViewControllerAnimated:YES completion:^{[self resumePlayback];}];}
- (void)confirm:(NSString*)title text:(NSString*)text action:(void(^)(void))callback{UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[self resumePlayback];}]];[a addAction:[UIAlertAction actionWithTitle:@"Tiếp tục" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){callback();}]];[self presentViewController:a animated:YES completion:nil];}
- (void)importCardURL:(NSURL*)url{
 if(!url){_operation=NO;[self resumePlayback];return;}++_generation;_lastRam.reset();_operation=YES;dispatch_async(_worker,^{BOOL scope=[url startAccessingSecurityScopedResource];__block NSData* bytes=nil;NSFileCoordinator* coordinator=[[NSFileCoordinator alloc]init];NSError* error=nil;[coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL* location){NSDictionary* info=[NSFileManager.defaultManager attributesOfItemAtPath:location.path error:nil];if(info.fileSize==131072)bytes=[NSData dataWithContentsOfURL:location];}];if(scope)[url stopAccessingSecurityScopedResource];BOOL ok=bytes.length==131072&&((const uint8_t*)bytes.bytes)[0]=='M'&&((const uint8_t*)bytes.bytes)[1]=='C';if(ok){[self persistCard];BOOL backed=[self backup:[self cardPath]];const uint8_t* b=(const uint8_t*)bytes.bytes;ok=backed&&self->_core->setMemoryCard({b,b+bytes.length});if(ok){[self persistCard];self->_core->reset();}}dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;[self alert:ok?@"Đã nhập thẻ nhớ":@"Không nhập được thẻ nhớ" text:ok?@"Chọn LOAD trong game.":@"Chỉ nhận thẻ nhớ RAW .mcr/.mcd đúng 128 KB, có chữ ký MC."];});});
}
- (void)exportCard{_operation=YES;dispatch_async(_worker,^{[self persistCard];auto card=self->_core->memoryCard();NSString* directory=[self->_root stringByAppendingPathComponent:@"exports"];[NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];NSString* path=[directory stringByAppendingPathComponent:@"Legend-memory-card.mcr"];BOOL ok=card.size()==131072&&[[NSData dataWithBytes:card.data() length:card.size()]writeToFile:path options:NSDataWritingAtomic error:nil];dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;if(!ok){[self alert:@"Không xuất được thẻ" text:@"Không đọc được thẻ nhớ."];return;}UIDocumentPickerViewController* picker=[[UIDocumentPickerViewController alloc]initForExportingURLs:@[[NSURL fileURLWithPath:path]] asCopy:YES];picker.delegate=self;self->_pickMode=3;[self presentViewController:picker animated:YES completion:nil];});});}
- (void)tick:(CADisplayLink*)link {
 if(!_ready||_paused||_background||_inFlight)return;double now=link.timestamp;if(!_clock)_clock=now-1.0/_fps;double elapsed=std::clamp(now-_clock,0.,.1);_clock=now;_frameDebt+=elapsed*_fps*_speed;int count=MIN(8,int(_frameDebt));if(count<1)return;_frameDebt-=count;_inFlight=YES;NSUInteger generation=_generation;BOOL snapshot=!_analyzing&&now-_lastSnapshot>=.15;if(snapshot){_analyzing=YES;_lastSnapshot=now;}
 dispatch_async(_worker,^{BOOL changed=NO;for(int i=0;i<count;i++)changed=self->_core->run()||changed;UIImage* image=nil;if(changed){auto& f=self->_core->frame;NSData* bytes=[NSData dataWithBytes:f.rgba.data() length:f.rgba.size()];CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)bytes);CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);CGImageRef cg=CGImageCreate(f.width,f.height,8,32,f.width*4,space,kCGImageAlphaLast|kCGBitmapByteOrder32Big,provider,NULL,NO,kCGRenderingIntentDefault);if(cg){image=[UIImage imageWithCGImage:cg];CGImageRelease(cg);}CGColorSpaceRelease(space);CGDataProviderRelease(provider);}
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
