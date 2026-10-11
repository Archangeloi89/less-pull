#import "GuideTour.h"
#import "Localize.h"
#import <QuartzCore/QuartzCore.h>

// What the guide's face and body do on a beat. HOP, SPIN, WIGGLE, SQUINT and DIZZY play once; GRAY and BLUSH stay
// until a beat says PLAIN; DROOP comes by itself while it waits for you.
typedef NS_ENUM(NSInteger,GTFace){GTFaceNone,GTFaceHop,GTFaceSpin,GTFaceWiggle,GTFaceDroop,GTFaceSquint,GTFaceGray,GTFaceBlush,GTFaceDizzy,GTFacePlain};

// ---- One beat: a line, a face, maybe a card with a scene, a place to go, something real to do or wait for.
@interface GTBeat : NSObject
@property(copy) NSString *say;
@property GTFace face;
@property NSInteger scene;                      // -1: a plain bubble; otherwise a card with this scene
@property(copy) NSValue *(^to)(void);           // where the guide goes (screen point); nil: stays
@property(copy) NSValue *(^pointAt)(void);      // what its pointy side points at (screen point); nil: the card
@property(copy) NSValue *(^avoid)(void);        // a real panel to keep clear of (screen rect)
@property(copy) void (^run)(void);
@property(copy) BOOL (^onlyIf)(void);
@property(copy) BOOL (^until)(void);
@property double timeout,hold;
@property(copy) NSString *timeoutSay;
@property BOOL home;
@end
@implementation GTBeat
- (instancetype)init {if((self=[super init]))_scene=-1;return self;}
@end
static GTBeat *Beat(NSString *say,GTFace face) {GTBeat *b=[GTBeat new];b.say=say;b.face=face;return b;}

static double Ease(double k){k=MAX(0,MIN(1,k));return k<.5?4*k*k*k:1-pow(-2*k+2,3)/2;}
static NSColor *Mix(NSColor *a,NSColor *b,double k){a=[a colorUsingColorSpace:NSColorSpace.sRGBColorSpace];b=[b colorUsingColorSpace:NSColorSpace.sRGBColorSpace];k=MAX(0,MIN(1,k));
 return [NSColor colorWithSRGBRed:a.redComponent+(b.redComponent-a.redComponent)*k green:a.greenComponent+(b.greenComponent-a.greenComponent)*k blue:a.blueComponent+(b.blueComponent-a.blueComponent)*k alpha:a.alphaComponent+(b.alphaComponent-a.alphaComponent)*k];}

