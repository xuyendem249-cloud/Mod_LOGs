#import "LegendGachaView.hpp"
#import "LegendViews.hpp"
#import "LegendConsoleSkin.hpp"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#include "Gacha.hpp"
#include <cmath>

namespace {
using Legend::ConsoleSkin::color;
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
CAGradientLayer* tint(UIView* view,uint32_t top,uint32_t bottom,uint32_t border,CGFloat radius){
 CAGradientLayer* layer=[CAGradientLayer layer];
 layer.colors=@[(__bridge id)color(top).CGColor,(__bridge id)color(bottom).CGColor];
 layer.cornerRadius=radius;layer.borderWidth=1;layer.borderColor=color(border).CGColor;
 [view.layer insertSublayer:layer atIndex:0];
 return layer;
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
 UIScrollView* _choices;
 UIView* _menu,*_results;
 UILabel* _stars,*_message;
 UIButton* _close,*_again,*_tapPack;
 UIStackView* _boxes,*_giftRow;
 UITextField* _code;
 UIScrollView* _grid;
 CAGradientLayer* _walletTint,*_closeTint;
 NSMutableArray<CAGradientLayer*>* _packTints;
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
 self.view.backgroundColor=color(0xff100e20);
 NSURL* background=mediaFile(_media,@"ambient.mp4");
 if(background){
  _ambient=[AVQueuePlayer queuePlayerWithItems:@[]];
  _ambient.muted=YES;
  _ambientLoop=[AVPlayerLooper playerLooperWithPlayer:_ambient templateItem:[AVPlayerItem playerItemWithURL:background]];
  _ambientLayer=[AVPlayerLayer playerLayerWithPlayer:_ambient];
  _ambientLayer.videoGravity=AVLayerVideoGravityResize;
  [self.view.layer addSublayer:_ambientLayer];
 }
 NSURL* music=mediaFile(_media,@"bgm.mp3");
 if(music){_music=[[AVAudioPlayer alloc]initWithContentsOfURL:music error:nil];_music.numberOfLoops=-1;_music.volume=.5;}
 _choices=[[UIScrollView alloc]init];_choices.showsVerticalScrollIndicator=NO;
 _choices.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;[self.view addSubview:_choices];
 _menu=[[UIView alloc]init];[_choices addSubview:_menu];
 _results=[[UIView alloc]init];_results.hidden=YES;[self.view addSubview:_results];
 _podium=[[LGGoldPodium alloc]init];_podium.opaque=NO;_podium.backgroundColor=UIColor.clearColor;
 _podium.art=mediaImage(_media,@"podium.png");[_menu addSubview:_podium];
 UIImage* first=mediaImage(_media,@"pack.png");
 if(first)_faces=@[first,mediaImage(_media,@"kaiba.png")?:first,mediaImage(_media,@"jonouchi.png")?:first];
 _pack=[[UIImageView alloc]initWithImage:first];_pack.contentMode=UIViewContentModeScaleAspectFit;
 [_menu addSubview:_pack];
 _tapPack=[UIButton buttonWithType:UIButtonTypeCustom];_tapPack.tag=1;_tapPack.accessibilityLabel=@"Pack x1";
 [_tapPack addTarget:self action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];[_menu addSubview:_tapPack];
 _stars=label(23,color(0xffffd77c));
 _walletTint=tint(_stars,0xf233261d,0xf215101b,0xffce9a54,12);
 [self.view addSubview:_stars];[self updateStars];
 _close=action(@"×",UIColor.clearColor,self,@selector(close));_close.titleLabel.font=[UIFont boldSystemFontOfSize:22];
 _close.layer.borderWidth=0;
 _closeTint=tint(_close,0xff922f40,0xff641b2b,0xffce6870,12);
 _close.accessibilityLabel=@"Đóng Gacha";[self.view addSubview:_close];
 _message=label(13,UIColor.whiteColor);_message.numberOfLines=2;[self.view addSubview:_message];
 _boxes=[[UIStackView alloc]init];_boxes.distribution=UIStackViewDistributionFillEqually;_boxes.spacing=6;
 _packTints=[NSMutableArray array];
 for(int quantity:{1,5,10}){
  NSString* name=[NSString stringWithFormat:@"Pack x%d\n",quantity];
  NSString* cost=[NSString stringWithFormat:@"★ %d",Legend::Gacha::price(quantity)];
  NSMutableAttributedString* display=[[NSMutableAttributedString alloc]initWithString:name attributes:
   @{NSForegroundColorAttributeName:color(0xfff1eef6),NSFontAttributeName:[UIFont boldSystemFontOfSize:14]}];
  [display appendAttributedString:[[NSAttributedString alloc]initWithString:cost attributes:
   @{NSForegroundColorAttributeName:color(0xffffd77c),NSFontAttributeName:[UIFont boldSystemFontOfSize:16.8]}]];
  UIButton* button=action(name,UIColor.clearColor,self,@selector(open:));
  [button setAttributedTitle:display forState:UIControlStateNormal];
  button.layer.borderWidth=0;
  CAGradientLayer* cap=quantity==5?tint(button,0xff26684c,0xff123b2d,0xff63b987,6):
   quantity==10?tint(button,0xff93374a,0xff5e1b2c,0xffd0707b,6):tint(button,0xff1b1930,0xff1b1930,0xff78663c,6);
  [_packTints addObject:cap];
  button.tag=quantity;
  [_boxes addArrangedSubview:button];
 }
 [_menu addSubview:_boxes];
 _giftRow=[[UIStackView alloc]init];
 _giftRow.spacing=7;_giftRow.layoutMargins=UIEdgeInsetsMake(0,10,0,6);_giftRow.layoutMarginsRelativeArrangement=YES;
 _giftRow.backgroundColor=color(0xe61b1930);_giftRow.layer.cornerRadius=6;
 _giftRow.layer.borderWidth=1;_giftRow.layer.borderColor=color(0xff78663c).CGColor;
 UILabel* gift=label(19,LGGold());gift.text=@"🎁";gift.accessibilityLabel=@"Mã quà Gacha";
 [gift.widthAnchor constraintEqualToConstant:32].active=YES;
 [_giftRow addArrangedSubview:gift];
 _code=[[UITextField alloc]init];
 _code.borderStyle=UITextBorderStyleNone;
 _code.backgroundColor=UIColor.clearColor;_code.textColor=UIColor.whiteColor;
 _code.autocorrectionType=UITextAutocorrectionTypeNo;_code.autocapitalizationType=UITextAutocapitalizationTypeNone;
 _code.accessibilityLabel=@"Mã quà Gacha";
 _code.returnKeyType=UIReturnKeyDone;[_code addTarget:self action:@selector(redeem) forControlEvents:UIControlEventEditingDidEndOnExit];
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
 _again=action(@"Mở tiếp",color(0xff1b1930),self,@selector(returnToPacks));[_grid addSubview:_again];
}
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];
 [_ambient play];[_music play];
 NSURL* entrance=mediaFile(_media,@"enter.wav");
 if(entrance){_stinger=[[AVAudioPlayer alloc]initWithContentsOfURL:entrance error:nil];[_stinger play];}
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
 _ambientLayer.frame=bounds;_rewardLayer.frame=bounds;
 constexpr CGFloat videoWidth=960,videoHeight=540;
 CGFloat openingScale=MIN(MAX(bounds.size.width/videoWidth,bounds.size.height/videoHeight),bounds.size.width/(videoWidth*.6));
 CGSize openingSize=CGSizeMake(videoWidth*openingScale,videoHeight*openingScale);
 _openingLayer.frame=CGRectMake(CGRectGetMidX(bounds)-openingSize.width/2,CGRectGetMidY(bounds)-openingSize.height/2,openingSize.width,openingSize.height);
 _results.frame=bounds;
 CGSize wallet=[_stars sizeThatFits:CGSizeMake(w-90,44)];
 _stars.frame=CGRectMake(x+16,y+9,MAX(84,ceil(wallet.width)+26),44);
 _close.frame=CGRectMake(CGRectGetMaxX(safe)-60,y+9,44,44);
 _walletTint.frame=_stars.bounds;_closeTint.frame=_close.bounds;
 CGFloat top=y+53,width=MAX(1,w-32);
 CGFloat bottom=CGRectGetMaxY(safe);
 if(self.keyboardLayoutGuide.layoutFrame.origin.y>top)bottom=MIN(bottom,self.keyboardLayoutGuide.layoutFrame.origin.y);
 _choices.frame=CGRectMake(x,top,w,MAX(0,bottom-top));
 _menu.frame=CGRectMake(0,0,w,379);_choices.contentSize=_menu.frame.size;
 _pack.bounds=CGRectMake(0,0,144,225);_pack.center=CGPointMake(w/2,112.5);
 _tapPack.frame=CGRectMake((w-144)/2,0,144,225);
 _podium.frame=CGRectMake(16,65,width,160);
 _boxes.frame=CGRectMake(19,225,MAX(1,width-6),64);[_boxes layoutIfNeeded];
 for(NSUInteger i=0;i<_packTints.count;i++)_packTints[i].frame=_boxes.arrangedSubviews[i].bounds;
 _giftRow.frame=CGRectMake(16,313,width,54);
 _message.frame=CGRectMake(x+16,CGRectGetMaxY(safe)-50,width,38);
 _grid.frame=CGRectMake(x+16,top,width,MAX(0,h-65));
 CGFloat usable=_grid.bounds.size.width;
 NSUInteger columns=MIN(_rewardImages.count,3);
 if(_rewardImages.count>1)columns=3;
 if(columns){
  CGFloat cardW=MAX(1,usable/columns-10),cardH=_rewardImages.count==1?192:110;
  for(NSUInteger i=0;i<_rewardImages.count;i++){
   NSUInteger inRow=MIN(columns,_rewardImages.count-(i/columns)*columns);
   CGFloat px=(usable-inRow*(cardW+10))/2+5+(i%columns)*(cardW+10),py=5+(i/columns)*(cardH+58);
   _rewardImages[i].frame=CGRectMake(px,py,cardW,cardH);
   _rewardLabels[i].frame=CGRectMake(px,py+cardH,cardW,48);
  }
  CGFloat end=std::ceil(double(_rewardImages.count)/columns)*(cardH+58);
  _again.frame=CGRectMake((usable-112)/2,end,112,42);
  _grid.contentSize=CGSizeMake(usable,end+54);
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
- (void)updateStars{
 NSString* number=[NSNumberFormatter localizedStringFromNumber:@(_balance) numberStyle:NSNumberFormatterDecimalStyle];
 _stars.text=[@"★ " stringByAppendingString:number];[self.view setNeedsLayout];
}
- (void)busy:(BOOL)on{
 _pending=on;_close.enabled=!on;_boxes.userInteractionEnabled=!on;_giftRow.userInteractionEnabled=!on;
}
- (void)open:(UIButton*)button{
 if(_pending||_revealing||!self.openPacks)return;
 int cost=Legend::Gacha::price(int(button.tag));
 if(_balance<cost){_message.text=[NSString stringWithFormat:@"Cần %d sao để mở ×%ld.",cost,(long)button.tag];return;}
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
 _openingLayer.videoGravity=AVLayerVideoGravityResizeAspect;
 [self.view.layer insertSublayer:_openingLayer below:_stars.layer];
 [self.view setNeedsLayout];
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
 _rewardLayer.videoGravity=AVLayerVideoGravityResize;
 [self.view.layer insertSublayer:_rewardLayer below:_results.layer];
 [_rewardPlayer play];
}
- (void)showRewards:(NSArray<NSNumber*>*)cards{
 ++_animation;
 _revealing=NO;
 _results.hidden=NO;_menu.hidden=YES;
 for(UIView* old in _grid.subviews)if(old!=_again)[old removeFromSuperview];
 _rewardImages=[NSMutableArray array];_rewardLabels=[NSMutableArray array];
 int tier=0;
 for(NSNumber* number in cards){
  int id=number.intValue;
  if(id<1||id>_game->cardCount)continue;
  UIImageView* view=[[UIImageView alloc]init];view.contentMode=UIViewContentModeScaleAspectFit;
  [_grid addSubview:view];[_rewardImages addObject:view];
  UILabel* name=label(12,LGGold());name.numberOfLines=2;name.text=LGText(_game->names[id]);
  [_grid addSubview:name];[_rewardLabels addObject:name];
  if(NSUInteger(id)<_tiers.count)tier=MAX(tier,[_tiers[id]intValue]);
  view.alpha=name.alpha=0;
  [UIView animateWithDuration:.19 delay:(_rewardImages.count-1)*.065 options:UIViewAnimationOptionCurveEaseOut
   animations:^{view.alpha=name.alpha=1;} completion:nil];
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
 _choices.contentOffset=CGPointZero;
}
- (void)close{
 if(_pending)return;
 ++_animation;
 [self dismissViewControllerAnimated:YES completion:self.closed];
}
@end
