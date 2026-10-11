#import "GuideTour.h"
#import "Localize.h"
#import <QuartzCore/QuartzCore.h>

// The website, once it is live: the goodbye then mentions the guide's second home there. nil: no website lines yet.
static NSString *const GTWebsite=nil;

// What the guide's face and body do on a beat. HOP, SPIN, WIGGLE, SQUINT, WIDE and DIZZY play once (a SPIN ends DIZZY);
// GRAY (its amber half goes gray), HALF (its left half fills, like the menu-bar circle with Grayscale on), BLUSH, EMPTY
// (plain, like the screen during Peek) and DROOP (sleepy) stay until a beat says PLAIN.
typedef NS_ENUM(NSInteger,GTFace){GTFaceNone,GTFaceHop,GTFaceSpin,GTFaceWiggle,GTFaceDroop,GTFaceSquint,GTFaceGray,GTFaceBlush,GTFaceDizzy,GTFacePlain,GTFaceWide,GTFaceHalf,GTFaceEmpty};

// ---- One beat: a line, a face, maybe a card with a scene, a place to go, something real to do or wait for.
@interface GTBeat : NSObject
@property(copy) NSString *say;
@property GTFace face;
@property NSInteger scene;                      // -1: a plain bubble; otherwise a card with this scene
@property(copy) NSValue *(^to)(void);           // where the guide goes (screen point); nil: it stays (a new scene: free space)
@property BOOL free;                            // go to the step's free spot, chosen once per step so the guide does not wander
@property(copy) NSValue *(^pointAt)(void);      // what its pointy side points at (screen point); nil: into the card, or down
@property(copy) NSValue *(^avoid)(void);        // a real panel to keep clear of (screen rect)
@property(copy) void (^run)(void);
@property(copy) BOOL (^onlyIf)(void);
@property(copy) BOOL (^until)(void);
@property double timeout,hold;
@property(copy) NSString *timeoutSay;
@property BOOL home;
@property(copy) NSArray *faces;                 // @[@seconds,@face] pairs played during the beat
@property(copy) NSArray *later;                 // @[@seconds,block] pairs: small things during the beat (where the tip points, a blush)
@property(copy) NSArray *nudges;                // @[@seconds,line,@face(,pointAt block)] while it waits, in order
@property(copy) NSArray *ramp;                  // @[@from,@to,@seconds]: real warmth rising, the right half blushing with it
@property(copy) NSString *afterSay;             // home: a last line in the bubble alone, once the guide is back in its spot
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
@property double size,alpha,clock,angle,eyeAngle,cardAlpha,cardTarget;
@property double grayK,blushK,leftK,emptyK,grayTarget,blushTarget,leftTarget,emptyTarget;
@property double hopAt,spinAt,wiggleAt,squintAt,dizzyAt,wideAt,blinkAt,blinkLen,nextBlink,pace;
@property BOOL droop,still,forcedDroop,leaving;  // still: Reduce Motion; forcedDroop: sleepy on purpose; leaving: dropping into its spot
@property NSRect card;                       // view coordinates; empty: no card or bubble
@property(copy) NSString *text;
@property(nonatomic) NSView *scene;
@end
@implementation GuideView
- (instancetype)initWithFrame:(NSRect)f {if((self=[super initWithFrame:f])){_hopAt=_spinAt=_wiggleAt=_squintAt=_dizzyAt=_blinkAt=_wideAt=-100;_pace=1;_blinkLen=.13;_angle=_eyeAngle=-M_PI_2;}return self;}
- (BOOL)isFlipped {return NO;}
- (void)setScene:(NSView *)scene {if(_scene==scene)return;[_scene removeFromSuperview];_scene=scene;if(scene){scene.alphaValue=0;[self addSubview:scene];}}
- (double)radius {return 19*self.size;}
- (NSPoint)drawnCenter {
 NSPoint p=self.pos;double t=self.clock;
 if(!self.still){p.y+=sin(t*2.1/self.pace)*1.5;  // a slower guide breathes slower too
  double h=t-self.hopAt;if(h>=0&&h<.62)p.y+=16*fabs(sin(M_PI*h/.31))*(1-h/.62);
  double w=t-self.wiggleAt;if(w>=0&&w<.7)p.x+=3.2*sin(w*42)*(1-w/.7);}
 return p;
}
- (NSRect)textRect {return NSMakeRect(NSMinX(self.card)+16,NSMinY(self.card)+14,self.card.size.width-32,self.scene?self.card.size.height-14-14-self.scene.frame.size.height-10:self.card.size.height-28);}
- (void)drawRect:(NSRect)dirty {
 if(self.alpha<=0.01&&(NSIsEmptyRect(self.card)||self.cardAlpha<=0.01))return;  // the last bubble can stay a moment after the guide is home
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
 if(self.alpha<=0.01)return;
 // the guide: the menu-bar circle with a pointy side and a face
 NSColor *ember=[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:1],*light=[NSColor colorWithWhite:.94 alpha:1];
 NSColor *half=Mix(Mix(Mix(ember,[NSColor colorWithSRGBRed:.86 green:.2 blue:.12 alpha:1],self.blushK),[NSColor colorWithWhite:.62 alpha:1],self.grayK),light,self.emptyK);
 NSColor *leftHalf=Mix(light,[NSColor colorWithWhite:.46 alpha:1],self.leftK);
 [NSGraphicsContext saveGraphicsState];
 NSShadow *glow=[NSShadow new];glow.shadowBlurRadius=14*self.size;glow.shadowOffset=NSZeroSize;glow.shadowColor=[Mix(ember,[NSColor colorWithWhite:.7 alpha:1],MAX(self.grayK,self.emptyK)) colorWithAlphaComponent:.5*self.alpha];[glow set];
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
 NSBezierPath *left=[NSBezierPath bezierPath];[left moveToPoint:NSMakePoint(0,m)];[left appendBezierPathWithArcWithCenter:NSZeroPoint radius:m startAngle:90 endAngle:270];[left closePath];[[leftHalf colorWithAlphaComponent:self.alpha] setFill];[left fill];
 [NSGraphicsContext restoreGraphicsState];
 NSBezierPath *ring=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-r+1,p.y-r+1,2*r-2,2*r-2)];ring.lineWidth=1.4;[[NSColor colorWithWhite:.97 alpha:.85*self.alpha] setStroke];[ring stroke];
 // the eyes: they look where the guide is about to point (a moment before the tip turns), blink now and then,
 // squint when happy, go wide when surprised, droop while waiting or sleepy, wobble when dizzy
 double look=0.1*r;NSPoint lookOff=NSMakePoint(cos(self.eyeAngle)*look,sin(self.eyeAngle)*look);
 double d=t-self.dizzyAt;if(!self.still&&d>=0&&d<1.1){lookOff.x+=cos(d*14)*r*.08;lookOff.y+=sin(d*14)*r*.08;}
 BOOL squint=t-self.squintAt>=0&&t-self.squintAt<1.3,wide=t-self.wideAt>=0&&t-self.wideAt<1.6;double blink=(t>=self.blinkAt&&t<self.blinkAt+self.blinkLen*self.pace)?.12:1;
 for(int i=-1;i<=1;i+=2){NSPoint e=NSMakePoint(p.x+i*r*.27+lookOff.x,p.y+r*.14+lookOff.y);double ew=r*(wide?.15:.13),eh=r*(wide?.28:.21);
  NSColor *ink=[NSColor colorWithWhite:.1 alpha:self.alpha];
  if(squint){NSBezierPath *arc=[NSBezierPath bezierPath];[arc moveToPoint:NSMakePoint(e.x-ew,e.y-eh*.2)];[arc curveToPoint:NSMakePoint(e.x+ew,e.y-eh*.2) controlPoint1:NSMakePoint(e.x-ew*.5,e.y+eh*.8) controlPoint2:NSMakePoint(e.x+ew*.5,e.y+eh*.8)];arc.lineWidth=1.6*self.size;arc.lineCapStyle=NSLineCapStyleRound;[ink setStroke];[arc stroke];continue;}
  NSRect er=NSMakeRect(e.x-ew,e.y-eh*blink,ew*2,2*eh*blink);
  if(self.droop||self.forcedDroop){[NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRect:NSMakeRect(er.origin.x-1,er.origin.y-1,er.size.width+2,er.size.height*.58)] addClip];[ink setFill];[[NSBezierPath bezierPathWithOvalInRect:er] fill];[NSGraphicsContext restoreGraphicsState];}
  else {[ink setFill];[[NSBezierPath bezierPathWithOvalInRect:er] fill];[[NSColor colorWithWhite:1 alpha:.8*self.alpha] setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(er.origin.x+ew*.9,NSMaxY(er)-eh*.55*blink,ew*.55,eh*.45*blink)] fill];}
 }
}
@end