// ---- The guide, its card or bubble, on a transparent layer over the whole screen.
@interface GuideView : NSView
@property NSPoint pos,pointAt;               // view coordinates; pointAt NSZeroPoint: no particular target
@property double size,alpha,clock,angle,grayK,blushK,grayTarget,blushTarget,cardAlpha,cardTarget;
@property double hopAt,spinAt,wiggleAt,squintAt,dizzyAt,blinkAt,nextBlink;
@property BOOL droop,still;                   // still: Reduce Motion
@property NSRect card;                       // view coordinates; empty: no card or bubble
@property(copy) NSString *text;
@property(nonatomic) NSView *scene;
@end
@implementation GuideView
- (instancetype)initWithFrame:(NSRect)f {if((self=[super initWithFrame:f])){_hopAt=_spinAt=_wiggleAt=_squintAt=_dizzyAt=_blinkAt=-100;}return self;}
- (BOOL)isFlipped {return NO;}
- (void)setScene:(NSView *)scene {if(_scene==scene)return;[_scene removeFromSuperview];_scene=scene;if(scene){scene.alphaValue=0;[self addSubview:scene];}}
- (double)radius {return 19*self.size;}
- (NSPoint)drawnCenter {
 NSPoint p=self.pos;double t=self.clock;
 if(!self.still){p.y+=sin(t*2.1)*1.5;
  double h=t-self.hopAt;if(h>=0&&h<.62)p.y+=16*fabs(sin(M_PI*h/.31))*(1-h/.62);
  double w=t-self.wiggleAt;if(w>=0&&w<.7)p.x+=3.2*sin(w*42)*(1-w/.7);}
 return p;
}
- (NSRect)textRect {return NSMakeRect(NSMinX(self.card)+16,NSMinY(self.card)+14,self.card.size.width-32,self.scene?self.card.size.height-14-14-self.scene.frame.size.height-10:self.card.size.height-28);}
- (void)drawRect:(NSRect)dirty {
 if(self.alpha<=0.01)return;
 NSPoint p=[self drawnCenter];double r=[self radius],t=self.clock;
 // the card or bubble, with a small tail toward the guide
 if(!NSIsEmptyRect(self.card)&&self.cardAlpha>0.01){
  double a=self.cardAlpha;NSRect c=self.card;
  NSBezierPath *box=[NSBezierPath bezierPathWithRoundedRect:c xRadius:16 yRadius:16];
  NSPoint edge=NSMakePoint(MIN(MAX(p.x,NSMinX(c)+22),NSMaxX(c)-22),MIN(MAX(p.y,NSMinY(c)+22),NSMaxY(c)-22));
  if(p.x<NSMinX(c))edge.x=NSMinX(c);else if(p.x>NSMaxX(c))edge.x=NSMaxX(c);else if(p.y<NSMinY(c))edge.y=NSMinY(c);else edge.y=NSMaxY(c);
  double dx=p.x-edge.x,dy=p.y-edge.y,len=hypot(dx,dy);
  if(len>r+4){double ux=dx/len,uy=dy/len;NSBezierPath *tail=[NSBezierPath bezierPath];[tail moveToPoint:NSMakePoint(edge.x-uy*9,edge.y+ux*9)];[tail lineToPoint:NSMakePoint(edge.x+ux*12,edge.y+uy*12)];[tail lineToPoint:NSMakePoint(edge.x+uy*9,edge.y-ux*9)];[tail closePath];[box appendBezierPath:tail];}
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh=[NSShadow new];sh.shadowBlurRadius=22;sh.shadowOffset=NSMakeSize(0,-5);sh.shadowColor=[NSColor colorWithWhite:0 alpha:.3*a];[sh set];
  [[NSColor.windowBackgroundColor colorWithAlphaComponent:.98*a] setFill];[box fill];
  [NSGraphicsContext restoreGraphicsState];
  [[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:.55*a] setStroke];box.lineWidth=1.2;[box stroke];
  if(self.text.length){NSMutableParagraphStyle *ps=[NSMutableParagraphStyle new];ps.lineSpacing=2;ps.alignment=self.scene?NSTextAlignmentCenter:NSTextAlignmentNatural;
   NSDictionary *at=@{NSFontAttributeName:[NSFont systemFontOfSize:14 weight:NSFontWeightRegular],NSForegroundColorAttributeName:[NSColor.labelColor colorWithAlphaComponent:a],NSParagraphStyleAttributeName:ps};
   [self.text drawWithRect:[self textRect] options:NSStringDrawingUsesLineFragmentOrigin attributes:at];}
  self.scene.alphaValue=a;
 }
 // the guide: the menu-bar circle with a pointy side and a face
 NSColor *ember=[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:1];
 NSColor *half=Mix(Mix(ember,[NSColor colorWithSRGBRed:.86 green:.2 blue:.12 alpha:1],self.blushK),[NSColor colorWithWhite:.62 alpha:1],self.grayK);
 [NSGraphicsContext saveGraphicsState];
 NSShadow *glow=[NSShadow new];glow.shadowBlurRadius=14*self.size;glow.shadowOffset=NSZeroSize;glow.shadowColor=[Mix(ember,[NSColor colorWithWhite:.7 alpha:1],self.grayK) colorWithAlphaComponent:.5*self.alpha];[glow set];
 NSBezierPath *body=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-r,p.y-r,2*r,2*r)];
 double ang=self.angle;NSBezierPath *tip=[NSBezierPath bezierPath];
 [tip moveToPoint:NSMakePoint(p.x+cos(ang+0.75)*r*.92,p.y+sin(ang+0.75)*r*.92)];[tip lineToPoint:NSMakePoint(p.x+cos(ang)*r*1.62,p.y+sin(ang)*r*1.62)];[tip lineToPoint:NSMakePoint(p.x+cos(ang-0.75)*r*.92,p.y+sin(ang-0.75)*r*.92)];[tip closePath];
 [[NSColor colorWithWhite:.15 alpha:self.alpha] setFill];[body fill];[tip fill];
 [NSGraphicsContext restoreGraphicsState];
 // the two halves of the mark, which can twirl
 [NSGraphicsContext saveGraphicsState];
 NSAffineTransform *tr=[NSAffineTransform transform];[tr translateXBy:p.x yBy:p.y];
 double s=t-self.spinAt;if(!self.still&&s>=0&&s<.8)[tr rotateByDegrees:-360*Ease(s/.8)];[tr concat];
 double m=r*.74;
 NSBezierPath *right=[NSBezierPath bezierPath];[right moveToPoint:NSMakePoint(0,-m)];[right appendBezierPathWithArcWithCenter:NSZeroPoint radius:m startAngle:-90 endAngle:90];[right closePath];[[half colorWithAlphaComponent:self.alpha] setFill];[right fill];
 NSBezierPath *left=[NSBezierPath bezierPath];[left moveToPoint:NSMakePoint(0,m)];[left appendBezierPathWithArcWithCenter:NSZeroPoint radius:m startAngle:90 endAngle:270];[left closePath];[[NSColor colorWithWhite:.94 alpha:self.alpha] setFill];[left fill];
 [NSGraphicsContext restoreGraphicsState];
 NSBezierPath *ring=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-r+1,p.y-r+1,2*r-2,2*r-2)];ring.lineWidth=1.4;[[NSColor colorWithWhite:.97 alpha:.85*self.alpha] setStroke];[ring stroke];
 // the eyes: they look where the guide points, blink now and then, squint when happy, droop while waiting, wobble when dizzy
 double look=0.07*r;NSPoint lookOff=NSMakePoint(cos(ang)*look,sin(ang)*look);
 double d=t-self.dizzyAt;if(!self.still&&d>=0&&d<1.1){lookOff.x+=cos(d*14)*r*.08;lookOff.y+=sin(d*14)*r*.08;}
 BOOL squint=t-self.squintAt>=0&&t-self.squintAt<1.3;double blink=(t>=self.blinkAt&&t<self.blinkAt+.13)?.12:1;
 for(int i=-1;i<=1;i+=2){NSPoint e=NSMakePoint(p.x+i*r*.27+lookOff.x,p.y+r*.14+lookOff.y);double ew=r*.13,eh=r*.21;
  NSColor *ink=[NSColor colorWithWhite:.1 alpha:self.alpha];
  if(squint){NSBezierPath *arc=[NSBezierPath bezierPath];[arc moveToPoint:NSMakePoint(e.x-ew,e.y-eh*.2)];[arc curveToPoint:NSMakePoint(e.x+ew,e.y-eh*.2) controlPoint1:NSMakePoint(e.x-ew*.5,e.y+eh*.8) controlPoint2:NSMakePoint(e.x+ew*.5,e.y+eh*.8)];arc.lineWidth=1.6*self.size;arc.lineCapStyle=NSLineCapStyleRound;[ink setStroke];[arc stroke];continue;}
  NSRect er=NSMakeRect(e.x-ew,e.y-eh*blink,ew*2,2*eh*blink);
  if(self.droop){[NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRect:NSMakeRect(er.origin.x-1,er.origin.y-1,er.size.width+2,er.size.height*.58)] addClip];[ink setFill];[[NSBezierPath bezierPathWithOvalInRect:er] fill];[NSGraphicsContext restoreGraphicsState];}
  else {[ink setFill];[[NSBezierPath bezierPathWithOvalInRect:er] fill];[[NSColor colorWithWhite:1 alpha:.8*self.alpha] setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(er.origin.x+ew*.9,NSMaxY(er)-eh*.55*blink,ew*.55,eh*.45*blink)] fill];}
 }
}
@end

