#import "GuideTour.h"
#import "Localize.h"
#import <QuartzCore/QuartzCore.h>

// The website, once it is live: the goodbye then mentions the guide's second home there. nil: no website lines yet.
static NSString *const GTWebsite=nil;

// What the guide (the cursor from lesspull.com) does on a beat. HOP, SPIN, WAVE (= WIGGLE), NOD (= SQUINT), POP (= WIDE),
// DIZZY, PRESS (a click in the air; it never clicks for you), POKED, TILT, SHIVER and ARRIVE play once (a SPIN ends DIZZY);
// GRAY and BLUSH (its Guide tag loses its color, or goes red) and DROOP (sleepy) stay until a beat says PLAIN.
typedef NS_ENUM(NSInteger,GTFace){GTFaceNone,GTFaceHop,GTFaceSpin,GTFaceWiggle,GTFaceDroop,GTFaceSquint,GTFaceGray,GTFaceBlush,GTFaceDizzy,GTFacePlain,GTFaceWide,GTFaceHalf,GTFaceEmpty,
 GTFacePress,GTFacePoked,GTFaceTilt,GTFaceShiver,GTFaceArrive};
static NSColor *GTAmber(double a){return [NSColor colorWithSRGBRed:232/255.0 green:137/255.0 blue:74/255.0 alpha:a];}
static NSColor *GTCream(double a){return [NSColor colorWithSRGBRed:1 green:250/255.0 blue:242/255.0 alpha:a];}
static NSColor *GTInk(double a){return [NSColor colorWithSRGBRed:36/255.0 green:29/255.0 blue:20/255.0 alpha:a];}

// ---- One beat: a line, a face, maybe a card with a scene, a place to go, something real to do or wait for.
@interface GTBeat : NSObject
@property(copy) NSString *say;
@property GTFace face;
@property NSInteger scene;                      // -1: a plain bubble; otherwise a card with this scene
@property(copy) NSValue *(^to)(void);           // where the guide goes (screen point); nil: it stays (a new scene: free space)
@property BOOL free;                            // go to the station's free spot, chosen once per station so the guide does not wander
@property(copy) NSValue *(^pointAt)(void);      // what its pointy side points at (screen point); nil: into the card, or down
@property(copy) NSValue *(^ring)(void);         // something real to click, ringed in amber (screen rect)
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
@property(copy) NSArray<NSString *> *ask;       // answer buttons in the card; the beat waits for one (Next picks the last)
@property(copy) void (^answered)(NSInteger index);
@property(copy) NSArray *(^choices)(void);      // check boxes before the buttons (e.g. the installed browsers); their names
@property(copy) void (^chosen)(NSArray<NSNumber *> *picked);  // which boxes were ticked when a button was pressed
@property(copy) NSString *mark;                 // the menu item to choose gets the guide's amber dot (resume, grayscale, app-exception, …)
@property(copy) NSString *afterSay;             // home: a last line in the bubble alone, once the guide is back in its spot
@property(copy) NSString *keys;                 // keycaps beside the guide while the beat is up (e.g. ⌥A)
@end
@implementation GTBeat
- (instancetype)init {if((self=[super init]))_scene=-1;return self;}
@end
static GTBeat *Beat(NSString *say,GTFace face) {GTBeat *b=[GTBeat new];b.say=say;b.face=face;return b;}

static double Ease(double k){k=MAX(0,MIN(1,k));return k<.5?4*k*k*k:1-pow(-2*k+2,3)/2;}
static NSColor *Mix(NSColor *a,NSColor *b,double k){a=[a colorUsingColorSpace:NSColorSpace.sRGBColorSpace];b=[b colorUsingColorSpace:NSColorSpace.sRGBColorSpace];k=MAX(0,MIN(1,k));
 return [NSColor colorWithSRGBRed:a.redComponent+(b.redComponent-a.redComponent)*k green:a.greenComponent+(b.greenComponent-a.greenComponent)*k blue:a.blueComponent+(b.blueComponent-a.blueComponent)*k alpha:a.alphaComponent+(b.alphaComponent-a.alphaComponent)*k];}

