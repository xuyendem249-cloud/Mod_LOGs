#import "LegendGachaView.hpp"
#import "LegendViews.hpp"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#include "Gacha.hpp"
#include <cmath>

namespace {
UIColor* slate(double r,double g,double b){return [UIColor colorWithRed:r green:g blue:b alpha:1];}
UIImage* mediaImage(NSURL* folder,NSString* name){
 return [UIImage imageWithContentsOfFile:[folder URLByAppendingPathComponent:name].path];
}
NSURL* mediaFile(NSURL* folder,NSString* name){
 NSURL* url=[folder URLByAppendingPathComponent:name];
 return [NSFileManager.defaultManager fileExistsAtPath:url.path]?url:nil;
}
UIButton* action(NSString* title,UIColor* color,id owner,SEL selector){
 UIButton* button=[UIButton buttonWithType:UIButtonTypeSystem];
 [button setTitle:title forState:UIControlStateNormal];
 [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 button.titleLabel.font=[UIFont boldSystemFontOfSize:14];
 button.titleLabel.textAlignment=NSTextAlignmentCenter;
 button.titleLabel.numberOfLines=2;
 button.backgroundColor=color;
 button.layer.cornerRadius=12;
 button.layer.borderWidth=1;
 button.layer.borderColor=[LGGold()colorWithAlphaComponent:.72].CGColor;
 [button addTarget:owner action:selector forControlEvents:UIControlEventTouchUpInside];
 return button;
}
UILabel* label(CGFloat size,UIColor* color){
 UILabel* value=[[UILabel alloc]init];
 value.font=[UIFont boldSystemFontOfSize:size];
 value.textColor=color;
 value.textAlignment=NSTextAlignmentCenter;
 return value;
}
}

@interface LGGoldPodium:UIView
@property(nonatomic,strong) UIImage* art;
@property(nonatomic) double elapsed;
@end

@implementation LGGoldPodium
- (void)drawRect:(CGRect)rect{
 if(!self.art)return;
 CGSize image=self.art.size;
 CGFloat s=MIN(rect.size.width/image.width,rect.size.height/image.height);
 CGRect place=CGRectMake(CGRectGetMidX(rect)-image.width*s/2,CGRectGetMidY(rect)-image.height*s/2,
  image.width*s,image.height*s);
 [self.art drawInRect:place];
 CGContextRef canvas=UIGraphicsGetCurrentContext();
 CGFloat x=CGRectGetMidX(place),rim=place.origin.y+place.size.height*.78,factor=place.size.width*.84/350;
 double elapsed=self.elapsed;
 CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
 const CGFloat colors[]={1,.82,.49,.66,1,.73,.33,.30,1,.73,.33,0};
 const CGFloat stops[]={0,.45,1};
 CGGradientRef glow=CGGradientCreateWithColorComponents(color,colors,stops,3);
 CGColorSpaceRelease(color);
 CGContextSaveGState(canvas);
 CGContextClipToRect(canvas,CGRectMake(place.origin.x,0,place.size.width,rim+4*factor));
 for(int beam=0;beam<4;beam++){
  double phase=elapsed*1.3+beam*2.1;
  CGFloat center=x+(beam?std::sin(phase)*(32+beam*22)*factor:0);
  CGFloat y=rim-(beam?36+beam*9:9)*factor;
  CGContextSaveGState(canvas);
  CGContextTranslateCTM(canvas,center,y);
  CGContextScaleCTM(canvas,(beam?46+beam*8:164)*factor,(beam?62+beam*8:27)*factor);
  CGContextSetAlpha(canvas,beam?.25+.10*std::sin(phase+.6):.57+.14*std::sin(elapsed*2.4));
  CGContextDrawRadialGradient(canvas,glow,CGPointZero,0,CGPointZero,1,0);
  CGContextRestoreGState(canvas);
 }
 CGGradientRelease(glow);
 for(int i=0;i<24;i++){
  double progress=std::fmod(elapsed*(.24+(i%4)*.017)+i*.61803398875,1.);
  CGFloat py=rim-progress*120*factor;
  CGFloat px=x+std::sin(i*2.2+elapsed*.55)*(65+progress*65)*factor;
  double sparkle=std::sin(elapsed*5+i*1.7);
  CGFloat alpha=.92*std::sin(progress*M_PI)*(.5+.5*sparkle*sparkle);
  CGFloat radius=MAX(.65,(1.5+(i%5)*.2)*factor);
  CGContextSetRGBFillColor(canvas,1,.74,.36,alpha/4);
  CGContextFillEllipseInRect(canvas,CGRectMake(px-radius*2.4,py-radius*2.4,radius*4.8,radius*4.8));
  CGContextSetRGBFillColor(canvas,1,.94,.73,alpha);
  CGContextFillEllipseInRect(canvas,CGRectMake(px-radius*.66,py-radius*.66,radius*1.32,radius*1.32));
  if(i%3==0){
   CGContextSetRGBStrokeColor(canvas,1,.94,.73,alpha);
   CGContextSetLineWidth(canvas,MAX(.6,factor));
   CGContextMoveToPoint(canvas,px-radius*1.6,py);CGContextAddLineToPoint(canvas,px+radius*1.6,py);
   CGContextMoveToPoint(canvas,px,py-radius*1.6);CGContextAddLineToPoint(canvas,px,py+radius*1.6);
   CGContextStrokePath(canvas);
  }
 }
 CGContextRestoreGState(canvas);
}
@end

@implementation LGGachaController{
 std::shared_ptr<Legend::GameData> _game;
 dispatch_queue_t _queue;
 NSURL* _media;
 NSInteger _balance;
 NSArray<UIImage*>* _faces;
 NSArray<NSNumber*>* _tiers;
 AVQueuePlayer* _ambient;
 AVPlayerLooper* _ambientLoop;
 AVPlayerLayer* _ambientLayer;
 AVQueuePlayer* _rewardPlayer;
 AVPlayerLooper* _rewardLoop;
 AVPlayerLayer* _rewardLayer;
 AVPlayer* _opening;
 AVPlayerLayer* _openingLayer;
 id _openingEnd;
 AVAudioPlayer* _music,*_stinger;
 CADisplayLink* _link;
 CFTimeInterval _started;
 LGGoldPodium* _podium;
 UIImageView* _pack;
 UIView* _menu,*_results;
 UILabel* _stars,*_message;
 UIButton* _close,*_again;
 UIStackView* _boxes,*_giftRow;
 UITextField* _code;
 UIScrollView* _grid;
 NSMutableArray<UIImageView*>* _rewardImages;
 NSMutableArray<UILabel*>* _rewardLabels;
 BOOL _pending,_revealing;
 NSUInteger _animation;
}
- (instancetype)initWithData:(std::shared_ptr<Legend::GameData>)game
                       stars:(NSInteger)stars media:(NSURL*)media queue:(dispatch_queue_t)queue{
 if((self=[super init])){
  _game=std::move(game);
  _queue=queue;_media=media;_balance=stars;
  self.modalPresentationStyle=UIModalPresentationFullScreen;
 }
 return self;
}
- (void)viewDidLoad{
 [super viewDidLoad];
 self.view.backgroundColor=slate(.035,.028,.07);
 NSURL* background=mediaFile(_media,@"ambient.mp4");
 if(background){
  _ambient=[AVQueuePlayer queuePlayerWithItems:@[]];
  _ambient.muted=YES;
  _ambientLoop=[AVPlayerLooper playerLooperWithPlayer:_ambient templateItem:[AVPlayerItem playerItemWithURL:background]];
  _ambientLayer=[AVPlayerLayer playerLayerWithPlayer:_ambient];
  _ambientLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
  [self.view.layer addSublayer:_ambientLayer];
 }
 NSURL* music=mediaFile(_media,@"bgm.mp3");
 if(music){_music=[[AVAudioPlayer alloc]initWithContentsOfURL:music error:nil];_music.numberOfLoops=-1;}
 _menu=[[UIView alloc]init];[self.view addSubview:_menu];
 _results=[[UIView alloc]init];_results.hidden=YES;[self.view addSubview:_results];
 _podium=[[LGGoldPodium alloc]init];_podium.opaque=NO;_podium.backgroundColor=UIColor.clearColor;
 _podium.art=mediaImage(_media,@"podium.png");[_menu addSubview:_podium];
 UIImage* first=mediaImage(_media,@"pack.png");
 if(first)_faces=@[first,mediaImage(_media,@"kaiba.png")?:first,mediaImage(_media,@"jonouchi.png")?:first];
 _pack=[[UIImageView alloc]initWithImage:first];_pack.contentMode=UIViewContentModeScaleAspectFit;
 [_menu addSubview:_pack];
 _stars=label(24,LGGold());_stars.textAlignment=NSTextAlignmentLeft;
 _stars.layer.shadowColor=LGGold().CGColor;_stars.layer.shadowOpacity=.65;_stars.layer.shadowRadius=7;
 [self.view addSubview:_stars];[self updateStars];
 _close=action(@"×",slate(.62,.10,.15),self,@selector(close));_close.titleLabel.font=[UIFont boldSystemFontOfSize:24];
 _close.accessibilityLabel=@"Đóng Gacha";[self.view addSubview:_close];
 _message=label(13,UIColor.whiteColor);_message.numberOfLines=2;[self.view addSubview:_message];
 _boxes=[[UIStackView alloc]init];_boxes.distribution=UIStackViewDistributionFillEqually;_boxes.spacing=8;
 NSArray<UIColor*>* colors=@[slate(.16,.13,.24),slate(.105,.32,.20),slate(.55,.11,.18)];
 size_t index=0;
 for(int quantity:{1,5,10}){
  UIButton* button=action([NSString stringWithFormat:@"Pack x%d\n★ %d",quantity,Legend::Gacha::price(quantity)],
   colors[index++],self,@selector(open:));
  button.tag=quantity;
  [_boxes addArrangedSubview:button];
 }
 [_menu addSubview:_boxes];
 _giftRow=[[UIStackView alloc]init];
 _giftRow.spacing=12;
 UIImageView* gift=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"gift"]];
 gift.tintColor=LGGold();gift.contentMode=UIViewContentModeCenter;
 [gift.widthAnchor constraintEqualToConstant:28].active=YES;
 [_giftRow addArrangedSubview:gift];
 _code=[[UITextField alloc]init];
 _code.borderStyle=UITextBorderStyleRoundedRect;
 _code.backgroundColor=slate(.15,.12,.22);_code.textColor=UIColor.whiteColor;
 _code.autocorrectionType=UITextAutocorrectionTypeNo;_code.autocapitalizationType=UITextAutocapitalizationTypeNone;
 _code.accessibilityLabel=@"Mã quà Gacha";
 [_giftRow addArrangedSubview:_code];
 UIButton* redeem=action(@"Đổi mã",slate(.19,.15,.27),self,@selector(redeem));
 [redeem.widthAnchor constraintEqualToConstant:78].active=YES;
 [_giftRow addArrangedSubview:redeem];
 [_menu addSubview:_giftRow];
 NSData* rarity=[NSData dataWithContentsOfURL:[_media URLByAppendingPathComponent:@"cards/tiers.json"]];
 if(rarity){
  id decoded=[NSJSONSerialization JSONObjectWithData:rarity options:0 error:nil];
  if([decoded isKindOfClass:NSDictionary.class]){
   NSArray* rating=((NSDictionary*)decoded)[@"rating"];
   if([rating isKindOfClass:NSArray.class])_tiers=rating;
  }
 }
 _grid=[[UIScrollView alloc]init];[_results addSubview:_grid];
 _again=action(@"Mở tiếp",slate(.19,.15,.27),self,@selector(returnToPacks));[_results addSubview:_again];
}
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 [_ambient play];[_music play];
 if(!_link){
  _started=CACurrentMediaTime();
  _link=[CADisplayLink displayLinkWithTarget:self selector:@selector(advance:)];
  [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
 }
}
- (void)viewDidDisappear:(BOOL)animated{
 [super viewDidDisappear:animated];
 [_link invalidate];_link=nil;
 [_ambient pause];[_music stop];[_stinger stop];
 [self stopOpening];
 [self stopRewardBackdrop];
}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];
 CGRect bounds=self.view.bounds;
 CGRect safe=UIEdgeInsetsInsetRect(bounds,self.view.safeAreaInsets);
 CGFloat w=safe.size.width,h=safe.size.height,x=safe.origin.x,y=safe.origin.y;
 CGFloat center=CGRectGetMidX(safe);
 _ambientLayer.frame=bounds;_openingLayer.frame=bounds;_rewardLayer.frame=bounds;
 _menu.frame=_results.frame=bounds;
 _stars.frame=CGRectMake(x+16,y+5,w-82,44);_close.frame=CGRectMake(CGRectGetMaxX(safe)-58,y+8,44,42);
 CGFloat width=MIN(w-28,540),packHeight=MAX(5,h-174);
 _pack.bounds=CGRectMake(0,0,MIN(w*.55,packHeight*.76),packHeight*.89);
 _pack.center=CGPointMake(center,y+40+packHeight*.44);
 _podium.frame=CGRectMake(center-MIN(w*.68,350)/2,y+packHeight*.68,MIN(w*.68,350),packHeight*.34+28);
 _boxes.frame=CGRectMake(center-width/2,CGRectGetMaxY(safe)-118,width,52);
 CGFloat giftWidth=MIN(width,342);
 _giftRow.frame=CGRectMake(center-giftWidth/2,CGRectGetMaxY(safe)-56,giftWidth,36);
 _message.frame=CGRectMake(x+12,y+48,w-24,38);
 _grid.frame=CGRectMake(x+10,y+84,w-20,MAX(0,h-145));
 _again.frame=CGRectMake(center-70,CGRectGetMaxY(safe)-50,140,40);
 CGFloat usable=_grid.bounds.size.width;
 NSUInteger columns=MIN(_rewardImages.count,w>h?5:3);
 if(columns){
  CGFloat cardW=MIN(120,(usable-12*columns)/columns),cardH=cardW*1.32;
  CGFloat left=(usable-columns*(cardW+12)+12)/2;
  for(NSUInteger i=0;i<_rewardImages.count;i++){
   CGFloat px=left+(i%columns)*(cardW+12),py=8+(i/columns)*(cardH+44);
   _rewardImages[i].frame=CGRectMake(px,py,cardW,cardH);
   _rewardLabels[i].frame=CGRectMake(px,py+cardH,cardW,40);
  }
  _grid.contentSize=CGSizeMake(usable,8+std::ceil(double(_rewardImages.count)/columns)*(cardH+44));
 }
}
- (void)advance:(CADisplayLink*)link{
 if(_openingLayer&&_openingLayer.readyForDisplay&&_openingLayer.opacity==0){
  [CATransaction begin];[CATransaction setDisableActions:YES];_openingLayer.opacity=1;[CATransaction commit];
 }
 if(_rewardLayer&&_rewardLayer.readyForDisplay&&_rewardLayer.opacity==0){
  [CATransaction begin];[CATransaction setDisableActions:YES];_rewardLayer.opacity=1;[CATransaction commit];
 }
 if(_menu.hidden||!_faces.count)return;
 double elapsed=link.timestamp-_started;
 double angle=std::fmod(MAX(0,elapsed),24.)*2*M_PI/8;
 size_t face=static_cast<size_t>((angle+M_PI/2)/M_PI)%_faces.count;
 _pack.image=_faces[face];
 CATransform3D perspective=CATransform3DIdentity;
 perspective.m34=-1/MAX(1,_pack.bounds.size.width*4);
 _pack.layer.transform=CATransform3DRotate(perspective,std::cos(angle)<0?angle-M_PI:angle,0,1,0);
 _podium.elapsed=MAX(0,elapsed);[_podium setNeedsDisplay];
}
- (void)updateStars{_stars.text=[NSString stringWithFormat:@"★ %ld",(long)_balance];}
- (void)busy:(BOOL)on{
 _pending=on;_close.enabled=!on;_boxes.userInteractionEnabled=!on;_giftRow.userInteractionEnabled=!on;
}
- (void)open:(UIButton*)button{
 if(_pending||_revealing||!self.openPacks)return;
 [self.view endEditing:YES];[self busy:YES];_message.text=nil;
 __weak LGGachaController* weak=self;
 self.openPacks(button.tag,_balance,^(NSInteger stars,NSArray<NSNumber*>* cards,NSString* error){
  LGGachaController* owner=weak;
  if(!owner)return;
  [owner busy:NO];
  if(error){owner->_message.text=error;return;}
  owner->_balance=stars;[owner updateStars];
  [owner playOpening:cards];
 });
}
- (void)redeem{
 if(_pending||_revealing||!self.gift)return;
 [self.view endEditing:YES];[self busy:YES];_message.text=nil;
 __weak LGGachaController* weak=self;
 self.gift(_code.text?:@"",^(NSInteger stars,NSString* error){
  LGGachaController* owner=weak;if(!owner)return;
  [owner busy:NO];owner->_message.text=error;
  if(!error){owner->_balance=stars;[owner updateStars];owner->_code.text=@"";owner->_message.text=@"Đã đổi mã";}
 });
}
- (void)playOpening:(NSArray<NSNumber*>*)cards{
 [self stopOpening];
 _revealing=YES;
 _menu.userInteractionEnabled=NO;
 NSUInteger ticket=++_animation;
 NSURL* url=mediaFile(_media,@"open.mp4");
 if(!url){[self showRewards:cards];return;}
 AVPlayerItem* item=[AVPlayerItem playerItemWithURL:url];
 _opening=[AVPlayer playerWithPlayerItem:item];
 _openingLayer=[AVPlayerLayer playerLayerWithPlayer:_opening];
 _openingLayer.frame=self.view.bounds;_openingLayer.opacity=0;
 _openingLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
 [self.view.layer insertSublayer:_openingLayer below:_stars.layer];
 __weak LGGachaController* weak=self;
 _openingEnd=[NSNotificationCenter.defaultCenter addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
  object:item queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* note){
   LGGachaController* owner=weak;
   if(owner&&ticket==owner->_animation)[owner showRewards:cards];
  }];
 [_opening play];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,6*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  LGGachaController* owner=weak;
  if(owner&&ticket==owner->_animation&&owner->_revealing)[owner showRewards:cards];
 });
}
- (void)stopOpening{
 if(_openingEnd){[NSNotificationCenter.defaultCenter removeObserver:_openingEnd];_openingEnd=nil;}
 [_opening pause];[_openingLayer removeFromSuperlayer];_openingLayer=nil;_opening=nil;
}
- (void)stopRewardBackdrop{
 [_rewardPlayer pause];
 [_rewardLoop disableLooping];
 [_rewardLayer removeFromSuperlayer];
 _rewardLayer=nil;_rewardLoop=nil;_rewardPlayer=nil;
}
- (void)showRewardBackdrop:(int)tier{
 [self stopRewardBackdrop];
 if(tier<1||tier>3)return;
 NSURL* url=mediaFile(_media,@[@"rare.mp4",@"epic.mp4",@"legendary.mp4"][tier-1]);
 if(!url)return;
 _rewardPlayer=[AVQueuePlayer queuePlayerWithItems:@[]];
 _rewardPlayer.muted=YES;
 _rewardLoop=[AVPlayerLooper playerLooperWithPlayer:_rewardPlayer templateItem:[AVPlayerItem playerItemWithURL:url]];
 _rewardLayer=[AVPlayerLayer playerLayerWithPlayer:_rewardPlayer];
 _rewardLayer.frame=self.view.bounds;_rewardLayer.opacity=0;
 _rewardLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
 [self.view.layer insertSublayer:_rewardLayer below:_results.layer];
 [_rewardPlayer play];
}
- (void)showRewards:(NSArray<NSNumber*>*)cards{
 ++_animation;
 _revealing=NO;
 _results.hidden=NO;_menu.hidden=YES;
 for(UIView* old in _grid.subviews)[old removeFromSuperview];
 _rewardImages=[NSMutableArray array];_rewardLabels=[NSMutableArray array];
 int tier=0;
 for(NSNumber* number in cards){
  int id=number.intValue;
  if(id<1||id>_game->cardCount)continue;
  UIImageView* view=[[UIImageView alloc]init];view.contentMode=UIViewContentModeScaleAspectFit;
  [_grid addSubview:view];[_rewardImages addObject:view];
  UILabel* name=label(11,LGGold());name.numberOfLines=2;name.text=LGText(_game->names[id]);
  [_grid addSubview:name];[_rewardLabels addObject:name];
  if(NSUInteger(id)<_tiers.count)tier=MAX(tier,[_tiers[id]intValue]);
  dispatch_async(_queue,^{
   UIImage* art=mediaImage(self->_media,[NSString stringWithFormat:@"cards/%03d.webp",id]);
   if(!art){try{art=LGPixels(self->_game->art(id),102,96);}catch(const std::exception&){}}
   dispatch_async(dispatch_get_main_queue(),^{view.image=art;});
  });
 }
 _grid.contentOffset=CGPointZero;[self.view setNeedsLayout];
 [self stopOpening];
 [self showRewardBackdrop:tier];
 NSURL* cue=mediaFile(_media,@[@"common.wav",@"rare.wav",@"epic.wav",@"legendary.wav"][MAX(0,MIN(3,tier))]);
 if(cue){_stinger=[[AVAudioPlayer alloc]initWithContentsOfURL:cue error:nil];[_stinger play];}
}
- (void)returnToPacks{
 [_stinger stop];_stinger=nil;
 [self stopRewardBackdrop];
 _results.hidden=YES;_menu.hidden=NO;_menu.userInteractionEnabled=YES;
}
- (void)close{
 if(_pending)return;
 ++_animation;
 [self dismissViewControllerAnimated:YES completion:self.closed];
}
@end
