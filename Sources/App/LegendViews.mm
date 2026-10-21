#import "LegendViews.hpp"
#import <QuartzCore/QuartzCore.h>
#include <algorithm>
using namespace Legend;
UIColor* LGGold(){return [UIColor colorWithRed:.96 green:.78 blue:.36 alpha:1];}
UIColor* LGInk(){return [UIColor colorWithRed:.045 green:.025 blue:.095 alpha:1];}
NSString* LGText(const std::string& text){return [[NSString alloc]initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding]?:@"";}
NSString* LGOrder(const std::vector<int>& slots){NSMutableArray* a=[NSMutableArray array];for(int slot:slots)[a addObject:[NSString stringWithFormat:@"%d",slot+1]];return [a componentsJoinedByString:@" + "];}
UIImage* LGPixels(const std::vector<uint32_t>& pixels,int width,int height){
 if(pixels.size()!=size_t(width*height))return nil;NSData* bytes=[NSData dataWithBytes:pixels.data() length:pixels.size()*4];CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)bytes);CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
 CGImageRef image=CGImageCreate(width,height,8,32,width*4,space,kCGImageAlphaFirst|kCGBitmapByteOrder32Little,provider,NULL,NO,kCGRenderingIntentDefault);UIImage* result=image?[UIImage imageWithCGImage:image]:nil;if(image)CGImageRelease(image);CGColorSpaceRelease(space);CGDataProviderRelease(provider);return result;
}
NSAttributedString* LGDescription(GameData& data,int card){
 NSString* raw=LGText(data.descriptions[card]);NSMutableAttributedString* out=[[NSMutableAttributedString alloc]init];NSRegularExpression* regex=[NSRegularExpression regularExpressionWithPattern:@"\ue000([0-9]+)\ue001" options:0 error:nil];NSUInteger start=0;
 for(NSTextCheckingResult* match in [regex matchesInString:raw options:0 range:NSMakeRange(0,raw.length)]){[out appendAttributedString:[[NSAttributedString alloc]initWithString:[raw substringWithRange:NSMakeRange(start,match.range.location-start)]]];NSInteger icon=[[raw substringWithRange:[match rangeAtIndex:1]] integerValue];if(icon>=0&&icon<41){NSTextAttachment* a=[[NSTextAttachment alloc]init];a.image=LGPixels(data.icons[icon],16,16);a.bounds=CGRectMake(0,-3,16,16);[out appendAttributedString:[NSAttributedString attributedStringWithAttachment:a]];}start=NSMaxRange(match.range);}
 [out appendAttributedString:[[NSAttributedString alloc]initWithString:[raw substringFromIndex:start]]];if(out.length)[out addAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:14],NSForegroundColorAttributeName:UIColor.whiteColor} range:NSMakeRange(0,out.length)];return out;
}
@implementation LGBackdrop
- (void)drawRect:(CGRect)rect{
 CGContextRef c=UIGraphicsGetCurrentContext();CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGFloat colours[]={.025,.015,.06,1, .22,.065,.32,1, .055,.025,.11,1};CGFloat positions[]={0,.48,1};CGGradientRef gradient=CGGradientCreateWithColorComponents(space,colours,positions,3);CGContextDrawLinearGradient(c,gradient,CGPointZero,CGPointMake(w,h),0);CGGradientRelease(gradient);CGColorSpaceRelease(space);
 CGContextSetStrokeColorWithColor(c,[LGGold() colorWithAlphaComponent:.55].CGColor);CGContextSetLineWidth(c,1.5);CGContextStrokeRect(c,CGRectInset(self.bounds,5,5));CGContextStrokeRect(c,CGRectInset(self.bounds,10,10));
 CGFloat cx=w*.5,cy=h*.52,r=MIN(w,h)*.43;CGContextSetLineWidth(c,2);CGContextSetStrokeColorWithColor(c,[LGGold() colorWithAlphaComponent:.23].CGColor);
 for(int j=0;j<3;j++)CGContextStrokeEllipseInRect(c,CGRectMake(cx-r+j*9,cy-r+j*9,2*(r-j*9),2*(r-j*9)));
 CGContextMoveToPoint(c,cx,cy-r*.84);CGContextAddLineToPoint(c,cx+r*.76,cy+r*.55);CGContextAddLineToPoint(c,cx-r*.76,cy+r*.55);CGContextClosePath(c);CGContextStrokePath(c);
 // Eye motif and geometric glyphs stay outside the opaque game image.
 CGContextMoveToPoint(c,cx-r*.4,cy);CGContextAddQuadCurveToPoint(c,cx,cy-r*.3,cx+r*.4,cy);CGContextAddQuadCurveToPoint(c,cx,cy+r*.3,cx-r*.4,cy);CGContextStrokePath(c);CGContextStrokeEllipseInRect(c,CGRectMake(cx-r*.12,cy-r*.12,r*.24,r*.24));
 CGContextSetStrokeColorWithColor(c,[LGGold() colorWithAlphaComponent:.4].CGColor);
 for(CGFloat y=32;y<h-24;y+=44)for(CGFloat x: {CGFloat(22),w-22}){CGContextMoveToPoint(c,x-5,y);CGContextAddLineToPoint(c,x+5,y);CGContextAddLineToPoint(c,x,y+8);CGContextAddLineToPoint(c,x,y+20);CGContextMoveToPoint(c,x-6,y+15);CGContextAddLineToPoint(c,x+6,y+15);CGContextStrokePath(c);}
}
@end
@implementation LGFusionOverlay{DuelView _view;FusionRow _row;BOOL _has;}
- (instancetype)initWithFrame:(CGRect)frame{if((self=[super initWithFrame:frame])){self.userInteractionEnabled=NO;self.backgroundColor=UIColor.clearColor;self.opaque=NO;}return self;}
- (void)showView:(const DuelView&)view row:(const FusionRow*)row{_view=view;_has=row!=nullptr;if(row)_row=*row;[self setNeedsDisplay];}
- (void)drawRect:(CGRect)rect{if(!_has||!_view.active)return;CGFloat sx=self.bounds.size.width/320,sy=self.bounds.size.height/240;for(size_t order=_view.prefix.size();order<_row.slots.size();order++)for(const auto& h:_view.hand)if(h.slot==_row.slots[order]){CGRect box=CGRectMake((h.x+33)*sx,(h.y+2)*sy,13*sx,10*sy);[[UIColor colorWithRed:.21 green:.06 blue:.1 alpha:1]setFill];[[UIBezierPath bezierPathWithRoundedRect:box cornerRadius:2]fill];NSString* t=[NSString stringWithFormat:@"%zu",order+1];NSMutableParagraphStyle* p=[[NSMutableParagraphStyle alloc]init];p.alignment=NSTextAlignmentCenter;[t drawInRect:box withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:box.size.height*.85],NSForegroundColorAttributeName:[UIColor colorWithRed:1 green:.35 blue:.35 alpha:1],NSParagraphStyleAttributeName:p}];}}
@end