// ---- The guide (the cursor from lesspull.com, with its amber Guide tag), its bubble or card, a ring around the real
// thing to click, and the little door it comes through, on a transparent layer over the whole screen.
@interface GuideView : NSView
@property NSPoint pos,pointAt;               // pos: the cursor's tip, view coordinates; pointAt: what it is about (NSZeroPoint: nothing)
@property double size,alpha,clock,cardAlpha,cardTarget,askHeight,lean;
@property double grayK,blushK,leftK,emptyK,grayTarget,blushTarget,leftTarget,emptyTarget;
@property double hopAt,spinAt,wiggleAt,squintAt,dizzyAt,wideAt,pressAt,pokedAt,tiltAt,shiverAt,arriveAt,pace;
@property NSRect ring;@property double ringAlpha,ringTarget;
@property NSPoint door;@property double doorK;  // the little door (a dark circle with an amber ring), 0 closed … 1 open
@property(copy) NSString *keys;
@property BOOL droop,still,forcedDroop,leaving;  // still: Reduce Motion; forcedDroop: sleepy on purpose; leaving: going home
@property NSRect card;                       // view coordinates; empty: no card or bubble
@property(copy) NSString *text;
@property(nonatomic) NSView *scene;
@end
@implementation GuideView
- (instancetype)initWithFrame:(NSRect)f {if((self=[super initWithFrame:f])){_hopAt=_spinAt=_wiggleAt=_squintAt=_dizzyAt=_wideAt=_pressAt=_pokedAt=_tiltAt=_shiverAt=_arriveAt=-100;_pace=1;}return self;}
- (BOOL)isFlipped {return NO;}
- (void)setScene:(NSView *)scene {if(_scene==scene)return;[_scene removeFromSuperview];_scene=scene;if(scene){scene.alphaValue=0;[self addSubview:scene];}}
- (double)radius {return 22*self.size;}
// The cursor's body, down and right of its tip (the arrow and the Guide tag): bubbles keep clear of it.
- (NSRect)bodyRect {NSPoint p=self.pos;return NSMakeRect(p.x-4,p.y-54,78,58);}
- (NSPoint)drawnTip {
 NSPoint p=self.pos;double t=self.clock;
 if(!self.still){p.y+=1.6*(1-cos(2*M_PI*t/(1.7*self.pace)));  // the website's idle bob
  double h=t-self.hopAt;if(h>=0&&h<.62)p.y+=16*fabs(sin(M_PI*h/.31))*(1-h/.62);
  double sv=t-self.shiverAt;if(sv>=0&&sv<.6)p.x+=1.6*sin(sv*80)*(1-sv/.6);}
 return p;
}
- (NSRect)textRect {double h=self.scene?self.card.size.height-14-14-self.scene.frame.size.height-10:self.card.size.height-26;return NSMakeRect(NSMinX(self.card)+14,NSMinY(self.card)+12+self.askHeight,self.card.size.width-28,h-self.askHeight);}
- (void)drawRect:(NSRect)dirty {
 double t=self.clock;
 // the ring: around the real thing to click, with a soft ping now and then
 if(self.ringAlpha>.01&&!NSIsEmptyRect(self.ring)){
  NSRect rr=NSInsetRect(self.ring,-5,-5);BOOL round=fabs(rr.size.width-rr.size.height)<10;double ph=fmod(t,1.5)/1.5;
  NSBezierPath *(^shape)(NSRect)=^NSBezierPath *(NSRect r){double cr=MIN(9,r.size.height/2);return round?[NSBezierPath bezierPathWithOvalInRect:r]:[NSBezierPath bezierPathWithRoundedRect:r xRadius:cr yRadius:cr];};
  NSBezierPath *main=shape(rr);main.lineWidth=2.6;[GTAmber(self.ringAlpha*(.8+.2*sin(t*4))) setStroke];[main stroke];
  if(!self.still){NSBezierPath *ping=shape(NSInsetRect(rr,-13*ph,-13*ph));ping.lineWidth=2;[GTAmber(self.ringAlpha*.55*(1-ph)) setStroke];[ping stroke];}
 }
 // the little door: a dark circle with an amber ring, like the website's circle in the corner
 if(self.doorK>.01){double R=24*self.doorK;NSRect dr=NSMakeRect(self.door.x-R,self.door.y-R,2*R,2*R);
  [NSGraphicsContext saveGraphicsState];NSShadow *sh=[NSShadow new];sh.shadowBlurRadius=14;sh.shadowOffset=NSMakeSize(0,-4);sh.shadowColor=[NSColor colorWithWhite:0 alpha:.35*MIN(1,self.doorK)];[sh set];
  [[NSColor colorWithSRGBRed:.09 green:.08 blue:.07 alpha:1] setFill];[[NSBezierPath bezierPathWithOvalInRect:dr] fill];[NSGraphicsContext restoreGraphicsState];
  NSBezierPath *edge=[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(dr,-1.5,-1.5)];edge.lineWidth=3;[GTAmber(.6) setStroke];[edge stroke];}
 if(self.alpha<=0.01&&(NSIsEmptyRect(self.card)||self.cardAlpha<=0.01))return;  // the last bubble can stay a moment after the guide is home
 NSPoint p=[self drawnTip];
 // the bubble (cream with an amber edge, as on the website) or a card with a scene, with a small tail toward the tip
 if(!NSIsEmptyRect(self.card)&&self.cardAlpha>0.01){
  double a=self.cardAlpha;NSRect c=self.card;BOOL card=self.scene!=nil;
  NSBezierPath *box=[NSBezierPath bezierPathWithRoundedRect:c xRadius:14 yRadius:14];
  NSPoint aimAt=NSMakePoint(p.x+6,p.y-4);
  NSPoint edge=NSMakePoint(MIN(MAX(aimAt.x,NSMinX(c)+20),NSMaxX(c)-20),MIN(MAX(aimAt.y,NSMinY(c)+20),NSMaxY(c)-20));
  if(aimAt.y<NSMinY(c))edge.y=NSMinY(c);else if(aimAt.y>NSMaxY(c))edge.y=NSMaxY(c);else if(aimAt.x<NSMinX(c))edge.x=NSMinX(c);else edge.x=NSMaxX(c);
  double dx=aimAt.x-edge.x,dy=aimAt.y-edge.y,len=hypot(dx,dy);
  if(len>8){double ux=dx/len,uy=dy/len;NSBezierPath *tail=[NSBezierPath bezierPath];[tail moveToPoint:NSMakePoint(edge.x-uy*7,edge.y+ux*7)];[tail lineToPoint:NSMakePoint(edge.x+ux*MIN(10,len-2),edge.y+uy*MIN(10,len-2))];[tail lineToPoint:NSMakePoint(edge.x+uy*7,edge.y-ux*7)];[tail closePath];[box appendBezierPath:tail];}
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh=[NSShadow new];sh.shadowBlurRadius=24;sh.shadowOffset=NSMakeSize(0,-8);sh.shadowColor=[NSColor colorWithWhite:0 alpha:.32*a];[sh set];
  [(card?[NSColor.windowBackgroundColor colorWithAlphaComponent:.98*a]:GTCream(a)) setFill];[box fill];
  [NSGraphicsContext restoreGraphicsState];
  [GTAmber(.95*a) setStroke];box.lineWidth=1.5;[box stroke];
  if(self.text.length){NSMutableParagraphStyle *ps=[NSMutableParagraphStyle new];ps.lineSpacing=1.5;ps.alignment=card?NSTextAlignmentCenter:NSTextAlignmentNatural;
   NSDictionary *at=@{NSFontAttributeName:[NSFont systemFontOfSize:card?14:14.5 weight:card?NSFontWeightRegular:NSFontWeightSemibold],NSForegroundColorAttributeName:card?[NSColor.labelColor colorWithAlphaComponent:a]:GTInk(a),NSParagraphStyleAttributeName:ps};
   [self.text drawWithRect:[self textRect] options:NSStringDrawingUsesLineFragmentOrigin attributes:at];}
  self.scene.alphaValue=a;
 }
 if(self.alpha<=0.01)return;
 // the cursor: a black arrow with a white edge (the website's own), its gestures, and its amber Guide tag
 double u=1.42*self.size;  // points per unit of the website's 24-unit arrow
 double ar=t-self.arriveAt,scale=1;if(ar>=0&&ar<.5){double k=ar/.5;scale=.2+.8*(1+2.6*pow(k-1,3)+1.6*pow(k-1,2));}  // pops in with an overshoot
 double w=t-self.wideAt;if(w>=0&&w<.35)scale*=1+.16*sin(M_PI*w/.35);
 double pr=t-self.pressAt;if(pr>=0&&pr<.22)scale*=.86+.14*(pr/.22);
 double sx=1,sy=1,pk=t-self.pokedAt;if(pk>=0&&pk<.45){double k=pk/.45;if(k<.3){sx=1+.28*k/.3;sy=1-.22*k/.3;}else if(k<.6){double q=(k-.3)/.3;sx=1.28-.4*q;sy=.78+.4*q;}else{double q=(k-.6)/.4;sx=.88+.12*q;sy=1.18-.18*q;}}
 double rot=self.lean,wv=t-self.wiggleAt;if(!self.still&&wv>=0&&wv<.95){double k=wv/.95;rot+=-17*M_PI/180*sin(2*M_PI*2.5*k)*(1-k*.6);}  // the website's wave
 double tl=t-self.tiltAt;if(tl>=0&&tl<1.8)rot+=16*M_PI/180*(tl<.25?tl/.25:tl<1.5?1:1-(tl-1.5)/.3);
 double nd=t-self.squintAt;if(nd>=0&&nd<.5)rot-=10*M_PI/180*sin(M_PI*nd/.5);  // a happy nod
 double dz=t-self.dizzyAt;if(!self.still&&dz>=0&&dz<1.1)rot+=8*M_PI/180*sin(dz*14)*(1-dz/1.1);
 if(self.droop||self.forcedDroop)rot-=20*M_PI/180;  // sleepy: it sags
 double sp=t-self.spinAt;if(!self.still&&sp>=0&&sp<.8)rot-=2*M_PI*Ease(sp/.8);
 if(self.still){rot=0;scale=1;sx=sy=1;}
 NSPoint pivot=NSMakePoint(p.x+6*u,p.y-9*u);  // the middle of the arrow
 NSAffineTransform *tr=[NSAffineTransform transform];[tr translateXBy:pivot.x yBy:pivot.y];[tr rotateByRadians:rot];[tr scaleXBy:scale*sx yBy:scale*sy];[tr translateXBy:-pivot.x yBy:-pivot.y];
 NSBezierPath *arrow=[NSBezierPath bezierPath];double pts[7][2]={{5,2.5},{5,18.7},{9.1,14.8},{11.8,21.1},{14.4,20},{11.7,13.8},{17.4,13.8}};
 for(int i=0;i<7;i++){NSPoint q=NSMakePoint(p.x+(pts[i][0]-5)*u,p.y-(pts[i][1]-2.5)*u);if(i==0)[arrow moveToPoint:q];else [arrow lineToPoint:q];}[arrow closePath];[arrow transformUsingAffineTransform:tr];
 arrow.lineJoinStyle=NSLineJoinStyleRound;arrow.lineWidth=1.4*u;
 [NSGraphicsContext saveGraphicsState];NSShadow *ds=[NSShadow new];ds.shadowBlurRadius=4;ds.shadowOffset=NSMakeSize(0,-2);ds.shadowColor=[NSColor colorWithWhite:0 alpha:.35*self.alpha];[ds set];
 [[NSColor colorWithWhite:1 alpha:self.alpha] setStroke];[arrow stroke];[NSGraphicsContext restoreGraphicsState];
 [[NSColor colorWithWhite:.067 alpha:self.alpha] setFill];[arrow fill];
 // a click in the air: a white ring at the tip
 if(pr>=0&&pr<.55){double k=pr/.55;double R=16*(.4+.8*k);NSBezierPath *ring=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-R,p.y-R,2*R,2*R)];ring.lineWidth=2;[[NSColor colorWithWhite:1 alpha:.95*(1-k)*self.alpha] setStroke];[ring stroke];}
 // the Guide tag (or keycaps, when it shows a shortcut): amber, and it loses its color in Grayscale too
 NSString *tag=self.keys.length?self.keys:L(@"Guide");NSDictionary *ta=@{NSFontAttributeName:[NSFont systemFontOfSize:self.keys.length?12.5:11.5 weight:NSFontWeightBold],NSForegroundColorAttributeName:[NSColor colorWithSRGBRed:29/255.0 green:18/255.0 blue:8/255.0 alpha:self.alpha]};
 NSSize ts=[tag sizeWithAttributes:ta];double tw=ts.width+16*self.size,th=ts.height+6*self.size,ta0=MIN(1,scale);
 NSRect tagRect=NSMakeRect(p.x+19*u,p.y-19*u-th,tw*ta0,th*ta0);
 NSColor *tagColor=Mix(Mix(GTAmber(1),[NSColor colorWithSRGBRed:.86 green:.2 blue:.12 alpha:1],self.blushK),[NSColor colorWithWhite:.6 alpha:1],self.grayK);
 if(ta0>.5){[NSGraphicsContext saveGraphicsState];NSShadow *tsh=[NSShadow new];tsh.shadowBlurRadius=8;tsh.shadowOffset=NSMakeSize(0,-3);tsh.shadowColor=[NSColor colorWithWhite:0 alpha:.3*self.alpha];[tsh set];
  [[tagColor colorWithAlphaComponent:self.alpha] setFill];[[NSBezierPath bezierPathWithRoundedRect:tagRect xRadius:th/2 yRadius:th/2] fill];[NSGraphicsContext restoreGraphicsState];
  [tag drawAtPoint:NSMakePoint(NSMinX(tagRect)+8*self.size,NSMinY(tagRect)+3*self.size) withAttributes:ta];}
}
@end