@interface GuideTour ()
@property NSPanel *overlay;
@property GuideView *view;
@property NSTimer *frameTimer,*waitTimer,*rampTimer;
@property NSArray<NSArray<GTBeat *> *(^)(void)> *steps;
@property NSArray *cleanups;
@property(nonatomic,readwrite) NSInteger step;
@property(nonatomic,readwrite) BOOL slow;
@property NSInteger beatIndex,generation,sceneKind;
@property NSArray<GTBeat *> *beats;
@property NSPoint from,target,stepSpot;
@property double moveStart,moveDuration,waitStart,aimSince,lastWant,lastIconCheck;
@property BOOL running,waiting,hasStepSpot,iconWasHidden,iconFoundSaid;
@property NSRect avoidRect;                    // screen coordinates: the real panel on screen now
@end

@implementation GuideTour
- (instancetype)initWithHost:(id<GuideTourHost>)host {if((self=[super init])){_host=host;_sceneKind=-1;_lastWant=-M_PI_2;}return self;}
- (NSInteger)stepCount {return self.steps.count;}
- (double)pace {return self.slow?1.6:1;}
- (BOOL)reduceMotion {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;}
- (NSScreen *)screen {NSRect icon=[self.host guideIconFrame];for(NSScreen *s in NSScreen.screens)if(!NSIsEmptyRect(icon)&&NSIntersectsRect(s.frame,icon))return s;NSRect f=[self.host guideSettingsFrame];for(NSScreen *s in NSScreen.screens)if(NSIntersectsRect(s.frame,f))return s;return NSScreen.mainScreen?:NSScreen.screens.firstObject;}
- (NSPoint)local:(NSPoint)q {return NSMakePoint(q.x-self.overlay.frame.origin.x,q.y-self.overlay.frame.origin.y);}
- (NSRect)localRect:(NSRect)q {if(NSIsEmptyRect(q))return NSZeroRect;q.origin=[self local:q.origin];return q;}
- (NSPoint)onScreen:(NSPoint)q {return NSMakePoint(q.x+self.overlay.frame.origin.x,q.y+self.overlay.frame.origin.y);}
- (NSPoint)iconPoint {NSRect f=[self.host guideIconFrame];return NSIsEmptyRect(f)?NSZeroPoint:NSMakePoint(NSMidX(f),NSMidY(f));}
// Its home: the circle in the menu bar. While macOS hides it, the right end of the menu bar, where hidden icons go.
- (NSPoint)homePoint {NSPoint p=[self iconPoint];if(!NSEqualPoints(p,NSZeroPoint))return p;NSRect f=self.screen.frame;double bar=MAX(24,NSMaxY(f)-NSMaxY(self.screen.visibleFrame));return NSMakePoint(NSMaxX(f)-170,NSMaxY(f)-bar/2);}
- (NSRect)bounds {return NSInsetRect([self localRect:self.screen.visibleFrame],12,12);}