@interface GuideTour ()
@property NSPanel *overlay;
@property GuideView *view;
@property NSTimer *frameTimer,*waitTimer;
@property NSArray<NSArray<GTBeat *> *(^)(void)> *steps;
@property NSArray *cleanups;
@property(nonatomic,readwrite) NSInteger step;
@property(nonatomic,readwrite) BOOL slow;
@property NSInteger beatIndex,generation,sceneKind;
@property NSArray<GTBeat *> *beats;
@property NSPoint from,target;
@property double moveStart,moveDuration,waitStart;
@property BOOL peekSeen,running,waiting;
@property NSRect avoidRect;                    // screen coordinates: the real panel on screen now
@end

@implementation GuideTour
- (instancetype)initWithHost:(id<GuideTourHost>)host {if((self=[super init])){_host=host;_sceneKind=-1;}return self;}
- (NSInteger)stepCount {return self.steps.count;}
- (double)pace {return self.slow?1.6:1;}
- (BOOL)reduceMotion {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;}
- (NSScreen *)screen {NSRect icon=[self.host guideIconFrame];for(NSScreen *s in NSScreen.screens)if(!NSIsEmptyRect(icon)&&NSIntersectsRect(s.frame,icon))return s;NSRect f=[self.host guideSettingsFrame];for(NSScreen *s in NSScreen.screens)if(NSIntersectsRect(s.frame,f))return s;return NSScreen.mainScreen?:NSScreen.screens.firstObject;}
- (NSPoint)local:(NSPoint)q {return NSMakePoint(q.x-self.overlay.frame.origin.x,q.y-self.overlay.frame.origin.y);}
- (NSRect)localRect:(NSRect)q {if(NSIsEmptyRect(q))return NSZeroRect;q.origin=[self local:q.origin];return q;}
- (NSPoint)iconPoint {NSRect f=[self.host guideIconFrame];return NSIsEmptyRect(f)?NSZeroPoint:NSMakePoint(NSMidX(f),NSMidY(f));}
- (NSRect)bounds {return NSInsetRect([self localRect:self.screen.visibleFrame],12,12);}