// ---- The tour bar: seven stations on a line that fills in amber, the station's name, Slower, Next and End tour.
// A small floating panel: in front in every Space and app, draggable, and it never takes the focus from the app you
// are in (so "Exception for …" stays about that app).
@interface GTStation : NSButton
@property NSInteger index,phase;             // phase 0 ahead, 1 done, 2 here
@property BOOL hover;
@property(copy) void (^hovered)(NSInteger index,BOOL inside);
@end
@implementation GTStation
- (void)updateTrackingAreas {[super updateTrackingAreas];for(NSTrackingArea *a in self.trackingAreas.copy)[self removeTrackingArea:a];[self addTrackingArea:[[NSTrackingArea alloc]initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil]];}
- (void)mouseEntered:(NSEvent *)e {self.hover=YES;self.needsDisplay=YES;if(self.hovered)self.hovered(self.index,YES);}
- (void)mouseExited:(NSEvent *)e {self.hover=NO;self.needsDisplay=YES;if(self.hovered)self.hovered(self.index,NO);}
- (BOOL)acceptsFirstMouse:(NSEvent *)e {return YES;}
- (void)drawRect:(NSRect)dirty {
 double d=self.hover||self.phase==2?22:19;NSRect c=NSMakeRect(NSMidX(self.bounds)-d/2,NSMidY(self.bounds)-d/2,d,d);NSBezierPath *o=[NSBezierPath bezierPathWithOvalInRect:c];NSColor *ink;
 if(self.phase==2){[GTAmber(1) setFill];[o fill];ink=NSColor.whiteColor;}
 else if(self.phase==1){[NSColor.windowBackgroundColor setFill];[o fill];[GTAmber(.32) setFill];[o fill];[GTAmber(.9) setStroke];o.lineWidth=1.2;[o stroke];ink=NSColor.labelColor;}
 else {[NSColor.windowBackgroundColor setFill];[o fill];[(self.hover?GTAmber(.9):NSColor.tertiaryLabelColor) setStroke];o.lineWidth=1.2;[o stroke];ink=NSColor.secondaryLabelColor;}
 NSString *n=[NSString stringWithFormat:@"%ld",(long)self.index+1];NSDictionary *a=@{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:11 weight:self.phase==2?NSFontWeightBold:NSFontWeightMedium],NSForegroundColorAttributeName:ink};
 NSSize s=[n sizeWithAttributes:a];[n drawAtPoint:NSMakePoint(NSMidX(c)-s.width/2,NSMidY(c)-s.height/2) withAttributes:a];
}
@end
@interface GTStepper : NSView
@property NSArray<GTStation *> *stations;@property NSInteger current;
@end
@implementation GTStepper
- (BOOL)isFlipped {return NO;}
- (void)drawRect:(NSRect)dirty {
 if(self.stations.count<2)return;NSRect a=self.stations.firstObject.frame,b=self.stations.lastObject.frame,c=self.stations[MAX(0,MIN(self.current,(NSInteger)self.stations.count-1))].frame;double y=NSMidY(a);
 NSBezierPath *line=[NSBezierPath bezierPath];[line moveToPoint:NSMakePoint(NSMidX(a),y)];[line lineToPoint:NSMakePoint(NSMidX(b),y)];line.lineWidth=2;[NSColor.quaternaryLabelColor setStroke];[line stroke];
 NSBezierPath *done=[NSBezierPath bezierPath];[done moveToPoint:NSMakePoint(NSMidX(a),y)];[done lineToPoint:NSMakePoint(NSMidX(c),y)];done.lineWidth=2;[GTAmber(.9) setStroke];[done stroke];
}
@end
// The cursor's home during the tour, at the left end of its bar: a little dark circle with an amber ring.
@interface GTHomeDot : NSView
@end
@implementation GTHomeDot
- (BOOL)isFlipped {return NO;}
- (void)drawRect:(NSRect)dirty {NSRect c=NSInsetRect(self.bounds,3,3);[[NSColor colorWithSRGBRed:.09 green:.08 blue:.07 alpha:1] setFill];[[NSBezierPath bezierPathWithOvalInRect:c] fill];
 NSBezierPath *edge=[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(c,-1.2,-1.2)];edge.lineWidth=2.2;[GTAmber(.65) setStroke];[edge stroke];}
@end
// Clicking the guide while it only talks: it reacts (a small clickable patch over its arrow, never over a target).
@interface GTPokeView : NSView
@property(copy) void (^poked)(void);
@end
@implementation GTPokeView
- (BOOL)acceptsFirstMouse:(NSEvent *)e {return YES;}
- (void)mouseDown:(NSEvent *)e {if(self.poked)self.poked();}
- (void)resetCursorRects {[self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];}
@end
// A panel that never takes the focus: clicks on its buttons work, the app you are in stays in front.
@interface GTPanel : NSPanel
@end
@implementation GTPanel
- (BOOL)canBecomeMainWindow {return NO;}
@end
static GTPanel *GTMakePanel(NSRect frame,NSInteger level){
 GTPanel *p=[[GTPanel alloc]initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 p.opaque=NO;p.backgroundColor=NSColor.clearColor;p.level=level;p.becomesKeyOnlyIfNeeded=YES;p.hidesOnDeactivate=NO;p.releasedWhenClosed=NO;p.floatingPanel=YES;
 p.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;return p;
}

@interface GuideTour ()
@property NSPanel *overlay;
@property GuideView *view;
@property GTPanel *bar,*askPanel,*pokePanel;
@property NSInteger pokes;
@property(copy) NSArray<NSString *> *pokeLines;            // what it says when poked, in order; then the last ones in turn
@property GTStepper *stepper;
@property GTHomeDot *homeDot;
@property NSTextField *barLabel;
@property NSButton *slowButton,*nextButton,*endButton;
@property NSArray<NSString *> *stationNames;
@property NSView *askView;
@property NSArray<NSButton *> *askBoxes;
@property(copy) void (^askAnswered)(NSInteger index);
@property NSTimer *frameTimer,*waitTimer,*rampTimer;
@property NSArray<NSArray<GTBeat *> *(^)(void)> *steps;
@property NSArray *cleanups;
@property(nonatomic,readwrite) NSInteger step;
@property(nonatomic,readwrite) BOOL slow;
@property NSInteger beatIndex,generation,sceneKind;
@property NSArray<GTBeat *> *beats;
@property NSPoint from,target,stepSpot;
@property double moveStart,moveDuration,anticipation,landedAt,waitStart,lastIconCheck,lastRingCheck,doorTarget,doorVel;
@property NSPoint landDir;
@property BOOL running,waiting,asking,hasStepSpot,iconWasHidden,iconFoundSaid;
@property(copy) NSValue *(^ringBlock)(void);
@property NSRect avoidRect;                    // screen coordinates: the real panel on screen now
@end

@implementation GuideTour
- (instancetype)initWithHost:(id<GuideTourHost>)host {if((self=[super init])){_host=host;_sceneKind=-1;_landedAt=-100;}return self;}
- (NSInteger)stepCount {return self.steps.count;}
- (double)pace {return self.slow?1.6:1;}
- (BOOL)reduceMotion {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;}
- (NSScreen *)screen {NSRect icon=[self.host guideIconFrame];for(NSScreen *s in NSScreen.screens)if(!NSIsEmptyRect(icon)&&NSIntersectsRect(s.frame,icon))return s;NSRect f=[self.host guideStartFrame];for(NSScreen *s in NSScreen.screens)if(NSIntersectsRect(s.frame,f))return s;return NSScreen.mainScreen?:NSScreen.screens.firstObject;}
- (NSPoint)local:(NSPoint)q {return NSMakePoint(q.x-self.overlay.frame.origin.x,q.y-self.overlay.frame.origin.y);}
- (NSRect)localRect:(NSRect)q {if(NSIsEmptyRect(q))return NSZeroRect;q.origin=[self local:q.origin];return q;}
- (NSPoint)onScreen:(NSPoint)q {return NSMakePoint(q.x+self.overlay.frame.origin.x,q.y+self.overlay.frame.origin.y);}
- (NSPoint)iconPoint {NSRect f=[self.host guideIconFrame];return NSIsEmptyRect(f)?NSZeroPoint:NSMakePoint(NSMidX(f),NSMidY(f));}
// Its home: the circle in the menu bar. While macOS hides it, the right end of the menu bar, where hidden icons go.
- (NSPoint)homePoint {NSPoint p=[self iconPoint];if(!NSEqualPoints(p,NSZeroPoint))return p;NSRect f=self.screen.frame;double bar=MAX(24,NSMaxY(f)-NSMaxY(self.screen.visibleFrame));return NSMakePoint(NSMaxX(f)-170,NSMaxY(f)-bar/2);}
- (NSRect)bounds {return NSInsetRect([self localRect:self.screen.visibleFrame],12,12);}
- (NSRect)barFrame {return self.bar.visible?self.bar.frame:NSZeroRect;}
- (NSRect)screenFrameOf:(NSView *)v {return v.window?[v.window convertRectToScreen:[v convertRect:v.bounds toView:nil]]:NSZeroRect;}

#pragma mark the tour bar
- (void)makeBar {
 self.stationNames=@[L(@"The pull"),L(@"Less Pull"),L(@"Apps"),L(@"Websites"),L(@"Peek"),L(@"Sessions"),L(@"Your turn")];
 NSInteger n=self.stationNames.count;double gap=40,w=24+gap*(n-1)+24;
 GTStepper *stepper=[[GTStepper alloc]initWithFrame:NSMakeRect(0,0,w,28)];NSMutableArray *stations=[NSMutableArray new];__weak GuideTour *weak=self;
 for(NSInteger i=0;i<n;i++){GTStation *s=[[GTStation alloc]initWithFrame:NSMakeRect(gap*i,1,26,26)];s.bordered=NO;s.title=@"";s.index=i;s.target=self;s.action=@selector(stationClicked:);s.toolTip=self.stationNames[i];
  s.accessibilityLabel=[NSString stringWithFormat:L(@"Step %ld: %@"),(long)i+1,self.stationNames[i]];s.hovered=^(NSInteger index,BOOL inside){[weak hoverStation:inside?index:-1];};[stepper addSubview:s];[stations addObject:s];}
 stepper.stations=stations;self.stepper=stepper;[stepper.widthAnchor constraintEqualToConstant:gap*(n-1)+26].active=YES;[stepper.heightAnchor constraintEqualToConstant:28].active=YES;
 self.barLabel=[NSTextField labelWithString:@""];self.barLabel.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];self.barLabel.textColor=NSColor.secondaryLabelColor;self.barLabel.lineBreakMode=NSLineBreakByTruncatingTail;
 [self.barLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
 self.slowButton=[NSButton buttonWithTitle:L(@"Slower") target:self action:@selector(slowClicked:)];self.slowButton.buttonType=NSButtonTypePushOnPushOff;self.slowButton.controlSize=NSControlSizeSmall;self.slowButton.bezelStyle=NSBezelStyleRounded;self.slowButton.toolTip=L(@"The circle takes more time for each step.");
 self.nextButton=[NSButton buttonWithTitle:L(@"Next") target:self action:@selector(nextClicked:)];self.nextButton.controlSize=NSControlSizeSmall;self.nextButton.bezelStyle=NSBezelStyleRounded;
 self.endButton=[NSButton buttonWithTitle:L(@"End tour") target:self action:@selector(endClicked:)];self.endButton.controlSize=NSControlSizeSmall;self.endButton.bezelStyle=NSBezelStyleRounded;
 NSView *flex=[NSView new];[flex setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[flex.widthAnchor constraintGreaterThanOrEqualToConstant:8].active=YES;
 NSStackView *buttons=[NSStackView stackViewWithViews:@[self.barLabel,flex,self.slowButton,self.nextButton,self.endButton]];buttons.spacing=6;
 GTHomeDot *dot=[[GTHomeDot alloc]initWithFrame:NSMakeRect(0,0,28,28)];[dot.widthAnchor constraintEqualToConstant:28].active=YES;[dot.heightAnchor constraintEqualToConstant:28].active=YES;dot.toolTip=L(@"Guide");self.homeDot=dot;
 NSStackView *top=[NSStackView stackViewWithViews:@[dot,stepper]];top.spacing=14;
 NSStackView *column=[NSStackView stackViewWithViews:@[top,buttons]];column.orientation=NSUserInterfaceLayoutOrientationVertical;column.alignment=NSLayoutAttributeCenterX;column.spacing=8;column.edgeInsets=NSEdgeInsetsMake(12,14,12,14);
 [buttons.widthAnchor constraintEqualToAnchor:column.widthAnchor constant:-28].active=YES;[column.widthAnchor constraintGreaterThanOrEqualToConstant:404].active=YES;
 NSVisualEffectView *back=[NSVisualEffectView new];back.material=NSVisualEffectMaterialPopover;back.blendingMode=NSVisualEffectBlendingModeBehindWindow;back.state=NSVisualEffectStateActive;back.wantsLayer=YES;back.layer.cornerRadius=14;back.layer.masksToBounds=YES;
 column.translatesAutoresizingMaskIntoConstraints=NO;[back addSubview:column];[NSLayoutConstraint activateConstraints:@[[column.leadingAnchor constraintEqualToAnchor:back.leadingAnchor],[column.trailingAnchor constraintEqualToAnchor:back.trailingAnchor],[column.topAnchor constraintEqualToAnchor:back.topAnchor],[column.bottomAnchor constraintEqualToAnchor:back.bottomAnchor]]];
 NSSize size=column.fittingSize;GTPanel *p=GTMakePanel(NSMakeRect(0,0,size.width,size.height),NSFloatingWindowLevel);p.hasShadow=YES;p.movableByWindowBackground=YES;p.contentView=back;p.accessibilityLabel=L(@"Less Pull tour");
 // first time: top left, under the menu bar, away from the circle and its menu; later where you dragged it
 NSRect v=self.screen.visibleFrame;NSPoint origin=NSMakePoint(NSMinX(v)+20,NSMaxY(v)-20-size.height);NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:@"tourBarOrigin"];
 if(saved){NSPoint o=NSPointFromString(saved);for(NSScreen *s in NSScreen.screens)if(NSContainsRect(s.visibleFrame,NSMakeRect(o.x,o.y,size.width,size.height)))origin=o;}
 [p setFrameOrigin:origin];self.bar=p;
 [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidMoveNotification object:p queue:nil usingBlock:^(NSNotification *note){[NSUserDefaults.standardUserDefaults setObject:NSStringFromPoint(((NSWindow *)note.object).frame.origin) forKey:@"tourBarOrigin"];}];
 p.alphaValue=0;[p orderFrontRegardless];[p.contentView layoutSubtreeIfNeeded];
}
- (void)revealBar {GTPanel *p=self.bar;if(self.reduceMotion)p.alphaValue=1;else [NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.18;p.animator.alphaValue=1;} completionHandler:nil];}
// One shape that changes, as on the website: the Settings window shrinks and rounds into the tour bar, or grows back
// out of it. A shell with the window's look travels between the two; the old look fades early, the new one late.
- (void)morphFrom:(NSRect)from to:(NSRect)to image:(NSImage *)image growing:(BOOL)growing then:(void(^)(void))done {
 if(self.reduceMotion||!image||NSIsEmptyRect(from)||NSIsEmptyRect(to)){done();return;}
 GTPanel *shell=GTMakePanel(from,NSFloatingWindowLevel+1);shell.hasShadow=YES;shell.ignoresMouseEvents=YES;
 NSView *box=[[NSView alloc]initWithFrame:(NSRect){NSZeroPoint,from.size}];box.wantsLayer=YES;box.layer.cornerRadius=growing?14:11;box.layer.masksToBounds=YES;box.layer.backgroundColor=NSColor.windowBackgroundColor.CGColor;box.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
 NSImageView *pic=[NSImageView imageViewWithImage:image];pic.imageScaling=NSImageScaleAxesIndependently;pic.frame=box.bounds;pic.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;pic.alphaValue=growing?0:1;[box addSubview:pic];
 shell.contentView=box;[shell orderFrontRegardless];
 [NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=growing?.62:.58;c.timingFunction=[CAMediaTimingFunction functionWithControlPoints:.5 :0 :.15 :1];[shell.animator setFrame:to display:YES];}
  completionHandler:^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.12;shell.animator.alphaValue=0;} completionHandler:^{[shell orderOut:nil];}];done();}];
 if(growing)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.36*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.24;pic.animator.alphaValue=1;} completionHandler:nil];});
 else [NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.18;pic.animator.alphaValue=0;} completionHandler:nil];
}
- (void)updateBar {
 for(GTStation *s in self.stepper.stations){s.phase=s.index<self.step?1:s.index==self.step?2:0;s.needsDisplay=YES;}self.stepper.current=self.step;self.stepper.needsDisplay=YES;
 [self hoverStation:-1];self.slowButton.state=self.slow;self.nextButton.title=self.step+1>=self.stepCount?L(@"Done"):L(@"Next");
}
- (void)hoverStation:(NSInteger)i {
 if(i>=0&&i!=self.step){self.barLabel.stringValue=[NSString stringWithFormat:L(@"Go to %ld · %@"),(long)i+1,self.stationNames[i]];self.barLabel.textColor=GTAmber(1);return;}
 NSInteger s=MAX(0,MIN(self.step,(NSInteger)self.stationNames.count-1));self.barLabel.stringValue=[NSString stringWithFormat:L(@"Step %ld of %ld · %@"),(long)s+1,(long)self.stationNames.count,self.stationNames[s]];self.barLabel.textColor=NSColor.secondaryLabelColor;
}
- (void)stationClicked:(GTStation *)sender {[self jumpTo:sender.index];}
- (void)slowClicked:(id)sender {[self toggleSlow];}
- (void)nextClicked:(id)sender {[self next];}
- (void)endClicked:(id)sender {[self endEarly];}
- (void)closeBar {[self closeBarAt:.2];}
- (void)closeBarAt:(double)fade {GTPanel *p=self.bar;self.bar=nil;if(!p)return;[NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowDidMoveNotification object:p];
 if(self.reduceMotion||fade<=0){[p orderOut:nil];return;}[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=fade;p.animator.alphaValue=0;} completionHandler:^{[p orderOut:nil];}];}

