#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuartzCore/QuartzCore.h>
#include "PlayerCore.hpp"
#include <memory>

static UIColor* Gold(){return [UIColor colorWithRed:.83 green:.69 blue:.34 alpha:1];}
static UIColor* Ink(){return [UIColor colorWithRed:.055 green:.045 blue:.11 alpha:1];}
static NSString* const LGErrorDomain=@"LegendPlayer";
static NSError* Failure(NSString* text){return [NSError errorWithDomain:LGErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:text}];}
static CGRect FitGame(CGRect area){CGFloat w=MIN(area.size.width,area.size.height*4/3);CGFloat h=w*3/4;return CGRectMake(CGRectGetMidX(area)-w/2,CGRectGetMidY(area)-h/2,w,h);}

@interface LGBackdrop:UIView @end
@implementation LGBackdrop
- (void)drawRect:(CGRect)rect {
 CGContextRef c=UIGraphicsGetCurrentContext();[Ink() setFill];UIRectFill(rect);
 CGContextSetStrokeColorWithColor(c,[Gold() colorWithAlphaComponent:.15].CGColor);CGContextSetLineWidth(c,1);
 CGRect border=CGRectInset(self.bounds,5,5);CGContextStrokeRect(c,border);
 CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
 for(int i=0;i<7;i++){CGFloat d=12+i*9;CGContextMoveToPoint(c,d,0);CGContextAddLineToPoint(c,d,24);CGContextAddLineToPoint(c,24,d);CGContextAddLineToPoint(c,0,d);CGContextMoveToPoint(c,w-d,h);CGContextAddLineToPoint(c,w-d,h-24);CGContextAddLineToPoint(c,w-24,h-d);CGContextAddLineToPoint(c,w,h-d);}CGContextStrokePath(c);
 CGContextSetStrokeColorWithColor(c,[Gold() colorWithAlphaComponent:.07].CGColor);
 CGFloat radius=MIN(w,h)*.31;CGContextStrokeEllipseInRect(c,CGRectMake(w/2-radius,h/2-radius,radius*2,radius*2));
 CGContextMoveToPoint(c,w/2,h/2-radius);CGContextAddLineToPoint(c,w/2+radius*.87,h/2+radius*.5);CGContextAddLineToPoint(c,w/2-radius*.87,h/2+radius*.5);CGContextClosePath(c);CGContextStrokePath(c);
}
@end

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

@interface LGPlayer:UIViewController<UIDocumentPickerDelegate> {
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
}
@end