#pragma mark start and end
- (void)start {
 if(self.running)return;self.running=YES;
 NSScreen *s=self.screen;
 self.overlay=[[NSPanel alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.overlay.opaque=NO;self.overlay.backgroundColor=NSColor.clearColor;self.overlay.ignoresMouseEvents=YES;self.overlay.hasShadow=NO;self.overlay.level=NSPopUpMenuWindowLevel+1;  // above the real panels; cards are placed beside them
 self.overlay.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;
 self.view=[[GuideView alloc]initWithFrame:(NSRect){NSZeroPoint,s.frame.size}];self.view.still=self.reduceMotion;self.overlay.contentView=self.view;[self.overlay setFrame:s.frame display:NO];[self.overlay orderFrontRegardless];
 self.overlay.accessibilityLabel=L(@"Less Pull tour");
 [self buildSteps];
 GuideView *v=self.view;v.pos=self.from=self.target=[self local:[self homePoint]];v.alpha=0;v.size=.4;v.leaving=YES;v.angle=v.eyeAngle=M_PI_2;v.nextBlink=CACurrentMediaTime()+2.5;
 self.frameTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(frame:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.frameTimer forMode:NSRunLoopCommonModes];
 // up there, the circle winks twice; then its spot empties (it stays empty while the guide is out), and out it comes
 double t=0;if(!NSEqualPoints([self iconPoint],NSZeroPoint)&&!self.reduceMotion)for(int i=0;i<2;i++){[self after:t do:^{[self.host guideSpotEmpty:YES];}];[self after:t+.16 do:^{[self.host guideSpotEmpty:NO];}];t+=.42;}
 [self after:t+.12 do:^{[self.host guideSpotEmpty:YES];self.view.leaving=NO;if(self.reduceMotion){self.view.alpha=1;self.view.size=1;}[self playStep:0];}];
}
- (void)stop {[self finish:NO];}
- (void)finish:(BOOL)completed {
 if(!self.running)return;self.running=NO;self.generation++;
 [self runCleanup:self.step];
 [self.frameTimer invalidate];[self.waitTimer invalidate];[self.rampTimer invalidate];self.view.scene=nil;[self.overlay orderOut:nil];self.overlay=nil;
 [self.host guideSpotEmpty:NO];[self.host guideLookGray:-1 warmth:-1];[self.host guideFinished:completed];
}
- (void)runCleanup:(NSInteger)step {if(step>=0&&step<(NSInteger)self.cleanups.count){id c=self.cleanups[step];if(c!=NSNull.null)((void(^)(void))c)();}self.avoidRect=NSZeroRect;}
- (void)halt {[self runCleanup:self.step];self.generation++;[self.waitTimer invalidate];[self.rampTimer invalidate];self.waiting=NO;self.view.forcedDroop=NO;}

#pragma mark controls (they live in the Settings window)
- (void)next {
 if(!self.running||self.view.leaving)return;
 if(self.waiting){[self.waitTimer invalidate];self.waiting=NO;self.generation++;self.beatIndex++;[self playBeat];return;}  // waiting for your hands: Next means "not now", and the step goes on without it
 if(self.step+1>=(NSInteger)self.steps.count){[self finish:YES];return;}
 [self playStep:self.step+1];
}
- (void)back {
 if(!self.running||self.view.leaving||self.step<=0)return;NSInteger target=self.step-1;
 [self halt];[self face:GTFacePlain];self.view.pointAt=NSZeroPoint;[self show:L(@"Once more, then.") scene:-1];[self after:1.1*self.pace do:^{[self playStep:target];}];
}
// End tour: whatever it showed goes back first, then one short goodbye, and home.
- (void)endEarly {
 if(!self.running||self.view.leaving)return;
 [self halt];[self.host guideLookGray:-1 warmth:-1];[self face:GTFacePlain];self.view.pointAt=NSZeroPoint;
 NSArray *lines=@[@[L(@"Okay, home it is. The rest waits under About, any time."),@(GTFaceNone)],@[L(@"Fair enough. I’ll be up here, being round and quiet."),@(GTFaceSquint)],@[L(@"Short tour. I like short. See you in the menu bar."),@(GTFaceHop)]];
 NSArray *pick=lines[arc4random_uniform((uint32_t)lines.count)];[self face:[pick[1] integerValue]];[self show:pick[0] scene:-1];
 [self after:[self readingTime:pick[0]] do:^{[self goHomeThen:^{[self finish:NO];}];}];
}
- (void)toggleSlow {self.slow=!self.slow;self.view.pace=self.pace;[self.host guideProgress:self];[self interject:self.slow?L(@"Slower. My favorite speed. Circles are never in a hurry."):L(@"Normal speed again. I can do fast. For a while.") face:self.slow?GTFaceSquint:GTFaceHop];}

#pragma mark the frame clock
- (void)frame:(NSTimer *)timer {
 double now=CACurrentMediaTime();GuideView *v=self.view;v.clock=now;
 if(self.moveDuration>0){double k=MIN(1,(now-self.moveStart)/self.moveDuration),e=Ease(k);
  NSPoint a=self.from,b=self.target;double arc=sin(M_PI*e)*MIN(90,hypot(b.x-a.x,b.y-a.y)*.2);
  v.pos=NSMakePoint(a.x+(b.x-a.x)*e,a.y+(b.y-a.y)*e+arc);if(k>=1)self.moveDuration=0;}
 // where the pointy side points: the target; or into a card with a scene; or the way it flies; or down, like a pin
 NSPoint aim=v.pointAt;if(NSEqualPoints(aim,NSZeroPoint)&&v.scene&&!NSIsEmptyRect(v.card)&&v.cardTarget>0)aim=NSMakePoint(NSMidX(v.card),NSMidY(v.card));
 if(self.moveDuration>0)aim=self.target;
 double want=NSEqualPoints(aim,NSZeroPoint)?-M_PI_2:atan2(aim.y-v.pos.y,aim.x-v.pos.x);
 if(v.forcedDroop)want+=remainder(-M_PI_2-want,2*M_PI)*.2;  // sleepy: the tip sags a little
 // the eyes glance first; the tip follows a moment later
 if(fabs(remainder(want-self.lastWant,2*M_PI))>.35){self.lastWant=want;self.aimSince=now;}
 v.eyeAngle+=remainder(want-v.eyeAngle,2*M_PI)*(v.still?1:.3);
 if(v.still||self.moveDuration>0||now-self.aimSince>.22)v.angle+=remainder(want-v.angle,2*M_PI)*(v.still?1:.14);
 v.grayK+=(v.grayTarget-v.grayK)*.08;v.blushK+=(v.blushTarget-v.blushK)*.08;v.leftK+=(v.leftTarget-v.leftK)*.08;v.emptyK+=(v.emptyTarget-v.emptyK)*.1;v.cardAlpha+=(v.cardTarget-v.cardAlpha)*(v.still?1:.2);
 if(!v.leaving){if(v.alpha<1)v.alpha=MIN(1,v.alpha+.08);if(v.size<1)v.size=MIN(1,v.size+.05);}
 if(now>=v.nextBlink){v.blinkAt=now;v.blinkLen=v.forcedDroop?.42:.13;v.nextBlink=now+(v.forcedDroop?2.0:2.4+arc4random_uniform(2800)/1000.0)*self.pace;}  // sleepy: one long blink every two seconds
 // waiting for you: a sleepy look after a while, and a little shuffle now and then
 if(self.waiting){double w=now-self.waitStart;v.droop=w>6;if(w>4&&fmod(w,4.5)<1.0/60*1.5)v.wiggleAt=now;}else v.droop=NO;
 // its spot comes out later in the tour (moved during Peek, say): it notices, once
 if(self.iconWasHidden&&!self.iconFoundSaid&&!self.waiting&&!v.leaving&&self.step>=2&&now-self.lastIconCheck>.5){self.lastIconCheck=now;
  if(!NSEqualPoints([self iconPoint],NSZeroPoint)){self.iconFoundSaid=YES;[self interject:L(@"There I am! Thank you. Oof, I spun too hard.") face:GTFaceSpin];}}
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
// Up into its spot (while macOS hides the spot: out of view at the right end of the menu bar), a tiny bounce, gone.
- (void)goHomeThen:(void(^)(void))done {[self show:nil scene:-1];self.view.pointAt=NSZeroPoint;double t=[self moveTo:[self homePoint]];[self after:t+.05 do:^{[self shrinkThen:done];}];}
- (void)shrinkThen:(void(^)(void))done {
 self.view.leaving=YES;
 if(self.reduceMotion){self.view.alpha=0;done();return;}
 double start=CACurrentMediaTime();__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/.5);
  s.view.size=1-.65*k+.12*sin(M_PI*k);s.view.alpha=1-k;if(k>=1){[timer invalidate];done();}}];  // a tiny bounce as it drops into its spot
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}
// A card or bubble goes on a free side of the guide: inside the screen, clear of the real panel, and if it can, clear of
// the Settings window. A bubble sits away from the tip, so the tip is never covered; a card with a scene takes the tip into it.
- (NSRect)placeSize:(NSSize)size near:(NSPoint)g scene:(BOOL)scene {
 double r=[self.view radius]+20;NSRect b=[self bounds];NSRect hard=[self localRect:self.avoidRect],soft=[self localRect:[self.host guideSettingsFrame]];
 NSRect (^clampY)(NSRect)=^NSRect(NSRect c){c.origin.y=MIN(MAX(c.origin.y,NSMinY(b)),NSMaxY(b)-c.size.height);return c;};
 NSRect (^clampX)(NSRect)=^NSRect(NSRect c){c.origin.x=MIN(MAX(c.origin.x,NSMinX(b)),NSMaxX(b)-c.size.width);return c;};
 NSValue *right=[NSValue valueWithRect:clampY(NSMakeRect(g.x+r,g.y-size.height*.6,size.width,size.height))],*left=[NSValue valueWithRect:clampY(NSMakeRect(g.x-r-size.width,g.y-size.height*.6,size.width,size.height))];
 NSValue *below=[NSValue valueWithRect:clampX(NSMakeRect(g.x-size.width/2,g.y-r-size.height,size.width,size.height))],*above=[NSValue valueWithRect:clampX(NSMakeRect(g.x-size.width/2,g.y+r,size.width,size.height))];
 NSArray *candidates=@[right,left,below,above];
 if(!scene){NSPoint aim=self.view.pointAt;double a=NSEqualPoints(aim,NSZeroPoint)?-M_PI_2:atan2(aim.y-g.y,aim.x-g.x),cx=cos(a),cy=sin(a);
  if(fabs(cy)>=fabs(cx))candidates=cy>0?@[below,right,left,above]:@[above,right,left,below];
  else candidates=cx>0?@[left,below,above,right]:@[right,below,above,left];}
 NSRect body=NSMakeRect(g.x-r+18,g.y-r+18,2*(r-18),2*(r-18));
 for(int pass=0;pass<2;pass++)for(NSValue *v in candidates){NSRect c=v.rectValue;if(!NSContainsRect(b,c))continue;if(!NSIsEmptyRect(hard)&&NSIntersectsRect(c,NSInsetRect(hard,-10,-10)))continue;if(pass==0&&!NSIsEmptyRect(soft)&&NSIntersectsRect(c,soft))continue;
  if(NSIntersectsRect(c,body))continue;return c;}
 return clampX(clampY([candidates.firstObject rectValue]));
}
// A spot in free space for the guide and a card of this size: away from the real panel and, if it can, from the Settings window; near where it is.
- (NSValue *)freeSpotFor:(NSSize)size {
 NSRect v=self.screen.visibleFrame,set=[self.host guideSettingsFrame];NSPoint here=[self onScreen:self.view.pos];
 NSPoint best=NSMakePoint(NSMidX(v),NSMidY(v));double bestScore=-1e9;
 for(double fy=.72;fy>=.3;fy-=.14)for(double fx=.18;fx<=.82;fx+=.16){NSPoint q=NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy);
  NSRect c=[self placeSize:size near:[self local:q] scene:YES];c.origin=[self onScreen:c.origin];
  double score=0;if(NSIntersectsRect(c,set))score-=1000;if(NSContainsRect(set,NSMakeRect(q.x-20,q.y-20,40,40)))score-=800;if(!NSIsEmptyRect(self.avoidRect)&&NSIntersectsRect(c,self.avoidRect))score-=5000;if(!NSContainsRect(v,c))score-=3000;
  score-=hypot(q.x-here.x,q.y-here.y)*.3;if(score>bestScore){bestScore=score;best=q;}}
 return [NSValue valueWithPoint:best];
}
- (NSValue *)stepFreeSpot {if(!self.hasStepSpot){self.stepSpot=[self freeSpotFor:NSMakeSize(452,232)].pointValue;self.hasStepSpot=YES;}return [NSValue valueWithPoint:self.stepSpot];}
- (NSSize)sizeForText:(NSString *)text scene:(BOOL)scene {
 NSDictionary *a=@{NSFontAttributeName:[NSFont systemFontOfSize:14]};double w=scene?420:312;
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
 NSPoint g=self.moveDuration>0?self.target:v.pos;NSRect c=[self placeSize:size near:g scene:kind>=0];v.card=c;
 if(v.scene)v.scene.frame=NSMakeRect(NSMinX(c)+16,NSMaxY(c)-14-140,420,140);
 if(!sameScene&&v.cardAlpha>.5&&kind>=0)v.cardAlpha=.35;  // a new scene fades in again
 v.cardTarget=1;
 if(text.length)NSAccessibilityPostNotificationWithUserInfo(self.overlay,NSAccessibilityAnnouncementRequestedNotification,@{NSAccessibilityAnnouncementKey:text,NSAccessibilityPriorityKey:@(NSAccessibilityPriorityHigh)});
}
- (void)face:(GTFace)f {
 GuideView *v=self.view;double now=CACurrentMediaTime();
 switch(f){case GTFaceHop:v.hopAt=now;break;case GTFaceSpin:v.spinAt=now;v.dizzyAt=now+.8;break;case GTFaceWiggle:v.wiggleAt=now;break;case GTFaceSquint:v.squintAt=now;break;case GTFaceDizzy:v.dizzyAt=now;break;
  case GTFaceWide:v.wideAt=now;v.forcedDroop=NO;break;case GTFaceGray:v.grayTarget=1;break;case GTFaceBlush:v.blushTarget=1;break;case GTFaceHalf:v.leftTarget=1;break;case GTFaceEmpty:v.emptyTarget=1;break;
  case GTFaceDroop:v.forcedDroop=YES;v.blinkAt=now+.25;v.blinkLen=.5;break;  // one slow blink
  case GTFacePlain:v.grayTarget=v.blushTarget=v.leftTarget=v.emptyTarget=0;v.forcedDroop=NO;break;case GTFaceNone:break;}
}
// Real warmth rising on the real screen (a passing look, never saved), its right half blushing along.
- (void)rampFrom:(double)a to:(double)b over:(double)seconds {
 [self.rampTimer invalidate];double start=CACurrentMediaTime();NSInteger g=self.generation;__weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 self.rampTimer=[NSTimer timerWithTimeInterval:1.0/15 repeats:YES block:^(NSTimer *t){GuideTour *s=weak;if(!s||g!=s.generation||!s.running){[t invalidate];return;}
  double k=MIN(1,(CACurrentMediaTime()-start)/(seconds*s.pace)),x=a+(b-a)*k;[host guideLookGray:-1 warmth:x];s.view.blushTarget=MIN(1,x/3);if(k>=1)[t invalidate];}];
 [NSRunLoop.mainRunLoop addTimer:self.rampTimer forMode:NSRunLoopCommonModes];
}
- (double)readingTime:(NSString *)text {if(!text.length)return 0;NSUInteger words=[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].count;return MAX(2.4,words*.36+1.0)*self.pace;}
- (void)interject:(NSString *)text face:(GTFace)f {
 if(!self.running||self.view.leaving)return;NSString *before=self.view.text;NSInteger kind=self.sceneKind,g=self.generation;[self face:f];[self show:text scene:kind];
 [self after:2.4*self.pace do:^{if(g==self.generation&&[self.view.text isEqual:text])[self show:before scene:kind];}];
}
- (void)after:(double)seconds do:(void(^)(void))block {NSInteger g=self.generation;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(g==self.generation&&self.running)block();});}