@interface LGDetail:UIViewController
@property(nonatomic,strong) NSAttributedString* content;
@property(nonatomic,strong) UIImage* art;
@property(nonatomic,copy) NSString* heading;
@property(nonatomic,strong) NSArray<UIImage*>* ingredients;
@end
@implementation LGDetail{UIScrollView* _scroll;UILabel* _text;UIImageView* _art;UIButton* _close;NSMutableArray<UIImageView*>* _ingredients;}
- (void)viewDidLoad{[super viewDidLoad];self.view.backgroundColor=LGInk();_close=[UIButton buttonWithType:UIButtonTypeSystem];[_close setTitle:@"Đóng hình ảnh" forState:0];[_close setTitleColor:LGGold() forState:0];[_close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_close];_scroll=[[UIScrollView alloc]init];[self.view addSubview:_scroll];_art=[[UIImageView alloc]initWithImage:self.art];_art.contentMode=UIViewContentModeScaleAspectFit;_art.layer.magnificationFilter=kCAFilterNearest;[_scroll addSubview:_art];_text=[[UILabel alloc]init];_text.numberOfLines=0;_text.attributedText=self.content;[_scroll addSubview:_text];_ingredients=[NSMutableArray array];for(UIImage* image in self.ingredients){UIImageView* v=[[UIImageView alloc]initWithImage:image];v.contentMode=UIViewContentModeScaleAspectFit;[_ingredients addObject:v];[_scroll addSubview:v];}}
- (void)close{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];CGRect a=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);_close.frame=CGRectMake(a.origin.x,a.origin.y,a.size.width,42);_scroll.frame=CGRectMake(a.origin.x,a.origin.y+44,a.size.width,MAX(0,a.size.height-44));CGFloat w=_scroll.bounds.size.width,s=MIN(240,w-32);_art.frame=CGRectMake((w-s)/2,8,s,s*96/102);CGFloat y=CGRectGetMaxY(_art.frame)+12;for(NSUInteger i=0;i<_ingredients.count;i++)_ingredients[i].frame=CGRectMake(w/2-90+i*96,y,84,80);if(_ingredients.count)y+=90;CGSize size=[_text sizeThatFits:CGSizeMake(w-32,CGFLOAT_MAX)];_text.frame=CGRectMake(16,y,w-32,size.height);_scroll.contentSize=CGSizeMake(w,y+size.height+24);}
- (BOOL)prefersStatusBarHidden{return YES;}
@end