@implementation LGPlayer
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskAllButUpsideDown;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (void)viewDidLoad {
 [super viewDidLoad];self.view=[[LGBackdrop alloc]initWithFrame:self.view.bounds];self.view.multipleTouchEnabled=YES;
 _core=std::make_unique<Legend::PlayerCore>();_worker=dispatch_queue_create("vn.anhchugia35.legend.core",DISPATCH_QUEUE_SERIAL);_fps=59.94;_sampleRate=44100;
 NSString* docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;_root=[docs stringByAppendingPathComponent:@"Legend"];
 for(NSString* name in @[@"system",@"saves",@"content"]) [[NSFileManager defaultManager] createDirectoryAtPath:[_root stringByAppendingPathComponent:name] withIntermediateDirectories:YES attributes:nil error:nil];
 _screen=[[UIImageView alloc]init];_screen.backgroundColor=UIColor.blackColor;_screen.contentMode=UIViewContentModeScaleToFill;_screen.layer.magnificationFilter=kCAFilterNearest;_screen.clipsToBounds=YES;[self.view addSubview:_screen];
 _placeholder=[[UILabel alloc]init];_placeholder.text=@"LEGEND\n\nMở menu ☰ để nhập BIOS và chọn game\nBản iOS thử nghiệm bước 2";_placeholder.textColor=Gold();_placeholder.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];_placeholder.numberOfLines=0;_placeholder.textAlignment=NSTextAlignmentCenter;[_screen addSubview:_placeholder];
 _toolbar=[[UIView alloc]init];[self.view addSubview:_toolbar];
 _menu=[self tool:@"☰" action:@selector(menu)];_menu.accessibilityLabel=@"Menu";_save=[self tool:@"Lưu" action:@selector(save)];_load=[self tool:@"Tải" action:@selector(load)];
 _credit=[[UILabel alloc]init];_credit.text=@"By AnhChuGia35";_credit.textColor=[Gold() colorWithAlphaComponent:.8];_credit.font=[UIFont systemFontOfSize:10];_credit.textAlignment=NSTextAlignmentCenter;[_toolbar addSubview:_credit];
 _logo=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"AppLogo.png"]];_logo.contentMode=UIViewContentModeScaleAspectFit;[self.view addSubview:_logo];
 _pads=[NSMutableDictionary dictionary];NSArray* names=@[@"X",@"Vuông",@"Select",@"Start",@"Lên",@"Xuống",@"Trái",@"Phải",@"Tròn",@"Tam giác",@"L1",@"R1",@"L2",@"R2"];
 __weak LGPlayer* weak=self;
 for(NSInteger i=0;i<14;i++){LGPadButton* b=[[LGPadButton alloc]init];b.padID=i;b.accessibilityLabel=names[i];if(i>=10)[b setTitle:names[i] forState:UIControlStateNormal];b.change=^(BOOL down){LGPlayer* owner=weak;if(owner&&owner->_core)owner->_core->input.button((unsigned)i,down);};_pads[@(i)]=b;[self.view addSubview:b];}
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationWillResignActiveNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
 [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupted:) name:AVAudioSessionInterruptionNotification object:nil];
 _displayLink=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];_displayLink.preferredFrameRateRange=CAFrameRateRangeMake(30,60,60);[_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (UIButton*)tool:(NSString*)title action:(SEL)action{LGPadButton* b=[[LGPadButton alloc]init];[b setTitle:title forState:UIControlStateNormal];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[_toolbar addSubview:b];return b;}
- (void)releaseButtons{_core->input.clear();for(LGPadButton* b in _pads.allValues)b.highlighted=NO;}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];if(!_operation)[self resume];
 if([NSProcessInfo.processInfo.environment[@"LEGEND_SMOKE"] isEqualToString:@"1"]){[self.view layoutIfNeeded];BOOL valid=_pads.count==14&&_screen.frame.size.width>0&&_screen.frame.size.height>0;for(LGPadButton* b in _pads.allValues)valid=valid&&CGRectContainsRect(self.view.bounds,b.frame)&&b.frame.size.width>0&&b.frame.size.height>0;
 NSDictionary* report=@{@"app_launched":@YES,@"all_14_buttons_inside_view":@(valid),@"game_or_bios_tested":@NO};NSData* json=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];[json writeToFile:[_root stringByAppendingPathComponent:@"simulator_smoke.json"] atomically:YES];}
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{[self releaseButtons];_clock=0;[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context){[self.view setNeedsLayout];} completion:nil];}
- (void)cluster:(CGRect)area right:(BOOL)right {
 CGFloat s=MIN(area.size.width,area.size.height);CGRect box=CGRectMake(CGRectGetMidX(area)-s/2,CGRectGetMidY(area)-s/2,s,s);CGFloat u=s/3;
 NSArray* ids=right?@[@9,@0,@1,@8]:@[@4,@5,@6,@7];NSArray* points=@[[NSValue valueWithCGPoint:CGPointMake(1,0)],[NSValue valueWithCGPoint:CGPointMake(1,2)],[NSValue valueWithCGPoint:CGPointMake(0,1)],[NSValue valueWithCGPoint:CGPointMake(2,1)]];
 for(NSUInteger i=0;i<4;i++){CGPoint p=points[i].CGPointValue;_pads[ids[i]].frame=CGRectInset(CGRectMake(box.origin.x+p.x*u,box.origin.y+p.y*u,u,u),2,2);}
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];CGRect a=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);CGFloat x=a.origin.x,y=a.origin.y,w=a.size.width,h=a.size.height,g=6;
 BOOL landscape=w>h;CGFloat toolbarH=44;
 if(landscape){CGFloat side=MIN(w*.2,h*.53);CGFloat center=w-side*2-g*2;
  _screen.frame=FitGame(CGRectMake(x+side+g,y,center,MAX(1,h-toolbarH-g)));_toolbar.frame=CGRectMake(x+side+g,y+h-toolbarH,center,toolbarH);
  CGFloat shoulder=MIN(48,h*.14),bottom=MIN(50,h*.15),padH=h-shoulder-bottom-g*4;
  _pads[@10].frame=CGRectMake(x+g,y+g,(side-g*3)/2,shoulder);_pads[@12].frame=CGRectMake(x+side/2+g/2,y+g,(side-g*3)/2,shoulder);
  _pads[@13].frame=CGRectMake(x+w-side+g,y+g,(side-g*3)/2,shoulder);_pads[@11].frame=CGRectMake(x+w-side/2+g/2,y+g,(side-g*3)/2,shoulder);
  [self cluster:CGRectMake(x+g,y+shoulder+g*2,side-g*2,padH) right:NO];[self cluster:CGRectMake(x+w-side+g,y+shoulder+g*2,side-g*2,padH) right:YES];
  _pads[@2].frame=CGRectMake(x+side*.2,y+h-bottom-g,side*.6,bottom);_pads[@3].frame=CGRectMake(x+w-side*.8,y+h-bottom-g,side*.6,bottom);_logo.frame=CGRectMake(x+w/2-12,y+h-toolbarH+1,24,24);_logo.hidden=NO;
 }else{CGFloat gameH=MIN(w*.75,h*.43);_screen.frame=FitGame(CGRectMake(x,y,w,gameH));_toolbar.frame=CGRectMake(x,y+gameH,w,toolbarH);
  CGFloat top=y+gameH+toolbarH+g,remaining=y+h-top,shoulder=MIN(54,remaining*.14),bottom=MIN(54,remaining*.16);CGFloat padY=top+shoulder+g,padH=MAX(1,remaining-shoulder-bottom-g*3);CGFloat half=(w-g*3)/2;
  NSArray* ids=@[@10,@12,@13,@11];for(NSUInteger i=0;i<4;i++)_pads[ids[i]].frame=CGRectMake(x+g+i*(w-g)/4,top,(w-g)/4-g,shoulder);
  [self cluster:CGRectMake(x+g,padY,half,padH) right:NO];[self cluster:CGRectMake(x+w/2+g/2,padY,half,padH) right:YES];
  _pads[@2].frame=CGRectMake(x+w*.13,y+h-bottom-g,w*.24,bottom);_pads[@3].frame=CGRectMake(x+w*.63,y+h-bottom-g,w*.24,bottom);
  CGFloat logoSize=MIN(44,MAX(16,bottom-8));_logo.frame=CGRectMake(x+w/2-logoSize/2,y+h-bottom-g+(bottom-logoSize)/2,logoSize,logoSize);_logo.hidden=NO;
 }
 _placeholder.frame=CGRectInset(_screen.bounds,20,20);CGFloat tw=_toolbar.bounds.size.width;_menu.frame=CGRectMake(2,2,48,40);_load.frame=CGRectMake(tw-54,2,52,40);_save.frame=CGRectMake(tw-110,2,52,40);_credit.frame=landscape?CGRectMake(110,26,MAX(0,tw-220),16):CGRectMake(54,2,MAX(0,tw-168),40);
 _save.enabled=_load.enabled=_ready;_save.alpha=_load.alpha=_ready?1:.4;[self.view setNeedsDisplay];
}
- (void)alert:(NSString*)title text:(NSString*)text{UIAlertController* a=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];__weak LGPlayer* weak=self;[a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];[self presentViewController:a animated:YES completion:nil];}
- (void)menu {
 [self pause];UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Legend · iOS thử nghiệm" message:@"Nhập BIOS trước, sau đó chọn file ISO hoặc BIN một track. VIP/Fusion đang được chuyển sang iOS." preferredStyle:UIAlertControllerStyleActionSheet];
 __weak LGPlayer* weak=self;
 [a addAction:[UIAlertAction actionWithTitle:@"Mở game ISO / BIN" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak pick:NO];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Nhập BIOS PlayStation" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak pick:YES];}]];
 if(_ready)[a addAction:[UIAlertAction actionWithTitle:@"Tiếp tục chơi" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[weak resumePlayback];}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){[weak resumePlayback];}]];
 a.popoverPresentationController.sourceView=_menu;a.popoverPresentationController.sourceRect=_menu.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (void)pick:(BOOL)bios{_pickingBIOS=bios;_operation=YES;UIDocumentPickerViewController* picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeData] asCopy:NO];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller{_operation=NO;[self resumePlayback];}