#pragma mark the steps
- (void)playStep:(NSInteger)i {
 [self halt];self.hasStepSpot=NO;[self face:GTFacePlain];
 self.step=i;self.beats=self.steps[i]();self.beatIndex=0;[self.host guideProgress:self];[self playBeat];
}
- (void)playBeat {
 if(!self.running)return;
 if(self.beatIndex>=(NSInteger)self.beats.count){if(self.step+1<(NSInteger)self.steps.count)[self playStep:self.step+1];else [self finish:YES];return;}
 GTBeat *b=self.beats[self.beatIndex];
 if(b.onlyIf&&!b.onlyIf()){self.beatIndex++;[self playBeat];return;}
 if(b.run)b.run();
 if(b.avoid){NSValue *a=b.avoid();self.avoidRect=a?a.rectValue:NSZeroRect;}
 if(b.face!=GTFaceDroop)self.view.forcedDroop=NO;
 [self face:b.face];
 for(NSArray *f in b.faces){GTFace face=[f[1] integerValue];[self after:[f[0] doubleValue]*self.pace do:^{[self face:face];}];}
 for(NSArray *l in b.later)[self after:[l[0] doubleValue]*self.pace do:l[1]];
 if(b.ramp.count==3)[self rampFrom:[b.ramp[0] doubleValue] to:[b.ramp[1] doubleValue] over:[b.ramp[2] doubleValue]];
 GuideView *v=self.view;NSValue *aim=b.pointAt?b.pointAt():nil;v.pointAt=aim?[self local:aim.pointValue]:NSZeroPoint;
 if(b.home){[self show:b.say scene:-1];
  [self after:[self readingTime:b.say] do:^{[self goHomeThen:^{
   [self.host guideSpotEmpty:NO];  // back in its spot, the real icon again; one blink
   [self after:.3 do:^{[self.host guideSpotEmpty:YES];}];[self after:.42 do:^{[self.host guideSpotEmpty:NO];}];
   if(!b.afterSay.length){[self after:.6 do:^{[self finish:YES];}];return;}
   [self after:.55 do:^{[self show:b.afterSay scene:-1];}];[self after:.55+2.5*self.pace do:^{[self show:nil scene:-1];[self after:.6 do:^{[self finish:YES];}];}];}];}];
  return;}
 double travel=0;NSValue *to=b.to?b.to():nil;
 if(!to&&(b.free||(b.scene>=0&&self.sceneKind!=b.scene)))to=[self stepFreeSpot];
 if(to){travel=[self moveTo:to.pointValue];if(travel>0)[self show:nil scene:-1];}
 void (^speak)(void)=^{[self show:b.say scene:b.scene];};
 if(travel>0)[self after:travel*.85 do:speak];else speak();
 double wait=travel*.85+[self readingTime:b.say]+b.hold*self.pace;
 void (^advance)(void)=^{self.waiting=NO;self.beatIndex++;[self playBeat];};
 if(!b.until){[self after:wait do:advance];return;}
 // waiting for something real, with a friendly line now and then if it takes a while
 NSInteger g=self.generation;__weak GuideTour *weak=self;[self.waitTimer invalidate];__block NSUInteger nudged=0;
 [self after:travel*.85+.6 do:^{GuideTour *s=weak;s.waiting=YES;s.waitStart=CACurrentMediaTime();
  s.waitTimer=[NSTimer timerWithTimeInterval:.15 repeats:YES block:^(NSTimer *t){GuideTour *w=weak;if(!w||g!=w.generation||!w.running){[t invalidate];return;}
   if(b.until()){[t invalidate];w.waiting=NO;[w after:.35 do:advance];return;}
   double waited=CACurrentMediaTime()-w.waitStart;
   if(nudged<b.nudges.count&&waited>=[b.nudges[nudged][0] doubleValue]*w.pace){NSArray *n=b.nudges[nudged++];[w face:[n[2] integerValue]];
    if(n.count>3){NSValue *(^na)(void)=n[3];NSValue *p=na();if(p)w.view.pointAt=[w local:p.pointValue];}[w show:n[1] scene:w.sceneKind];}
   if(b.timeout>0&&waited>b.timeout*w.pace){[t invalidate];w.waiting=NO;if(b.timeoutSay.length){[w face:GTFacePlain];w.view.pointAt=NSZeroPoint;[w show:b.timeoutSay scene:-1];[w after:[w readingTime:b.timeoutSay] do:advance];}else advance();}}];
  [NSRunLoop.mainRunLoop addTimer:s.waitTimer forMode:NSRunLoopCommonModes];}];
}