#pragma mark start and end
- (void)start {
 if(self.running)return;self.running=YES;
 NSScreen *s=self.screen;
 self.overlay=[[NSPanel alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.overlay.opaque=NO;self.overlay.backgroundColor=NSColor.clearColor;self.overlay.ignoresMouseEvents=YES;self.overlay.hasShadow=NO;self.overlay.level=NSPopUpMenuWindowLevel+1;  // above the real panels; cards are placed beside them
 self.overlay.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;
 self.view=[[GuideView alloc]initWithFrame:(NSRect){NSZeroPoint,s.frame.size}];self.view.size=1;self.view.still=self.reduceMotion;self.overlay.contentView=self.view;[self.overlay setFrame:s.frame display:NO];[self.overlay orderFrontRegardless];
 self.overlay.accessibilityLabel=L(@"Less Pull tour");
 [self buildSteps];
 NSPoint icon=[self iconPoint];NSRect startFrame=[self.host guideStartFrame];
 NSPoint begin=NSEqualPoints(icon,NSZeroPoint)?NSMakePoint(NSMidX(startFrame),NSMaxY(startFrame)-40):icon;
 self.view.pos=self.from=self.target=[self local:begin];self.view.alpha=self.reduceMotion?1:0;self.view.size=self.reduceMotion?1:.4;self.view.nextBlink=CACurrentMediaTime()+2;
 self.frameTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(frame:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.frameTimer forMode:NSRunLoopCommonModes];
 [self playStep:0];
}
- (void)stop {[self finish:NO];}
- (void)finish:(BOOL)completed {
 if(!self.running)return;self.running=NO;self.generation++;
 [self runCleanup:self.step];
 [self.frameTimer invalidate];[self.waitTimer invalidate];self.view.scene=nil;[self.overlay orderOut:nil];self.overlay=nil;
 [self.host guideLookGray:-1 warmth:-1];[self.host guideFinished:completed];
}
- (void)runCleanup:(NSInteger)step {if(step>=0&&step<(NSInteger)self.cleanups.count){id c=self.cleanups[step];if(c!=NSNull.null)((void(^)(void))c)();}self.avoidRect=NSZeroRect;}

#pragma mark controls (they live in the Settings window)
- (void)next {if(!self.running)return;if(self.step+1>=(NSInteger)self.steps.count){[self finish:YES];return;}[self playStep:self.step+1];}
- (void)back {if(self.running&&self.step>0)[self playStep:self.step-1];}
- (void)toggleSlow {self.slow=!self.slow;[self.host guideProgress:self];[self interject:self.slow?L(@"Slower? Gladly. I like to take my time anyway."):L(@"Back to my usual speed. Hold on to something.") face:self.slow?GTFaceSquint:GTFaceHop];}

#pragma mark the frame clock
- (void)frame:(NSTimer *)timer {
 double now=CACurrentMediaTime();GuideView *v=self.view;v.clock=now;
 if(self.moveDuration>0){double k=MIN(1,(now-self.moveStart)/self.moveDuration),e=Ease(k);
  NSPoint a=self.from,b=self.target;double arc=sin(M_PI*e)*MIN(90,hypot(b.x-a.x,b.y-a.y)*.2);
  v.pos=NSMakePoint(a.x+(b.x-a.x)*e,a.y+(b.y-a.y)*e+arc);if(k>=1)self.moveDuration=0;}
 // where the pointy side points: the target, or the card, or the way it flies
 NSPoint aim=v.pointAt;if(NSEqualPoints(aim,NSZeroPoint)&&!NSIsEmptyRect(v.card)&&v.cardTarget>0)aim=NSMakePoint(NSMidX(v.card),NSMidY(v.card));
 if(self.moveDuration>0)aim=self.target;
 double want=NSEqualPoints(aim,NSZeroPoint)?-M_PI_2:atan2(aim.y-v.pos.y,aim.x-v.pos.x);double diff=remainder(want-v.angle,2*M_PI);v.angle+=diff*(v.still?1:.14);
 v.grayK+=(v.grayTarget-v.grayK)*.08;v.blushK+=(v.blushTarget-v.blushK)*.08;v.cardAlpha+=(v.cardTarget-v.cardAlpha)*(v.still?1:.2);
 if(v.alpha<1)v.alpha=MIN(1,v.alpha+.08);if(v.size<1)v.size=MIN(1,v.size+.05);
 if(now>=v.nextBlink){v.blinkAt=now;v.nextBlink=now+2.4+arc4random_uniform(2800)/1000.0;}
 // waiting for you: a sleepy look after a while, and a little shuffle now and then
 if(self.waiting){double w=now-self.waitStart;v.droop=w>6;if(w>4&&fmod(w,4.5)<1.0/60*1.5)v.wiggleAt=now;}else v.droop=NO;
 if(v.cardTarget<=0&&v.cardAlpha<.02&&v.scene){v.scene=nil;self.sceneKind=-1;}
 v.needsDisplay=YES;
}

#pragma mark moving, placing, talking
- (double)moveTo:(NSPoint)screenPoint {
 NSPoint to=[self local:screenPoint];NSRect b=[self bounds];to.x=MIN(MAX(to.x,NSMinX(b)+24),NSMaxX(b)-24);to.y=MIN(MAX(to.y,NSMinY(b)+24),NSMaxY([self localRect:self.screen.frame])-14);
 if(hypot(to.x-self.view.pos.x,to.y-self.view.pos.y)<2)return 0;
 if(self.reduceMotion){self.view.pos=self.target=to;self.moveDuration=0;return .2;}
 self.from=self.view.pos;self.target=to;self.moveStart=CACurrentMediaTime();self.moveDuration=MIN(1.7,.5+hypot(to.x-self.from.x,to.y-self.from.y)/1300)*self.pace;return self.moveDuration;
}
// The card or bubble goes on the free side of the guide: inside the screen, clear of the real panel, and if it can, clear of the Settings window.
- (NSRect)placeSize:(NSSize)size near:(NSPoint)g {
 double r=[self.view radius]+20;NSRect b=[self bounds];NSRect hard=[self localRect:self.avoidRect],soft=[self localRect:[self.host guideSettingsFrame]];
 NSRect (^clampY)(NSRect)=^NSRect(NSRect c){c.origin.y=MIN(MAX(c.origin.y,NSMinY(b)),NSMaxY(b)-c.size.height);return c;};
 NSRect (^clampX)(NSRect)=^NSRect(NSRect c){c.origin.x=MIN(MAX(c.origin.x,NSMinX(b)),NSMaxX(b)-c.size.width);return c;};
 NSArray *candidates=@[[NSValue valueWithRect:clampY(NSMakeRect(g.x+r,g.y-size.height*.6,size.width,size.height))],[NSValue valueWithRect:clampY(NSMakeRect(g.x-r-size.width,g.y-size.height*.6,size.width,size.height))],
  [NSValue valueWithRect:clampX(NSMakeRect(g.x-size.width/2,g.y-r-size.height,size.width,size.height))],[NSValue valueWithRect:clampX(NSMakeRect(g.x-size.width/2,g.y+r,size.width,size.height))]];
 NSRect body=NSMakeRect(g.x-r+18,g.y-r+18,2*(r-18),2*(r-18));
 for(int pass=0;pass<2;pass++)for(NSValue *v in candidates){NSRect c=v.rectValue;if(!NSContainsRect(b,c))continue;if(!NSIsEmptyRect(hard)&&NSIntersectsRect(c,NSInsetRect(hard,-10,-10)))continue;if(pass==0&&!NSIsEmptyRect(soft)&&NSIntersectsRect(c,soft))continue;
  if(NSIntersectsRect(c,body))continue;return c;}
 return clampX(clampY([candidates.firstObject rectValue]));
}
// A spot in free space for the guide and a card of this size: away from the real panel and, if it can, from the Settings window; near where it is.
- (NSValue *)freeSpotFor:(NSSize)size {
 NSRect v=self.screen.visibleFrame,set=[self.host guideSettingsFrame];NSPoint here=NSMakePoint(self.view.pos.x+self.overlay.frame.origin.x,self.view.pos.y+self.overlay.frame.origin.y);
 NSPoint best=NSMakePoint(NSMidX(v),NSMidY(v));double bestScore=-1e9;
 for(double fy=.72;fy>=.3;fy-=.14)for(double fx=.18;fx<=.82;fx+=.16){NSPoint q=NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy);
  NSRect c=[self placeSize:size near:[self local:q]];c.origin.x+=self.overlay.frame.origin.x;c.origin.y+=self.overlay.frame.origin.y;
  double score=0;if(NSIntersectsRect(c,set))score-=1000;if(NSContainsRect(set,NSMakeRect(q.x-20,q.y-20,40,40)))score-=800;if(!NSIsEmptyRect(self.avoidRect)&&NSIntersectsRect(c,self.avoidRect))score-=5000;if(!NSContainsRect(v,c))score-=3000;
  score-=hypot(q.x-here.x,q.y-here.y)*.3;if(score>bestScore){bestScore=score;best=q;}}
 return [NSValue valueWithPoint:best];
}
- (NSSize)sizeForText:(NSString *)text scene:(BOOL)scene {
 NSDictionary *a=@{NSFontAttributeName:[NSFont systemFontOfSize:14]};double w=scene?420:290;
 NSRect t=[text?:@"" boundingRectWithSize:NSMakeSize(w,1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:a];
 if(scene)return NSMakeSize(452,14+140+10+MAX(20,ceil(t.size.height)+4)+14);
 return NSMakeSize(MAX(120,ceil(t.size.width)+34),ceil(t.size.height)+30);
}
- (void)show:(NSString *)text scene:(NSInteger)kind {
 GuideView *v=self.view;
 if(!text.length&&kind<0){v.cardTarget=0;return;}
 BOOL sameScene=kind>=0&&kind==self.sceneKind&&v.scene;
 if(kind<0){v.scene=nil;self.sceneKind=-1;}
 else if(!sameScene){v.scene=[self.host guideScene:kind];self.sceneKind=kind;}
 v.text=text;NSSize size=[self sizeForText:text scene:kind>=0];
 NSPoint g=self.moveDuration>0?self.target:v.pos;NSRect c=[self placeSize:size near:g];v.card=c;
 if(v.scene)v.scene.frame=NSMakeRect(NSMinX(c)+16,NSMaxY(c)-14-140,420,140);
 if(!sameScene&&v.cardAlpha>.5&&kind>=0)v.cardAlpha=.35;  // a new scene fades in again
 v.cardTarget=1;
 if(text.length)NSAccessibilityPostNotificationWithUserInfo(self.overlay,NSAccessibilityAnnouncementRequestedNotification,@{NSAccessibilityAnnouncementKey:text,NSAccessibilityPriorityKey:@(NSAccessibilityPriorityHigh)});
}
- (void)face:(GTFace)f {
 GuideView *v=self.view;double now=CACurrentMediaTime();
 switch(f){case GTFaceHop:v.hopAt=now;break;case GTFaceSpin:v.spinAt=now;v.dizzyAt=now+.8;break;case GTFaceWiggle:v.wiggleAt=now;break;case GTFaceSquint:v.squintAt=now;break;case GTFaceDizzy:v.dizzyAt=now;break;
  case GTFaceGray:v.grayTarget=1;break;case GTFaceBlush:v.blushTarget=1;break;case GTFacePlain:v.grayTarget=0;v.blushTarget=0;break;case GTFaceDroop:case GTFaceNone:break;}
}
- (double)readingTime:(NSString *)text {if(!text.length)return 0;NSUInteger words=[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].count;return MAX(2.4,words*.36+1.0)*self.pace;}
- (void)interject:(NSString *)text face:(GTFace)f {
 if(!self.running)return;NSString *before=self.view.text;NSInteger kind=self.sceneKind,g=self.generation;[self face:f];[self show:text scene:kind];
 [self after:2.4 do:^{if(g==self.generation&&[self.view.text isEqual:text])[self show:before scene:kind];}];
}
- (void)after:(double)seconds do:(void(^)(void))block {NSInteger g=self.generation;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(g==self.generation&&self.running)block();});}