- (NSString*)importURL:(NSURL*)url bios:(BOOL)bios error:(NSError**)error {
 NSFileManager* fm=NSFileManager.defaultManager;NSString* ext=url.pathExtension.lowercaseString;if(!bios&&![@[@"iso",@"bin"] containsObject:ext]){*error=Failure(@"Bước này hỗ trợ ISO và BIN một track. Hãy chọn bản ISO của mod.");return nil;}
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
 if(!urls.count){_operation=NO;[self resume];return;}BOOL bios=_pickingBIOS;NSURL* url=urls.firstObject;[self pause];_operation=YES;_menu.enabled=NO;_placeholder.hidden=NO;_placeholder.text=@"Đang nhập file…";
 dispatch_async(_worker,^{NSError* error=nil;NSString* file=[self importURL:url bios:bios error:&error];BOOL success=file!=nil;
  if(success&&!bios){[self persistCard];std::string problem;success=self->_core->open(file.UTF8String,self->_root.UTF8String,problem);if(!success)error=Failure([NSString stringWithUTF8String:problem.c_str()]);else{self->_gameKey=file.lastPathComponent.stringByDeletingPathExtension;NSData* card=[NSData dataWithContentsOfFile:[self cardPath]];if(card.length==131072){const auto* b=static_cast<const uint8_t*>(card.bytes);self->_core->setMemoryCard({b,b+card.length});}}}
  double fps=self->_core->fps,rate=self->_core->sampleRate;BOOL loaded=self->_core->isLoaded();
  dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;self->_menu.enabled=YES;self->_ready=loaded;self->_fps=fps;self->_sampleRate=rate;self->_placeholder.hidden=loaded;if(!bios){[self->_audioEngine stop];self->_audioEngine=nil;self->_audioSource=nil;self->_screen.image=nil;}[self.view setNeedsLayout];
   if(!success){self->_placeholder.text=@"LEGEND\n\nMở menu để nhập BIOS và chọn game";[self alert:@"Không nhập được file" text:error.localizedDescription?:@"Lỗi đọc file."];}
   else if(bios){self->_placeholder.text=@"LEGEND\n\nĐã nhập BIOS · Chọn Mở game trong menu";[self alert:@"Đã nhập BIOS" text:@"Chọn Mở game trong menu để bắt đầu. BIOS mới sẽ được dùng khi mở game lại."];}
   if(success)[self resume];
  });
 });
}
- (NSString*)cardPath{return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[_gameKey stringByAppendingPathExtension:@"mcr"]];}
- (NSString*)statePath{return [[_root stringByAppendingPathComponent:@"saves"] stringByAppendingPathComponent:[_gameKey stringByAppendingPathExtension:@"state"]];}
- (void)persistCard{if(!_gameKey)return;auto bytes=_core->memoryCard();if(bytes.empty())return;NSData* data=[NSData dataWithBytes:bytes.data() length:bytes.size()];NSError* error=nil;if(![data writeToFile:[self cardPath] options:NSDataWritingAtomic error:&error])NSLog(@"Legend: không ghi được thẻ nhớ: %@",error);}
- (void)save {
 if(!_ready||_operation)return;_operation=YES;[self pause];dispatch_async(_worker,^{auto state=self->_core->saveState();BOOL ok=!state.empty();NSError* error=nil;if(ok)ok=[[NSData dataWithBytes:state.data() length:state.size()] writeToFile:[self statePath] options:NSDataWritingAtomic error:&error];[self persistCard];dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;[self alert:ok?@"Đã lưu nhanh":@"Không lưu được" text:ok?@"Save được lưu riêng cho game này.":error.localizedDescription?:@"Core không tạo được save."];});});
 }