#pragma mark a poke
- (void)placePoke {
 GuideView *v=self.view;BOOL resting=self.running&&!v.leaving&&v.alpha>.9&&self.moveDuration<=0&&!self.asking&&!self.ringBlock&&!self.waiting&&self.pokeLines.count;
 if(!resting){[self.pokePanel orderOut:nil];return;}
 NSRect r=NSMakeRect(v.pos.x-2,v.pos.y-30,28,32);r.origin=[self onScreen:r.origin];
 if(!self.pokePanel){self.pokePanel=GTMakePanel(r,NSPopUpMenuWindowLevel+2);GTPokeView *pv=[[GTPokeView alloc]initWithFrame:(NSRect){NSZeroPoint,r.size}];__weak GuideTour *weak=self;pv.poked=^{[weak poked];};self.pokePanel.contentView=pv;}
 if(!NSEqualRects(self.pokePanel.frame,r))[self.pokePanel setFrame:r display:NO];if(!self.pokePanel.visible)[self.pokePanel orderFrontRegardless];
}
- (void)poked {
 if(!self.pokeLines.count)return;NSInteger n=self.pokes++,count=self.pokeLines.count;NSString *line=n<count?self.pokeLines[n]:self.pokeLines[count-1-(n-count)%MIN(2,count)];
 [self interject:line face:GTFacePoked];
}

#pragma mark answers in the card
- (void)showAsk:(NSArray<NSString *> *)labels choices:(NSArray<NSString *> *)choices answered:(void(^)(NSInteger))done {
 NSStackView *row=[NSStackView new];row.spacing=8;
 for(NSUInteger i=0;i<labels.count;i++){NSButton *b=[NSButton buttonWithTitle:labels[i] target:self action:@selector(askClicked:)];b.tag=i;b.bezelStyle=NSBezelStyleRounded;if(i==0)b.bezelColor=GTAmber(1);[row addArrangedSubview:b];}
 NSMutableArray *boxes=[NSMutableArray new];for(NSString *c in choices){NSButton *box=[NSButton checkboxWithTitle:c target:nil action:nil];box.state=choices.count==1;[boxes addObject:box];}
 self.askBoxes=boxes;
 if(boxes.count){NSStackView *list=[NSStackView stackViewWithViews:boxes];list.orientation=NSUserInterfaceLayoutOrientationVertical;list.alignment=NSLayoutAttributeLeading;list.spacing=4;
  NSStackView *all=[NSStackView stackViewWithViews:@[list,row]];all.orientation=NSUserInterfaceLayoutOrientationVertical;all.alignment=NSLayoutAttributeLeading;all.spacing=10;self.askView=all;}
 else self.askView=row;
 self.askAnswered=done;self.asking=YES;
}
- (NSArray<NSNumber *> *)tickedBoxes {NSMutableArray *out=[NSMutableArray new];[self.askBoxes enumerateObjectsUsingBlock:^(NSButton *b,NSUInteger i,BOOL *stop){if(b.state==NSControlStateValueOn)[out addObject:@(i)];}];return out;}
- (void)askClicked:(NSButton *)sender {[self answer:sender.tag];}
- (void)answer:(NSInteger)i {if(!self.asking)return;self.asking=NO;void (^d)(NSInteger)=self.askAnswered;self.askAnswered=nil;if(d)d(i);[self hideAsk];}
- (void)hideAsk {self.askView=nil;self.askBoxes=nil;self.view.askHeight=0;[self.askPanel orderOut:nil];self.askPanel.contentView=nil;}
- (void)placeAsk {
 if(!self.askView){[self.askPanel orderOut:nil];return;}
 NSSize as=self.askView.fittingSize;NSRect c=self.view.card;NSRect f=NSMakeRect(NSMinX(c)+16,NSMinY(c)+12,c.size.width-32,as.height);f.origin=[self onScreen:f.origin];
 if(!self.askPanel)self.askPanel=GTMakePanel(f,NSPopUpMenuWindowLevel+2);
 NSView *holder=[[NSView alloc]initWithFrame:(NSRect){NSZeroPoint,f.size}];self.askView.frame=NSMakeRect(0,0,as.width,as.height);[holder addSubview:self.askView];
 self.askPanel.contentView=holder;[self.askPanel setFrame:f display:YES];self.askPanel.alphaValue=self.view.cardAlpha;[self.askPanel orderFrontRegardless];
}