@implementation LGVipController{
 std::shared_ptr<GameData> _data;std::shared_ptr<Bytes> _ram;DuelView _duel;dispatch_queue_t _queue;
 UIButton* _close;UIButton* _npcButton;UIImageView* _npcPhoto;UISegmentedControl* _tabs;UISearchBar* _search;UISwitch* _follow;UISwitch* _dealt;UILabel* _followLabel;UILabel* _dealtLabel;UILabel* _status;
 UITableView* _table;UIScrollView* _detail;UILabel* _description;UIImageView* _art;NSArray<UIImageView*>* _materials;
 NSMutableArray<NSDictionary*>* _rows;NSDictionary* _selection;NSInteger _npc,_revision;BOOL _wide,_actual;CGFloat _keyboard;
}
- (instancetype)initWithData:(std::shared_ptr<GameData>)data queue:(dispatch_queue_t)queue ram:(std::shared_ptr<Bytes>)ram{if((self=[super init])){_data=std::move(data);_queue=queue;_ram=std::move(ram);if(_ram)_duel=FusionAdvisor::inspect(*_ram);_npc=_duel.npc>=1&&_duel.npc<=40?_duel.npc:1;self.modalPresentationStyle=UIModalPresentationFullScreen;}return self;}
- (UILabel*)label:(NSString*)s{UILabel* l=[[UILabel alloc]init];l.text=s;l.textColor=LGGold();l.font=[UIFont systemFontOfSize:12];[self.view addSubview:l];return l;}
- (void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=LGInk();_rows=[NSMutableArray array];_close=[UIButton buttonWithType:UIButtonTypeSystem];[_close setTitle:@"VIP · Deck & Drop                         Đóng" forState:0];[_close setTitleColor:LGGold() forState:0];[_close addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_close];
 _npcPhoto=[[UIImageView alloc]init];_npcPhoto.contentMode=UIViewContentModeScaleAspectFit;[self.view addSubview:_npcPhoto];_npcButton=[UIButton buttonWithType:UIButtonTypeSystem];[_npcButton setTitleColor:UIColor.whiteColor forState:0];[_npcButton addTarget:self action:@selector(chooseNPC) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:_npcButton];
 _tabs=[[UISegmentedControl alloc]initWithItems:@[@"Deck",@"S/A POW",@"BCD POW",@"S/A TECH",@"Fusion"]];_tabs.selectedSegmentIndex=0;_tabs.selectedSegmentTintColor=LGGold();[_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor,NSFontAttributeName:[UIFont systemFontOfSize:10]} forState:0];[_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName:LGInk()} forState:UIControlStateSelected];[_tabs addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];[self.view addSubview:_tabs];
 _search=[[UISearchBar alloc]init];_search.placeholder=@"ID / tên bài / nguyên liệu Fusion";_search.delegate=self;_search.searchBarStyle=UISearchBarStyleMinimal;_search.searchTextField.textColor=UIColor.whiteColor;[self.view addSubview:_search];
 _followLabel=[self label:@"Theo NPC"];_dealtLabel=[self label:@"40 lá đã chia"];_follow=[[UISwitch alloc]init];_follow.on=YES;[_follow addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];[self.view addSubview:_follow];_dealt=[[UISwitch alloc]init];[_dealt addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];[self.view addSubview:_dealt];_status=[self label:@""];
 _table=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];_table.backgroundColor=LGInk();_table.dataSource=self;_table.delegate=self;_table.rowHeight=96;_table.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;[self.view addSubview:_table];
 _detail=[[UIScrollView alloc]init];_detail.backgroundColor=[UIColor colorWithRed:.12 green:.075 blue:.2 alpha:1];[self.view addSubview:_detail];_art=[[UIImageView alloc]init];_art.contentMode=UIViewContentModeScaleAspectFit;_art.layer.magnificationFilter=kCAFilterNearest;[_detail addSubview:_art];_description=[[UILabel alloc]init];_description.numberOfLines=0;[_detail addSubview:_description];UIImageView* one=[[UIImageView alloc]init];UIImageView* two=[[UIImageView alloc]init];_materials=@[one,two];for(UIImageView* v in _materials){v.contentMode=UIViewContentModeScaleAspectFit;[_detail addSubview:v];}
 [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];[self refresh];
}
- (void)dealloc{[[NSNotificationCenter defaultCenter]removeObserver:self];}
- (void)keyboard:(NSNotification*)note{CGRect r=[self.view convertRect:[note.userInfo[UIKeyboardFrameEndUserInfoKey]CGRectValue] fromView:nil];_keyboard=MAX(0,CGRectGetMaxY(self.view.bounds)-r.origin.y);[self.view setNeedsLayout];}
- (void)close{[self.view endEditing:YES];_revision++;[self dismissViewControllerAnimated:YES completion:self.closed];}
- (BOOL)prefersStatusBarHidden{return YES;}
- (void)chooseNPC{
 UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Chọn NPC" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 for(int n=1;n<=40;n++){NSString* name=[NSString stringWithFormat:@"[%02d] %@",n,LGText(_data->npcNames[n==40?0:n])];[a addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){self->_npc=n;self->_follow.on=NO;[self refresh];}]];}
 [a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=_npcButton;a.popoverPresentationController.sourceRect=_npcButton.bounds;[self presentViewController:a animated:YES completion:nil];
}
- (BOOL)matches:(NSString*)q card:(int)card{return q.length==0||[q isEqualToString:[NSString stringWithFormat:@"%d",card]]||[LGText(_data->names[card]) rangeOfString:q options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound;}
- (void)searchBar:(UISearchBar*)bar textDidChange:(NSString*)text{[self refresh];}
- (void)searchBarSearchButtonClicked:(UISearchBar*)bar{[bar resignFirstResponder];[self refresh];}
- (void)refresh{
 if(_follow.on&&_duel.npc>=1&&_duel.npc<=40)_npc=_duel.npc;int physical=_npc==40?0:int(_npc),mode=int(_tabs.selectedSegmentIndex);NSInteger revision=++_revision;
 [_npcButton setTitle:[NSString stringWithFormat:@"[%02ld] %@ ▾",(long)_npc,LGText(_data->npcNames[physical])] forState:0];_npcPhoto.image=LGPixels(_data->npcPhoto(physical),48,48);_dealt.hidden=_dealtLabel.hidden=mode!=0;
 NSString* q=[_search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];BOOL actual=_dealt.on&&mode==0&&_ram&&_duel.duel&&_duel.npc==_npc;_status.text=@"Đang đọc…";
 dispatch_async(_queue,^{NSMutableArray* found=[NSMutableArray array];NSString* problem=nil;try{
  if(mode==4){int terrain=self->_duel.duel?std::clamp(self->_duel.terrain,0,6):0;for(const auto& entry:self->_data->fusions(terrain)){int a=entry.first/1024,b=entry.first%1024,r=entry.second;if([self matches:q card:a]||[self matches:q card:b]||[self matches:q card:r])[found addObject:@{@"id":@(r),@"a":@(a),@"b":@(b),@"weight":@0}];}}
  else{std::array<int,722> weights=self->_data->pools[physical][mode];if(actual){weights.fill(0);for(int i=0;i<40;i++){int id=u16(*self->_ram,0x1a7e20+(40+i)*6);if(id>=1&&id<=722)weights[id-1]++;}}for(int id=1;id<=722;id++)if(weights[id-1]&&[self matches:q card:id])[found addObject:@{@"id":@(id),@"weight":@(weights[id-1])}];[found sortUsingComparator:^NSComparisonResult(NSDictionary* a,NSDictionary* b){int x=[a[@"weight"]intValue],y=[b[@"weight"]intValue];if(x!=y)return x>y?NSOrderedAscending:NSOrderedDescending;return [a[@"id"]compare:b[@"id"]];}];}
 }catch(const std::exception& e){problem=LGText(e.what());}
 dispatch_async(dispatch_get_main_queue(),^{if(revision!=self->_revision)return;self->_actual=actual;self->_rows=found;self->_status.text=problem?:[NSString stringWithFormat:@"%lu dòng%@",(unsigned long)found.count,actual?@" · 40 lá thực tế":@" · trọng số / 2048"];[self->_table reloadData];self->_selection=found.firstObject;if(self->_selection)[self detail:self->_selection modal:NO];else{self->_art.image=nil;self->_description.text=@"Không tìm thấy bài";}});
 });
}
- (NSInteger)tableView:(UITableView*)table numberOfRowsInSection:(NSInteger)section{return _rows.count;}
- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)path{
 UITableViewCell* cell=[table dequeueReusableCellWithIdentifier:@"card"];if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"card"];NSDictionary* row=_rows[path.row];int id=[row[@"id"]intValue];cell.textLabel.text=[NSString stringWithFormat:@"[%03d] %@",id,LGText(_data->names[id])];cell.textLabel.textColor=LGGold();cell.textLabel.font=[UIFont boldSystemFontOfSize:13];cell.textLabel.numberOfLines=2;auto s=_data->stats(id);NSString* extra=row[@"a"]?[NSString stringWithFormat:@"[%@] %@ + [%@] %@",row[@"a"],LGText(_data->names[[row[@"a"]intValue]]),row[@"b"],LGText(_data->names[[row[@"b"]intValue]])]:_actual?[NSString stringWithFormat:@"Số lượng: %@",row[@"weight"]]:[NSString stringWithFormat:@"Trọng số: %@ · %.4f%%",row[@"weight"],[row[@"weight"]doubleValue]*100/2048];cell.detailTextLabel.text=[NSString stringWithFormat:@"ATK %d / DEF %d\n%@",s[0],s[1],extra];cell.detailTextLabel.textColor=UIColor.whiteColor;cell.detailTextLabel.font=[UIFont systemFontOfSize:11];cell.detailTextLabel.numberOfLines=3;cell.backgroundColor=path.row%2?[UIColor colorWithRed:.09 green:.06 blue:.15 alpha:1]:[UIColor colorWithRed:.14 green:.10 blue:.22 alpha:1];cell.imageView.image=nil;cell.tag=id;
 if(!row[@"a"]){dispatch_async(_queue,^{UIImage* art=nil;try{art=LGPixels(self->_data->art(id),102,96);}catch(...){}dispatch_async(dispatch_get_main_queue(),^{if(cell.tag==id){cell.imageView.image=art;[cell setNeedsLayout];}});});}return cell;
}
- (void)tableView:(UITableView*)table didSelectRowAtIndexPath:(NSIndexPath*)path{_selection=_rows[path.row];[self detail:_selection modal:!_wide];}
- (void)detail:(NSDictionary*)row modal:(BOOL)modal{
 int id=[row[@"id"]intValue];NSInteger revision=_revision;dispatch_async(_queue,^{UIImage* art=nil;NSMutableArray* materials=[NSMutableArray array];try{art=LGPixels(self->_data->art(id),102,96);if(row[@"a"])for(NSString* k in @[@"a",@"b"]){UIImage* image=LGPixels(self->_data->art([row[k]intValue]),102,96);if(image)[materials addObject:image];}}catch(...){}
 auto stats=self->_data->stats(id);NSString* head=[NSString stringWithFormat:@"[%03d] %@\nATK %d / DEF %d\n\n",id,LGText(self->_data->names[id]),stats[0],stats[1]];NSMutableAttributedString* content=[[NSMutableAttributedString alloc]initWithString:head attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:14],NSForegroundColorAttributeName:LGGold()}];[content appendAttributedString:LGDescription(*self->_data,id)];
 dispatch_async(dispatch_get_main_queue(),^{if(revision!=self->_revision||self->_selection!=row)return;if(modal&&!self->_wide){LGDetail* d=[[LGDetail alloc]init];d.content=content;d.art=art;d.ingredients=materials;d.modalPresentationStyle=UIModalPresentationFullScreen;[self presentViewController:d animated:YES completion:nil];}else{self->_art.image=art;self->_description.attributedText=content;for(NSUInteger i=0;i<2;i++)self->_materials[i].image=i<materials.count?materials[i]:nil;self->_detail.contentOffset=CGPointZero;[self.view setNeedsLayout];}});
 });
}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];CGRect a=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);CGFloat x=a.origin.x+8,y=a.origin.y,w=a.size.width-16,h=a.size.height;BOOL wasWide=_wide;_wide=a.size.width>a.size.height&&w>=600;if(!wasWide&&_wide&&[self.presentedViewController isKindOfClass:LGDetail.class])[self dismissViewControllerAnimated:NO completion:nil];CGFloat left=_wide?w*.55:w;
 _close.frame=CGRectMake(x,y,w,36);y+=38;CGFloat contentY=y;_npcPhoto.frame=CGRectMake(x,y,40,40);_npcButton.frame=CGRectMake(x+44,y,left-44,40);y+=42;_tabs.frame=CGRectMake(x,y,left,32);y+=34;_search.frame=CGRectMake(x-6,y,left+12,44);y+=44;
 _followLabel.frame=CGRectMake(x,y,left*.5-50,32);_follow.frame=CGRectMake(x+left*.5-53,y,51,31);_dealtLabel.frame=CGRectMake(x+left*.5+4,y,left*.5-59,32);_dealt.frame=CGRectMake(x+left-51,y,51,31);y+=32;_status.frame=CGRectMake(x,y,left,24);y+=24;
 CGFloat bottom=MIN(CGRectGetMaxY(a),self.view.bounds.size.height-_keyboard);_table.frame=CGRectMake(x,y,left,MAX(0,bottom-y));_detail.hidden=!_wide;_detail.frame=CGRectMake(x+left+8,contentY,MAX(0,w-left-8),MAX(0,h-38));CGFloat dw=_detail.bounds.size.width,s=MIN(150,MAX(1,dw-24));_art.frame=CGRectMake((dw-s)/2,6,s,s*96/102);CGFloat dy=CGRectGetMaxY(_art.frame)+8;BOOL mat=_materials.firstObject.image!=nil;for(NSUInteger i=0;i<2;i++){_materials[i].hidden=!mat;_materials[i].frame=CGRectMake(dw/2-76+i*80,dy,72,68);}if(mat)dy+=76;CGSize size=[_description sizeThatFits:CGSizeMake(MAX(1,dw-20),CGFLOAT_MAX)];_description.frame=CGRectMake(10,dy,MAX(1,dw-20),size.height);_detail.contentSize=CGSizeMake(dw,dy+size.height+20);
}
@end