#pragma mark the steps
- (void)playStep:(NSInteger)i {
 [self runCleanup:self.step];self.generation++;[self.waitTimer invalidate];self.waiting=NO;
 self.step=i;self.beats=self.steps[i]();self.beatIndex=0;[self.host guideProgress:self];[self playBeat];
}
- (void)playBeat {
 if(!self.running)return;
 if(self.beatIndex>=(NSInteger)self.beats.count){if(self.step+1<(NSInteger)self.steps.count)[self playStep:self.step+1];else [self finish:YES];return;}
 GTBeat *b=self.beats[self.beatIndex];
 if(b.onlyIf&&!b.onlyIf()){self.beatIndex++;[self playBeat];return;}
 if(b.run)b.run();
 if(b.avoid){NSValue *a=b.avoid();self.avoidRect=a?a.rectValue:NSZeroRect;}
 [self face:b.face];
 GuideView *v=self.view;NSValue *aim=b.pointAt?b.pointAt():nil;v.pointAt=aim?[self local:aim.pointValue]:NSZeroPoint;
 if(b.home){[self show:b.say scene:-1];
  [self after:[self readingTime:b.say] do:^{[self show:nil scene:-1];NSPoint icon=[self iconPoint];double t=NSEqualPoints(icon,NSZeroPoint)?0:[self moveTo:icon];[self after:t+.05 do:^{[self shrinkAndEnd];}];}];return;}
 double travel=0;NSValue *to=b.to?b.to():nil;
 if(!to&&b.scene>=0&&self.sceneKind!=b.scene)to=[self freeSpotFor:[self sizeForText:b.say scene:YES]];
 if(to){[self show:nil scene:-1];travel=[self moveTo:to.pointValue];}
 void (^speak)(void)=^{[self show:b.say scene:b.scene];};
 if(travel>0)[self after:travel*.85 do:speak];else speak();
 double wait=travel*.85+[self readingTime:b.say]+b.hold*self.pace;
 void (^advance)(void)=^{self.waiting=NO;self.beatIndex++;[self playBeat];};
 if(!b.until){[self after:wait do:advance];return;}
 // waiting for something real, with a friendly line if it takes a while
 NSInteger g=self.generation;__weak GuideTour *weak=self;[self.waitTimer invalidate];
 [self after:travel*.85+.6 do:^{GuideTour *s=weak;s.waiting=YES;s.waitStart=CACurrentMediaTime();
  s.waitTimer=[NSTimer timerWithTimeInterval:.15 repeats:YES block:^(NSTimer *t){GuideTour *w=weak;if(!w||g!=w.generation||!w.running){[t invalidate];return;}
   if(b.until()){[t invalidate];w.waiting=NO;[w after:.35 do:advance];return;}
   if(b.timeout>0&&CACurrentMediaTime()-w.waitStart>b.timeout*w.pace){[t invalidate];w.waiting=NO;if(b.timeoutSay.length){[w face:GTFaceDroop];[w show:b.timeoutSay scene:-1];[w after:[w readingTime:b.timeoutSay] do:advance];}else advance();}}];
  [NSRunLoop.mainRunLoop addTimer:s.waitTimer forMode:NSRunLoopCommonModes];}];
}
- (void)shrinkAndEnd {
 if(self.reduceMotion){[self finish:YES];return;}
 double start=CACurrentMediaTime();__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/.5);s.view.size=1-.65*k;s.view.alpha=1-k;if(k>=1){[timer invalidate];[s finish:YES];}}];
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}