#pragma mark start and end
- (void)start {
 if(self.running)return;self.running=YES;
 NSScreen *s=self.screen;
 self.overlay=[[NSPanel alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.overlay.opaque=NO;self.overlay.backgroundColor=NSColor.clearColor;self.overlay.ignoresMouseEvents=YES;self.overlay.hasShadow=NO;self.overlay.level=NSPopUpMenuWindowLevel+1;  // above the real panels and menus; cards are placed beside them
 self.overlay.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;
 self.view=[[GuideView alloc]initWithFrame:(NSRect){NSZeroPoint,s.frame.size}];self.view.still=self.reduceMotion;self.overlay.contentView=self.view;[self.overlay setFrame:s.frame display:NO];[self.overlay orderFrontRegardless];
 self.overlay.accessibilityLabel=L(@"Less Pull tour");
 [self buildSteps];[self makeBar];
 NSRect settings=[self.host guideSettingsFrame];NSImage *look=NSIsEmptyRect(settings)?nil:[self.host guideSettingsSnapshot];
 GuideView *v=self.view;v.alpha=0;v.size=1;v.leaving=YES;
 self.frameTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(frame:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.frameTimer forMode:NSRunLoopCommonModes];
 // The Settings window turns into the tour's small bar; out of the bar's little circle (its home, as the circle in the
 // website's corner) the cursor pops, with a little overshoot, hops down, waves, and the circle closes behind it.
 [self.host guideShowSettings:NO];
 [self morphFrom:settings to:self.bar.frame image:look growing:NO then:^{
  [self revealBar];GuideView *g=self.view;g.door=[self doorPoint];g.doorK=0;g.pos=self.from=self.target=NSMakePoint(g.door.x-5,g.door.y+7);
  if(self.reduceMotion){g.leaving=NO;g.alpha=1;[self playStep:0];return;}
  [self after:.1 do:^{self.doorTarget=1;}];
  [self after:.4 do:^{GuideView *c=self.view;c.alpha=1;c.arriveAt=CACurrentMediaTime();}];
  [self after:.75 do:^{NSPoint d=self.view.door;[self moveTo:[self onScreen:NSMakePoint(d.x+40,d.y-70)]];}];
  [self after:1.1 do:^{self.doorTarget=0;}];
  [self after:1.5 do:^{[self face:GTFaceWiggle];self.view.leaving=NO;[self playStep:0];}];}];
}
- (void)stop {[self finish:NO];}
- (void)finish:(BOOL)completed {
 if(!self.running)return;self.running=NO;self.generation++;
 [self runCleanup:self.step];[self hideAsk];[self.askPanel orderOut:nil];[self.pokePanel orderOut:nil];
 [self.frameTimer invalidate];[self.waitTimer invalidate];[self.rampTimer invalidate];self.view.scene=nil;[self.overlay orderOut:nil];self.overlay=nil;
 [self.host guideSpotEmpty:NO];[self.host guideLookGray:-1 warmth:-1];
 // the bar grows back into the Settings window it came from
 NSRect settings=[self.host guideSettingsFrame];GTPanel *bar=self.bar;NSRect from=bar.visible?bar.frame:NSZeroRect;NSImage *look=NSIsEmptyRect(settings)?nil:[self.host guideSettingsSnapshot];
 [self closeBarAt:0];id<GuideTourHost> host=self.host;
 [self morphFrom:from to:settings image:look growing:YES then:^{[host guideShowSettings:YES];[host guideFinished:completed];}];
}
- (void)runCleanup:(NSInteger)step {if(step>=0&&step<(NSInteger)self.cleanups.count){id c=self.cleanups[step];if(c!=NSNull.null)((void(^)(void))c)();}self.avoidRect=NSZeroRect;}
- (void)halt {[self.host guideDo:@"mark" with:nil];[self runCleanup:self.step];self.generation++;[self.waitTimer invalidate];[self.rampTimer invalidate];self.waiting=NO;self.view.forcedDroop=NO;self.asking=NO;self.askAnswered=nil;[self hideAsk];self.ringBlock=nil;self.view.ringTarget=0;}

#pragma mark controls (the tour bar)
- (void)next {
 if(!self.running)return;
 if(self.asking){[self answer:-1];return;}  // a question: Next means "not now"
 if(self.waiting){[self.waitTimer invalidate];self.waiting=NO;self.generation++;self.ringBlock=nil;self.view.ringTarget=0;self.beatIndex++;[self playBeat];return;}  // waiting for your hands: Next means "not now", and the station goes on without it
 if(self.view.leaving)return;
 if(self.step+1>=(NSInteger)self.steps.count){  // Done: it still flies home and says goodbye, just without the rest of the station
  NSUInteger h=[self.beats indexOfObjectPassingTest:^BOOL(GTBeat *b,NSUInteger i,BOOL *stop){return b.home;}];
  if(h!=NSNotFound&&(NSInteger)h>self.beatIndex){self.generation++;[self.waitTimer invalidate];self.waiting=NO;self.beatIndex=h;[self playBeat];}
  else [self finish:YES];return;}
 [self playStep:self.step+1];
}
- (void)back {if(self.running&&self.step>0)[self jumpTo:self.step-1];}
- (void)jumpTo:(NSInteger)station {
 if(!self.running||station<0||station>=(NSInteger)self.steps.count)return;
 GuideView *v=self.view;v.leaving=NO;  // even on its way home, it comes back out
 [self playStep:station];
}
// End tour: at once. Whatever it showed goes back, the guide pops into its spot, the bar goes.
- (void)endEarly {
 if(!self.running)return;
 [self halt];[self.host guideLookGray:-1 warmth:-1];[self show:nil scene:-1];
 [self popThen:^{[self finish:NO];}];
}
- (void)toggleSlow {self.slow=!self.slow;self.view.pace=self.pace;[self updateBar];[self interject:self.slow?L(@"Slower. My favorite speed. Circles are never in a hurry."):L(@"Normal speed again. I can do fast. For a while.") face:self.slow?GTFaceSquint:GTFaceHop];}

#pragma mark the frame clock
- (void)frame:(NSTimer *)timer {
 double now=CACurrentMediaTime();GuideView *v=self.view;v.clock=now;
 double leanWant=0;
 if(self.moveDuration>0&&now>=self.moveStart){double k=MIN(1,(now-self.moveStart)/self.moveDuration),e=Ease(k);NSPoint a=self.from,b=self.target;double dist=hypot(b.x-a.x,b.y-a.y);
  double lift=dist<170?MAX(18,dist*.35):MIN(90,dist*.18);  // a short way is a hop, a long one the website's arc
  NSPoint np=NSMakePoint(a.x+(b.x-a.x)*e,a.y+(b.y-a.y)*e+sin(M_PI*e)*lift);double dx=np.x-v.pos.x;
  leanWant=MAX(-.28,MIN(.28,-dx*.03));v.pos=np;  // it leans into the way it goes
  if(k>=1){self.moveDuration=0;self.landedAt=now;self.landDir=dist>1?NSMakePoint((b.x-a.x)/dist,(b.y-a.y)/dist):NSZeroPoint;}}
 else if(self.moveDuration<=0){double l=now-self.landedAt;if(!v.still&&l>=0&&l<.7){double o=MIN(7,4+l*0)*exp(-l*7)*sin(l*17);v.pos=NSMakePoint(self.target.x+self.landDir.x*o,self.target.y+self.landDir.y*o);}}  // a soft overshoot as it lands
 v.lean+=(leanWant-v.lean)*(v.still?1:.15);
 // the door: a little spring as it opens and closes
 self.doorVel+=(self.doorTarget-v.doorK)*.22;self.doorVel*=.7;v.doorK=MAX(0,v.doorK+self.doorVel);if(self.doorTarget==0&&v.doorK<.02){v.doorK=0;self.doorVel=0;}
 v.grayK+=(v.grayTarget-v.grayK)*.08;v.blushK+=(v.blushTarget-v.blushK)*.08;v.leftK+=(v.leftTarget-v.leftK)*.08;v.emptyK+=(v.emptyTarget-v.emptyK)*.1;v.cardAlpha+=(v.cardTarget-v.cardAlpha)*(v.still?1:.2);
 // the ring follows the real thing (a panel can move); it fades in and out
 if(self.ringBlock&&now-self.lastRingCheck>.3){self.lastRingCheck=now;NSValue *r=self.ringBlock();v.ring=r?[self localRect:r.rectValue]:NSZeroRect;}
 v.ringAlpha+=((self.ringBlock&&!NSIsEmptyRect(v.ring)?v.ringTarget:0)-v.ringAlpha)*.15;
 if(self.askPanel.visible)self.askPanel.alphaValue=v.cardAlpha;
 [self placePoke];
 if(!v.leaving){if(v.alpha<1)v.alpha=MIN(1,v.alpha+.08);if(v.size<1)v.size=MIN(1,v.size+.06);}
 // waiting for you: a sleepy look after a while, and a little shuffle now and then
 if(self.waiting){double w=now-self.waitStart;v.droop=w>6;if(w>4&&fmod(w,4.5)<1.0/60*1.5)v.wiggleAt=now;}else v.droop=NO;
 // its spot comes out later in the tour (moved during Peek, say): it notices, once
 if(self.iconWasHidden&&!self.iconFoundSaid&&!self.waiting&&!v.leaving&&self.step>=2&&now-self.lastIconCheck>.5){self.lastIconCheck=now;
  if(!NSEqualPoints([self iconPoint],NSZeroPoint)){self.iconFoundSaid=YES;[self interject:L(@"There I am! Thank you. Oof, I spun too hard.") face:GTFaceSpin];}}
 if(v.cardTarget<=0&&v.cardAlpha<.02&&v.scene){v.scene=nil;self.sceneKind=-1;}
 v.needsDisplay=YES;
}

#pragma mark moving, placing, talking
// A move: the website's arc (a hop for a short way), leaning into it, with a soft overshoot as it lands. Returns the time until it arrives.
- (double)moveTo:(NSPoint)screenPoint {
 NSPoint to=[self local:screenPoint];NSRect b=[self bounds];to.x=MIN(MAX(to.x,NSMinX(b)+8),NSMaxX(b)-70);to.y=MIN(MAX(to.y,NSMinY(b)+60),NSMaxY([self localRect:self.screen.frame])-8);
 GuideView *v=self.view;double dist=hypot(to.x-v.pos.x,to.y-v.pos.y);if(dist<2)return 0;
 if(self.reduceMotion){v.pos=self.target=to;self.moveDuration=0;return .2;}
 self.anticipation=0;self.from=v.pos;self.target=to;self.moveStart=CACurrentMediaTime();self.landedAt=-100;
 self.moveDuration=MIN(1.5,.42+dist/1500)*(1+(self.pace-1)*.5);return self.moveDuration;
}
- (NSPoint)doorPoint {NSRect d=[self screenFrameOf:self.homeDot];if(self.bar&&!NSIsEmptyRect(d))return [self local:NSMakePoint(NSMidX(d),NSMidY(d))];NSPoint h=[self local:[self homePoint]];return NSMakePoint(h.x,h.y-44);}
// Home: it flies to its little circle, the circle opens, it dives in, the circle closes.
- (void)goHomeThen:(void(^)(void))done {
 [self show:nil scene:-1];self.view.pointAt=NSZeroPoint;GuideView *v=self.view;v.door=[self doorPoint];
 double t=[self moveTo:[self onScreen:NSMakePoint(v.door.x-16,v.door.y-30)]];
 [self after:MAX(0,t-.35) do:^{self.doorTarget=1;}];
 [self after:t+.12 do:^{[self shrinkThen:done];}];
}
- (void)shrinkThen:(void(^)(void))done {
 self.view.leaving=YES;
 if(self.reduceMotion){self.view.alpha=0;done();return;}
 double start=CACurrentMediaTime();NSPoint from=self.view.pos,into=NSMakePoint(self.view.door.x-4,self.view.door.y+6);__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/.42),e=Ease(k);
  s.view.pos=NSMakePoint(from.x+(into.x-from.x)*e,from.y+(into.y-from.y)*e+sin(M_PI*e)*22);s.target=s.view.pos;s.view.size=1-.8*e;s.view.alpha=1-pow(k,2);  // a little jump, and in
  if(k>=1){[timer invalidate];s.doorTarget=0;[s after:.3 do:done];}}];
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}
// Ended early: a quick pop where it is, no words.
- (void)popThen:(void(^)(void))done {
 GuideView *v=self.view;v.leaving=YES;if(self.reduceMotion||v.alpha<.05){v.alpha=0;done();return;}
 double start=CACurrentMediaTime(),s0=v.size;__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/.3);
  s.view.size=k<.3?s0*(1+.18*k/.3):s0*1.18*(1-(k-.3)/.7);s.view.alpha=k<.3?1:1-(k-.3)/.7;if(k>=1){[timer invalidate];done();}}];
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}
// A bubble or card goes near the cursor: above it first (as on the website), never over its arrow and tag, inside the
// screen, clear of the real panel, and if it can, clear of the tour bar.
- (NSRect)placeSize:(NSSize)size near:(NSPoint)g scene:(BOOL)scene {
 NSRect b=[self bounds];NSRect hard=[self localRect:self.avoidRect],soft=[self localRect:NSInsetRect([self barFrame],-8,-8)];double w=size.width,h=size.height;
 NSRect body=NSMakeRect(g.x-4,g.y-54,78,58);
 NSArray *candidates=@[[NSValue valueWithRect:NSMakeRect(g.x-14,g.y+14,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-w+14,g.y+14,w,h)],[NSValue valueWithRect:NSMakeRect(g.x+80,g.y-h/2-18,w,h)],
  [NSValue valueWithRect:NSMakeRect(g.x-w-16,g.y-h/2,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-10,g.y-62-h,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-w+60,g.y-62-h,w,h)]];
 for(int pass=0;pass<2;pass++)for(NSValue *v in candidates){NSRect c=v.rectValue;if(!NSContainsRect(b,c))continue;if(NSIntersectsRect(c,body))continue;if(!NSIsEmptyRect(hard)&&NSIntersectsRect(c,NSInsetRect(hard,-10,-10)))continue;if(pass==0&&!NSIsEmptyRect(soft)&&NSIntersectsRect(c,soft))continue;return c;}
 NSRect c=[candidates.firstObject rectValue];c.origin.x=MIN(MAX(c.origin.x,NSMinX(b)),NSMaxX(b)-w);c.origin.y=MIN(MAX(c.origin.y,NSMinY(b)),NSMaxY(b)-h);return c;
}
// A spot in free space for the guide and a card of this size: away from the real panel and the tour bar; near where it is.
- (NSValue *)freeSpotFor:(NSSize)size {
 NSRect v=self.screen.visibleFrame,bar=NSInsetRect([self barFrame],-20,-20);NSPoint here=[self onScreen:self.view.pos];
 NSPoint best=NSMakePoint(NSMidX(v),NSMidY(v));double bestScore=-1e9;
 for(double fy=.72;fy>=.3;fy-=.14)for(double fx=.18;fx<=.82;fx+=.16){NSPoint q=NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy);
  NSRect c=[self placeSize:size near:[self local:q] scene:YES];c.origin=[self onScreen:c.origin];
  double score=0;if(!NSIsEmptyRect(bar)&&NSIntersectsRect(c,bar))score-=1000;if(!NSIsEmptyRect(self.avoidRect)&&NSIntersectsRect(c,self.avoidRect))score-=5000;if(!NSContainsRect(v,c))score-=3000;
  score-=hypot(q.x-here.x,q.y-here.y)*.3;if(score>bestScore){bestScore=score;best=q;}}
 return [NSValue valueWithPoint:best];
}
- (NSValue *)stepFreeSpot {if(!self.hasStepSpot){self.stepSpot=[self freeSpotFor:NSMakeSize(452,232)].pointValue;self.hasStepSpot=YES;}return [NSValue valueWithPoint:self.stepSpot];}
- (NSSize)sizeForText:(NSString *)text scene:(BOOL)scene {
 NSDictionary *a=@{NSFontAttributeName:[NSFont systemFontOfSize:14]};double w=scene?420:312;NSSize ask=self.askView?self.askView.fittingSize:NSZeroSize;
 NSRect t=[text?:@"" boundingRectWithSize:NSMakeSize(w,1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:a];
 if(scene)return NSMakeSize(452,14+140+10+MAX(20,ceil(t.size.height)+4)+14+(ask.height?ask.height+10:0));
 return NSMakeSize(MAX(MAX(120,ceil(t.size.width)+34),ask.width+32),ceil(t.size.height)+30+(ask.height?ask.height+12:0));
}
- (void)show:(NSString *)text scene:(NSInteger)kind {
 GuideView *v=self.view;
 if(!text.length&&kind<0){v.cardTarget=0;[self.askPanel orderOut:nil];return;}
 BOOL sameScene=kind>=0&&kind==self.sceneKind&&v.scene;
 if(kind<0){v.scene=nil;self.sceneKind=-1;}
 else if(!sameScene){v.scene=[self.host guideScene:kind];self.sceneKind=kind;}
 v.text=text;NSSize size=[self sizeForText:text scene:kind>=0];v.askHeight=self.askView?self.askView.fittingSize.height+10:0;
 NSPoint g=self.moveDuration>0?self.target:v.pos;NSRect c=[self placeSize:size near:g scene:kind>=0];v.card=c;
 if(v.scene)v.scene.frame=NSMakeRect(NSMinX(c)+16,NSMaxY(c)-14-140,420,140);
 if(!sameScene&&v.cardAlpha>.5&&kind>=0)v.cardAlpha=.35;  // a new scene fades in again
 v.cardTarget=1;[self placeAsk];
 if(text.length)NSAccessibilityPostNotificationWithUserInfo(self.overlay,NSAccessibilityAnnouncementRequestedNotification,@{NSAccessibilityAnnouncementKey:text,NSAccessibilityPriorityKey:@(NSAccessibilityPriorityHigh)});
}
- (void)face:(GTFace)f {
 GuideView *v=self.view;double now=CACurrentMediaTime();
 switch(f){case GTFaceHop:v.hopAt=now;break;case GTFaceSpin:v.spinAt=now;v.dizzyAt=now+.8;break;case GTFaceWiggle:v.wiggleAt=now;break;case GTFaceSquint:v.squintAt=now;break;case GTFaceDizzy:v.dizzyAt=now;break;
  case GTFaceWide:v.wideAt=now;v.forcedDroop=NO;break;case GTFaceGray:v.grayTarget=1;break;case GTFaceBlush:v.blushTarget=1;break;case GTFaceHalf:v.leftTarget=1;break;case GTFaceEmpty:v.emptyTarget=1;break;
  case GTFaceDroop:v.forcedDroop=YES;break;case GTFacePress:v.pressAt=now;break;case GTFacePoked:v.pokedAt=now;break;case GTFaceTilt:v.tiltAt=now;break;case GTFaceShiver:v.shiverAt=now;break;case GTFaceArrive:v.arriveAt=now;break;
  case GTFacePlain:v.grayTarget=v.blushTarget=v.leftTarget=v.emptyTarget=0;v.forcedDroop=NO;break;case GTFaceNone:break;}
}
// Real warmth rising on the real screen (a passing look, never saved), its right half blushing along.
- (void)rampFrom:(double)a to:(double)b over:(double)seconds {
 [self.rampTimer invalidate];double start=CACurrentMediaTime();NSInteger g=self.generation;__weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 self.rampTimer=[NSTimer timerWithTimeInterval:1.0/15 repeats:YES block:^(NSTimer *t){GuideTour *s=weak;if(!s||g!=s.generation||!s.running){[t invalidate];return;}
  double k=MIN(1,(CACurrentMediaTime()-start)/(seconds*s.pace)),x=a+(b-a)*k;[host guideLookGray:-1 warmth:x];s.view.blushTarget=MIN(1,x/3);if(k>=1)[t invalidate];}];
 [NSRunLoop.mainRunLoop addTimer:self.rampTimer forMode:NSRunLoopCommonModes];
}
- (double)readingTime:(NSString *)text {if(!text.length)return 0;NSUInteger words=[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].count;return MAX(2.2,words*.3+1.0)*self.pace;}  // about 200 words a minute, plus a breath
- (void)interject:(NSString *)text face:(GTFace)f {
 if(!self.running||self.view.leaving||self.asking)return;NSString *before=self.view.text;NSInteger kind=self.sceneKind,g=self.generation;[self face:f];[self show:text scene:kind];
 [self after:2.4*self.pace do:^{if(g==self.generation&&[self.view.text isEqual:text])[self show:before scene:kind];}];
}
- (void)after:(double)seconds do:(void(^)(void))block {NSInteger g=self.generation;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(g==self.generation&&self.running)block();});}