@implementation LGSettingsController
- (void)viewDidLoad{[super viewDidLoad];self.title=@"Cấu hình · Legend iOS 0.3";self.view.backgroundColor=LGInk();self.tableView.backgroundColor=LGInk();self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Đóng" style:UIBarButtonItemStyleDone target:self action:@selector(close)];}
- (void)close{[self dismissViewControllerAnimated:YES completion:self.closed];}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)table{return 3;}
- (NSInteger)tableView:(UITableView*)table numberOfRowsInSection:(NSInteger)section{return section==0?4:section==1?6:1;}
- (NSString*)tableView:(UITableView*)table titleForHeaderInSection:(NSInteger)section{return @[@"Hình gốc 4:3 · tự xoay dọc/ngang",@"BIOS & thẻ nhớ",@"Mã nguồn và giấy phép"][section];}
- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)p{
 UITableViewCell* c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];c.backgroundColor=[UIColor colorWithRed:.14 green:.09 blue:.22 alpha:1];c.textLabel.textColor=UIColor.whiteColor;c.detailTextLabel.textColor=LGGold();c.textLabel.font=[UIFont systemFontOfSize:14];
 if(p.section==0){c.textLabel.text=@[@"Fusion",@"Tốc độ",@"Slot lưu nhanh",@"Âm lượng"][p.row];c.detailTextLabel.text=p.row==0?@[@"Tắt",@"Chỉ số thứ tự",@"Số + hướng dẫn"][self.fusionMode]:p.row==1?[NSString stringWithFormat:@"%.2g×",self.speed]:p.row==2?[NSString stringWithFormat:@"%ld / 10",(long)self.slot]:@"";if(p.row==3){UISlider* s=[[UISlider alloc]initWithFrame:CGRectMake(0,0,170,32)];s.minimumValue=0;s.maximumValue=1;s.value=self.volume;[s addTarget:self action:@selector(volumeChanged:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;}}
 else if(p.section==1)c.textLabel.text=@[@"Nhập BIOS 512 KB",@"Nhập thẻ nhớ RAW 128 KB",@"Xuất thẻ nhớ",@"Khởi động lại game",@"Lưu vào slot hiện tại",@"Tải slot hiện tại"][p.row];else c.textLabel.text=@"SwanStation · mã nguồn · giấy phép";return c;
}
- (void)volumeChanged:(UISlider*)s{self.volume=s.value;if(self.changed)self.changed(self);}
- (void)tableView:(UITableView*)table didSelectRowAtIndexPath:(NSIndexPath*)p{
 [table deselectRowAtIndexPath:p animated:YES];if(p.section==0&&p.row<3){NSArray* choices=p.row==0?@[@"Tắt",@"Chỉ đánh số",@"Số + bảng hướng dẫn"]:p.row==1?@[@"1×",@"1.3×",@"1.5×",@"2×",@"2.5×",@"3×",@"4×"]:@[@"Slot 1",@"Slot 2",@"Slot 3",@"Slot 4",@"Slot 5",@"Slot 6",@"Slot 7",@"Slot 8",@"Slot 9",@"Slot 10"];
 UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Chọn" message:nil preferredStyle:UIAlertControllerStyleActionSheet];for(NSUInteger i=0;i<choices.count;i++)[a addAction:[UIAlertAction actionWithTitle:choices[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){const double speeds[]={1,1.3,1.5,2,2.5,3,4};if(p.row==0)self.fusionMode=i;else if(p.row==1)self.speed=speeds[i];else self.slot=i+1;if(self.changed)self.changed(self);[self.tableView reloadData];}]];[a addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=table;a.popoverPresentationController.sourceRect=[table rectForRowAtIndexPath:p];[self presentViewController:a animated:YES completion:nil];
 }else if(p.section!=0){NSString* command=p.section==2?@"license":@[@"bios",@"cardIn",@"cardOut",@"reset",@"save",@"load"][p.row];[self dismissViewControllerAnimated:YES completion:^{if(self.command)self.command(command);}];}
}
@end