// ---- The script (TOUR-SCRIPT-v2, Fable). Lines are data; the engine above plays them.
- (void)buildSteps {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 BOOL (^iconShown)(void)=^BOOL{return !NSIsEmptyRect([host guideIconFrame]);};
 NSValue *(^homeAim)(void)=^NSValue *{return [NSValue valueWithPoint:[weak homePoint]];};
 // near its spot, a little below the menu bar; beside the Settings window rather than over it
 NSValue *(^nearHome)(double)=^NSValue *(double drop){GuideTour *s=weak;NSPoint p=[s homePoint],q=NSMakePoint(p.x,p.y-drop);NSRect real=[host guideSettingsFrame],set=NSInsetRect(real,-36,-36),v=s.screen.visibleFrame;
  if(!NSIsEmptyRect(real)&&NSPointInRect(q,set)){BOOL roomLeft=NSMinX(set)-30>NSMinX(v),roomRight=NSMaxX(set)+30<NSMaxX(v);q.x=(roomLeft&&(p.x-NSMinX(set)<NSMaxX(set)-p.x||!roomRight))?NSMinX(set):NSMaxX(set);}
  return [NSValue valueWithPoint:q];};
 NSValue *(^here)(void)=^NSValue *{GuideTour *s=weak;return [NSValue valueWithPoint:[s onScreen:s.view.pos]];};
 NSValue *(^mid)(NSRect)=^NSValue *(NSRect f){return NSIsEmptyRect(f)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
 NSValue *(^cardAim)(void)=^NSValue *{return mid([host guideControlFrame:@"card"]);};
 NSValue *(^slowerAim)(void)=^NSValue *{return mid([host guideControlFrame:@"slower"]);};
 NSValue *(^nextAim)(void)=^NSValue *{return mid([host guideControlFrame:@"next"]);};
 NSValue *(^screenAt)(double,double)=^NSValue *(double fx,double fy){NSRect v=weak.screen.visibleFrame;return [NSValue valueWithPoint:NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy)];};
 NSValue *(^screenMid)(void)=^NSValue *{return screenAt(.5,.4);};
 NSValue *(^down)(void)=^NSValue *{GuideTour *s=weak;NSPoint p=[s onScreen:s.view.pos];return [NSValue valueWithPoint:NSMakePoint(p.x,p.y-400)];};
 void (^aimAt)(NSValue *)=^(NSValue *p){GuideTour *s=weak;if(p)s.view.pointAt=[s local:p.pointValue];};
 // beside a real panel: on the side with room for a bubble, and if it can, away from the Settings window
 NSValue *(^besidePanel)(void)=^NSValue *{NSRect f=weak.avoidRect;if(NSIsEmptyRect(f))return nil;NSRect v=weak.screen.visibleFrame,set=[host guideSettingsFrame];
  BOOL lRoom=NSMinX(f)-400>NSMinX(v),rRoom=NSMaxX(f)+400<NSMaxX(v);
  BOOL lClear=NSIsEmptyRect(set)||!NSIntersectsRect(NSMakeRect(NSMinX(f)-400,NSMinY(f),400,f.size.height),set),rClear=NSIsEmptyRect(set)||!NSIntersectsRect(NSMakeRect(NSMaxX(f),NSMinY(f),400,f.size.height),set);
  BOOL right=(rRoom&&rClear)||(!(lRoom&&lClear)&&rRoom);return [NSValue valueWithPoint:NSMakePoint(right?NSMaxX(f)+40:NSMinX(f)-40,NSMidY(f)+30)];};
 // beside the Settings window, level with one of its tour controls, so the tip can show it from close by
 NSValue *(^besideControl)(NSString *,BOOL)=^NSValue *(NSString *which,BOOL preferLeft){NSRect c=[host guideControlFrame:which],set=[host guideSettingsFrame],v=weak.screen.visibleFrame;if(NSIsEmptyRect(c)||NSIsEmptyRect(set))return nil;
  BOOL lRoom=NSMinX(set)-70>NSMinX(v),rRoom=NSMaxX(set)+70<NSMaxX(v),left=preferLeft?(lRoom||!rRoom):(!rRoom&&lRoom);if(!lRoom&&!rRoom)return nil;
  return [NSValue valueWithPoint:NSMakePoint(left?NSMinX(set)-42:NSMaxX(set)+42,NSMidY(c))];};
 NSValue *(^panelAim)(void)=^NSValue *{NSRect f=weak.avoidRect;return NSIsEmptyRect(f)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
 NSMutableArray *steps=[NSMutableArray new],*cleanups=[NSMutableArray new];
 // 0 hello: out of its spot, a drop, the first words, and where the tour controls are
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Hi! I’m the circle from your menu bar. I’ll show you around."),GTFaceHop);a.to=^NSValue *{return nearHome(62);};a.pointAt=homeAim;
  GTBeat *b=Beat(L(@"An icon giving a tour. A first, for both of us."),GTFaceNone);
  GTBeat *c=Beat(L(@"My tip points at what I’m talking about. Now: your tour controls."),GTFaceNone);c.to=^NSValue *{return besideControl(@"card",NO);};c.pointAt=cardAim;
  GTBeat *d=Beat(L(@"Too fast? Press Slower. Honestly, my favorite button."),GTFaceSquint);d.to=^NSValue *{return besideControl(@"slower",YES);};d.pointAt=slowerAim;
  return @[a,b,c,d];}];
 [cleanups addObject:NSNull.null];
 // 1 home: its spot; while the menu bar hides it, it asks for a hand and waits
 [steps addObject:^NSArray *{
  __block BOOL wasHidden=NO;BOOL notch=[host guideHasNotch];
  GTBeat *hid=Beat(notch?L(@"Hm. My spot is under the notch. It eats an icon or two. Today: me."):L(@"Hm. My spot is hidden. Your menu bar is full."),GTFaceDroop);hid.to=^NSValue *{return nearHome(62);};hid.pointAt=homeAim;
  hid.onlyIf=^BOOL{if(iconShown())return NO;wasHidden=YES;weak.iconWasHidden=YES;return YES;};
  hid.later=@[@[@1.1,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x-300,s.view.pos.y+60);}],@[@1.8,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x+300,s.view.pos.y+60);}],@[@2.5,^{aimAt(homeAim());}]];  // a look left, a look right
  GTBeat *drag=Beat(L(@"Click » up there. Then hold ⌘ and drag the circle toward the clock."),GTFaceNone);drag.scene=0;drag.to=here;drag.onlyIf=^BOOL{return !iconShown();};
  drag.until=iconShown;drag.timeout=90;drag.timeoutSay=L(@"Let’s carry on. You can come back to this; the tour is under About.");
  drag.nudges=@[@[@4,L(@"I’d do it myself, but I have no hands."),@(GTFaceWiggle)],@[@20,L(@"No rush. I’ll wait right here."),@(GTFaceDroop)],@[@45,L(@"Or leave it for now: Next, in the Settings window. I’ll manage up there."),@(GTFacePlain),nextAim]];
  GTBeat *found=Beat(L(@"There I am! Thank you. Oof, I spun too hard."),GTFaceSpin);found.to=^NSValue *{return nearHome(56);};found.pointAt=homeAim;found.hold=.5;
  found.onlyIf=^BOOL{if(!(wasHidden&&iconShown()))return NO;weak.iconFoundSaid=YES;return YES;};
  GTBeat *still=Beat(L(@"It’s up there somewhere, hiding. Anyway: that’s where I live."),GTFaceDroop);still.to=^NSValue *{return nearHome(62);};still.pointAt=homeAim;still.onlyIf=^BOOL{return wasHidden&&!iconShown();};
  GTBeat *mine=Beat(L(@"Up here. This spot in the menu bar is mine. Small, but mine."),GTFacePlain);mine.to=^NSValue *{return nearHome(56);};mine.pointAt=homeAim;mine.onlyIf=iconShown;
  GTBeat *halves=Beat(L(@"Left half gray: Grayscale on. Right half amber: warmth. One look, no words."),GTFaceHalf);halves.faces=@[@[@2.4,@(GTFaceBlush)]];
  GTBeat *menu=Beat(L(@"Click my spot and the menu drops. Grayscale, Extra Warmth: all right there."),GTFacePlain);menu.scene=1;menu.to=here;menu.hold=1.5;
  return @[hid,drag,found,still,mine,halves,menu];}];
 [cleanups addObject:NSNull.null];
 // 2 Grayscale, on the real screen: full color, then gray, then back to yours
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Your real screen, in full color. Every badge and button: look at me, look at me."),GTFaceNone);a.free=YES;a.run=^{[host guideLookGray:0 warmth:0];};a.pointAt=^NSValue *{return screenAt(.8,.2);};
  a.later=@[@[@1.7,^{aimAt(screenAt(.2,.2));}]];  // the tip sweeps across the screen
  GTBeat *b=Beat(L(@"Grayscale. The color goes, and my warm half with it. Fair is fair."),GTFaceGray);b.run=^{[host guideLookGray:1 warmth:0];};b.pointAt=screenMid;
  GTBeat *c=Beat(L(@"Nothing is gone. It just pulls at you less."),GTFaceNone);
  GTBeat *d=Beat(L(@"Back to your own setting. I only borrow your screen. Nothing is saved."),GTFacePlain);d.run=^{[host guideLookGray:-1 warmth:-1];};d.faces=@[@[@.45,@(GTFaceHop)]];
  return @[a,b,c,d];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 3 Extra Warmth, on the real screen: amber rising to red, the guide's right half with it
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Extra Warmth: a touch of amber, all the way to red. Watch my right half."),GTFaceNone);a.free=YES;a.ramp=@[@.3,@3.0,@4.2];a.pointAt=screenMid;
  a.later=@[@[@2.9,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x+90,s.view.pos.y-8);}]];  // the tip turns toward its own right half
  GTBeat *b=Beat(L(@"Don’t look at me like that. That’s warmth, not blushing."),GTFaceWide);b.run=^{weak.view.blushTarget=1;};
  return @[a,b];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 4 exceptions: the scene, then the real panel with the guide beside it
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Some apps need their color. Photos, say. So: an exception, right from the menu."),GTFaceNone);a.scene=2;a.free=YES;a.hold=2;
  GTBeat *b=Beat(L(@"The real panel, for the app in front. Change one thing; the rest carries over."),GTFaceNone);b.to=besidePanel;b.pointAt=panelAim;b.hold=1.5;
  b.onlyIf=^BOOL{NSRect f=[host guideShowExceptionPanel];weak.avoidRect=f;return !NSIsEmptyRect(f);};
  GTBeat *c=Beat(L(@"Websites can have one too. Fine by me: some things look better in color."),GTFaceSquint);c.run=^{[host guideHideExceptionPanel];weak.avoidRect=NSZeroRect;};c.free=YES;
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideHideExceptionPanel];}];
 // 5 Peek, hands-on: it waits for the real shortcut
 [steps addObject:^NSArray *{
  NSString *key=[host guidePeekLabel],*shortcuts=L(@"Shortcuts");
  if(!key){GTBeat *none=Beat([NSString stringWithFormat:L(@"Peek has no shortcut yet. Settings → %@, whenever you like."),shortcuts],GTFaceNone);none.free=YES;return @[none];}
  __block BOOL seen=NO;__block double heldSince=-1;NSString *tap=[NSString stringWithFormat:L(@"Hold, don’t tap: %@. Take your time."),key];
  GTBeat *a=Beat(L(@"Sometimes you need color for a second. A chart, a photo, the red button."),GTFaceNone);a.free=YES;
  GTBeat *ask=Beat([NSString stringWithFormat:L(@"Your turn. Hold %@. I would, but I have no hands."),key],GTFaceWiggle);ask.pointAt=down;
  ask.timeout=45;ask.timeoutSay=[NSString stringWithFormat:L(@"No problem. Peek waits under Settings → %@. Moving on."),shortcuts];
  ask.nudges=@[@[@8,tap,@(GTFacePlain)],@[@20,L(@"No hurry. I’m good at waiting. It’s most of my job."),@(GTFaceDroop)]];
  ask.until=^BOOL{BOOL p=[host guidePeeking];double now=CACurrentMediaTime();
   if(p){if(heldSince<0)heldSince=now;if(now-heldSince>=.45||[host guidePeekKept]){seen=YES;return YES;}return NO;}
   if(heldSince>=0&&now-heldSince<.45){GuideTour *s=weak;[s after:.5 do:^{if(s.waiting&&![host guidePeeking]){[s face:GTFacePlain];[s show:tap scene:-1];}}];}  // a tap, not a hold
   heldSince=-1;return NO;};
  GTBeat *color=Beat(L(@"There! Color, for exactly as long as you hold it."),GTFaceWide);color.run=^{[weak face:GTFaceEmpty];};color.faces=@[@[@.05,@(GTFaceHop)]];color.pointAt=screenMid;
  color.onlyIf=^BOOL{return seen&&![host guidePeekKept];};color.until=^BOOL{return ![host guidePeeking]||[host guidePeekKept];};color.timeout=40;
  GTBeat *kept=Beat([NSString stringWithFormat:L(@"Kept it! Press %@ once more and it’s quiet again."),key],GTFaceHop);kept.run=^{[weak face:GTFaceEmpty];};kept.onlyIf=^BOOL{return seen&&[host guidePeekKept];};
  GTBeat *quiet=Beat(L(@"And quiet again. Twice, quickly, keeps the color until you press again."),GTFaceSquint);quiet.run=^{[weak face:GTFacePlain];};quiet.onlyIf=^BOOL{return seen&&![host guidePeekKept];};
  return @[a,ask,color,kept,quiet];}];
 [cleanups addObject:^{[weak face:GTFacePlain];}];
 // 6 sessions and breaks: the scene, then the real panel
 [steps addObject:^NSArray *{
  __block BOOL shown=NO;
  GTBeat *a=Beat(L(@"A session: a stretch of focused work with a gentle end."),GTFaceNone);a.scene=4;a.free=YES;
  GTBeat *b=Beat(L(@"No alarm. A warm glow, a soft gong, and the count goes on past the end."),GTFaceNone);b.scene=4;b.hold=1;
  GTBeat *c=Beat(L(@"Here it is, under my spot. Session or Break: a break calls you back. Once."),GTFaceNone);c.to=besidePanel;c.pointAt=panelAim;c.hold=1.5;
  c.onlyIf=^BOOL{NSRect f=[host guideShowSessionPanel];weak.avoidRect=f;shown=!NSIsEmptyRect(f);return shown;};
  GTBeat *d=Beat(L(@"Once is plenty. Nobody likes a nagging circle."),GTFaceSquint);d.run=^{[host guideHideSessionPanel];weak.avoidRect=NSZeroRect;};d.onlyIf=^BOOL{return shown;};
  return @[a,b,c,d];}];
 [cleanups addObject:^{[host guideHideSessionPanel];}];
 // 7 night: the real night look for a moment, and a sleepy guide
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"At night, a few points warmer. Like this. Night Shift sets the rhythm."),GTFaceNone);a.free=YES;a.run=^{[host guideNightPreview:YES];};a.pointAt=screenMid;
  a.later=@[@[@.4,^{weak.view.blushTarget=.35;}]];a.faces=@[@[@3.4,@(GTFaceDroop)]];
  GTBeat *b=Beat(L(@"Hm. This light makes me sleepy. Give me a second."),GTFaceDroop);b.hold=.4;
  GTBeat *c=Beat(L(@"There. Night Shift itself: Automatic, On or Off, in the same menu."),GTFacePlain);c.run=^{[host guideNightPreview:NO];};c.faces=@[@[@.05,@(GTFaceHop)]];c.pointAt=homeAim;
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideNightPreview:NO];}];
 // 8 private
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"No account. No tracking. I don’t even know your name, and I like it that way."),GTFaceNone);a.scene=5;a.free=YES;
  GTBeat *b=Beat(L(@"The browser only says which site is in front. I forget it right away."),GTFaceNone);b.scene=5;
  GTBeat *c=Beat(L(@"Screenshots keep their colors. Quiet for you, normal for everyone else."),GTFaceSquint);c.scene=5;
  return @[a,b,c];}];
 [cleanups addObject:NSNull.null];
 // 9 goodbye, back into its spot
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"And that’s everything. From here on: your screen, your rules."),GTFaceSpin);a.to=^NSValue *{return nearHome(150);};a.hold=.5;
  NSMutableArray *beats=[NSMutableArray arrayWithObject:a];
  if(GTWebsite){[beats addObject:Beat([NSString stringWithFormat:L(@"One more thing: this isn’t my only home. I also live on %@."),GTWebsite],GTFaceNone)];[beats addObject:Beat(L(@"A whole Mac to play with there, and a few secrets. Come visit."),GTFaceSquint)];}
  GTBeat *h=Beat(L(@"Time to go home, up there. I’d wave, but: no hands."),GTFaceNone);h.pointAt=homeAim;h.home=YES;h.afterSay=L(@"Enjoy the quiet.");[beats addObject:h];
  return beats;}];
 [cleanups addObject:NSNull.null];
 self.steps=steps;self.cleanups=cleanups;
}
@end