// ---- The script. Lines are data; the engine above plays them.
- (void)buildSteps {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 NSValue *(^nearStart)(void)=^NSValue *{NSRect f=[host guideStartFrame];NSRect v=weak.screen.visibleFrame;double x=NSMinX(f)-60>NSMinX(v)+340?NSMinX(f)-60:NSMaxX(f)+60;return [NSValue valueWithPoint:NSMakePoint(x,NSMaxY(f)-70)];};
 NSValue *(^belowIcon)(void)=^NSValue *{NSPoint p=[weak iconPoint];return NSEqualPoints(p,NSZeroPoint)?nil:[NSValue valueWithPoint:NSMakePoint(p.x-46,p.y-48)];};
 NSValue *(^iconAim)(void)=^NSValue *{NSPoint p=[weak iconPoint];return NSEqualPoints(p,NSZeroPoint)?nil:[NSValue valueWithPoint:p];};
 NSValue *(^besidePanel)(void)=^NSValue *{NSRect f=weak.avoidRect;if(NSIsEmptyRect(f))return nil;NSRect v=weak.screen.visibleFrame;BOOL left=NSMinX(f)-560>NSMinX(v);return [NSValue valueWithPoint:NSMakePoint(left?NSMinX(f)-40:NSMaxX(f)+40,NSMaxY(f)-30)];};
 NSValue *(^panelAim)(void)=^NSValue *{NSRect f=weak.avoidRect;return NSIsEmptyRect(f)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
 BOOL (^iconShown)(void)=^BOOL{return !NSIsEmptyRect([host guideIconFrame]);};
 NSMutableArray *steps=[NSMutableArray new],*cleanups=[NSMutableArray new];
 // 1 hello: out of the menu bar, a hop, and the first words
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Hi! I’m the circle from your menu bar. Usually I just sit up there, being round."),GTFaceHop);a.to=nearStart;
  GTBeat *b=Beat(L(@"Today I get to fly. The buttons for this tour are in the window, in case I talk too fast."),GTFaceSquint);b.pointAt=^NSValue *{NSRect f=[host guideStartFrame];return [NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
  return @[a,b];}];
 [cleanups addObject:NSNull.null];
 // 2 home, and help when the menu bar hides it
 [steps addObject:^NSArray *{
  __block BOOL wasHidden=NO;  // remembered, so the happy line plays once the circle is out again
  GTBeat *home=Beat(L(@"That’s where I live, up there. One click on me opens the menu."),GTFaceNone);home.to=belowIcon;home.pointAt=iconAim;home.onlyIf=iconShown;
  GTBeat *hidden=Beat(L(@"Hm. I can’t find my own home. The menu bar is full, or the notch is in the way."),GTFaceDroop);hidden.scene=0;hidden.onlyIf=^BOOL{if(iconShown())return NO;wasHidden=YES;return YES;};
  GTBeat *drag=Beat(L(@"Click » in the menu bar to see what’s hidden, then hold ⌘ and drag me toward the clock. I’ll wait."),GTFaceNone);drag.scene=0;drag.onlyIf=^BOOL{return !iconShown();};drag.until=iconShown;drag.timeout=60;drag.timeoutSay=L(@"No rush. You can do it later; the menu bar keeps my place.");
  GTBeat *found=Beat(L(@"There I am! Much better."),GTFaceSpin);found.to=belowIcon;found.pointAt=iconAim;found.onlyIf=^BOOL{return wasHidden&&iconShown();};
  return @[home,hidden,drag,found];}];
 [cleanups addObject:NSNull.null];
 // 3 quiet: the scene first, then the real screen
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Your screen is loud. Every color is waving for your attention."),GTFaceWiggle);a.scene=1;
  GTBeat *b=Beat(L(@"Shh. That’s Grayscale, on your real screen."),GTFaceGray);b.scene=1;b.run=^{[host guideLookGray:1 warmth:0];};
  GTBeat *c=Beat(L(@"Everything still works. It just stopped shouting."),GTFaceSquint);c.scene=1;c.hold=.4;
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 4 warmth
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Then warmth. A touch of amber takes the blue out of the light."),GTFacePlain);a.scene=1;a.run=^{[host guideLookGray:-1 warmth:.7];};
  GTBeat *b=Beat(L(@"All the way to red, if you like it cozy. I’m blushing."),GTFaceBlush);b.scene=1;b.run=^{[host guideLookGray:-1 warmth:2.4];};
  GTBeat *c=Beat(L(@"And back to yours. I never touch your settings. Promise."),GTFacePlain);c.scene=1;c.run=^{[host guideLookGray:-1 warmth:-1];};
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 5 exceptions: the scene, then the real panel with the card beside it
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Some apps really need color. Photos in gray? That’s just sad."),GTFaceDroop);a.scene=2;
  GTBeat *b=Beat(L(@"So they get an exception. This one’s real, for the app you were just using."),GTFaceHop);b.avoid=^NSValue *{NSRect f=[host guideShowExceptionPanel];return NSIsEmptyRect(f)?nil:[NSValue valueWithRect:f];};b.to=besidePanel;b.pointAt=panelAim;
  GTBeat *c=Beat(L(@"Change one thing, and the rest stays as you set it."),GTFaceNone);c.pointAt=panelAim;
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideHideExceptionPanel];}];
 // 6 peek, hands-on
 [steps addObject:^NSArray *{
  NSString *key=[host guidePeekLabel];
  if(!key){GTBeat *n=Beat(L(@"Need color for a moment? Give Peek a shortcut under Shortcuts, then hold it."),GTFaceNone);n.scene=3;return @[n];}
  weak.peekSeen=NO;
  GTBeat *ask=Beat([NSString stringWithFormat:L(@"A quick trick for you. Hold %@."),key],GTFaceHop);ask.scene=3;ask.until=^BOOL{BOOL p=[host guidePeeking];if(p)weak.peekSeen=YES;return p;};ask.timeout=25;ask.timeoutSay=[NSString stringWithFormat:L(@"No rush. %@ works any time, even when I’m gone."),key];
  GTBeat *color=Beat(L(@"Color! For exactly as long as you hold it."),GTFaceSpin);color.scene=3;color.onlyIf=^BOOL{return weak.peekSeen;};color.until=^BOOL{return ![host guidePeeking];};color.timeout=20;
  GTBeat *done=Beat(L(@"And quiet again. You’re a natural."),GTFaceSquint);done.scene=3;done.onlyIf=^BOOL{return weak.peekSeen;};
  return @[ask,color,done];}];
 [cleanups addObject:NSNull.null];
 // 7 sessions and breaks: the scene, then the real panel
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Need to focus? A session ends with a warm glow and a soft gong. No alarm."),GTFaceSquint);a.scene=4;
  GTBeat *b=Beat(L(@"Or take a break. I’ll call you back once. Just once, I’m not nagging."),GTFaceWiggle);b.avoid=^NSValue *{NSRect f=[host guideShowSessionPanel];return NSIsEmptyRect(f)?nil:[NSValue valueWithRect:f];};b.to=besidePanel;b.pointAt=panelAim;
  return @[a,b];}];
 [cleanups addObject:^{[host guideHideSessionPanel];}];
 // 8 night
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"At night I get a little warmer. Like this."),GTFaceBlush);a.run=^{[host guideNightPreview:YES];};a.hold=1;GTBeat *b=Beat(L(@"Whenever your night begins. You set when that is."),GTFacePlain);return @[a,b];}];
 [cleanups addObject:^{[host guideNightPreview:NO];}];
 // 9 private
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"And nothing leaves your Mac. No account, no tracking. I don’t even know your name."),GTFaceNone);a.scene=5;GTBeat *b=Beat(L(@"I like it that way."),GTFaceSquint);b.scene=5;return @[a,b];}];
 [cleanups addObject:NSNull.null];
 // 10 goodbye, back into the menu bar
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"That’s the tour. I’ll be up in the menu bar, being round again."),GTFaceSpin);a.home=YES;return @[a];}];
 [cleanups addObject:NSNull.null];
 self.steps=steps;self.cleanups=cleanups;
}
@end