- (void)load {
 if(!_ready||_operation)return;_operation=YES;[self pause];dispatch_async(_worker,^{NSData* data=[NSData dataWithContentsOfFile:[self statePath]];BOOL ok=NO;if(data.length&&data.length<=64*1024*1024){const auto* p=static_cast<const uint8_t*>(data.bytes);ok=self->_core->loadState({p,p+data.length});}dispatch_async(dispatch_get_main_queue(),^{self->_operation=NO;if(ok)[self resume];else [self alert:@"Chưa tải được save" text:@"Chưa có save nhanh cho game này hoặc save không tương thích."];});});
 }
- (void)pause{_paused=YES;_clock=0;[self releaseButtons];[_audioEngine pause];_core->audio.clear();}
- (void)resume{if(self.presentedViewController)return;[self resumePlayback];}
- (void)resumePlayback{if(!_ready||_background||_operation)return;_paused=NO;_clock=0;NSError* error=nil;if(!_audioEngine)[self startAudio:&error];else [_audioEngine startAndReturnError:&error];if(error)NSLog(@"Legend audio: %@",error);}
- (void)background{_background=YES;[self pause];dispatch_async(_worker,^{[self persistCard];});}
- (void)foreground{_background=NO;[self resume];}
- (void)audioInterrupted:(NSNotification*)note{NSNumber* type=note.userInfo[AVAudioSessionInterruptionTypeKey];if(type.unsignedIntegerValue==AVAudioSessionInterruptionTypeBegan)[self pause];else [self resume];}
- (void)startAudio:(NSError**)error {
 AVAudioSession* session=AVAudioSession.sharedInstance;if(![session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:error])return;if(![session setActive:YES error:error])return;
 _audioEngine=[[AVAudioEngine alloc]init];AVAudioFormat* format=[[AVAudioFormat alloc]initStandardFormatWithSampleRate:_sampleRate channels:2];Legend::AudioRing* ring=&_core->audio;
 _audioSource=[[AVAudioSourceNode alloc]initWithFormat:format renderBlock:^OSStatus(BOOL* silence,const AudioTimeStamp* timestamp,AVAudioFrameCount frames,AudioBufferList* buffers){
  if(buffers->mNumberBuffers!=2||!buffers->mBuffers[0].mData||!buffers->mBuffers[1].mData){for(UInt32 i=0;i<buffers->mNumberBuffers;i++)if(buffers->mBuffers[i].mData)memset(buffers->mBuffers[i].mData,0,buffers->mBuffers[i].mDataByteSize);*silence=YES;return noErr;}
  ring->render(static_cast<float*>(buffers->mBuffers[0].mData),static_cast<float*>(buffers->mBuffers[1].mData),frames);*silence=NO;return noErr;
 }];[_audioEngine attachNode:_audioSource];[_audioEngine connect:_audioSource to:_audioEngine.mainMixerNode format:format];[_audioEngine startAndReturnError:error];
}
- (void)tick:(CADisplayLink*)link {
 if(!_ready||_paused||_background||_inFlight)return;double now=link.timestamp;if(!_clock)_clock=now;if(now+.0005<_clock)return;_clock+=1.0/_fps;if(_clock<now-.1)_clock=now+1.0/_fps;_inFlight=YES;
 dispatch_async(_worker,^{BOOL changed=self->_core->run();UIImage* image=nil;if(changed){auto& f=self->_core->frame;NSData* bytes=[NSData dataWithBytes:f.rgba.data() length:f.rgba.size()];CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)bytes);CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);CGImageRef cg=CGImageCreate(f.width,f.height,8,32,f.width*4,space,kCGImageAlphaLast|kCGBitmapByteOrder32Big,provider,NULL,NO,kCGRenderingIntentDefault);if(cg){image=[UIImage imageWithCGImage:cg];CGImageRelease(cg);}CGColorSpaceRelease(space);CGDataProviderRelease(provider);}
  static unsigned frames=0;if(++frames%300==0)[self persistCard];dispatch_async(dispatch_get_main_queue(),^{if(image)self->_screen.image=image;self->_inFlight=NO;});
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