#pragma mark the stations
- (void)playStep:(NSInteger)i {
 [self halt];self.hasStepSpot=NO;[self face:GTFacePlain];
 self.step=i;self.beats=self.steps[i]();self.beatIndex=0;[self updateBar];[self playBeat];
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
 self.ringBlock=b.ring;self.lastRingCheck=0;v.ringTarget=b.ring?1:0;[self.host guideDo:@"mark" with:b.mark];
 if(b.home){[self show:b.say scene:-1];
  [self after:[self readingTime:b.say] do:^{[self goHomeThen:^{
   if(!b.afterSay.length){[self after:.6 do:^{[self finish:YES];}];return;}
   [self after:.55 do:^{[self show:b.afterSay scene:-1];}];[self after:.55+2.5*self.pace do:^{[self show:nil scene:-1];[self after:.6 do:^{[self finish:YES];}];}];}];}];
  return;}
 double travel=0;NSValue *to=b.to?b.to():nil;
 if(!to&&(b.free||(b.scene>=0&&self.sceneKind!=b.scene)))to=[self stepFreeSpot];
 if(to){travel=[self moveTo:to.pointValue];if(travel>0)[self show:nil scene:-1];}
 void (^advance)(void)=^{self.waiting=NO;self.ringBlock=nil;self.view.ringTarget=0;self.beatIndex++;[self playBeat];};
 // a question: answer buttons in the card; the station goes on with the answer
 if(b.ask.count){
  NSArray *choices=b.choices?b.choices():nil;
  void (^speak)(void)=^{[self showAsk:b.ask choices:choices answered:^(NSInteger i){NSInteger pick=i<0?(NSInteger)b.ask.count-1:i;NSArray *ticked=i<0?@[]:[self tickedBoxes];if(b.chosen)b.chosen(ticked);if(b.answered)b.answered(pick);[self after:.25 do:advance];}];[self show:b.say scene:b.scene];};
  if(travel>0)[self after:travel*.85 do:speak];else speak();
  return;}
 void (^speak)(void)=^{[self show:b.say scene:b.scene];};
 if(travel>0)[self after:travel*.85 do:speak];else speak();
 double wait=travel*.85+[self readingTime:b.say]+b.hold*self.pace;
 if(!b.until){[self after:wait do:advance];return;}
 // waiting for something real, with a friendly line now and then if it takes a while
 NSInteger g=self.generation;__weak GuideTour *weak=self;[self.waitTimer invalidate];__block NSUInteger nudged=0;
 [self after:travel*.85+.6 do:^{GuideTour *s=weak;s.waiting=YES;s.waitStart=CACurrentMediaTime();
  s.waitTimer=[NSTimer timerWithTimeInterval:.15 repeats:YES block:^(NSTimer *t){GuideTour *w=weak;if(!w||g!=w.generation||!w.running){[t invalidate];return;}
   if(b.until()){[t invalidate];w.waiting=NO;w.ringBlock=nil;w.view.ringTarget=0;[w after:.35 do:advance];return;}
   double waited=CACurrentMediaTime()-w.waitStart;
   if(nudged<b.nudges.count&&waited>=[b.nudges[nudged][0] doubleValue]*w.pace){NSArray *n=b.nudges[nudged++];[w face:[n[2] integerValue]];
    if(n.count>3){NSValue *(^na)(void)=n[3];NSValue *p=na();if(p)w.view.pointAt=[w local:p.pointValue];}[w show:n[1] scene:w.sceneKind];}
   if(b.timeout>0&&waited>b.timeout*w.pace){[t invalidate];w.waiting=NO;w.ringBlock=nil;w.view.ringTarget=0;if(b.timeoutSay.length){[w face:GTFacePlain];w.view.pointAt=NSZeroPoint;[w show:b.timeoutSay scene:-1];[w after:[w readingTime:b.timeoutSay] do:advance];}else advance();}}];
  [NSRunLoop.mainRunLoop addTimer:s.waitTimer forMode:NSRunLoopCommonModes];}];
}

// ---- The script (TOUR-SCRIPT-v2 by Fable, arranged in seven stations; v3 makes them hands-on). Lines are data.
- (void)buildSteps {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 BOOL (^iconShown)(void)=^BOOL{return !NSIsEmptyRect([host guideIconFrame]);};
 NSValue *(^homeAim)(void)=^NSValue *{return [NSValue valueWithPoint:[weak homePoint]];};
 NSValue *(^nearHome)(double)=^NSValue *(double drop){GuideTour *s=weak;NSPoint p=[s homePoint];return [NSValue valueWithPoint:NSMakePoint(p.x,p.y-drop)];};
 NSValue *(^here)(void)=^NSValue *{GuideTour *s=weak;return [NSValue valueWithPoint:[s onScreen:s.view.pos]];};
 NSValue *(^mid)(NSRect)=^NSValue *(NSRect f){return NSIsEmptyRect(f)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
 NSValue *(^stepperAim)(void)=^NSValue *{return mid([weak screenFrameOf:weak.stepper]);};
 NSValue *(^slowerAim)(void)=^NSValue *{return mid([weak screenFrameOf:weak.slowButton]);};
 NSValue *(^tipOn)(NSRect)=^NSValue *(NSRect r){return NSIsEmptyRect(r)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(r)+2,NSMidY(r)-3)];};  // a cursor points by being there
 NSValue *(^screenAt)(double,double)=^NSValue *(double fx,double fy){NSRect v=weak.screen.visibleFrame;return [NSValue valueWithPoint:NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy)];};
 NSValue *(^screenMid)(void)=^NSValue *{return screenAt(.5,.4);};
 NSValue *(^down)(void)=^NSValue *{GuideTour *s=weak;NSPoint p=[s onScreen:s.view.pos];return [NSValue valueWithPoint:NSMakePoint(p.x,p.y-400)];};
 void (^aimAt)(NSValue *)=^(NSValue *p){GuideTour *s=weak;if(p)s.view.pointAt=[s local:p.pointValue];};
 // beside a real panel: on the side with room for a bubble, and if it can, away from the tour bar
 NSValue *(^besidePanel)(void)=^NSValue *{NSRect f=weak.avoidRect;if(NSIsEmptyRect(f))return nil;NSRect v=weak.screen.visibleFrame,bar=[weak barFrame];
  BOOL lRoom=NSMinX(f)-400>NSMinX(v),rRoom=NSMaxX(f)+400<NSMaxX(v);
  BOOL lClear=NSIsEmptyRect(bar)||!NSIntersectsRect(NSMakeRect(NSMinX(f)-400,NSMinY(f),400,f.size.height),bar),rClear=NSIsEmptyRect(bar)||!NSIntersectsRect(NSMakeRect(NSMaxX(f),NSMinY(f),400,f.size.height),bar);
  BOOL right=(rRoom&&rClear)||(!(lRoom&&lClear)&&rRoom);return [NSValue valueWithPoint:NSMakePoint(right?NSMaxX(f)+40:NSMinX(f)-40,NSMidY(f)+30)];};
 NSValue *(^panelAim)(void)=^NSValue *{NSRect f=weak.avoidRect;return NSIsEmptyRect(f)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(f),NSMidY(f))];};
 NSMutableArray *steps=[NSMutableArray new],*cleanups=[NSMutableArray new];
 // 1 The pull: out of its spot, hello, the tour bar, and your real screen in full color
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Hi! I’m the circle from your menu bar. I’ll show you around."),GTFaceHop);a.to=^NSValue *{return nearHome(62);};a.pointAt=homeAim;
  GTBeat *b=Beat(L(@"An icon giving a tour. A first, for both of us."),GTFaceNone);
  GTBeat *c=Beat(L(@"My tip points at what I’m talking about. Now: your tour controls."),GTFaceNone);c.to=^NSValue *{return tipOn([weak screenFrameOf:weak.stepper.stations[MIN(3,weak.stepper.stations.count-1)]]);};c.pointAt=stepperAim;c.ring=^NSValue *{NSRect f=[weak screenFrameOf:weak.stepper];return NSIsEmptyRect(f)?nil:[NSValue valueWithRect:f];};
  GTBeat *d=Beat(L(@"Too fast? Press Slower. Honestly, my favorite button."),GTFaceSquint);d.to=^NSValue *{return tipOn([weak screenFrameOf:weak.slowButton]);};d.pointAt=slowerAim;d.ring=^NSValue *{NSRect f=[weak screenFrameOf:weak.slowButton];return NSIsEmptyRect(f)?nil:[NSValue valueWithRect:f];};
  GTBeat *e=Beat(L(@"Your real screen, in full color. Every badge and button: look at me, look at me."),GTFaceNone);e.free=YES;e.run=^{[host guideLookGray:0 warmth:0];};e.pointAt=^NSValue *{return screenAt(.8,.2);};
  e.later=@[@[@1.7,^{aimAt(screenAt(.2,.2));}]];  // the tip sweeps across the screen
  return @[a,b,c,d,e];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 2 Less Pull: its spot (or help to bring it out), the two halves, Grayscale and warmth on the real screen
 [steps addObject:^NSArray *{
  __block BOOL wasHidden=NO;BOOL notch=[host guideHasNotch];
  GTBeat *hid=Beat(notch?L(@"Hm. My spot is under the notch. It eats an icon or two. Today: me."):L(@"Hm. My spot is hidden. Your menu bar is full."),GTFaceDroop);hid.to=^NSValue *{return nearHome(62);};hid.pointAt=homeAim;
  hid.onlyIf=^BOOL{if(iconShown())return NO;wasHidden=YES;weak.iconWasHidden=YES;return YES;};
  hid.later=@[@[@1.1,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x-300,s.view.pos.y+60);}],@[@1.8,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x+300,s.view.pos.y+60);}],@[@2.5,^{aimAt(homeAim());}]];  // a look left, a look right
  GTBeat *drag=Beat(L(@"Click » up there. Then hold ⌘ and drag the circle toward the clock."),GTFaceNone);drag.scene=0;drag.to=here;drag.onlyIf=^BOOL{return !iconShown();};
  drag.until=iconShown;drag.timeout=90;drag.timeoutSay=L(@"Let’s carry on. You can come back to this; the tour is under About.");
  drag.nudges=@[@[@4,L(@"I’d do it myself, but I have no hands."),@(GTFaceWiggle)],@[@20,L(@"No rush. I’ll wait right here."),@(GTFaceDroop)]];
  GTBeat *found=Beat(L(@"There I am! Thank you. Oof, I spun too hard."),GTFaceSpin);found.to=^NSValue *{return nearHome(56);};found.pointAt=homeAim;found.hold=.5;
  found.onlyIf=^BOOL{if(!(wasHidden&&iconShown()))return NO;weak.iconFoundSaid=YES;return YES;};
  GTBeat *still=Beat(L(@"It’s up there somewhere, hiding. Anyway: that’s where I live."),GTFaceDroop);still.to=^NSValue *{return nearHome(62);};still.pointAt=homeAim;still.onlyIf=^BOOL{return wasHidden&&!iconShown();};
  GTBeat *mine=Beat(L(@"Up here. This spot in the menu bar is mine. Small, but mine."),GTFacePlain);mine.to=^NSValue *{return nearHome(56);};mine.pointAt=homeAim;mine.onlyIf=iconShown;
  mine.ring=^NSValue *{NSRect f=[host guideIconFrame];return NSIsEmptyRect(f)?nil:[NSValue valueWithRect:f];};
  GTBeat *halves=Beat(L(@"Left half gray: Grayscale on. Right half amber: warmth. One look, no words."),GTFaceHalf);halves.faces=@[@[@2.4,@(GTFaceBlush)]];
  GTBeat *menu=Beat(L(@"Click my spot and the menu drops. Grayscale, Extra Warmth: all right there."),GTFacePlain);menu.scene=1;menu.to=here;menu.hold=1.5;
  GTBeat *g1=Beat(L(@"Grayscale. The color goes, and my warm half with it. Fair is fair."),GTFaceGray);g1.free=YES;g1.run=^{[host guideLookGray:1 warmth:0];};g1.pointAt=screenMid;
  GTBeat *g2=Beat(L(@"Nothing is gone. It just pulls at you less."),GTFaceNone);
  GTBeat *w1=Beat(L(@"Extra Warmth: a touch of amber, all the way to red. Watch my right half."),GTFacePlain);w1.ramp=@[@.3,@3.0,@4.2];w1.pointAt=screenMid;
  w1.later=@[@[@2.9,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x+90,s.view.pos.y-8);}]];  // the tip turns toward its own right half
  GTBeat *w2=Beat(L(@"Don’t look at me like that. That’s warmth, not blushing."),GTFaceWide);w2.run=^{weak.view.blushTarget=1;};
  GTBeat *back=Beat(L(@"Back to your own setting. I only borrow your screen. Nothing is saved."),GTFacePlain);back.run=^{[host guideLookGray:-1 warmth:-1];};back.faces=@[@[@.45,@(GTFaceHop)]];
  return @[hid,drag,found,still,mine,halves,menu,g1,g2,w1,w2,back];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 3 Apps: the scene, then the real panel with the guide beside it
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"Some apps need their color. Photos, say. So: an exception, right from the menu."),GTFaceNone);a.scene=2;a.free=YES;a.hold=2;
  GTBeat *b=Beat(L(@"The real panel, for the app in front. Change one thing; the rest carries over."),GTFaceNone);b.to=besidePanel;b.pointAt=panelAim;b.hold=1.5;
  b.onlyIf=^BOOL{NSRect f=[host guideShowExceptionPanel];weak.avoidRect=f;return !NSIsEmptyRect(f);};
  GTBeat *c=Beat(L(@"Websites can have one too. Fine by me: some things look better in color."),GTFaceSquint);c.run=^{[host guideHideExceptionPanel];weak.avoidRect=NSZeroRect;};c.free=YES;
  return @[a,b,c];}];
 [cleanups addObject:^{[host guideHideExceptionPanel];}];
 // 4 Websites
 [steps addObject:^NSArray *{
  GTBeat *a=Beat(L(@"The browser only says which site is in front. I forget it right away."),GTFaceNone);a.scene=5;a.free=YES;
  GTBeat *b=Beat(L(@"Screenshots keep their colors. Quiet for you, normal for everyone else."),GTFaceSquint);b.scene=5;
  return @[a,b];}];
 [cleanups addObject:NSNull.null];
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
 // 6 Sessions and night
 [steps addObject:^NSArray *{
  __block BOOL shown=NO;
  GTBeat *a=Beat(L(@"A session: a stretch of focused work with a gentle end."),GTFaceNone);a.scene=4;a.free=YES;
  GTBeat *b=Beat(L(@"No alarm. A warm glow, a soft gong, and the count goes on past the end."),GTFaceNone);b.scene=4;b.hold=1;
  GTBeat *c=Beat(L(@"Here it is, under my spot. Session or Break: a break calls you back. Once."),GTFaceNone);c.to=besidePanel;c.pointAt=panelAim;c.hold=1.5;
  c.onlyIf=^BOOL{NSRect f=[host guideShowSessionPanel];weak.avoidRect=f;shown=!NSIsEmptyRect(f);return shown;};
  GTBeat *d=Beat(L(@"Once is plenty. Nobody likes a nagging circle."),GTFaceSquint);d.run=^{[host guideHideSessionPanel];weak.avoidRect=NSZeroRect;};d.onlyIf=^BOOL{return shown;};
  GTBeat *n1=Beat(L(@"At night, a few points warmer. Like this. Night Shift sets the rhythm."),GTFaceNone);n1.free=YES;n1.run=^{[host guideNightPreview:YES];};n1.pointAt=screenMid;
  n1.later=@[@[@.4,^{weak.view.blushTarget=.35;}]];n1.faces=@[@[@3.4,@(GTFaceDroop)]];
  GTBeat *n2=Beat(L(@"Hm. This light makes me sleepy. Give me a second."),GTFaceDroop);n2.hold=.4;
  GTBeat *n3=Beat(L(@"There. Night Shift itself: Automatic, On or Off, in the same menu."),GTFacePlain);n3.run=^{[host guideNightPreview:NO];};n3.faces=@[@[@.05,@(GTFaceHop)]];n3.pointAt=homeAim;
  return @[a,b,c,d,n1,n2,n3];}];
 [cleanups addObject:^{[host guideHideSessionPanel];[host guideNightPreview:NO];}];
 // 7 Your turn: private, and home
 [steps addObject:^NSArray *{
  GTBeat *p=Beat(L(@"No account. No tracking. I don’t even know your name, and I like it that way."),GTFaceNone);p.scene=5;p.free=YES;
  GTBeat *a=Beat(L(@"And that’s everything. From here on: your screen, your rules."),GTFaceSpin);a.to=^NSValue *{return nearHome(150);};a.hold=.5;
  NSMutableArray *beats=[NSMutableArray arrayWithObjects:p,a,nil];
  if(GTWebsite){[beats addObject:Beat([NSString stringWithFormat:L(@"One more thing: this isn’t my only home. I also live on %@."),GTWebsite],GTFaceNone)];[beats addObject:Beat(L(@"A whole Mac to play with there, and a few secrets. Come visit."),GTFaceSquint)];}
  GTBeat *h=Beat(L(@"Time to go home, up there. I’d wave, but: no hands."),GTFaceNone);h.pointAt=homeAim;h.home=YES;h.afterSay=L(@"Enjoy the quiet.");[beats addObject:h];
  return beats;}];
 [cleanups addObject:NSNull.null];
 self.steps=steps;self.cleanups=cleanups;
}
@end
