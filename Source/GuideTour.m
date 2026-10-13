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
@property(copy) NSString *ident;                // a name, for jumps inside the station
@property BOOL jumpOnly;                        // only played when a jump leads here
@property(copy) NSString *(^sayBlock)(void);    // a line made when the beat plays (an app's name, a shortcut)
@property(copy) void (^onNext)(void);           // what Next does during this beat's wait (the one step the guide may do itself)
@property(copy) NSString *nextTo,*doneTo,*timeoutTo;  // where Next, success and the timeout lead (an ident, or "next-station")
@property(copy) NSString *menuItem;             // the menu item it waits for: when the menu closes without it, a word
@property(copy) NSString *(^pokeSay)(void);     // what a poke gets during this beat
@property BOOL lean,ringIsCircle;               // lean: it peers at what it points at; ringIsCircle: the ring is on its door
@property double soft;                          // the wait ends by itself after this many seconds
@property(copy) void (^done)(void);             // runs when the beat ends, any way
@property(copy) NSArray<GTBeat *> *(^then)(void);  // beats to play right after this one (e.g. one walk-through per browser)
@property BOOL thenInserted;                    // they are in already (a line played again does not add them twice)
@property BOOL countdown;                       // the tag shows the session's seconds left (the tour's sample session)
@property NSInteger ticked;                     // check boxes: -1 one choice is ticked, 0 none, 1 all
@property(copy) NSIndexSet *(^tickedSet)(void);  // or exactly these boxes ticked
@property(copy) NSValue *(^hint)(void);         // a slider to drag: chevrons along it show the way (screen rect)
@property double hintDir;                       // 1 right, -1 left
@property BOOL freeKeys;                        // the user may need the arrow keys here (a browser, a text field, System Settings)
@property(copy) NSIndexSet *askKeep;            // answer buttons that do something and keep the question up (Copy)
@property(copy) NSArray *(^shelf)(void);        // a file or folder to drag, in a little window by the bar: @[path, line]
@end
@implementation GTBeat
- (instancetype)init {if((self=[super init])){_scene=-1;_ticked=-1;}return self;}
@end
static GTBeat *Beat(NSString *say,GTFace face) {GTBeat *b=[GTBeat new];b.say=say;b.face=face;return b;}

static double Ease(double k){k=MAX(0,MIN(1,k));return k<.5?4*k*k*k:1-pow(-2*k+2,3)/2;}
static NSColor *Mix(NSColor *a,NSColor *b,double k){a=[a colorUsingColorSpace:NSColorSpace.sRGBColorSpace];b=[b colorUsingColorSpace:NSColorSpace.sRGBColorSpace];k=MAX(0,MIN(1,k));
 return [NSColor colorWithSRGBRed:a.redComponent+(b.redComponent-a.redComponent)*k green:a.greenComponent+(b.greenComponent-a.greenComponent)*k blue:a.blueComponent+(b.blueComponent-a.blueComponent)*k alpha:a.alphaComponent+(b.alphaComponent-a.alphaComponent)*k];}

// The text of a bubble (semibold, like the website's) or of a card under a scene; measured and drawn alike.
// The bubble and its tail as one outline, as on the website: the tail is part of the edge (a small 45° point on the
// side that faces the guide, near its tip), so the line runs on without a seam.
static NSBezierPath *GTBubble(NSRect c,double r,NSPoint aim){
 double x0=NSMinX(c),x1=NSMaxX(c),y0=NSMinY(c),y1=NSMaxY(c),w=8,h=8;NSInteger edge=aim.y<y0-2?0:aim.y>y1+2?1:aim.x<x0?2:aim.x>x1?3:-1;  // 0 bottom, 1 top, 2 left, 3 right
 double bx=MIN(MAX(aim.x,x0+r+w+4),x1-r-w-4),by=MIN(MAX(aim.y,y0+r+w+4),y1-r-w-4);
 NSBezierPath *p=[NSBezierPath bezierPath];[p moveToPoint:NSMakePoint(x0+r,y1)];
 if(edge==1){[p lineToPoint:NSMakePoint(bx-w,y1)];[p lineToPoint:NSMakePoint(bx,y1+h)];[p lineToPoint:NSMakePoint(bx+w,y1)];}
 [p lineToPoint:NSMakePoint(x1-r,y1)];[p appendBezierPathWithArcFromPoint:NSMakePoint(x1,y1) toPoint:NSMakePoint(x1,y1-r) radius:r];
 if(edge==3){[p lineToPoint:NSMakePoint(x1,by+w)];[p lineToPoint:NSMakePoint(x1+h,by)];[p lineToPoint:NSMakePoint(x1,by-w)];}
 [p lineToPoint:NSMakePoint(x1,y0+r)];[p appendBezierPathWithArcFromPoint:NSMakePoint(x1,y0) toPoint:NSMakePoint(x1-r,y0) radius:r];
 if(edge==0){[p lineToPoint:NSMakePoint(bx+w,y0)];[p lineToPoint:NSMakePoint(bx,y0-h)];[p lineToPoint:NSMakePoint(bx-w,y0)];}
 [p lineToPoint:NSMakePoint(x0+r,y0)];[p appendBezierPathWithArcFromPoint:NSMakePoint(x0,y0) toPoint:NSMakePoint(x0,y0+r) radius:r];
 if(edge==2){[p lineToPoint:NSMakePoint(x0,by-w)];[p lineToPoint:NSMakePoint(x0-h,by)];[p lineToPoint:NSMakePoint(x0,by+w)];}
 [p lineToPoint:NSMakePoint(x0,y1-r)];[p appendBezierPathWithArcFromPoint:NSMakePoint(x0,y1) toPoint:NSMakePoint(x0+r,y1) radius:r];
 [p closePath];p.lineJoinStyle=NSLineJoinStyleRound;return p;
}
static NSDictionary *GTTextAttributes(BOOL card){NSMutableParagraphStyle *ps=[NSMutableParagraphStyle new];ps.lineSpacing=1.5;ps.alignment=card?NSTextAlignmentCenter:NSTextAlignmentNatural;
 return @{NSFontAttributeName:card?[NSFont systemFontOfSize:14]:[NSFont systemFontOfSize:14.5 weight:NSFontWeightSemibold],NSParagraphStyleAttributeName:ps};}
// ---- The guide (the cursor from lesspull.com, with its amber Guide tag), its bubble or card, a ring around the real
// thing to click, and the little door it comes through, on a transparent layer over the whole screen.
@interface GuideView : NSView
@property NSPoint pos,pointAt;               // pos: the cursor's tip, view coordinates; pointAt: what it is about (NSZeroPoint: nothing)
@property double size,alpha,clock,cardAlpha,cardTarget,askHeight,lean,peer;
@property double grayK,blushK,leftK,emptyK,grayTarget,blushTarget,leftTarget,emptyTarget;
@property double hopAt,spinAt,wiggleAt,squintAt,dizzyAt,wideAt,pressAt,pokedAt,tiltAt,shiverAt,arriveAt,pace;
@property NSRect ring;@property double ringAlpha,ringTarget;
@property NSRect hint;@property double hintAlpha,hintDir;  // arrows along a slider: drag this way
@property double popAt;                       // a new line: the bubble settles in
@property double talkAt;                      // a new line: the cursor says it (a little bounce, a sway)
@property NSPoint door;@property double doorK;  // the circle in the menu bar as a door: an amber glow around it while open, 0 closed … 1 open
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
- (NSRect)textRect {double h=self.scene?self.card.size.height-14-14-self.scene.frame.size.height-10:self.card.size.height-26;return NSMakeRect(NSMinX(self.card)+14,NSMinY(self.card)+13+self.askHeight,self.card.size.width-28,h-self.askHeight+2);}
- (void)drawRect:(NSRect)dirty {
 double t=self.clock;
 // the ring: around the real thing to click, with a soft ping now and then
 if(self.ringAlpha>.01&&!NSIsEmptyRect(self.ring)){
  NSRect rr=NSInsetRect(self.ring,-5,-5);BOOL round=fabs(rr.size.width-rr.size.height)<14;double pulse=.5+.5*sin(t*5.2);
  NSBezierPath *(^shape)(NSRect)=^NSBezierPath *(NSRect r){double cr=MIN(10,r.size.height/2);return round?[NSBezierPath bezierPathWithOvalInRect:r]:[NSBezierPath bezierPathWithRoundedRect:r xRadius:cr yRadius:cr];};
  // a soft amber wash inside, a glowing ring that breathes, and two pings that travel well beyond it
  [GTAmber(self.ringAlpha*(.10+.08*pulse)) setFill];[shape(rr) fill];
  [NSGraphicsContext saveGraphicsState];NSShadow *glow=[NSShadow new];glow.shadowBlurRadius=10+6*pulse;glow.shadowOffset=NSZeroSize;glow.shadowColor=GTAmber(self.ringAlpha*.9);[glow set];
  NSBezierPath *main=shape(NSInsetRect(rr,-1.5*pulse,-1.5*pulse));main.lineWidth=3.2;[GTAmber(self.ringAlpha) setStroke];[main stroke];[NSGraphicsContext restoreGraphicsState];
  if(!self.still){double reach=round?MAX(30,rr.size.width*1.3):MIN(26,MAX(14,rr.size.height*.75));
   for(int k=0;k<2;k++){double ph=fmod(t/1.3+k*.5,1);NSBezierPath *ping=shape(NSInsetRect(rr,-reach*Ease(ph),-reach*Ease(ph)));ping.lineWidth=3.4*(1-ph)+.6;[GTAmber(self.ringAlpha*.95*pow(1-ph,1.2)) setStroke];[ping stroke];}}
 }
 // drag hints: three chevrons gliding along a slider, the way to drag it
 if(self.hintAlpha>.01&&!NSIsEmptyRect(self.hint)){NSRect h=self.hint;double span=MAX(40,h.size.width-24),y=NSMidY(h)+7;
  for(int i=0;i<3;i++){double k=fmod(t*.55+i/3.0,1),x=self.hintDir>=0?NSMinX(h)+12+span*k:NSMaxX(h)-12-span*k,fadeK=sin(M_PI*k);
   NSBezierPath *c=[NSBezierPath bezierPath];double d=self.hintDir>=0?1:-1;[c moveToPoint:NSMakePoint(x-4*d,y+5)];[c lineToPoint:NSMakePoint(x+2*d,y)];[c lineToPoint:NSMakePoint(x-4*d,y-5)];
   c.lineWidth=4.2;c.lineCapStyle=NSLineCapStyleRound;c.lineJoinStyle=NSLineJoinStyleRound;[[NSColor colorWithWhite:1 alpha:.85*self.hintAlpha*fadeK] setStroke];[c stroke];
   c.lineWidth=2.2;[GTAmber(self.hintAlpha*fadeK) setStroke];[c stroke];}}  // amber on a white edge: it reads on the warm track
 // the little door: a dark circle with an amber ring, like the website's circle in the corner
 if(self.doorK>.01){double k=MIN(1,self.doorK),R=12+3*k;NSRect dr=NSMakeRect(self.door.x-R,self.door.y-R,2*R,2*R);  // the open circle glows; the cursor passes through it
  [NSGraphicsContext saveGraphicsState];NSShadow *gl=[NSShadow new];gl.shadowBlurRadius=10*k;gl.shadowOffset=NSZeroSize;gl.shadowColor=GTAmber(.9*k);[gl set];
  NSBezierPath *o=[NSBezierPath bezierPathWithOvalInRect:dr];o.lineWidth=2.2;[GTAmber(.85*k) setStroke];[o stroke];[NSGraphicsContext restoreGraphicsState];}
 if(self.alpha<=0.01&&(NSIsEmptyRect(self.card)||self.cardAlpha<=0.01))return;  // the last bubble can stay a moment after the guide is home
 NSPoint p=[self drawnTip];
 // the bubble (cream with an amber edge, as on the website) or a card with a scene, with a small tail toward the tip
 if(!NSIsEmptyRect(self.card)&&self.cardAlpha>0.01){
  double a=self.cardAlpha;NSRect c=self.card;BOOL card=self.scene!=nil;
  double pk=MIN(1,MAX(0,(t-self.popAt)/.2)),pop=self.still?1:.965+.035*Ease(pk);  // a new line settles in
  [NSGraphicsContext saveGraphicsState];NSAffineTransform *pt=[NSAffineTransform transform];[pt translateXBy:NSMidX(c) yBy:NSMidY(c)];[pt scaleBy:pop];[pt translateXBy:-NSMidX(c) yBy:-NSMidY(c)];[pt concat];
  NSPoint aimAt=NSMakePoint(p.x+6,p.y-4);NSBezierPath *box=GTBubble(c,14,aimAt);
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh=[NSShadow new];sh.shadowBlurRadius=24;sh.shadowOffset=NSMakeSize(0,-8);sh.shadowColor=[NSColor colorWithWhite:0 alpha:.32*a];[sh set];
  [(card?[NSColor.windowBackgroundColor colorWithAlphaComponent:.98*a]:GTCream(a)) setFill];[box fill];
  [NSGraphicsContext restoreGraphicsState];
  [GTAmber(.95*a) setStroke];box.lineWidth=1.5;[box stroke];
  if(self.text.length){NSMutableDictionary *at=[GTTextAttributes(card) mutableCopy];at[NSForegroundColorAttributeName]=card?[NSColor.labelColor colorWithAlphaComponent:a]:GTInk(a);
   [self.text drawWithRect:[self textRect] options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:at];}
  [NSGraphicsContext restoreGraphicsState];self.scene.alphaValue=a;
 }
 if(self.alpha<=0.01)return;
 // the cursor: a black arrow with a white edge (the website's own), its gestures, and its amber Guide tag
 double u=1.42*self.size;  // points per unit of the website's 24-unit arrow
 double ar=t-self.arriveAt,scale=1;if(ar>=0&&ar<.5){double k=ar/.5;scale=.2+.8*(1+2.6*pow(k-1,3)+1.6*pow(k-1,2));}  // pops in with an overshoot
 double w=t-self.wideAt;if(w>=0&&w<.35)scale*=1+.16*sin(M_PI*w/.35);
 double pr=t-self.pressAt;if(pr>=0&&pr<.22)scale*=.86+.14*(pr/.22);
 double sx=1,sy=1,pk=t-self.pokedAt;if(pk>=0&&pk<.45){double k=pk/.45;if(k<.3){sx=1+.28*k/.3;sy=1-.22*k/.3;}else if(k<.6){double q=(k-.3)/.3;sx=1.28-.4*q;sy=.78+.4*q;}else{double q=(k-.6)/.4;sx=.88+.12*q;sy=1.18-.18*q;}}
 double rot=self.lean+self.peer,wv=t-self.wiggleAt;if(!self.still&&wv>=0&&wv<.95){double k=wv/.95;rot+=-17*M_PI/180*sin(2*M_PI*2.5*k)*(1-k*.6);}  // the website's wave
 double tl=t-self.tiltAt;if(tl>=0&&tl<1.8)rot+=16*M_PI/180*(tl<.25?tl/.25:tl<1.5?1:1-(tl-1.5)/.3);
 double nd=t-self.squintAt;if(nd>=0&&nd<.5)rot-=10*M_PI/180*sin(M_PI*nd/.5);  // a happy nod
 double tk=t-self.talkAt;if(!self.still&&tk>=0&&tk<1.3){double dk=(1-tk/1.3)*(1-tk/1.3);scale*=1+.055*fabs(sin(tk*M_PI*2.7))*dk;rot+=.07*sin(tk*M_PI*1.8)*dk;}  // talking: it bounces as the line comes
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

// ---- The tour bar: seven stations on a line that fills in amber, the station's name and End tour, then the speed and the ← → keys.
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
// A key of the Mac keyboard on the tour bar, ← or →: one line back or on. A click works always; the real key works
// while the guide talks (while you work, your arrow keys stay yours). It shows the press when the real key is used.
@interface GTKeyCap : NSButton
@property(copy) NSString *glyph;
@property double pressedAt;
@property BOOL live;                            // the real key works now (otherwise only the click; it looks quieter)
@property NSTimer *pressTimer;
- (void)flash;
@end
@implementation GTKeyCap
- (BOOL)acceptsFirstMouse:(NSEvent *)e {return YES;}
- (NSSize)intrinsicContentSize {return NSMakeSize(30,24);}
- (void)flash {self.pressedAt=CACurrentMediaTime();[self.pressTimer invalidate];__weak GTKeyCap *weak=self;__block int n=0;
 self.pressTimer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *t){GTKeyCap *k=weak;if(!k||++n>12){[t invalidate];return;}k.needsDisplay=YES;}];[NSRunLoop.mainRunLoop addTimer:self.pressTimer forMode:NSRunLoopCommonModes];}
- (void)drawRect:(NSRect)dirty {
 double k=CACurrentMediaTime()-self.pressedAt,press=k>=0&&k<.35?1-k/.35:0;if(self.isHighlighted)press=1;
 NSRect r=NSInsetRect(self.bounds,1.5,3);r.origin.y+=1.5*(1-press);  // a key stands a little above its shadow; pressed, it goes down
 NSBezierPath *base=[NSBezierPath bezierPathWithRoundedRect:NSOffsetRect(r,0,-1.5*(1-press)) xRadius:5 yRadius:5];[[NSColor colorWithWhite:0 alpha:.2] setFill];[base fill];
 NSBezierPath *key=[NSBezierPath bezierPathWithRoundedRect:r xRadius:5 yRadius:5];[NSColor.windowBackgroundColor setFill];[key fill];[[NSColor.labelColor colorWithAlphaComponent:.16] setFill];[key fill];if(press>0){[GTAmber(.75*press) setFill];[key fill];}[[NSColor colorWithWhite:0 alpha:.18] setStroke];key.lineWidth=.6;[key stroke];
 NSDictionary *a=@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor};NSSize s=[self.glyph sizeWithAttributes:a];
 NSMutableDictionary *ga=[a mutableCopy];if(!self.live&&press<=0)ga[NSForegroundColorAttributeName]=[NSColor.labelColor colorWithAlphaComponent:.45];[self.glyph drawAtPoint:NSMakePoint(NSMidX(r)-s.width/2,NSMidY(r)-s.height/2+.5) withAttributes:ga];
}
@end
// A file or folder to drag somewhere (Opera's extensions page): its icon, its name and a line;
// drag it from here. Copy path puts the path on the clipboard (only when clicked).
@interface GTShelfView : NSView <NSDraggingSource>
@property NSURL *url;@property(copy) NSString *caption;
@end
@implementation GTShelfView
- (BOOL)acceptsFirstMouse:(NSEvent *)e {return YES;}
- (BOOL)isFlipped {return NO;}
- (void)mouseDown:(NSEvent *)e {}
- (void)mouseDragged:(NSEvent *)e {if(!self.url)return;NSImage *icon=[NSWorkspace.sharedWorkspace iconForFile:self.url.path];NSDraggingItem *item=[[NSDraggingItem alloc]initWithPasteboardWriter:self.url];
 [item setDraggingFrame:NSMakeRect(12,NSMidY(self.bounds)-22,44,44) contents:icon];[self beginDraggingSessionWithItems:@[item] event:e source:self];}
- (NSDragOperation)draggingSession:(NSDraggingSession *)s sourceOperationMaskForDraggingContext:(NSDraggingContext)c {return NSDragOperationCopy|NSDragOperationGeneric|NSDragOperationLink;}
- (void)resetCursorRects {[self addCursorRect:NSMakeRect(0,0,NSMaxX(self.bounds)-90,self.bounds.size.height) cursor:NSCursor.openHandCursor];}
- (void)drawRect:(NSRect)dirty {
 if(!self.url)return;NSImage *icon=[NSWorkspace.sharedWorkspace iconForFile:self.url.path];[icon drawInRect:NSMakeRect(12,NSMidY(self.bounds)-22,44,44)];
 [self.url.lastPathComponent drawAtPoint:NSMakePoint(66,NSMidY(self.bounds)+2) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor}];
 [self.caption?:@"" drawAtPoint:NSMakePoint(66,NSMidY(self.bounds)-16) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11],NSForegroundColorAttributeName:NSColor.secondaryLabelColor}];
}
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
 p.opaque=NO;p.backgroundColor=NSColor.clearColor;p.floatingPanel=YES;p.level=level;p.becomesKeyOnlyIfNeeded=YES;p.hidesOnDeactivate=NO;p.releasedWhenClosed=NO;  // floatingPanel first: it would reset the level
 p.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;return p;
}

@interface GuideTour ()
@property NSPanel *overlay;
@property GuideView *view;
@property GTPanel *bar,*askPanel,*pokePanel;
@property GTStepper *stepper;
@property NSTextField *barLabel;
@property NSButton *nextButton,*endButton;@property NSSegmentedControl *paceControl;
@property GTKeyCap *backKey,*forwardKey;           // ← and → (the forward key is also "next" for the guide's aims)
@property BOOL keysLive;                            // the real arrow keys are the tour's right now
@property NSMutableArray<NSNumber *> *shownBeats;   // the lines shown in this stop, in order (for ←)
@property NSInteger askButtons;
@property NSIndexSet *askPreset;
@property(copy) NSString *helperTitle;               // a helper outside the tour (one thing, its own small bar), or nil
@property(copy) NSValue *(^hintBlock)(void);
@property BOOL paused;                               // a click on the guide: it sits down; another click (or ←/→) goes on
@property double pausedAt,lastTap,lastKeysCheck;
@property(copy) NSString *pausedText;
@property GTPanel *shelfPanel;
@property NSInteger menuSeenStep;                    // the menu was opened unasked in this stop (said once)
@property BOOL menuWasOpenSeen,statusMenuSeen;
@property NSArray<NSString *> *stationNames;
@property NSView *askView;
@property NSArray<NSButton *> *askBoxes;
@property(copy) void (^askAnswered)(NSInteger index);
@property NSTimer *frameTimer,*waitTimer,*rampTimer;
@property NSArray<NSArray<GTBeat *> *(^)(void)> *steps;
@property NSArray *cleanups;
@property(nonatomic,readwrite) NSInteger step;
@property NSInteger paceLevel;  // 0 slow, 1 normal, 2 fast
@property NSInteger beatIndex,generation,sceneKind;
@property NSArray<GTBeat *> *beats;
@property NSPoint from,target,stepSpot;
@property double moveStart,moveDuration,anticipation,landedAt,waitStart,lastIconCheck,lastRingCheck,doorTarget,doorVel;
@property NSPoint landDir;
@property BOOL running,waiting,asking,hasStepSpot,iconWasHidden,iconFoundSaid;
@property(copy) NSValue *(^ringBlock)(void);
@property GTBeat *currentBeat;
@property(copy) NSString *jumpTarget,*pickedName;
@property BOOL ringOnCircle,peering,tourPaused,saidWebPriv;
@property(copy) void (^leaveRed)(void);  // stop 2: leaving it while the slider is still in the red puts your warmth back
@property NSInteger slowCount;
@property NSMutableSet<NSString *> *eggs;
@property double lastEggCheck,colleagueAt,hoverSince;
@property(copy) NSValue *(^avoidBlock)(void);  // the real panel to keep clear of (it lasts into the next beats, and counts only while it is on screen)
@property(readonly) NSRect avoidRect;          // where that panel is now (screen coordinates); empty once it has closed
@property NSRect lastMenu;                     // where the status menu was when last open (it drops there again)
@property double lastMenuCheck;
@property BOOL aimFollowsRing;                 // the tip follows the ring (the item to choose)
@property BOOL arriving;                       // the knock and the way out of the door: a station picked meanwhile waits for the end of it
@property NSInteger pendingStation;
@end

@implementation GuideTour
- (instancetype)initWithHost:(id<GuideTourHost>)host {if((self=[super init])){_host=host;_sceneKind=-1;_landedAt=-100;_paceLevel=1;}return self;}
- (NSInteger)stepCount {return self.steps.count;}
- (double)pace {return self.paceLevel==0?1.6:self.paceLevel==2?.7:1;}
- (BOOL)slow {return self.paceLevel==0;}
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
 self.stationNames=@[L(@"The pull"),L(@"Less Pull"),L(@"Apps"),L(@"Websites"),L(@"Peek"),L(@"Sessions & nights"),L(@"Your turn")];
 NSInteger n=self.stationNames.count;double gap=40,w=24+gap*(n-1)+24;
 GTStepper *stepper=[[GTStepper alloc]initWithFrame:NSMakeRect(0,0,w,28)];NSMutableArray *stations=[NSMutableArray new];__weak GuideTour *weak=self;
 for(NSInteger i=0;i<n;i++){GTStation *s=[[GTStation alloc]initWithFrame:NSMakeRect(gap*i,1,26,26)];s.bordered=NO;s.title=@"";s.index=i;s.target=self;s.action=@selector(stationClicked:);s.toolTip=self.stationNames[i];
  s.accessibilityLabel=[NSString stringWithFormat:L(@"Stop %ld: %@"),(long)i+1,self.stationNames[i]];s.hovered=^(NSInteger index,BOOL inside){[weak hoverStation:inside?index:-1];};[stepper addSubview:s];[stations addObject:s];}
 stepper.stations=stations;self.stepper=stepper;[stepper.widthAnchor constraintEqualToConstant:gap*(n-1)+26].active=YES;[stepper.heightAnchor constraintEqualToConstant:28].active=YES;
 self.barLabel=[NSTextField labelWithString:@""];self.barLabel.font=[NSFont systemFontOfSize:12 weight:NSFontWeightMedium];self.barLabel.textColor=NSColor.secondaryLabelColor;self.barLabel.lineBreakMode=NSLineBreakByTruncatingTail;
 [self.barLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
 if(self.helperTitle)self.barLabel.stringValue=self.helperTitle;
 // The speed: three words, the chosen one filled. A Slower button alone did not show whether it was on, least of all in grayscale.
 self.paceControl=[NSSegmentedControl segmentedControlWithLabels:@[L(@"Slow"),L(@"Normal"),L(@"Fast")] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(paceClicked:)];self.paceControl.controlSize=NSControlSizeSmall;self.paceControl.selectedSegment=self.paceLevel;
 self.paceControl.toolTip=L(@"How much time each line gets.");self.paceControl.accessibilityLabel=L(@"Tour speed");
 self.backKey=[GTKeyCap new];self.forwardKey=[GTKeyCap new];
 for(GTKeyCap *k in @[self.backKey,self.forwardKey]){BOOL back=k==self.backKey;k.glyph=back?@"←":@"→";k.bordered=NO;k.title=@"";k.target=self;k.action=back?@selector(backKeyClicked:):@selector(nextClicked:);
  k.toolTip=back?L(@"One line back. The ← key works too while I talk."):L(@"One line on. The → key works too while I talk; while I wait for you, it does the step or skips it.");
  k.accessibilityLabel=back?L(@"One line back"):L(@"One line on");[k.widthAnchor constraintEqualToConstant:30].active=YES;[k.heightAnchor constraintEqualToConstant:24].active=YES;}
 self.nextButton=self.forwardKey;
 NSStackView *keys=[NSStackView stackViewWithViews:@[self.backKey,self.forwardKey]];keys.spacing=2;
 self.endButton=[NSButton buttonWithTitle:L(@"End tour") target:self action:@selector(endClicked:)];self.endButton.controlSize=NSControlSizeSmall;self.endButton.bezelStyle=NSBezelStyleRounded;
 NSView *flex=[NSView new];[flex setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[flex.widthAnchor constraintGreaterThanOrEqualToConstant:8].active=YES;
 NSView *flex2=[NSView new];[flex2 setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
 NSStackView *buttons=[NSStackView stackViewWithViews:@[self.barLabel,flex,self.endButton]];buttons.spacing=6;  // the station's name gets the whole row: "Stop 6 of 7 · Sessions & nights" reads in full
 NSStackView *controls=[NSStackView stackViewWithViews:@[self.paceControl,flex2,keys]];controls.spacing=6;
 if(self.helperTitle){stepper.hidden=YES;self.endButton.title=L(@"Close");}
 NSStackView *column=[NSStackView stackViewWithViews:self.helperTitle?@[buttons,controls]:@[stepper,buttons,controls]];column.orientation=NSUserInterfaceLayoutOrientationVertical;column.alignment=NSLayoutAttributeCenterX;column.spacing=8;column.edgeInsets=NSEdgeInsetsMake(12,14,12,14);
 [buttons.widthAnchor constraintEqualToAnchor:column.widthAnchor constant:-28].active=YES;[controls.widthAnchor constraintEqualToAnchor:column.widthAnchor constant:-28].active=YES;[column.widthAnchor constraintGreaterThanOrEqualToConstant:404].active=YES;
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
 [self hoverStation:-1];self.paceControl.selectedSegment=self.paceLevel;
}
- (void)hoverStation:(NSInteger)i {
 if(self.helperTitle){self.barLabel.stringValue=self.helperTitle;self.barLabel.textColor=NSColor.secondaryLabelColor;return;}
 if(i>=0&&i!=self.step){self.barLabel.stringValue=[NSString stringWithFormat:L(@"Go to %ld · %@"),(long)i+1,self.stationNames[i]];self.barLabel.textColor=GTAmber(1);return;}
 NSInteger s=MAX(0,MIN(self.step,(NSInteger)self.stationNames.count-1));self.barLabel.stringValue=[NSString stringWithFormat:L(@"Stop %ld of %ld · %@"),(long)s+1,(long)self.stationNames.count,self.stationNames[s]];self.barLabel.textColor=NSColor.secondaryLabelColor;
}
- (void)stationClicked:(GTStation *)sender {[self jumpTo:sender.index];}
- (void)paceClicked:(NSSegmentedControl *)sender {[self choosePace:sender.selectedSegment];}
- (void)nextClicked:(id)sender {if(self.paused){[self resume];return;}[self next];}
- (void)backKeyClicked:(id)sender {[self lineBack];}
- (void)arrowKey:(NSInteger)direction {if(getenv("LP_TOUR_DEBUG"))NSLog(@"Less Pull tour test: arrow %ld at beat %ld waiting %d",(long)direction,(long)self.beatIndex,self.waiting);if(!self.running)return;if(self.paused){[self resume];if(direction>0)return;}[(direction<0?self.backKey:self.forwardKey) flash];if(direction<0)[self lineBack];else [self next];}
- (void)endClicked:(id)sender {[self endEarly];}
- (void)closeBar {[self closeBarAt:.2];}
- (void)closeBarAt:(double)fade {GTPanel *p=self.bar;self.bar=nil;if(!p)return;[NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowDidMoveNotification object:p];
 if(self.reduceMotion||fade<=0){[p orderOut:nil];return;}[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=fade;p.animator.alphaValue=0;} completionHandler:^{[p orderOut:nil];}];}

#pragma mark a poke
- (void)placePoke {
 GuideView *v=self.view;NSRect r=NSMakeRect(v.pos.x-3,v.pos.y-52,76,55);r.origin=[self onScreen:r.origin];  // the whole guide: arrow and tag
 NSValue *ring=self.ringBlock?self.ringBlock():nil;NSRect menu=[self.host guideFrame:@"menu"];if(!NSIsEmptyRect(menu)&&NSIntersectsRect(NSInsetRect(menu,-8,-8),r)){if(self.pokePanel.visible)[self.pokePanel orderOut:nil];return;}BOOL resting=self.running&&!v.leaving&&v.alpha>.9&&self.moveDuration<=0&&!self.asking&&!(ring&&NSIntersectsRect(NSInsetRect(ring.rectValue,-8,-8),r));
 if(!resting){if(self.pokePanel.visible)[self.pokePanel orderOut:nil];return;}
 if(!self.pokePanel){self.pokePanel=GTMakePanel(r,NSPopUpMenuWindowLevel+2);GTPokeView *pv=[[GTPokeView alloc]initWithFrame:(NSRect){NSZeroPoint,r.size}];__weak GuideTour *weak=self;pv.poked=^{[weak poked];};self.pokePanel.contentView=pv;}
 if(!NSEqualRects(self.pokePanel.frame,r))[self.pokePanel setFrame:r display:NO];if(!self.pokePanel.visible)[self.pokePanel orderFrontRegardless];
}
- (void)poked {
 if(self.paused){[self resume];return;}
 if(self.currentBeat.pokeSay&&self.waiting){[self interject:self.currentBeat.pokeSay() face:GTFacePoked];return;}
 [self pause];
}

#pragma mark answers in the card
- (void)showAsk:(NSArray<NSString *> *)labels choices:(NSArray<NSString *> *)choices ticked:(NSInteger)ticked answered:(void(^)(NSInteger))done {
 self.askButtons=labels.count;
 NSStackView *row=[NSStackView new];row.spacing=8;
 for(NSUInteger i=0;i<labels.count;i++){NSButton *b=[NSButton buttonWithTitle:labels[i] target:self action:@selector(askClicked:)];b.tag=i;b.bezelStyle=NSBezelStyleRounded;if(i==0){b.bezelColor=GTAmber(1);b.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];}[row addArrangedSubview:b];}
 NSMutableArray *boxes=[NSMutableArray new];for(NSString *c in choices){NSButton *box=[NSButton checkboxWithTitle:c target:nil action:nil];box.state=self.askPreset?[self.askPreset containsIndex:boxes.count]:(ticked>0||(ticked<0&&choices.count==1));[boxes addObject:box];}
 self.askBoxes=boxes;
 if(boxes.count){NSStackView *list=[NSStackView stackViewWithViews:boxes];list.orientation=NSUserInterfaceLayoutOrientationVertical;list.alignment=NSLayoutAttributeLeading;list.spacing=4;
  NSStackView *all=[NSStackView stackViewWithViews:@[list,row]];all.orientation=NSUserInterfaceLayoutOrientationVertical;all.alignment=NSLayoutAttributeLeading;all.spacing=10;self.askView=all;}
 else self.askView=row;
 self.askAnswered=done;self.asking=YES;
}
- (NSArray<NSNumber *> *)tickedBoxes {NSMutableArray *out=[NSMutableArray new];[self.askBoxes enumerateObjectsUsingBlock:^(NSButton *b,NSUInteger i,BOOL *stop){if(b.state==NSControlStateValueOn)[out addObject:@(i)];}];return out;}
- (void)askClicked:(NSButton *)sender {[self answer:sender.tag];}
- (void)answer:(NSInteger)i {if(getenv("LP_TOUR_DEBUG"))NSLog(@"Less Pull tour test: answer %ld asking %d beat %ld",(long)i,self.asking,(long)self.beatIndex);if(!self.asking)return;
 if(i>=0&&[self.currentBeat.askKeep containsIndex:(NSUInteger)i]){if(self.askAnswered)self.askAnswered(i);NSMutableArray *views=[NSMutableArray arrayWithObject:self.askView];
  while(views.count){NSView *v=views.lastObject;[views removeLastObject];[views addObjectsFromArray:v.subviews];if([v isKindOfClass:NSButton.class]&&v.tag==i&&![self.askBoxes containsObject:(NSButton *)v]&&![((NSButton *)v).title hasSuffix:@"✓"])((NSButton *)v).title=[((NSButton *)v).title stringByAppendingString:@" ✓"];}return;}self.asking=NO;void (^d)(NSInteger)=self.askAnswered;self.askAnswered=nil;if(d)d(i);[self hideAsk];}  // a button that acts keeps the question up
- (void)hideAsk {self.askView=nil;self.askBoxes=nil;self.view.askHeight=0;[self.askPanel orderOut:nil];self.askPanel.contentView=nil;}
- (void)placeAsk {
 if(!self.askView){[self.askPanel orderOut:nil];return;}
 NSSize as=self.askView.fittingSize;NSRect c=self.view.card;NSRect f=NSMakeRect(NSMinX(c)+16,NSMinY(c)+12,c.size.width-32,as.height);f.origin=[self onScreen:f.origin];
 if(!self.askPanel){self.askPanel=GTMakePanel(f,NSPopUpMenuWindowLevel+2);self.askPanel.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];}  // the bubble is cream: light controls on it
 NSView *holder=[[NSView alloc]initWithFrame:(NSRect){NSZeroPoint,f.size}];self.askView.frame=NSMakeRect(0,0,as.width,as.height);[holder addSubview:self.askView];
 self.askPanel.contentView=holder;[self.askPanel setFrame:f display:YES];self.askPanel.alphaValue=self.view.cardAlpha;[self.askPanel orderFrontRegardless];
}

#pragma mark start and end
- (void)start {[self startHelper:nil with:nil];}
- (void)startHelper:(NSString *)kind with:(id)argument {
 if(self.running)return;self.running=YES;self.arriving=YES;self.pendingStation=-1;
 if(kind)self.helperTitle=[kind isEqual:@"sunset"]?L(@"Help: Sunset to sunrise"):[NSString stringWithFormat:L(@"Help: %@"),[argument isKindOfClass:NSDictionary.class]?argument[@"name"]:@""];
 NSScreen *s=self.screen;
 self.overlay=[[NSPanel alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.overlay.opaque=NO;self.overlay.backgroundColor=NSColor.clearColor;self.overlay.ignoresMouseEvents=YES;self.overlay.hasShadow=NO;self.overlay.level=NSPopUpMenuWindowLevel+1;  // above the real panels and menus; cards are placed beside them
 self.overlay.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;
 self.view=[[GuideView alloc]initWithFrame:(NSRect){NSZeroPoint,s.frame.size}];self.view.still=self.reduceMotion;self.overlay.contentView=self.view;[self.overlay setFrame:s.frame display:NO];[self.overlay orderFrontRegardless];
 self.overlay.accessibilityLabel=L(@"Less Pull tour");
 if(kind)[self buildHelper:kind with:argument];else [self buildSteps];[self makeBar];
 NSRect settings=kind?NSZeroRect:[self.host guideSettingsFrame];NSImage *look=NSIsEmptyRect(settings)?nil:[self.host guideSettingsSnapshot];
 GuideView *v=self.view;v.alpha=0;v.size=1;v.leaving=YES;
 self.frameTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(frame:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.frameTimer forMode:NSRunLoopCommonModes];
 // The Settings window turns into the tour's small bar; out of the bar's little circle (its home, as the circle in the
 // website's corner) the cursor pops, with a little overshoot, hops down, waves, and the circle closes behind it.
 if(!kind)[self.host guideShowSettings:NO];
 [self morphFrom:settings to:self.bar.frame image:look growing:NO then:^{
  [self revealBar];GuideView *g=self.view;g.door=[self doorPoint];g.doorK=0;g.pos=self.from=self.target=g.door;
  if(self.reduceMotion){g.leaving=NO;g.alpha=1;[self arrived];return;}
  BOOL shown=!NSEqualPoints([self iconPoint],NSZeroPoint);double t=.2;
  if(kind){[self openDoor:YES];[self after:.3 do:^{GuideView *c=self.view;c.alpha=1;c.arriveAt=CACurrentMediaTime();}];  // a helper: no knock; the circle opens and out it comes
   [self after:.6 do:^{NSPoint d=self.view.door;[self moveTo:[self onScreen:NSMakePoint(d.x-30,d.y-62)]];}];[self after:.95 do:^{[self openDoor:NO];}];
   [self after:1.3 do:^{[self face:GTFaceWiggle];self.view.leaving=NO;[self arrived];}];return;}
  if(shown)for(int i=0;i<2;i++){[self after:t do:^{[self.host guideSpotEmpty:YES];}];[self after:t+.14 do:^{[self.host guideSpotEmpty:NO];}];t+=.36;}  // the circle winks twice
  [self after:t+.1 do:^{self.ringBlock=self.circleRing;self.lastRingCheck=0;self.view.ringTarget=.7;[self show:L(@"Knock knock.") scene:-1];}];  // a bubble at the circle, nobody in it yet
  [self after:t+1.25 do:^{[self show:nil scene:-1];self.ringBlock=nil;self.view.ringTarget=0;[self openDoor:YES];}];
  [self after:t+1.55 do:^{GuideView *c=self.view;c.alpha=1;c.arriveAt=CACurrentMediaTime();}];
  [self after:t+1.85 do:^{NSPoint d=self.view.door;[self moveTo:[self onScreen:NSMakePoint(d.x-30,d.y-62)]];}];
  [self after:t+2.15 do:^{[self openDoor:NO];}];
  [self after:t+2.4 do:^{[self face:GTFaceWiggle];self.view.leaving=NO;[self arrived];}];}];
}
- (void)arrived {self.arriving=NO;NSInteger first=self.pendingStation>=0?self.pendingStation:0;self.pendingStation=-1;[self playStep:first];}
- (void)stop {[self finish:NO];}
- (void)finish:(BOOL)completed {
 if(!self.running)return;self.running=NO;self.generation++;
 if(getenv("LP_TOUR_DEBUG"))NSLog(@"Less Pull tour test: finish(%d) from %@",completed,[[NSThread callStackSymbols] subarrayWithRange:NSMakeRange(1,MIN(6,NSThread.callStackSymbols.count-1))]);
 if(self.keysLive){self.keysLive=NO;[self.host guideDo:@"arrowKeys" with:@NO];}
 [self hideShelf];[self runCleanup:self.step];[self hideAsk];[self.askPanel orderOut:nil];[self.pokePanel orderOut:nil];
 [self.frameTimer invalidate];[self.waitTimer invalidate];[self.rampTimer invalidate];self.view.scene=nil;[self.overlay orderOut:nil];self.overlay=nil;
 [self.host guideSpotEmpty:NO];[self.host guideLookGray:-1 warmth:-1];
 // the bar grows back into the Settings window it came from
 NSRect settings=[self.host guideSettingsFrame];GTPanel *bar=self.bar;NSRect from=bar.visible?bar.frame:NSZeroRect;NSImage *look=NSIsEmptyRect(settings)?nil:[self.host guideSettingsSnapshot];
 [self closeBarAt:0];id<GuideTourHost> host=self.host;
 [self morphFrom:from to:settings image:look growing:YES then:^{[host guideShowSettings:YES];[host guideFinished:completed];}];
}
- (void)showShelf:(NSString *)path line:(NSString *)line {
 NSRect bar=[self barFrame];if(NSIsEmptyRect(bar))return;NSRect f=NSMakeRect(NSMinX(bar),NSMinY(bar)-10-64,MAX(330,bar.size.width),64);
 if(!self.shelfPanel){self.shelfPanel=GTMakePanel(f,NSFloatingWindowLevel);self.shelfPanel.hasShadow=YES;NSVisualEffectView *back=[NSVisualEffectView new];back.material=NSVisualEffectMaterialPopover;back.state=NSVisualEffectStateActive;back.wantsLayer=YES;back.layer.cornerRadius=12;back.layer.masksToBounds=YES;self.shelfPanel.contentView=back;}
 NSView *back=self.shelfPanel.contentView;for(NSView *v in back.subviews.copy)[v removeFromSuperview];
 GTShelfView *item=[[GTShelfView alloc]initWithFrame:NSMakeRect(0,0,f.size.width,f.size.height)];item.url=[NSURL fileURLWithPath:path];item.caption=line;item.autoresizingMask=NSViewWidthSizable;[back addSubview:item];
 NSButton *copy=[NSButton buttonWithTitle:L(@"Copy path") target:self action:@selector(shelfCopy:)];copy.controlSize=NSControlSizeSmall;copy.bezelStyle=NSBezelStyleRounded;[copy sizeToFit];copy.frame=NSMakeRect(f.size.width-copy.frame.size.width-12,(f.size.height-copy.frame.size.height)/2,copy.frame.size.width,copy.frame.size.height);copy.identifier=path;[back addSubview:copy];
 [self.shelfPanel setFrame:f display:YES];if(!self.shelfPanel.visible){self.shelfPanel.alphaValue=0;[self.shelfPanel orderFrontRegardless];[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.2;self.shelfPanel.animator.alphaValue=1;} completionHandler:nil];}
}
- (void)shelfCopy:(NSButton *)sender {[self.host guideDo:@"copyText" with:sender.identifier];sender.title=L(@"Copied ✓");[sender sizeToFit];}
- (void)hideShelf {[self.shelfPanel orderOut:nil];}
- (void)runCleanup:(NSInteger)step {if(step>=0&&step<(NSInteger)self.cleanups.count){id c=self.cleanups[step];if(c!=NSNull.null)((void(^)(void))c)();}self.avoidBlock=nil;}
- (void)halt {[self.host guideDo:@"mark" with:nil];[self runCleanup:self.step];self.generation++;[self.waitTimer invalidate];[self.rampTimer invalidate];self.waiting=NO;self.view.forcedDroop=NO;self.asking=NO;self.askAnswered=nil;[self hideAsk];self.ringBlock=nil;self.ringOnCircle=NO;self.view.ringTarget=0;self.view.keys=nil;self.peering=NO;}

#pragma mark controls (the tour bar)
- (void)next {
 if(!self.running||self.arriving)return;  // it is still on its way in
 if(self.asking){[self answer:self.askButtons==1?0:-1];return;}  // a question: → means "not now" (or "done", with the boxes as ticked)
 GTBeat *cur=self.currentBeat;
 if(self.waiting||(cur.until&&!cur.home&&!self.view.leaving)){GTBeat *b=cur;[self.waitTimer invalidate];self.waiting=NO;self.generation++;  // a step for your hands (waiting, or about to): Next does it itself, or goes on without it
  if(b.onNext){b.onNext();[self after:.35 do:^{[self endBeat:b to:b.nextTo];}];return;}  // a moment for the real panel or window to appear before the next line looks for it
  [self endBeat:b to:b.nextTo];return;}
 if(self.view.leaving)return;
 if(self.currentBeat&&!self.currentBeat.home&&self.beatIndex<(NSInteger)self.beats.count-1){self.generation++;[self endBeat:self.currentBeat to:nil];return;}  // only talking: on to the next line
 if(self.step+1>=(NSInteger)self.steps.count){  // Done: it still says goodbye and goes through its door, just without the rest of the station
  NSUInteger h=[self.beats indexOfObjectPassingTest:^BOOL(GTBeat *b,NSUInteger i,BOOL *stop){return b.home;}];
  if(h!=NSNotFound&&(NSInteger)h>self.beatIndex){self.generation++;[self.waitTimer invalidate];self.waiting=NO;self.beatIndex=h;[self playBeat];}
  else [self finish:YES];return;}
 [self playStep:self.step+1];
}
- (void)back {if(self.running&&self.step>0)[self jumpTo:self.step-1];}
- (void)pause {
 if(!self.running||self.paused||self.view.leaving)return;self.paused=YES;self.pausedAt=CACurrentMediaTime();self.pausedText=self.view.text;
 GuideView *v=self.view;[self face:GTFacePoked];v.forcedDroop=YES;v.keys=L(@"Paused");[self show:L(@"Paused. Click me again, or press →, to go on.") scene:-1];
}
// Going on after a pause: the line it was saying comes again, with all its time (nothing moves on behind your back).
- (void)resume {
 if(!self.paused)return;self.paused=NO;self.pausedText=nil;GuideView *v=self.view;v.forcedDroop=NO;[self face:GTFaceHop];
 [self.waitTimer invalidate];[self.rampTimer invalidate];self.waiting=NO;self.generation++;self.asking=NO;self.askAnswered=nil;[self hideAsk];
 if(self.shownBeats.count&&self.shownBeats.lastObject.integerValue>=self.beatIndex)[self.shownBeats removeLastObject];
 self.jumpTarget=self.currentBeat.ident;[self playBeat];
}
// ← : the line before, once more, and the stop goes on from there (a line that only plays after a jump plays too).
// Not past the stop's first line: the stops themselves are on the bar.
- (void)lineBack {
 if(!self.running||self.arriving||self.view.leaving)return;if(self.paused)[self resume];
 NSInteger cur=self.beatIndex,target=-1;for(NSNumber *n in self.shownBeats.reverseObjectEnumerator)if(n.integerValue<cur){target=n.integerValue;break;}
 if(target<0){[self face:GTFaceShiver];[self interject:L(@"That’s the start of this stop. The numbers on the bar go further back.") face:GTFaceNone];return;}
 [self.waitTimer invalidate];[self.rampTimer invalidate];self.waiting=NO;self.generation++;self.asking=NO;self.askAnswered=nil;[self hideAsk];
 self.ringBlock=nil;self.view.ringTarget=0;self.view.keys=nil;self.peering=NO;self.view.forcedDroop=NO;
 while(self.shownBeats.count&&self.shownBeats.lastObject.integerValue>=target)[self.shownBeats removeLastObject];
 self.beatIndex=MAX(0,MIN(target,(NSInteger)self.beats.count-1));self.jumpTarget=self.beats[self.beatIndex].ident;[self playBeat];
}
- (void)jumpTo:(NSInteger)station {
 if(!self.running||station<0||station>=(NSInteger)self.steps.count)return;
 if(self.arriving){self.pendingStation=station;return;}  // first it comes in through its door, then it goes there
 GuideView *v=self.view;v.leaving=NO;  // even on its way home, it comes back out
 BOOL back=station<self.step;[self playStep:station];
 if(back)[self interject:L(@"Once more, then.") face:GTFaceNone];
}
// End tour: at once and in silence. Everything shown and changed goes back, the guide folds into its door within half
// a second; only if something was put back, one small note by the circle.
- (void)endEarly {
 if(!self.running)return;
 [self halt];[self.host guideLookGray:-1 warmth:-1];[self show:nil scene:-1];
 BOOL changed=[self.host guideChangedSomething];[self.host guideKeepChanges:NO];
 [self foldThen:^{
  if(!changed){[self finish:NO];return;}
  GuideView *v=self.view;v.pos=v.door;[self show:L(@"Everything back as it was.") scene:-1];
  [self after:2 do:^{[self show:nil scene:-1];[self after:.35 do:^{[self finish:NO];}];}];} quick:YES];
}
- (NSString *)debugState {
 GuideView *v=self.view;NSRect card=v.card;if(!NSIsEmptyRect(card))card.origin=[self onScreen:card.origin];NSRect ring=v.ring;if(!NSIsEmptyRect(ring))ring.origin=[self onScreen:ring.origin];NSString *t=v.text?:@"";
 return [NSString stringWithFormat:@"step %ld beat %ld tag %@ [%@] tip %@ card %@ a%.2f ring %@ a%.2f hint %@ dir %.0f a%.2f avoid %@ waiting %d bounds %@ keep %@ zone %@ bar %@",(long)self.step+1,(long)self.beatIndex,v.keys?:@"-",[t substringToIndex:MIN(60,t.length)],NSStringFromPoint([self onScreen:v.pos]),NSStringFromRect(card),v.cardAlpha,NSStringFromRect(ring),v.ringAlpha,NSStringFromRect(v.hint),v.hintDir,v.hintAlpha,NSStringFromRect(self.avoidRect),self.waiting,NSStringFromRect([self bounds]),NSStringFromRect([self menuToKeepClear]),NSStringFromRect([self menuZone]),NSStringFromRect([self barFrame])];
}
- (void)debugAnswer:(NSInteger)button {[self answer:button];}
- (void)debugPoke {[self poked];}
- (void)debugTick:(NSInteger)box {if(box>=0&&box<(NSInteger)self.askBoxes.count)self.askBoxes[box].state=NSControlStateValueOn;}
- (void)debugPark {NSValue *p=[self nearBar]();if(!p)return;double t=[self moveTo:p.pointValue];[self after:t*.85 do:^{[self show:L(@"Opera opens the store page. Click Add to Opera, then confirm. I’ll notice.") scene:-1];}];}
- (void)toggleSlow {[self choosePace:self.paceLevel==0?1:0];}  // testing ("slower"): slow, or back to normal
- (void)choosePace:(NSInteger)level {
 level=MAX(0,MIN(2,level));if(level==self.paceLevel){[self updateBar];return;}self.paceLevel=level;self.view.pace=self.pace;[self updateBar];if(level==0)self.slowCount++;
 if(level==0&&self.slowCount==2&&[self egg:@"slower2"])[self interject:L(@"Slower again? No rush; I’m on holiday.") face:GTFaceNone];
 else [self interject:level==0?L(@"Slower it is. Real pixels are heavier; I felt that."):level==2?L(@"Faster, then. I’ll try not to blur."):L(@"Normal speed again.") face:GTFaceNone];
}

#pragma mark Easter eggs (each once; they read only system facts and Less Pull's own state)
- (BOOL)egg:(NSString *)key {if(!self.eggs)self.eggs=[NSMutableSet new];if([self.eggs containsObject:key])return NO;[self.eggs addObject:key];return YES;}
- (void)watchForEggs:(double)now {
 if(now-self.lastEggCheck<.25||!self.running||self.view.leaving)return;self.lastEggCheck=now;
 GuideView *v=self.view;id<GuideTourHost> h=self.host;BOOL resting=self.moveDuration<=0&&v.alpha>.9&&!self.asking&&!self.waiting;
 NSPoint mouse=[self local:NSEvent.mouseLocation];double dm=hypot(mouse.x-v.pos.x,mouse.y-v.pos.y);BOOL onGuide=NSPointInRect(mouse,NSMakeRect(v.pos.x-4,v.pos.y-34,30,38));
 // the user's own pointer comes close while the guide rests: a colleague
 if(resting&&dm<60&&!onGuide){if([self egg:@"colleague"]){self.colleagueAt=now;[self interject:L(@"A colleague! Real pointer, real job. I’m just visiting.") face:GTFaceTilt];}
  else if(self.colleagueAt>0&&now-self.colleagueAt>60&&[self egg:@"colleague2"])[self interject:L(@"Hello again. Two pointers, one screen. Historic.") face:GTFaceWiggle];}
 // resting on the guide for two seconds: "Yes?", once per station
 if(resting&&onGuide){if(self.hoverSince<=0)self.hoverSince=now;else if(now-self.hoverSince>2&&[self egg:[NSString stringWithFormat:@"hover%ld",(long)self.step]])[self interject:L(@"Yes?") face:GTFaceTilt];}else self.hoverSince=0;
 // the menu opened before station 2 asks for it
 if(self.step==0&&[[h guideValue:@"menuOpen"] boolValue]&&[self egg:@"eager"])[self interject:L(@"Eager! I like that. One moment; I’m getting there.") face:GTFaceHop];
 // the ring is on the circle, but the menu bar is hidden (full screen)
 if(self.ringOnCircle&&[[h guideValue:@"menuBarHidden"] boolValue]&&[self egg:[NSString stringWithFormat:@"fullscreen%ld",(long)self.step]])[self interject:L(@"Full screen. Big of you. The menu bar is hiding; the pointer at the top edge brings it back.") face:GTFaceTilt];
}

#pragma mark the frame clock
- (void)frame:(NSTimer *)timer {
 double now=CACurrentMediaTime();GuideView *v=self.view;v.clock=now;
 double leanWant=0;
 if(self.moveDuration>0&&now>=self.moveStart){double k=MIN(1,(now-self.moveStart)/self.moveDuration),e=Ease(k)-(k<.18&&!v.still?.07*sin(M_PI*k/.18):0);NSPoint a=self.from,b=self.target;double dist=hypot(b.x-a.x,b.y-a.y);  // a little wind-up, then off it goes
  double lift=dist<170?MAX(18,dist*.35):MIN(90,dist*.18);  // a short way is a hop, a long one the website's arc
  NSPoint np=NSMakePoint(a.x+(b.x-a.x)*e,a.y+(b.y-a.y)*e+sin(M_PI*e)*lift);double dx=np.x-v.pos.x;
  leanWant=MAX(-.28,MIN(.28,-dx*.03));v.pos=np;  // it leans into the way it goes
  if(k>=1){self.moveDuration=0;self.landedAt=now;self.landDir=dist>1?NSMakePoint((b.x-a.x)/dist,(b.y-a.y)/dist):NSZeroPoint;}}
 else if(self.moveDuration<=0){double l=now-self.landedAt;if(!v.still&&l>=0&&l<.7){double o=MIN(7,4+l*0)*exp(-l*7)*sin(l*17);v.pos=NSMakePoint(self.target.x+self.landDir.x*o,self.target.y+self.landDir.y*o);}}  // a soft overshoot as it lands
 if(!v.still&&self.moveDuration<=0)leanWant+=.035*sin(now*1.25);  // a little sway: alive while it talks
 v.lean+=(leanWant-v.lean)*(v.still?1:.15);
 // peering: it leans a little toward what it points at (the arrow's own direction is up and to the left)
 double peerWant=0;if(self.peering&&self.moveDuration<=0&&!NSEqualPoints(v.pointAt,NSZeroPoint)){double d=remainder(atan2(v.pointAt.y-v.pos.y,v.pointAt.x-v.pos.x)-2.16,2*M_PI);peerWant=MAX(-.36,MIN(.36,d*.42));}
 v.peer+=(peerWant-v.peer)*(v.still?1:.12);
 [self watchForEggs:now];
 if(now-self.lastKeysCheck>.2){self.lastKeysCheck=now;self.backKey.live=self.forwardKey.live=self.keysLive;self.backKey.needsDisplay=self.forwardKey.needsDisplay=YES;  // ← and → are the tour's, except where you may need them yourself (a browser, a field, an open menu)
  BOOL keys=self.running&&!self.arriving&&!v.leaving&&!(self.currentBeat.freeKeys&&!self.asking)&&![[self.host guideValue:@"menuOpen"] boolValue];if(keys!=self.keysLive){self.keysLive=keys;[self.host guideDo:@"arrowKeys" with:@(keys)];}}
 {BOOL menu=[[self.host guideValue:@"menuOpen"] boolValue];if(menu&&!self.statusMenuSeen)self.lastRingCheck=0;self.statusMenuSeen=menu;GTBeat *b=self.currentBeat;BOOL menuBeat=b.mark.length||b.ringIsCircle||b.menuItem.length||self.waiting;
  if(menu&&!self.menuWasOpenSeen&&!menuBeat&&!self.arriving&&self.menuSeenStep!=self.step+1&&self.step>=1){self.menuSeenStep=self.step+1;[self interject:L(@"You opened the menu. Look around; I’ll catch up.") face:GTFaceTilt];}self.menuWasOpenSeen=menu;}
 if(self.hintBlock&&now-self.lastRingCheck<.02){NSValue *h=self.hintBlock();v.hint=h?[self localRect:h.rectValue]:NSZeroRect;}
 v.hintAlpha+=((self.hintBlock&&!NSIsEmptyRect(v.hint)&&!self.paused?1:0)-v.hintAlpha)*.15;
 if(self.waiting&&!self.paused&&self.ringBlock&&self.moveDuration<=0&&now-self.waitStart>2&&now-self.lastTap>3.4){self.lastTap=now;v.pressAt=now;v.tiltAt=now-.2;}  // waiting: now and then a little tap toward the thing to click
 if(self.currentBeat.countdown&&!v.leaving){double left=[[self.host guideValue:@"sessionRemaining"] doubleValue];NSString *k=left>0?[NSString stringWithFormat:@"0:%02ld",(long)ceil(left)]:nil;if(!(k==v.keys||[k isEqual:v.keys]))v.keys=k;}
 // the door: a little spring as it opens and closes
 self.doorVel+=(self.doorTarget-v.doorK)*.22;self.doorVel*=.7;v.doorK=MAX(0,v.doorK+self.doorVel);if(self.doorTarget==0&&v.doorK<.02){v.doorK=0;self.doorVel=0;}
 v.grayK+=(v.grayTarget-v.grayK)*.08;v.blushK+=(v.blushTarget-v.blushK)*.08;v.leftK+=(v.leftTarget-v.leftK)*.08;v.emptyK+=(v.emptyTarget-v.emptyK)*.1;v.cardAlpha+=(v.cardTarget-v.cardAlpha)*(v.still?1:.2);
 // the ring follows the real thing (a panel can move); it fades in and out
 if(self.ringBlock&&now-self.lastRingCheck>(self.statusMenuSeen?.08:.3)){self.lastRingCheck=now;NSValue *r=self.ringBlock();v.ring=r?[self localRect:r.rectValue]:NSZeroRect;if(self.aimFollowsRing&&!NSIsEmptyRect(v.ring))v.pointAt=NSMakePoint(NSMidX(v.ring),NSMidY(v.ring));}
 if(now-self.lastMenuCheck>.2){self.lastMenuCheck=now;[self keepOffMenu];}
 v.ringAlpha+=((self.ringBlock&&!NSIsEmptyRect(v.ring)?v.ringTarget:0)-v.ringAlpha)*.15;
 if(self.askPanel.visible)self.askPanel.alphaValue=v.cardAlpha;
 [self placePoke];
 if(!v.leaving){if(v.alpha<1)v.alpha=MIN(1,v.alpha+.08);if(v.size<1)v.size=MIN(1,v.size+.06);}
 // waiting for you: a sleepy look after a while, and a little shuffle now and then
 if(self.waiting&&!self.paused){double w=now-self.waitStart;v.droop=w>45;if(w>4&&fmod(w,7.5)<1.0/60*1.5)v.wiggleAt=now;}else if(!self.paused)v.droop=NO;  // patient, not sleepy
 // its spot comes out later in the tour (moved during Peek, say): it notices, once
 if(self.iconWasHidden&&!self.iconFoundSaid&&!self.waiting&&!v.leaving&&self.step>=2&&now-self.lastIconCheck>.5){self.lastIconCheck=now;
  if(!NSEqualPoints([self iconPoint],NSZeroPoint)){self.iconFoundSaid=YES;[self interject:L(@"There it is! Thank you. A door I can see: luxury.") face:GTFaceHop];}}
 if(v.cardTarget<=0&&v.cardAlpha<.02&&v.scene){v.scene=nil;self.sceneKind=-1;}
 v.needsDisplay=YES;
}

#pragma mark moving, placing, talking
// A move: the website's arc (a hop for a short way), leaning into it, with a soft overshoot as it lands. Returns the time until it arrives.
- (double)moveTo:(NSPoint)screenPoint {
 NSRect menu=[self.host guideFrame:@"menu"];if(!NSIsEmptyRect(menu)&&NSIntersectsRect([self bodyOnScreenAt:screenPoint],NSInsetRect(menu,-12,-12)))screenPoint=[self spotBeside:menu];  // never onto the open menu
 NSPoint to=[self local:screenPoint];NSRect b=[self bounds];to.x=MIN(MAX(to.x,NSMinX(b)+8),NSMaxX(b)-70);to.y=MIN(MAX(to.y,NSMinY(b)+60),NSMaxY([self localRect:self.screen.frame])-8);
 GuideView *v=self.view;double dist=hypot(to.x-v.pos.x,to.y-v.pos.y);if(dist<2)return 0;
 if(self.reduceMotion){v.pos=self.target=to;self.moveDuration=0;return .2;}
 self.anticipation=0;self.from=v.pos;self.target=to;self.moveStart=CACurrentMediaTime();self.landedAt=-100;
 self.moveDuration=MIN(1.5,.42+dist/1500)*(1+(self.pace-1)*.5);return self.moveDuration;
}
// The menu, open now, or about to be (the step asks for it): bubbles keep clear of it.
- (NSRect)avoidRect {NSValue *a=self.avoidBlock?self.avoidBlock():nil;return a?a.rectValue:NSZeroRect;}
- (NSRect)menuToKeepClear {NSRect m=[self.host guideFrame:@"menu"];if(!NSIsEmptyRect(m))return m;GTBeat *b=self.currentBeat;return b&&(b.ringIsCircle||b.mark.length)&&!self.view.leaving?[self menuZone]:NSZeroRect;}
- (NSRect)bodyOnScreenAt:(NSPoint)p {return NSMakeRect(p.x-4,p.y-54,78,58);}
// The status menu: where it is while open; where it will drop while closed (where it was last time, or under the circle).
- (NSRect)menuZone {
 NSRect m=[self.host guideFrame:@"menu"];if(!NSIsEmptyRect(m)){self.lastMenu=m;return m;}if(!NSIsEmptyRect(self.lastMenu))return self.lastMenu;
 NSRect icon=[self.host guideIconFrame];if(NSIsEmptyRect(icon))return NSZeroRect;NSRect v=self.screen.visibleFrame;
 return NSMakeRect(MIN(NSMinX(icon)-2,NSMaxX(v)-324),NSMinY(icon)-400,320,400);
}
// Beside the menu, on its roomier side, level with its top: the guide's tip, so arrow, tag and bubble stay off it.
- (NSPoint)spotBeside:(NSRect)m {NSRect v=self.screen.visibleFrame;BOOL left=NSMinX(m)-NSMinX(v)>=420||NSMinX(m)-NSMinX(v)>=NSMaxX(v)-NSMaxX(m);return NSMakePoint(left?NSMinX(m)-100:NSMaxX(m)+26,MIN(NSMaxY(m)-34,NSMaxY(v)-44));}
// By the circle, but clear of it and of where its menu drops: a little down and to the side, so a click on the circle
// lands on the circle, and the opening menu finds the guide already beside it.
- (NSPoint)spotByCircle {NSPoint p=[self homePoint];NSRect zone=[self menuZone];double x=p.x-70;if(!NSIsEmptyRect(zone))x=MIN(x,NSMinX(zone)-100);return NSMakePoint(x,p.y-60);}
// While the status menu is open, the guide and its bubble keep off it, whatever the beat: they step to its free side.
- (void)keepOffMenu {
 GuideView *v=self.view;if(!self.running||v.leaving)return;
 NSRect m=[self.host guideFrame:@"menu"];if(NSIsEmptyRect(m))return;self.lastMenu=m;
 NSRect keep=NSInsetRect(m,-12,-12);NSPoint at=self.moveDuration>0?self.target:v.pos;
 if(NSIntersectsRect([self bodyOnScreenAt:[self onScreen:at]],keep))[self moveTo:[self spotBeside:m]];
 if(!v.text.length||v.cardTarget<=0||NSIsEmptyRect(v.card))return;
 NSRect card=v.card;card.origin=[self onScreen:card.origin];if(!NSIntersectsRect(card,keep)&&!NSIntersectsRect([self bodyOnScreenAt:[self onScreen:self.moveDuration>0?self.target:v.pos]],NSInsetRect(card,-4,-4)))return;
 NSRect want=[self placeSize:[self sizeForText:v.text scene:self.sceneKind>=0] near:self.moveDuration>0?self.target:v.pos scene:self.sceneKind>=0];if(!NSEqualRects(want,v.card))[self show:v.text scene:self.sceneKind];  // the bubble too, on the free side
}
- (NSPoint)doorPoint {return [self local:[self homePoint]];}  // the circle in the menu bar is the door
- (void)openDoor:(BOOL)open {self.doorTarget=open?1:0;[self.host guideSpotEmpty:open];}  // the circle shows its empty outline while it is open
// Home through the door: the circle grows into the door, the guide folds in along an arc, the door shrinks, the icon
// winks once. quick (End tour): the same within half a second.
- (void)foldThen:(void(^)(void))done quick:(BOOL)quick {
 [self show:nil scene:-1];self.view.pointAt=NSZeroPoint;GuideView *v=self.view;v.door=[self doorPoint];
 if(self.reduceMotion||v.alpha<.05){v.alpha=0;v.leaving=YES;done();return;}
 double t=[self moveTo:[self onScreen:NSMakePoint(v.door.x+2,v.door.y-16)]];if(quick&&t>0){self.moveDuration=.22;t=.22;}  // up to the circle, then in
 [self after:MAX(0,t-(quick?.2:.3)) do:^{[self openDoor:YES];}];
 [self after:t+(quick?.02:.08) do:^{[self shrinkThen:^{[self openDoor:NO];done();} quick:quick];}];
}
- (void)shrinkThen:(void(^)(void))done quick:(BOOL)quick {
 self.view.leaving=YES;
 if(self.reduceMotion){self.view.alpha=0;done();return;}
 double start=CACurrentMediaTime();NSPoint from=self.view.pos,into=self.view.door;__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/(quick?.24:.42)),e=Ease(k);
  s.view.pos=NSMakePoint(from.x+(into.x-from.x)*e,from.y+(into.y-from.y)*e+sin(M_PI*e)*22);s.target=s.view.pos;s.view.size=1-.8*e;s.view.alpha=1-pow(k,2);  // a little jump, and in
  if(k>=1){[timer invalidate];[s after:quick?.1:.22 do:done];}}];
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
 NSRect b=[self bounds];NSRect hard=[self localRect:self.avoidRect],soft=[self localRect:NSInsetRect([self barFrame],-8,-8)],menu=[self localRect:[self menuToKeepClear]],drop=[self localRect:NSIsEmptyRect(menu)?[self menuZone]:NSZeroRect];double w=size.width,h=size.height;
 NSRect body=NSMakeRect(g.x-4,g.y-54,78,58);
 NSArray *candidates=@[[NSValue valueWithRect:NSMakeRect(g.x-14,g.y+14,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-w+14,g.y+14,w,h)],[NSValue valueWithRect:NSMakeRect(g.x+80,g.y-h/2-18,w,h)],
  [NSValue valueWithRect:NSMakeRect(g.x-w-16,g.y-h/2,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-10,g.y-62-h,w,h)],[NSValue valueWithRect:NSMakeRect(g.x-w+60,g.y-62-h,w,h)]];
 if(getenv("LP_TOUR_DEBUG"))NSLog(@"Less Pull tour test: place %@ near %@ hard %@ menu %@ drop %@ soft %@ in %@",NSStringFromSize(size),NSStringFromPoint(g),NSStringFromRect(hard),NSStringFromRect(menu),NSStringFromRect(drop),NSStringFromRect(soft),NSStringFromRect(b));
 for(int pass=0;pass<2;pass++)for(NSValue *v in candidates){NSRect c=v.rectValue;if(!NSContainsRect(b,c))continue;if(NSIntersectsRect(c,body))continue;if(!NSIsEmptyRect(hard)&&NSIntersectsRect(c,NSInsetRect(hard,-10,-10)))continue;if(!NSIsEmptyRect(menu)&&NSIntersectsRect(c,NSInsetRect(menu,-10,-10)))continue;if(pass==0&&((!NSIsEmptyRect(soft)&&NSIntersectsRect(c,soft))||(!NSIsEmptyRect(drop)&&NSIntersectsRect(c,drop))))continue;return c;}
 NSRect c=[candidates.firstObject rectValue];c.origin.x=MIN(MAX(c.origin.x,NSMinX(b)),NSMaxX(b)-w);c.origin.y=MIN(MAX(c.origin.y,NSMinY(b)),NSMaxY(b)-h);return c;
}
// A spot in free space for the guide and a card of this size: away from the real panel and the tour bar; near where it is.
- (NSValue *)freeSpotFor:(NSSize)size {
 NSRect v=self.screen.visibleFrame,bar=NSInsetRect([self barFrame],-20,-20),avoid=self.avoidRect;NSPoint here=[self onScreen:self.view.pos];
 NSPoint best=NSMakePoint(NSMidX(v),NSMidY(v));double bestScore=-1e9;
 for(double fy=.72;fy>=.3;fy-=.14)for(double fx=.18;fx<=.82;fx+=.16){NSPoint q=NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy);
  NSRect c=[self placeSize:size near:[self local:q] scene:YES];c.origin=[self onScreen:c.origin];
  double score=0;if(!NSIsEmptyRect(bar)&&NSIntersectsRect(c,bar))score-=1000;if(!NSIsEmptyRect(avoid)&&NSIntersectsRect(c,avoid))score-=5000;if(!NSContainsRect(v,c))score-=3000;
  score-=hypot(q.x-here.x,q.y-here.y)*.3;if(score>bestScore){bestScore=score;best=q;}}
 return [NSValue valueWithPoint:best];
}
- (NSValue *)stepFreeSpot {if(!self.hasStepSpot){self.stepSpot=[self freeSpotFor:NSMakeSize(452,232)].pointValue;self.hasStepSpot=YES;}return [NSValue valueWithPoint:self.stepSpot];}
// Measured with the font and spacing it is drawn with, so every line fits (a bubble's text never gets cut off).
- (NSSize)sizeForText:(NSString *)text scene:(BOOL)scene {
 double w=scene?420:300;NSSize ask=self.askView?self.askView.fittingSize:NSZeroSize;
 NSRect t=[text?:@"" boundingRectWithSize:NSMakeSize(w,2000) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:GTTextAttributes(scene)];
 if(scene)return NSMakeSize(452,14+140+10+MAX(20,ceil(t.size.height)+6)+14+(ask.height?ask.height+10:0));
 return NSMakeSize(MAX(MAX(120,ceil(t.size.width)+30),ask.width+28),ceil(t.size.height)+30+(ask.height?ask.height+10:0));
}
- (void)show:(NSString *)text scene:(NSInteger)kind {
 GuideView *v=self.view;
 if(!text.length&&kind<0){v.cardTarget=0;[self.askPanel orderOut:nil];return;}
 BOOL sameScene=kind>=0&&kind==self.sceneKind&&v.scene;
 if(kind<0){v.scene=nil;self.sceneKind=-1;}
 else if(!sameScene){v.scene=[self.host guideScene:kind];self.sceneKind=kind;}
 if(![text isEqual:v.text])v.popAt=CACurrentMediaTime();v.text=text;NSSize size=[self sizeForText:text scene:kind>=0];v.askHeight=self.askView?self.askView.fittingSize.height+10:0;
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
- (double)readingTime:(NSString *)text {if(!text.length)return 0;NSUInteger words=[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].count;return MAX(2.5,words*.33+1.25)*self.pace;}  // about 180 words a minute, plus a breath
- (void)interject:(NSString *)text face:(GTFace)f {
 if(!self.running||self.view.leaving||self.asking)return;NSString *before=self.view.text;NSInteger kind=self.sceneKind,g=self.generation;[self face:f];[self show:text scene:kind];
 [self after:2.4*self.pace do:^{if(g==self.generation&&[self.view.text isEqual:text])[self show:before scene:kind];}];
}
- (void)after:(double)seconds do:(void(^)(void))block {[self after:seconds generation:self.generation do:block];}
// A timer in the common modes (it fires while a menu is open, too); while the guide is paused, it waits.
- (void)after:(double)seconds generation:(NSInteger)g do:(void(^)(void))block {
 __weak GuideTour *weak=self;NSTimer *t=[NSTimer timerWithTimeInterval:MAX(0,seconds) repeats:NO block:^(NSTimer *timer){GuideTour *s=weak;if(!s||g!=s.generation||!s.running)return;if(s.paused){[s after:.2 generation:g do:block];return;}block();}];
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}

#pragma mark the stations
- (void)playStep:(NSInteger)i {
 if(self.paused){self.paused=NO;self.view.forcedDroop=NO;}[self halt];self.hasStepSpot=NO;[self face:GTFacePlain];
 self.step=i;self.beats=self.steps[i]();self.beatIndex=0;self.jumpTarget=nil;self.shownBeats=[NSMutableArray new];[self updateBar];[self playBeat];
}
- (void)noteShown:(NSInteger)i {if(!self.shownBeats)self.shownBeats=[NSMutableArray new];if(self.shownBeats.lastObject.integerValue!=i||!self.shownBeats.count)[self.shownBeats addObject:@(i)];}
- (NSInteger)indexOfBeat:(NSString *)ident {if(!ident)return NSNotFound;return [self.beats indexOfObjectPassingTest:^BOOL(GTBeat *b,NSUInteger i,BOOL *stop){return [b.ident isEqual:ident];}];}
// Where a beat leads: an ident in the station, "next-station", or the next beat.
- (void)goToBeat:(NSString *)ident {if(getenv("LP_TOUR_DEBUG"))NSLog(@"Less Pull tour test: go to %@ (index %ld)",ident,(long)[self indexOfBeat:ident]);
 if([ident isEqual:@"next-station"]){if(self.step+1<(NSInteger)self.steps.count)[self playStep:self.step+1];else [self finish:YES];return;}
 NSInteger i=[self indexOfBeat:ident];if(i==NSNotFound)self.beatIndex++;else {self.beatIndex=i;self.jumpTarget=ident;}[self playBeat];
}
- (void)endBeat:(GTBeat *)b to:(NSString *)ident {
 self.waiting=NO;self.ringBlock=nil;self.ringOnCircle=NO;self.view.ringTarget=0;self.view.keys=nil;self.peering=NO;
 if(b.done)b.done();
 NSArray *more=b.then&&!b.thenInserted?b.then():nil;b.thenInserted=YES;if(more.count){NSMutableArray *all=[self.beats mutableCopy];[all insertObjects:more atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(self.beatIndex+1,more.count)]];self.beats=all;}
 NSString *to=ident?:b.doneTo;if(to){[self goToBeat:to];return;}
 self.beatIndex++;[self playBeat];
}
// A beat: its line, face and place, what it marks; then its reading time, an answer, or a wait for something real
// (nudges counted from the end of the line, the idle lines, the menu closing without the item, what Next does).
- (void)playBeat {
 if(!self.running)return;
 if(self.beatIndex>=(NSInteger)self.beats.count){if(self.step+1<(NSInteger)self.steps.count)[self playStep:self.step+1];else [self finish:YES];return;}
 GTBeat *b=self.beats[self.beatIndex];
 if((b.jumpOnly&&![self.jumpTarget isEqual:b.ident])||(b.onlyIf&&!b.onlyIf())){self.beatIndex++;[self playBeat];return;}
 self.jumpTarget=nil;self.currentBeat=b;
 if(b.run)b.run();
 NSString *say=b.sayBlock?b.sayBlock():b.say;
 if(b.avoid)self.avoidBlock=b.avoid;
 if(b.face!=GTFaceDroop)self.view.forcedDroop=NO;
 [self face:b.face];
 for(NSArray *f in b.faces){GTFace face=[f[1] integerValue];[self after:[f[0] doubleValue]*self.pace do:^{[self face:face];}];}
 for(NSArray *l in b.later)[self after:[l[0] doubleValue]*self.pace do:l[1]];
 if(b.ramp.count==3)[self rampFrom:[b.ramp[0] doubleValue] to:[b.ramp[1] doubleValue] over:[b.ramp[2] doubleValue]];
 GuideView *v=self.view;NSValue *aim=b.pointAt?b.pointAt():nil;v.pointAt=aim?[self local:aim.pointValue]:NSZeroPoint;v.keys=b.keys;self.peering=b.lean;
 self.ringBlock=b.ring;self.ringOnCircle=b.ringIsCircle;self.lastRingCheck=0;v.ringTarget=b.ring?1:0;[self.host guideDo:@"mark" with:b.mark];
 self.hintBlock=b.hint;v.hintDir=b.hintDir?:1;v.hint=NSZeroRect;
 NSArray *shelf=b.shelf?b.shelf():nil;if(shelf.count==2&&[shelf[0] length])[self showShelf:shelf[0] line:shelf[1]];else [self hideShelf];
 self.aimFollowsRing=NO;if(!b.ring&&b.mark.length){self.ringBlock=[self itemRing:b.mark];self.ringOnCircle=YES;v.ringTarget=1;self.aimFollowsRing=YES;}  // the item to choose pulses in the open menu
 if(b.home){NSValue *to=b.to?b.to():nil;double travel=to?[self moveTo:to.pointValue]:0;if(travel>0)[self show:nil scene:-1];  // the last line where it says goodbye, then home
  [self after:travel*.6 do:^{[self show:say scene:-1];}];
  [self after:travel*.6+[self readingTime:say] do:^{[self foldThen:^{
   if(!b.afterSay.length){[self after:.4 do:^{[self finish:YES];}];return;}
   GuideView *g=self.view;g.pos=g.door;[self show:b.afterSay scene:-1];[self after:2.5*self.pace do:^{[self show:nil scene:-1];[self after:.5 do:^{[self finish:YES];}];}];} quick:NO];}];
  return;}
 double travel=0;NSValue *to=b.to?b.to():nil;
 if(!to&&(b.free||(b.scene>=0&&self.sceneKind!=b.scene)))to=[self stepFreeSpot];
 if(to){NSPoint was=v.pos;travel=[self moveTo:to.pointValue];if(travel>0&&hypot(self.target.x-was.x,self.target.y-was.y)>150)[self show:nil scene:-1];}
 void (^advance)(void)=^{[self endBeat:b to:nil];};
 // a question: answer buttons in the bubble; the station goes on with the answer
 if(b.ask.count){
  NSArray *choices=b.choices?b.choices():nil;self.askPreset=nil;
  self.askPreset=b.tickedSet?b.tickedSet():nil;NSInteger idx=self.beatIndex;void (^speak)(void)=^{[self noteShown:idx];self.view.talkAt=CACurrentMediaTime();[self showAsk:b.ask choices:choices ticked:b.ticked answered:^(NSInteger i){NSInteger pick=i<0?(NSInteger)b.ask.count-1:i;NSArray *ticked=i<0?@[]:[self tickedBoxes];if(b.chosen)b.chosen(ticked);if(b.answered)b.answered(pick);[self after:.25 do:advance];}];[self show:say scene:b.scene];};
  if(travel>0)[self after:travel*.6 do:speak];else speak();
  return;}
 NSInteger idx=self.beatIndex;void (^speak)(void)=^{if(say.length){[self noteShown:idx];self.view.talkAt=CACurrentMediaTime();}[self show:say scene:b.scene];if(say.length&&b.pointAt&&b.lean)self.view.pressAt=CACurrentMediaTime()+.35;};  // it says the line (and taps at what it means)
 if(travel>0)[self after:travel*.6 do:speak];else speak();
 double wait=travel*.6+[self readingTime:say]+b.hold*self.pace+(travel>0?.45*self.pace:0);  // it moved while it spoke: a moment more to follow
 if(!b.until){[self after:wait do:advance];return;}
 // waiting for something real
 NSInteger g=self.generation;__weak GuideTour *weak=self;[self.waitTimer invalidate];__block NSUInteger nudged=0;__block BOOL menuWasOpen=NO,said180=NO;double base=[self readingTime:say];id<GuideTourHost> host=self.host;
 [self after:travel*.6+.4 do:^{GuideTour *s=weak;s.waiting=YES;s.waitStart=CACurrentMediaTime();
  s.waitTimer=[NSTimer timerWithTimeInterval:.15 repeats:YES block:^(NSTimer *t){GuideTour *w=weak;if(!w||g!=w.generation||!w.running){[t invalidate];return;}if(w.paused)return;
   if(b.until()){[t invalidate];w.waiting=NO;[w after:.1 do:advance];return;}
   double waited=CACurrentMediaTime()-w.waitStart,since=waited-base;
   if(nudged<b.nudges.count&&since>=[b.nudges[nudged][0] doubleValue]*w.pace){NSArray *n=b.nudges[nudged++];[w face:[n[2] integerValue]];
    if(n.count>3){NSValue *(^na)(void)=n[3];NSValue *p=na();if(p){w.view.pointAt=[w local:p.pointValue];w.aimFollowsRing=NO;}}[w show:n[1] scene:w.sceneKind];
    NSValue *(^was)(void)=w.ringBlock;if(n.count>4){w.ringBlock=n[4];w.lastRingCheck=0;w.view.ringTarget=1;}
    NSString *hint=n[1];if(say.length)[w after:[w readingTime:hint]+1.6*w.pace do:^{if(w.waiting&&w.currentBeat==b&&[w.view.text isEqual:hint]){w.aimFollowsRing=b.mark.length&&!b.ring;if(n.count>4){w.ringBlock=was;w.lastRingCheck=0;w.view.ringTarget=was?1:0;}[w show:say scene:w.sceneKind];}}];}
   // the menu closed without the item it waits for: once more, from the circle
   BOOL open=[[host guideValue:@"menuOpen"] boolValue];if(b.menuItem&&menuWasOpen&&!open&&!b.until()){NSString *chose=[host guideValue:@"lastMenuChoice"];[w face:chose.length?GTFaceTilt:GTFaceNone];
    [w show:chose.length?[NSString stringWithFormat:L(@"That was %@. My dot is on %@: click the circle again."),chose,b.menuItem]:[NSString stringWithFormat:L(@"The menu closed. Click the circle again, then %@."),b.menuItem] scene:-1];}menuWasOpen=open;
   if(!said180&&since>180*w.pace){said180=YES;[w interject:L(@"Three minutes. I’m fine; I have all day.") face:GTFaceNone];}
   if(b.soft>0&&since>b.soft*w.pace){[t invalidate];w.waiting=NO;advance();return;}
   if(b.timeout>0&&since>b.timeout*w.pace){[t invalidate];w.waiting=NO;
    if(b.timeoutSay.length){[w face:GTFacePlain];w.view.pointAt=NSZeroPoint;[w show:b.timeoutSay scene:-1];[w after:[w readingTime:b.timeoutSay] do:^{[w endBeat:b to:b.timeoutTo];}];}else [w endBeat:b to:b.timeoutTo];}}];
  [NSRunLoop.mainRunLoop addTimer:s.waitTimer forMode:NSRunLoopCommonModes];}];
}

#pragma mark small pieces for the script
- (NSValue *(^)(void))frameOf:(NSString *)key {id<GuideTourHost> h=self.host;return ^NSValue *{NSRect r=[h guideFrame:key];return NSIsEmptyRect(r)?nil:[NSValue valueWithRect:r];};}
- (NSValue *(^)(void))midOf:(NSString *)key {id<GuideTourHost> h=self.host;return ^NSValue *{NSRect r=[h guideFrame:key];return NSIsEmptyRect(r)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(r),NSMidY(r))];};}
- (BOOL(^)(void))isOn:(NSString *)key {id<GuideTourHost> h=self.host;return ^BOOL{return [[h guideValue:key] boolValue];};}
- (BOOL(^)(void))isOff:(NSString *)key {id<GuideTourHost> h=self.host;return ^BOOL{return ![[h guideValue:key] boolValue];};}
// The guide's tip just under the menu-bar circle (its door), or under the menu bar's right end while macOS hides it.
- (NSValue *(^)(void))underCircle {__weak GuideTour *weak=self;return ^NSValue *{return [NSValue valueWithPoint:[weak spotByCircle]];};}
// Beside the open menu (or where it will drop).
- (NSValue *(^)(void))menuSide {__weak GuideTour *weak=self;return ^NSValue *{GuideTour *s=weak;NSRect m=[s menuZone];return NSIsEmptyRect(m)?nil:[NSValue valueWithPoint:[s spotBeside:m]];};}
// Beside the menu, level with the item to choose (as on the website): the bubble talks right next to that line.
- (NSValue *(^)(void))besideItem:(NSString *)mark {__weak GuideTour *weak=self;id<GuideTourHost> h=self.host;NSString *key=[@"menu.item." stringByAppendingString:mark];return ^NSValue *{GuideTour *s=weak;NSRect m=[s menuZone];if(NSIsEmptyRect(m))return nil;
 NSPoint p=[s spotBeside:m];NSRect item=[h guideFrame:key];if(!NSIsEmptyRect(item))p.y=MIN(NSMidY(item)+14,NSMaxY(s.screen.visibleFrame)-44);return [NSValue valueWithPoint:p];};}
// Next to the tour bar, out of the way: while the user works in a browser or in System Settings, it waits here.
- (NSValue *(^)(void))nearBar {__weak GuideTour *weak=self;return ^NSValue *{GuideTour *s=weak;NSRect b=[s barFrame];if(NSIsEmptyRect(b))return nil;NSRect v=s.screen.visibleFrame;BOOL right=NSMidX(b)<NSMidX(v);
 return [NSValue valueWithPoint:NSMakePoint(right?NSMaxX(b)+26:NSMinX(b)-100,MIN(NSMaxY(b)-4,NSMaxY(v)-44))];};}
// The item to choose in the menu: its ring while the menu is open, the circle's while it is closed.
- (NSValue *(^)(void))itemRing:(NSString *)mark {id<GuideTourHost> h=self.host;NSValue *(^circle)(void)=[self circleRing];NSString *key=[@"menu.item." stringByAppendingString:mark];
 return ^NSValue *{if(![[h guideValue:@"menuOpen"] boolValue])return circle();NSRect r=[h guideFrame:key];return NSIsEmptyRect(r)?nil:[NSValue valueWithRect:r];};}
- (NSValue *(^)(void))circleAim {__weak GuideTour *weak=self;return ^NSValue *{return [NSValue valueWithPoint:[weak homePoint]];};}
- (NSValue *(^)(void))circleRing {id<GuideTourHost> h=self.host;return ^NSValue *{NSRect r=[h guideFrame:@"icon"];return NSIsEmptyRect(r)?nil:[NSValue valueWithRect:r];};}
// Beside a real window or panel, on its free side, level with its upper part; never over it.
- (NSValue *(^)(void))beside:(NSString *)key {__weak GuideTour *weak=self;id<GuideTourHost> h=self.host;return ^NSValue *{
 NSRect f=[h guideFrame:key];if(NSIsEmptyRect(f))return nil;NSRect v=weak.screen.visibleFrame;BOOL right=NSMaxX(f)+380<NSMaxX(v)||NSMinX(f)-380<NSMinX(v);
 return [NSValue valueWithPoint:NSMakePoint(right?NSMaxX(f)+30:NSMinX(f)-110,MIN(NSMaxY(f)-40,NSMaxY(v)-60))];};}
- (NSValue *(^)(void))at:(double)fx :(double)fy {__weak GuideTour *weak=self;return ^NSValue *{NSRect v=weak.screen.visibleFrame;return [NSValue valueWithPoint:NSMakePoint(NSMinX(v)+v.size.width*fx,NSMinY(v)+v.size.height*fy)];};}
- (void)aimAt:(NSValue *)p {if(p)self.view.pointAt=[self local:p.pointValue];}
- (NSArray *)idleNudges {return @[@[@30,L(@"Take your time. I’m not going anywhere; I only just got here."),@(GTFaceNone)],@[@60,L(@"Or skip it: → on the bar. We go on without it."),@(GTFaceNone),[self barAim:@"next"]]];}
- (NSArray *)circleNudges {return [@[@[@10,L(@"The circle, up in the menu bar. One click opens the menu."),@(GTFaceTilt)]] arrayByAddingObjectsFromArray:[self idleNudges]];}
- (NSArray *)nudge:(double)t say:(NSString *)line {return [@[@[@(t),line,@(GTFaceNone)]] arrayByAddingObjectsFromArray:[self idleNudges]];}
// The tour bar's parts: next (the → key), keys (← and →), end, slower, stations.
- (NSRect)barPart:(NSString *)which {
 if([which isEqual:@"keys"])return NSUnionRect([self screenFrameOf:self.backKey],[self screenFrameOf:self.forwardKey]);
 NSView *v=[which isEqual:@"next"]?self.forwardKey:[which isEqual:@"end"]?self.endButton:[which isEqual:@"slower"]?self.paceControl:self.stepper;return [self screenFrameOf:v];
}
- (NSValue *(^)(void))barAim:(NSString *)which {__weak GuideTour *weak=self;return ^NSValue *{NSRect r=[weak barPart:which];return NSIsEmptyRect(r)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(r),NSMidY(r))];};}
- (NSValue *(^)(void))barRing:(NSString *)which {__weak GuideTour *weak=self;return ^NSValue *{NSRect r=[weak barPart:which];return NSIsEmptyRect(r)?nil:[NSValue valueWithRect:r];};}
- (NSValue *(^)(void))tipOnBar:(NSString *)which {__weak GuideTour *weak=self;return ^NSValue *{GuideTour *s=weak;NSRect r=[which isEqual:@"stations"]?[s screenFrameOf:s.stepper.stations[MIN(3,s.stepper.stations.count-1)]]:[s barPart:which];return NSIsEmptyRect(r)?nil:[NSValue valueWithPoint:NSMakePoint(NSMidX(r)+2,NSMidY(r)-3)];};}
// The shared Settings sub-flow (3.1): the user opens Settings from the menu, then the tab; Next does it for them.
- (NSArray<GTBeat *> *)settingsFlowFor:(NSInteger)tab named:(NSString *)name when:(BOOL(^)(void))when {
 id<GuideTourHost> h=self.host;__weak GuideTour *weak=self;
 GTBeat *a=Beat(L(@"Click the circle, then Settings… at the bottom of the menu. My dot marks it."),GTFacePress);a.to=[self underCircle];a.ringIsCircle=YES;a.mark=@"settings";a.lean=YES;a.menuItem=L(@"Settings…");
 a.onlyIf=^BOOL{return when()&&![[h guideValue:@"settingsVisible"] boolValue];};a.until=[self isOn:@"settingsVisible"];a.nudges=[self circleNudges];a.onNext=^{[h guideDo:@"openSettings" with:nil];};
 GTBeat *b=Beat(nil,GTFacePress);b.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"The %@ tab, at the top of the window."),name];};b.avoid=[self frameOf:@"settings"];b.to=[self beside:@"settings"];
 NSString *tabKey=[NSString stringWithFormat:@"settings.tab.%ld",(long)tab];b.ring=[self frameOf:tabKey];b.pointAt=[self midOf:tabKey];
 b.onlyIf=^BOOL{return when()&&[[h guideValue:@"settingsTab"] integerValue]!=tab;};b.until=^BOOL{return [[h guideValue:@"settingsTab"] integerValue]==tab;};
 b.nudges=@[@[@10,[NSString stringWithFormat:L(@"Up top, the row of tabs: %@."),name],@(GTFaceNone)],@[@30,L(@"Take your time. I’m not going anywhere; I only just got here."),@(GTFaceNone)]];b.onNext=^{[h guideDo:@"selectTab" with:@(tab)];};
 (void)weak;return @[a,b];
}
// One browser's walk-through: its page opens (the store, the companion app for Safari, Mozilla's add-ons page for
// Firefox), the user adds the extension, Less Pull notices. Stop 4 of the tour uses it, and so does the
// helper that comes along from Settings → Websites (where the page is already open: connect NO).
- (NSArray<GTBeat *> *)walkFor:(NSDictionary *)br first:(BOOL)first connect:(BOOL)connect {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;NSValue *(^nearBar)(void)=[self nearBar];BOOL helper=self.helperTitle!=nil;
 NSString *name=br[@"name"],*bid=br[@"id"],*connId=[@"conn-" stringByAppendingString:bid],*laterId=[@"later-" stringByAppendingString:bid],*sideId=[@"side-" stringByAppendingString:bid];BOOL opera=[bid isEqual:@"com.operasoftware.Opera"];
 BOOL (^isConnected)(void)=^BOOL{for(NSDictionary *b in [host guideValue:@"browsers"])if([b[@"id"] isEqual:bid])return [b[@"connected"] boolValue];return NO;};
 __block BOOL opened=!connect;void (^connectOnce)(void)=^{if(!opened){opened=YES;[host guideDo:@"connectBrowser" with:bid];}else [host guideDo:@"openStorePage" with:bid];};  // the first time it connects (on the tour); ← opens the page again
 NSString *askId=[@"ask-" stringByAppendingString:bid],*wait2Id=[@"wait2-" stringByAppendingString:bid],*side2Id=[@"side2-" stringByAppendingString:bid],*side3Id=[@"side3-" stringByAppendingString:bid];
 NSMutableArray *out=[NSMutableArray new];GTBeat *wait;
 NSArray *park=first?@[@[@5,L(@"I’ll wait up by the bar, out of your way. Guest rules."),@(GTFaceNone)]]:@[];  // once, as it parks by the bar
 NSArray *skipNudge=@[@60,L(@"Or skip it: →. The setup waits behind my door: Less Pull’s Settings → Websites."),@(GTFaceNone),[self barAim:@"next"],self.circleRing];
 NSArray *waitNudges=[park arrayByAddingObjectsFromArray:@[@[@20,[NSString stringWithFormat:L(@"No rush. The page is in %@; I’m out here, admiring the real pixels."),name],@(GTFaceNone)],skipNudge]];
 if([bid isEqual:@"com.apple.Safari"]){GTBeat *s1=Beat(L(@"A small companion app opens. Click its button: Open Safari Settings."),GTFacePress);s1.to=nearBar;s1.run=connectOnce;s1.freeKeys=YES;
  s1.until=^BOOL{id f=[host guideValue:@"frontBundle"];return [f isEqual:@"com.apple.Safari"];};s1.timeout=30;s1.timeoutSay=L(@"Safari didn’t open? Open it yourself: Safari, Settings, Extensions.");s1.nextTo=nil;[out addObject:s1];
  wait=Beat(L(@"In Extensions, turn on Less Pull and allow it on all websites. I’ll notice."),GTFaceNone);}
 else if([bid isEqual:@"org.mozilla.firefox"]){wait=Beat(L(@"Firefox opens its add-ons page. Click Add to Firefox, then Add. I’ll notice."),GTFacePress);wait.run=connectOnce;}
 else if(opera){wait=Beat(L(@"Opera opens the store page. Click Add to Opera, then confirm. I’ll notice."),GTFacePress);wait.run=connectOnce;waitNudges=park;}
 else {BOOL chrome=[bid isEqual:@"com.google.Chrome"];wait=Beat([NSString stringWithFormat:chrome?L(@"%@ opens the store page. Click Add to Chrome, then Add extension. I’ll notice."):L(@"%@ opens the store page. Click its Add button, then Add extension. I’ll notice."),name],GTFacePress);wait.run=connectOnce;
  if([bid isEqual:@"com.microsoft.edgemac"])waitNudges=[@[@[@.1,L(@"Edge asks once about extensions from other stores. Say yes to that first."),@(GTFaceNone)]] arrayByAddingObjectsFromArray:waitNudges];}
 wait.to=nearBar;wait.until=isConnected;wait.nudges=waitNudges;wait.timeout=opera?20:150;wait.timeoutTo=opera?askId:laterId;wait.nextTo=opera?askId:laterId;wait.doneTo=connId;wait.freeKeys=YES;[out addObject:wait];
 if(opera){  // after a while: a plain question about Opera's error, and the other way if it is there
  GTBeat *ask=Beat(L(@"Still loading? Or does Opera say “Download error: Installation is not enabled”? Then there’s another way."),GTFaceTilt);ask.ident=askId;ask.jumpOnly=YES;ask.to=nearBar;
  ask.ask=@[L(@"Show me the other way"),L(@"Still trying"),L(@"Skip")];__weak GTBeat *weakAsk=ask;ask.answered=^(NSInteger i){weakAsk.doneTo=i==0?sideId:i==1?wait2Id:laterId;};[out addObject:ask];
  GTBeat *wait2=Beat(L(@"Take your time. I’ll notice when it’s in."),GTFaceNone);wait2.ident=wait2Id;wait2.jumpOnly=YES;wait2.to=nearBar;wait2.until=isConnected;wait2.timeout=25;wait2.timeoutTo=askId;wait2.nextTo=askId;wait2.doneTo=connId;wait2.freeKeys=YES;[out addObject:wait2];}
 GTBeat *ok=Beat([NSString stringWithFormat:helper?L(@"%@ is connected. With a website in front, the menu now offers its exception."):L(@"%@ is connected. That was the hard part; the rest is one slider."),name],GTFaceHop);ok.ident=connId;ok.jumpOnly=YES;ok.faces=@[@[@.7,@(GTFaceWiggle)]];ok.doneTo=[@"end-" stringByAppendingString:bid];[out addObject:ok];
 GTBeat *later=Beat(helper?L(@"Let’s leave it for now. Set up… tries again whenever you like."):L(@"Let’s leave it. The setup waits in Less Pull’s own Settings, the Websites tab. On we go."),GTFaceNone);later.ident=laterId;later.jumpOnly=YES;
 if(!helper){later.ring=self.circleRing;later.ringIsCircle=YES;later.lean=YES;later.pointAt=self.circleAim;}[out addObject:later];
 if(opera){  // Opera's side door: its own extensions page, Developer mode, and the extension folder from Less Pull dropped onto it (the same extension)
  NSValue *(^toggle)(void)=^NSValue *{NSRect w=[host guideFrame:@"window:com.operasoftware.Opera"];return NSIsEmptyRect(w)?nil:[NSValue valueWithPoint:NSMakePoint(NSMaxX(w)-78,NSMaxY(w)-118)];};  // about where the switch is: the top right of the page
  GTBeat *d1=Beat(L(@"First, Opera’s extensions page. Copy its address here, then in Opera: ⌘L, ⌘V, Return."),GTFacePress);d1.ident=sideId;d1.jumpOnly=YES;d1.to=nearBar;d1.freeKeys=YES;
  d1.ask=@[L(@"Copy opera://extensions"),L(@"The page is open")];d1.askKeep=[NSIndexSet indexSetWithIndex:0];d1.answered=^(NSInteger i){if(i==0)[host guideDo:@"copyText" with:@"opera://extensions"];};d1.doneTo=side2Id;[out addObject:d1];
  GTBeat *d2=Beat(L(@"Top right of that page: Developer mode. Switch it on."),GTFacePress);d2.ident=side2Id;d2.jumpOnly=YES;d2.to=^NSValue *{return toggle()?:nearBar();};d2.pointAt=toggle;d2.lean=YES;d2.freeKeys=YES;
  d2.ask=@[L(@"It’s on")];d2.doneTo=side3Id;[out addObject:d2];
  GTBeat *d3=Beat(L(@"Now drag the folder from the little window onto Opera’s extensions page. I’ll notice."),GTFaceNone);d3.ident=side3Id;d3.jumpOnly=YES;d3.to=nearBar;d3.freeKeys=YES;
  d3.shelf=^NSArray *{return @[[host guideValue:@"extensionFolder"]?:@"",L(@"Drag it onto Opera’s extensions page.")];};d3.until=isConnected;
  d3.nudges=@[@[@30,L(@"Hold the folder, drop it anywhere on the extensions page. It loads by itself."),@(GTFaceNone)],skipNudge];d3.timeout=180;d3.timeoutTo=laterId;d3.nextTo=laterId;d3.doneTo=connId;[out addObject:d3];}
 GTBeat *end=Beat(nil,GTFaceNone);end.ident=[@"end-" stringByAppendingString:bid];[out addObject:end];  // where both ways meet
 (void)weak;return out;
}
// Sunset to sunrise in macOS needs the time zone from your location (Date & Time) and Location Services. The night
// offer on the tour uses it, and so does the helper that comes along when Sunset is chosen in Settings without them.
// `after` is where it goes on (the tour: Warmer at night; the helper: home).
- (NSArray<GTBeat *> *)sunsetBeatsWhen:(BOOL(^)(void))when then:(NSString *)after explain:(BOOL)explain {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;NSValue *(^nearBar)(void)=[self nearBar];NSValue *(^setFrame)(void)=[self frameOf:@"settings"];
 BOOL (^needed)(void)=^BOOL{return when()&&![[host guideValue:@"sunsetAvailable"] boolValue];};
 GTBeat *sunhave=Beat(L(@"Sunset works here already. Nothing to do; the seasons take it from here."),GTFaceHop);sunhave.onlyIf=^BOOL{return when()&&[[host guideValue:@"sunsetAvailable"] boolValue];};sunhave.doneTo=after;
 GTBeat *ask=Beat(L(@"Sunset to sunrise needs your location: macOS sets the time zone from it. Shall I show you the switches?"),GTFaceTilt);ask.onlyIf=needed;ask.avoid=setFrame;ask.to=[self beside:@"settings"];
 ask.ask=@[L(@"Yes, show me"),L(@"Not now")];__weak GTBeat *weakAsk=ask;ask.answered=^(NSInteger i){if(i!=0)weakAsk.doneTo=@"night.sunlater";};(void)explain;
 GTBeat *sun2=Beat(L(@"Click Date & Time…, the small button there. System Settings opens at the spot."),GTFacePress);sun2.onlyIf=needed;sun2.avoid=setFrame;sun2.to=[self beside:@"settings"];sun2.ring=[self frameOf:@"settings.dateTime"];sun2.pointAt=[self midOf:@"settings.dateTime"];sun2.lean=YES;
 sun2.until=[self isOn:@"systemSettingsFront"];sun2.nudges=[self nudge:10 say:L(@"The small button under Night schedule: Date & Time…")];sun2.nextTo=@"night.sunlater";
 NSArray *skip=@[@90,L(@"Or leave it: →. Less Pull works it out from your time zone meanwhile."),@(GTFaceNone),[self barAim:@"next"]];
 GTBeat *sun3=Beat(L(@"In Date & Time, turn on “Set time zone automatically using your current location”."),GTFacePress);sun3.onlyIf=needed;sun3.to=nearBar;sun3.freeKeys=YES;
 sun3.until=^BOOL{return [[host guideValue:@"tzAuto"] boolValue]||[[host guideValue:@"sunsetAvailable"] boolValue];};sun3.nudges=@[@[@25,L(@"The switch is in Date & Time, next to the time zone. I’ll wait right here."),@(GTFaceNone)],skip];sun3.nextTo=@"night.sunlater";
 GTBeat *sun4=Beat(L(@"Now Location Services, in Privacy & Security: turn it on at the top. It may ask for your password."),GTFaceNone);sun4.to=nearBar;sun4.freeKeys=YES;
 sun4.onlyIf=^BOOL{return needed()&&![[host guideValue:@"locationServices"] boolValue];};sun4.until=^BOOL{return [[host guideValue:@"locationServices"] boolValue]||[[host guideValue:@"sunsetAvailable"] boolValue];};
 sun4.nudges=@[@[@30,L(@"System Settings, Privacy & Security, Location Services: the switch at the top."),@(GTFaceNone)],skip];sun4.nextTo=@"night.sunlater";
 GTBeat *sun5=Beat(L(@"Last one: at the bottom, System Services, Details…. Turn on Setting time zone."),GTFaceNone);sun5.onlyIf=needed;sun5.to=nearBar;sun5.freeKeys=YES;sun5.until=[self isOn:@"sunsetAvailable"];
 sun5.nudges=@[@[@30,L(@"Still in Location Services: scroll down to System Services, then Details…."),@(GTFaceNone)],skip];
 sun5.timeout=240;sun5.timeoutSay=L(@"Leave it for now. Less Pull works it out from your time zone until then.");sun5.timeoutTo=after;sun5.nextTo=@"night.sunlater";sun5.doneTo=@"night.sunok";
 GTBeat *sunok=Beat(L(@"Sunset’s in. Less Pull noticed by itself; I just stood here looking useful."),GTFaceHop);sunok.ident=@"night.sunok";sunok.jumpOnly=YES;sunok.faces=@[@[@.7,@(GTFaceWiggle)]];sunok.doneTo=after;
 GTBeat *sunlater=Beat(L(@"Leave it for now. Less Pull works it out from your time zone until then."),GTFaceNone);sunlater.ident=@"night.sunlater";sunlater.jumpOnly=YES;sunlater.doneTo=after;
 (void)weak;return @[sunhave,ask,sun2,sun3,sun4,sun5,sunok,sunlater];
}
// Which hello egg, if any: only what tells something (Reduce Motion: it walks; a notch: where its door may be).
- (NSString *)helloEgg {
 id<GuideTourHost> h=self.host;
 if([[h guideValue:@"reduceMotion"] boolValue])return L(@"Reduce Motion is on. Understood: no hopping, no spinning. I’ll walk.");
 if([[h guideValue:@"notch"] boolValue])return L(@"The menu bar has a notch. I keep wanting to look under it.");
 return nil;
}
// A helper outside the tour: the cursor comes out of its door for one thing (a browser's setup from Settings →
// Websites, or Sunset to sunrise in macOS), stays by its bar while you work, and goes home. Nothing to put back.
- (void)buildHelper:(NSString *)kind with:(id)argument {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 GTBeat *home=Beat(L(@"Done. I’ll be in my circle if you need me."),GTFaceNone);home.ident=@"helper.end";home.home=YES;
 NSArray *beats=@[home];
 if([kind isEqual:@"browser"]&&[argument isKindOfClass:NSDictionary.class]){NSDictionary *br=argument;
  GTBeat *hi=Beat([NSString stringWithFormat:L(@"I’ll walk you through %@. It takes a minute."),br[@"name"]?:@""],GTFaceWiggle);hi.to=[self nearBar];
  beats=[[@[hi] arrayByAddingObjectsFromArray:[self walkFor:br first:YES connect:NO]] arrayByAddingObject:home];}
 else if([kind isEqual:@"sunset"]){
  beats=[[self sunsetBeatsWhen:^BOOL{return YES;} then:@"helper.end" explain:NO] arrayByAddingObject:home];}
 self.steps=@[^NSArray *{return beats;}];self.cleanups=@[NSNull.null];(void)weak;(void)host;
}

// ---- The script: TOUR-SCRIPT-v3 by Fable, streamlined after Jiri's second run (12 Oct). The cursor from the website
// visits the real Mac; seven stops, the user does every step, the guide shows where. Lines are data; the engine plays them.
- (void)buildSteps {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 BOOL (^iconShown)(void)=^BOOL{return !NSIsEmptyRect([host guideIconFrame]);};
 NSString *(^str)(NSString *)=^NSString *(NSString *k){id v=[host guideValue:k];return [v isKindOfClass:NSString.class]?v:@"";};
 NSValue *(^here)(void)=^NSValue *{GuideTour *s=weak;return [NSValue valueWithPoint:[s onScreen:s.view.pos]];};
 NSValue *(^menuSide)(void)=[self menuSide];NSValue *(^nearBar)(void)=[self nearBar];
 NSMutableArray *steps=[NSMutableArray new],*cleanups=[NSMutableArray new];


 // 1 The pull: hello, the tour bar and its keys, the promise, and the screen without Less Pull
 [steps addObject:^NSArray *{
  BOOL again=[[host guideValue:@"tours"] integerValue]>1,pausedAtStart=[[host guideValue:@"paused"] boolValue];
  GTBeat *h1=Beat(GTWebsite?L(@"Hi! I’m the cursor from lesspull.com. Normally I live there. Today: a trip."):L(@"Hi! I’m the cursor from the Less Pull website. I live there. Today: a trip."),GTFaceNone);h1.to=weak.underCircle;h1.hold=1;
  GTBeat *h2=Beat(L(@"So this is your Mac. It looks great, by the way."),GTFaceTilt);h2.to=[weak at:.42 :.78];h2.pointAt=[weak at:.85 :.45];h2.hold=.6;h2.later=@[@[@1.8,^{[weak aimAt:[weak at:.15 :.4]()];}]];  // the tip sweeps the screen
  GTBeat *slot=Beat(nil,GTFaceNone);slot.sayBlock=^NSString *{return [weak helloEgg];};slot.onlyIf=^BOOL{return [weak helloEgg].length&&[weak egg:@"hello"];};
  GTBeat *visit=Beat(L(@"Second visit! I’m touched. Same jokes, though; I only packed the one set."),GTFaceWiggle);visit.onlyIf=^BOOL{return again;};
  GTBeat *bar=Beat(L(@"That little bar is the tour: seven stops. Click a number to jump there."),GTFaceNone);bar.to=[weak tipOnBar:@"stations"];bar.ring=[weak barRing:@"stations"];
  GTBeat *keys=Beat(L(@"← and → go one line back or on: here, or on your keyboard. Handy if I’m too quick."),GTFaceNone);keys.to=[weak tipOnBar:@"keys"];keys.ring=[weak barRing:@"keys"];keys.hold=.8;
  GTBeat *end=Beat(L(@"End tour sends me home at once."),GTFaceNone);end.to=[weak tipOnBar:@"end"];end.ring=[weak barRing:@"end"];
  GTBeat *field=Beat(L(@"One promise: this is a playing field. At the end, you pick what stays; the rest goes back."),GTFaceNone);field.free=YES;
  GTBeat *pause=pausedAtStart?Beat(L(@"Paused already? Handy. We start from the pull anyway."),GTFaceTilt):Beat(L(@"First, the pull. Less Pull pauses for a moment: your screen without it."),GTFacePress);pause.to=weak.underCircle;pause.pointAt=weak.circleAim;pause.ring=weak.circleRing;pause.ringIsCircle=YES;
  if(!pausedAtStart)pause.later=@[@[@1.4,^{[host guideDo:@"pause" with:nil];weak.tourPaused=YES;}]];
  GTBeat *p1=Beat(L(@"Full color. Everything on it wants a look. That’s the pull; I feel it too."),GTFaceTilt);p1.free=YES;p1.faces=@[@[@2.4,@(GTFaceShiver)]];p1.pointAt=[weak at:.85 :.35];p1.later=@[@[@1.6,^{[weak aimAt:[weak at:.15 :.2]()];}]];
  return @[h1,h2,slot,visit,bar,keys,end,field,pause,p1];}];
 [cleanups addObject:NSNull.null];

 // 2 Less Pull: the circle (its door), Resume from the menu, and the Extra Warmth slider
 [steps addObject:^NSArray *{
  __block BOOL wasHidden=NO;__block double warmStart=-1,warmLast=-1,warmSince=0;BOOL notch=[[host guideValue:@"notch"] boolValue];
  GTBeat *stage=Beat(nil,GTFaceNone);stage.run=^{if(![[host guideValue:@"paused"] boolValue]){[host guideDo:@"pause" with:nil];weak.tourPaused=YES;}};  // the stop starts paused, as after the pull
  GTBeat *hid=Beat(notch?L(@"Hm. My door is behind the notch. Of all the places."):L(@"Hm. My door is hidden. Your menu bar is full."),GTFaceTilt);hid.to=weak.underCircle;hid.pointAt=weak.circleAim;
  hid.onlyIf=^BOOL{if(iconShown())return NO;wasHidden=YES;weak.iconWasHidden=YES;return YES;};
  hid.later=@[@[@1.1,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x-300,s.view.pos.y+60);}],@[@1.8,^{GuideTour *s=weak;s.view.pointAt=NSMakePoint(s.view.pos.x+300,s.view.pos.y+60);}],@[@2.5,^{[weak aimAt:weak.circleAim()];}]];
  GTBeat *drag=Beat(L(@"Show the hidden icons up there, then hold ⌘ and drag my circle toward the clock. Like this."),GTFacePress);drag.scene=0;drag.to=here;drag.onlyIf=^BOOL{return !iconShown();};
  drag.until=iconShown;drag.timeout=90;drag.timeoutSay=L(@"Let’s carry on. You can come back to this; the tour is under About.");drag.timeoutTo=@"lp.1h";drag.nextTo=@"lp.1h";
  drag.nudges=@[@[@4,L(@"I’d drag it myself, but guest rules: I don’t touch anything here."),@(GTFaceNone)],@[@20,L(@"Room: quit an app whose icon you don’t need, or ⌘-drag a system icon out of the bar."),@(GTFaceNone)],@[@45,L(@"Or leave it for now: → on the bar. I’ll manage without my door."),@(GTFaceNone),[weak barAim:@"next"]]];
  GTBeat *found=Beat(L(@"There it is! Thank you. A door I can see: luxury."),GTFaceSpin);found.to=weak.underCircle;found.pointAt=weak.circleAim;found.faces=@[@[@.9,@(GTFaceHop)]];
  found.onlyIf=^BOOL{if(!(wasHidden&&iconShown()))return NO;weak.iconFoundSaid=YES;return YES;};
  GTBeat *lp1=Beat(L(@"That circle is Less Pull. Also my door: I came in through it."),GTFaceTilt);lp1.to=weak.underCircle;lp1.pointAt=weak.circleAim;lp1.ring=weak.circleRing;lp1.ringIsCircle=YES;lp1.onlyIf=iconShown;
  GTBeat *near=Beat(L(@"Tip: hold ⌘ and drag me next to the clock. There macOS never hides me."),GTFaceTilt);near.onlyIf=^BOOL{return iconShown()&&[[host guideValue:@"iconFarFromClock"] boolValue];};near.scene=0;near.hold=1;near.run=^{[host guideDo:@"iconArrow" with:@YES];};near.done=^{[host guideDo:@"iconArrow" with:@NO];};
  GTBeat *lp1h=Beat(L(@"It’s up there somewhere, hiding. Anyway: that circle is Less Pull, and my door."),GTFaceTilt);lp1h.ident=@"lp.1h";lp1h.to=weak.underCircle;lp1h.onlyIf=^BOOL{return !iconShown();};
  GTBeat *card=Beat(L(@"Your turn: click the circle. The menu drops out of it."),GTFacePress);card.to=here;card.ringIsCircle=YES;card.lean=YES;card.pointAt=weak.circleAim;  // the ring: the circle, then Resume Less Pull the moment the menu opens
  card.mark=@"resume";card.until=[weak isOn:@"menuOpen"];card.nudges=[weak circleNudges];card.onNext=^{[host guideDo:@"resume" with:nil];weak.tourPaused=NO;};card.nextTo=@"lp.skip";
  GTBeat *dot=Beat(L(@"The amber dot is mine: it marks what to pick. Here: Resume Less Pull."),GTFaceNone);dot.mark=@"resume";dot.lean=YES;dot.to=[weak besideItem:@"resume"];dot.menuItem=L(@"Resume Less Pull");
  dot.until=[weak isOff:@"paused"];dot.nudges=[weak idleNudges];dot.onNext=^{[host guideDo:@"resume" with:nil];weak.tourPaused=NO;};dot.nextTo=@"lp.skip";dot.done=^{weak.tourPaused=NO;};
  GTBeat *on=Beat(L(@"There it goes. The color steps back, and the pull with it."),GTFaceNone);on.free=YES;on.onlyIf=[weak isOn:@"gray"];
  GTBeat *onw=Beat(L(@"There it goes. The screen warms up, and the pull eases."),GTFaceNone);onw.free=YES;onw.onlyIf=[weak isOff:@"gray"];
  GTBeat *g3=Beat(L(@"Nothing is gone. It just pulls at you less."),GTFaceNone);
  GTBeat *w1=Beat(L(@"Again, please: click the circle. In the menu, Extra Warmth has a slider."),GTFacePress);w1.to=weak.underCircle;w1.ringIsCircle=YES;
  w1.ring=^NSValue *{return [[host guideValue:@"menuOpen"] boolValue]?[weak frameOf:@"menu.warmth"]():weak.circleRing();};w1.until=[weak isOn:@"menuOpen"];w1.nudges=[weak circleNudges];w1.nextTo=@"lp.rest";
  // Red is a place to visit, not to stay. Whatever way the slider gets there in this stop (let go in the red, → while
  // dragging, a pause halfway and then on to Red), the next line asks to slide it back, chevrons turned around.
  __block double peak=-1,backLast=-1,backSince=0;__block BOOL wentBack=NO,askedRed=NO;
  double (^comfortable)(void)=^double{return warmStart<0?40:warmStart>=85?50:warmStart;};  // where it was before Red (a red start: halfway)
  GTBeat *w2=Beat(L(@"Drag it toward Red. I’ll go with it; watch my tag."),GTFaceNone);w2.lean=YES;w2.to=menuSide;w2.pointAt=[weak midOf:@"menu.warmth"];w2.ring=[weak frameOf:@"menu.warmth"];
  w2.run=^{warmStart=[[host guideValue:@"warmth"] doubleValue];warmLast=warmStart;warmSince=CACurrentMediaTime();askedRed=YES;
   weak.leaveRed=^{if(!wentBack&&[[host guideValue:@"warmth"] doubleValue]>=85)[host guideDo:@"setWarmth" with:@(comfortable())];};};  // leaving the stop still red: your warmth comes back
  __block BOOL saidWay=NO;w2.hint=[weak frameOf:@"menu.warmth"];w2.hintDir=1;
  w2.until=^BOOL{double now=CACurrentMediaTime(),w=[[host guideValue:@"warmth"] doubleValue];if(w!=warmLast){warmLast=w;warmSince=now;}
   if(!saidWay&&w<warmStart-4){saidWay=YES;[weak interject:L(@"Other way: toward Red, to the right. Either works, though.") face:GTFaceTilt];}  // the wrong way: a word, not silence
   BOOL up=!(NSEvent.pressedMouseButtons&1);if(w>=85&&up&&now-warmSince>.6)return YES;  // in the red, and let go
   return w!=warmStart&&up&&now-warmSince>3;};  // or let go somewhere else, for three seconds
  w2.nudges=[weak nudge:10 say:L(@"The slider, next to Extra Warmth. Drag it, any direction.")];w2.nextTo=@"lp.rest";
  __weak GTBeat *weakW2=w2;w2.onNext=^{weakW2.nextTo=[[host guideValue:@"warmth"] doubleValue]>=85?nil:@"lp.rest";};  // → while in the red: on to the way back, not past it
  GTBeat *red=Beat(L(@"Red. Everything’s a sunset, me included. Now slide it back to where it feels right."),GTFaceTilt);red.ident=@"lp.red";red.onlyIf=^BOOL{return [[host guideValue:@"warmth"] doubleValue]>=85;};red.lean=YES;red.to=menuSide;
  red.ringIsCircle=YES;red.ring=^NSValue *{return [[host guideValue:@"menuOpen"] boolValue]?[weak frameOf:@"menu.warmth"]():weak.circleRing();};red.hint=[weak frameOf:@"menu.warmth"];red.hintDir=-1;
  red.pointAt=^NSValue *{return [[host guideValue:@"menuOpen"] boolValue]?[weak midOf:@"menu.warmth"]():weak.circleAim();};
  red.run=^{peak=[[host guideValue:@"warmth"] doubleValue];backLast=peak;backSince=CACurrentMediaTime();};
  red.until=^BOOL{double now=CACurrentMediaTime(),w=[[host guideValue:@"warmth"] doubleValue];if(w!=backLast){backLast=w;backSince=now;}
   if(w<=peak-10&&!(NSEvent.pressedMouseButtons&1)&&now-backSince>.8)wentBack=YES;return wentBack;};  // well below the red, and let go
  red.nudges=[weak nudge:10 say:L(@"To the left, until it feels right. The slider is in the menu, under the circle.")];
  red.onNext=^{[host guideDo:@"setWarmth" with:@(comfortable())];wentBack=YES;};  // → does it itself: the warmth from before Red
  GTBeat *mine=Beat(L(@"There. That warmth is yours."),GTFaceHop);mine.onlyIf=^BOOL{return wentBack;};
  GTBeat *off=Beat(L(@"All the way to Off. Fine too; Red is at the far right."),GTFaceTilt);off.onlyIf=^BOOL{return !wentBack&&[[host guideValue:@"warmth"] doubleValue]<12;};off.hint=[weak frameOf:@"menu.warmth"];off.hintDir=1;off.ring=[weak frameOf:@"menu.warmth"];
  GTBeat *some=Beat(L(@"A touch of amber. Far right is Red; far left is Off. Your call."),GTFaceNone);some.onlyIf=^BOOL{double w=[[host guideValue:@"warmth"] doubleValue];return !wentBack&&w>=12&&w<85;};
  GTBeat *late=Beat(nil,GTFaceNone);late.onlyIf=^BOOL{return askedRed&&!wentBack&&[[host guideValue:@"warmth"] doubleValue]>=85;};late.until=^BOOL{return YES;};late.doneTo=@"lp.red";  // on to Red after all: the way back too
  GTBeat *skip=Beat(L(@"I’ll ask Less Pull to resume, then. Quietly."),GTFaceNone);skip.ident=@"lp.skip";skip.jumpOnly=YES;skip.run=^{[host guideDo:@"resume" with:nil];weak.tourPaused=NO;};
  GTBeat *rest=Beat(L(@"Everything else lives in this menu too: pausing, Night Shift, Settings…"),GTFaceNone);rest.ident=@"lp.rest";rest.lean=YES;
  rest.pointAt=^NSValue *{return [[host guideValue:@"menuOpen"] boolValue]?[weak midOf:@"menu.night"]():weak.circleAim();};
  return @[stage,hid,drag,found,lp1,near,lp1h,card,dot,on,onw,g3,w1,w2,red,mine,off,some,late,skip,rest];}];
 [cleanups addObject:^{[host guideDo:@"iconArrow" with:@NO];if(weak.tourPaused){[host guideDo:@"resume" with:nil];weak.tourPaused=NO;}void (^back)(void)=weak.leaveRed;weak.leaveRed=nil;if(back)back();}];

 // 3 Apps: an exception for the app in front, made by the user, right from the menu
 [steps addObject:^NSArray *{
  __block NSString *picked=nil;
  GTBeat *e1=Beat(L(@"Some apps need their color. Photos, say. An exception lets one app keep it."),GTFaceNone);e1.to=weak.underCircle;e1.ringIsCircle=YES;e1.mark=@"app-exception";
  GTBeat *spot=Beat(L(@"Bring that app to the front, then click the circle. The menu offers it."),GTFacePress);spot.to=weak.underCircle;spot.ring=weak.circleRing;spot.ringIsCircle=YES;spot.lean=YES;spot.pointAt=weak.circleAim;
  spot.mark=@"app-exception";spot.until=^BOOL{return [[host guideValue:@"menuOpen"] boolValue]||[[host guideValue:@"exceptionPanel"] boolValue];};spot.nudges=[weak circleNudges];
  spot.onNext=^{[host guideDo:@"openExceptionPanel" with:nil];};spot.nextTo=@"exc.2";spot.done=^{weak.pickedName=str(@"frontApp");};
  GTBeat *dot=Beat(nil,GTFaceNone);dot.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"My dot is on Exception for %@… Choose it."),str(@"frontApp")];};dot.mark=@"app-exception";dot.lean=YES;dot.to=[weak besideItem:@"app-exception"];
  dot.run=^{weak.currentBeat.menuItem=[NSString stringWithFormat:L(@"Exception for %@…"),str(@"frontApp")];};dot.until=[weak isOn:@"exceptionPanel"];dot.nudges=[weak idleNudges];dot.onNext=^{[host guideDo:@"openExceptionPanel" with:nil];};
  GTBeat *ex2=Beat(nil,GTFaceNone);ex2.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"The real panel, for %@. Change one thing; the rest carries over."),weak.pickedName.length?weak.pickedName:str(@"frontApp")];};
  ex2.ident=@"exc.2";ex2.avoid=[weak frameOf:@"panel"];ex2.to=[weak beside:@"panel"];ex2.pointAt=[weak midOf:@"panel"];
  GTBeat *off=Beat(L(@"Find Grayscale and click Off. That’s color, for this app only."),GTFacePress);off.avoid=[weak frameOf:@"panel"];off.ring=[weak frameOf:@"panel.gray.off"];off.pointAt=[weak midOf:@"panel.gray.off"];off.lean=YES;
  off.until=[weak isOn:@"appException"];off.nudges=[weak nudge:10 say:L(@"The Grayscale row, inside the panel: three choices. Click Off.")];off.onNext=^{[host guideDo:@"closeExceptionPanel" with:nil];};off.nextTo=@"next-station";
  GTBeat *other=Beat(nil,GTFaceTilt);other.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"That works too. Anything in here is only for %@."),str(@"frontApp")];};other.onlyIf=[weak isOff:@"appGrayOff"];
  GTBeat *color=Beat(nil,GTFaceHop);color.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"There. %@ in color, for as long as it’s in front."),str(@"frontApp")];};color.onlyIf=[weak isOn:@"appGrayOff"];
  GTBeat *sw=Beat(L(@"Now click another app, or the desktop: it goes quiet again."),GTFaceNone);sw.run=^{picked=str(@"frontBundle");};
  sw.until=^BOOL{return ![str(@"frontBundle") isEqual:picked];};sw.nudges=[weak nudge:10 say:L(@"Any other app will do. Or click the desktop.")];
  GTBeat *quiet=Beat(nil,GTFaceNone);quiet.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Quiet again. The exception stays with %@, waiting. Like me, but with a purpose."),weak.pickedName?:@""];};
  return @[e1,spot,dot,ex2,off,other,color,sw,quiet];}];
 [cleanups addObject:^{[host guideDo:@"closeExceptionPanel" with:nil];}];

 // 4 Websites: connect a browser (an offer), then an exception for a website
 [steps addObject:^NSArray *{
  NSArray *browsers=[host guideValue:@"browsers"]?:@[];NSDictionary *connected=nil;for(NSDictionary *b in browsers)if([b[@"connected"] boolValue]){connected=b;break;}
  __block BOOL siteFlow=NO;__block NSArray *chosen=@[];NSString *(^connectedName)(void)=^NSString *{for(NSDictionary *b in [host guideValue:@"browsers"])if([b[@"connected"] boolValue])return b[@"name"];return @"";};
  BOOL (^anyConnected)(void)=^BOOL{return [[host guideValue:@"browserConnected"] boolValue];};
  NSArray *(^walkAll)(void)=^NSArray *{NSMutableArray *all=[NSMutableArray new];for(NSDictionary *b in chosen)[all addObjectsFromArray:[weak walkFor:b first:b==chosen.firstObject connect:YES]];return all;};
  GTBeat *have=Beat([NSString stringWithFormat:L(@"%@ is already connected. Good: websites get exceptions too."),connected[@"name"]?:@""],GTFaceNone);have.free=YES;have.onlyIf=^BOOL{return connected!=nil;};
  GTBeat *offer=Beat(browsers.count==1?[NSString stringWithFormat:L(@"Exceptions for websites need %@ connected: a small extension. Connect it now? Optional."),browsers.firstObject[@"name"]]:L(@"Exceptions for websites need your browser connected: a small extension. Connect it now? Optional."),GTFaceTilt);
  offer.free=YES;offer.onlyIf=^BOOL{return !connected&&browsers.count>0;};offer.ask=@[L(@"Connect"),L(@"Not now")];
  __weak GTBeat *weakOffer=offer;offer.answered=^(NSInteger i){if(i!=0){weakOffer.doneTo=@"web.no";return;}if(browsers.count==1){chosen=browsers;weakOffer.doneTo=@"walk";}};
  GTBeat *pick=Beat(L(@"Which ones? One or several; each gets the same small extension."),GTFaceNone);pick.onlyIf=^BOOL{return !connected&&browsers.count>1;};pick.ask=@[L(@"Connect"),L(@"Not now")];
  pick.choices=^NSArray *{NSMutableArray *names=[NSMutableArray new];for(NSDictionary *b in browsers)[names addObject:b[@"name"]];return names;};
  __weak GTBeat *weakPick=pick;pick.chosen=^(NSArray<NSNumber *> *ticked){NSMutableArray *c=[NSMutableArray new];for(NSNumber *n in ticked)[c addObject:browsers[n.integerValue]];chosen=c;};
  pick.answered=^(NSInteger i){if(i!=0||!chosen.count)weakPick.doneTo=@"web.no";};
  GTBeat *walkHere=Beat(nil,GTFaceNone);walkHere.ident=@"walk";walkHere.then=walkAll;  // the chosen browsers, one after another
  GTBeat *more=Beat(L(@"That’s enough for now. More browsers: Less Pull’s Settings → Websites. I’ll come and help."),GTFaceNone);more.ring=weak.circleRing;more.ringIsCircle=YES;more.lean=YES;more.pointAt=weak.circleAim;
  more.onlyIf=^BOOL{if(!chosen.count||!anyConnected())return NO;NSInteger open=0;for(NSDictionary *b in [host guideValue:@"browsers"])if(![b[@"connected"] boolValue])open++;return open>0;};
  GTBeat *open=Beat(nil,GTFaceNone);open.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Open any website in %@ and bring it to the front."),connectedName()];};open.to=nearBar;
  open.onlyIf=anyConnected;open.freeKeys=YES;open.until=^BOOL{return str(@"site").length>0;};open.nudges=[weak nudge:10 say:L(@"Any page at all; the first tab you have is fine.")];open.nextTo=@"web.skip";open.done=^{siteFlow=str(@"site").length>0;};
  GTBeat *skip=Beat(L(@"Another time, then. With a website in front, the menu offers it."),GTFaceNone);skip.ident=@"web.skip";skip.jumpOnly=YES;skip.doneTo=@"next-station";
  GTBeat *spot=Beat(L(@"Click the circle. The menu has a new line now."),GTFacePress);spot.onlyIf=^BOOL{return siteFlow;};spot.to=weak.underCircle;spot.ring=weak.circleRing;spot.ringIsCircle=YES;spot.lean=YES;spot.pointAt=weak.circleAim;
  spot.mark=@"site-exception";spot.until=^BOOL{return [[host guideValue:@"menuOpen"] boolValue]||[[host guideValue:@"exceptionPanel"] boolValue];};spot.nudges=[weak circleNudges];spot.onNext=^{[host guideDo:@"openSitePanel" with:nil];};spot.nextTo=@"web.panel";
  GTBeat *dot=Beat(nil,GTFaceNone);dot.onlyIf=^BOOL{return siteFlow;};dot.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"My dot: Exception for %@… Choose it."),str(@"site")];};dot.mark=@"site-exception";dot.lean=YES;dot.to=[weak besideItem:@"site-exception"];
  dot.until=[weak isOn:@"exceptionPanel"];dot.nudges=[weak idleNudges];dot.onNext=^{[host guideDo:@"openSitePanel" with:nil];};dot.run=^{weak.currentBeat.menuItem=[NSString stringWithFormat:L(@"Exception for %@…"),str(@"site")];};
  GTBeat *panel=Beat(L(@"Same panel, for a website. Whole domain, or This exact page: your call."),GTFaceNone);panel.ident=@"web.panel";panel.onlyIf=^BOOL{return siteFlow;};panel.avoid=[weak frameOf:@"panel"];panel.to=[weak beside:@"panel"];panel.pointAt=[weak midOf:@"panel.scope"];
  GTBeat *slider=Beat(L(@"Give it some Extra Warmth: drag the slider. Only this site gets it."),GTFacePress);slider.onlyIf=^BOOL{return siteFlow;};slider.avoid=[weak frameOf:@"panel"];slider.ring=[weak frameOf:@"panel.warmth"];slider.hint=[weak frameOf:@"panel.warmth"];slider.hintDir=1;slider.pointAt=[weak midOf:@"panel.warmth"];slider.lean=YES;
  slider.until=^BOOL{return [[host guideValue:@"siteException"] boolValue]&&!(NSEvent.pressedMouseButtons&1);};slider.nudges=[weak nudge:10 say:L(@"The Extra Warmth slider, inside the panel. Drag it a little.")];slider.nextTo=@"web.priv";  // done once made and the slider is let go
  GTBeat *warm=Beat(nil,GTFaceTilt);warm.onlyIf=^BOOL{return siteFlow;};warm.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Warmer, just for %@. Every other site stays as it was."),str(@"site")];};
  GTBeat *priv=Beat(L(@"Only the address goes to Less Pull, never the page. Private tabs: not even that."),GTFaceNone);priv.ident=@"web.priv";priv.onlyIf=^BOOL{return siteFlow;};priv.run=^{weak.saidWebPriv=YES;};priv.doneTo=@"next-station";
  GTBeat *no=Beat(L(@"No problem. Websites wait in Less Pull’s own Settings, the Websites tab, whenever you like."),GTFaceNone);no.ident=@"web.no";no.jumpOnly=YES;no.doneTo=@"next-station";no.ring=weak.circleRing;no.ringIsCircle=YES;no.lean=YES;no.pointAt=weak.circleAim;
  return @[have,offer,pick,walkHere,more,open,skip,spot,dot,panel,slider,warm,priv,no];}];
 [cleanups addObject:^{[host guideDo:@"closeExceptionPanel" with:nil];}];

 // 5 Peek: a shortcut if there is none (an offer), then hands-on
 [steps addObject:^NSArray *{
  __block NSString *label=str(@"peekShortcut");__block BOOL seen=NO,yes=NO;__block double heldSince=-1;
  GTBeat *offer=Beat(L(@"Peek has no shortcut yet. Want one? Less Pull can suggest keys nobody uses."),GTFaceTilt);offer.free=YES;offer.onlyIf=^BOOL{return label.length==0;};offer.ask=@[L(@"Set one up"),L(@"Not now")];
  __weak GTBeat *weakOffer=offer;offer.answered=^(NSInteger i){if(i==0)yes=YES;else weakOffer.doneTo=@"peek.none2";};
  NSArray *flow=[weak settingsFlowFor:1 named:L(@"Shortcuts") when:^BOOL{return yes;}];
  GTBeat *set1=Beat(L(@"Peek in color shortcut: click Suggest, or click the field and press your keys."),GTFacePress);set1.onlyIf=^BOOL{return yes;};set1.avoid=[weak frameOf:@"settings"];set1.to=[weak beside:@"settings"];
  set1.ring=[weak frameOf:@"settings.suggest"];set1.pointAt=[weak midOf:@"settings.suggest"];set1.until=^BOOL{return str(@"peekShortcut").length>0;};
  set1.nudges=@[@[@20,L(@"Suggest picks keys no macOS shortcut uses. One click, and they’re yours."),@(GTFaceNone)],@[@60,L(@"Or skip it: → on the bar. We go on without it."),@(GTFaceNone),[weak barAim:@"next"]]];
  set1.timeout=120;set1.timeoutSay=L(@"No problem. Peek waits under Settings → Shortcuts. Moving on.");set1.timeoutTo=@"next-station";set1.nextTo=@"next-station";
  set1.done=^{label=str(@"peekShortcut");};
  GTBeat *setok=Beat(nil,GTFaceHop);setok.onlyIf=^BOOL{return yes&&label.length;};setok.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"%@. Yours now. Let’s try it."),label];};setok.run=^{weak.currentBeat.keys=label;weak.view.keys=label;};
  GTBeat *none2=Beat(L(@"Whenever you like: Settings → Shortcuts. Moving on."),GTFaceNone);none2.ident=@"peek.none2";none2.jumpOnly=YES;none2.doneTo=@"next-station";none2.ring=weak.circleRing;none2.ringIsCircle=YES;
  GTBeat *p1=Beat(L(@"Sometimes you need color for a second. A chart, a photo, the red button."),GTFaceNone);p1.free=YES;p1.onlyIf=^BOOL{return label.length>0;};
  GTBeat *p2=Beat(nil,GTFaceNone);p2.scene=6;p2.onlyIf=^BOOL{return label.length>0;};p2.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Your turn: hold %@ together, and keep holding."),label];};p2.run=^{weak.currentBeat.keys=label;weak.view.keys=label;};
  p2.pokeSay=^NSString *{return [NSString stringWithFormat:L(@"Clicking me doesn’t peek. Hold %@; I’ll wait."),label];};
  p2.until=^BOOL{BOOL p=[host guidePeeking];double now=CACurrentMediaTime();
   if(p){if(heldSince<0)heldSince=now;if(now-heldSince>=.45||[host guidePeekKept]){seen=YES;return YES;}return NO;}
   if(heldSince>=0&&now-heldSince<.45){GuideTour *s=weak;NSString *tap=[NSString stringWithFormat:L(@"Hold, don’t tap: %@. Take your time."),label];[s after:.5 do:^{if(s.waiting&&![host guidePeeking]){[s face:GTFaceNone];[s show:tap scene:-1];}}];}  // a tap, not a hold
   heldSince=-1;return NO;};
  p2.nudges=@[@[@8,[NSString stringWithFormat:L(@"Hold, don’t tap: %@. Take your time."),label],@(GTFaceNone)],@[@20,L(@"No hurry. Cursors wait for a living."),@(GTFaceNone)]];
  p2.timeout=45;p2.timeoutSay=L(@"No problem. Peek waits under Settings → Shortcuts. Moving on.");p2.timeoutTo=@"next-station";p2.nextTo=@"next-station";
  GTBeat *p3=Beat(L(@"There! Color, for exactly as long as you hold it."),GTFaceHop);p3.onlyIf=^BOOL{return seen&&![host guidePeekKept];};p3.until=^BOOL{return ![host guidePeeking]||[host guidePeekKept];};p3.timeout=40;
  __block BOOL keptOnce=NO;
  GTBeat *twice=Beat(nil,GTFacePress);twice.scene=7;twice.onlyIf=^BOOL{return seen&&![host guidePeekKept];};twice.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Now press %@ twice, quickly. The color stays."),label];};
  twice.run=^{weak.currentBeat.keys=label;weak.view.keys=label;};twice.until=^BOOL{if([host guidePeekKept])keptOnce=YES;return keptOnce;};
  twice.nudges=@[@[@8,L(@"Twice in a row, like a double-click."),@(GTFaceNone)],@[@25,L(@"Or skip it: → on the bar. We go on without it."),@(GTFaceNone),[weak barAim:@"next"]]];twice.timeout=40;twice.timeoutTo=@"peek.end";twice.nextTo=@"peek.end";
  GTBeat *kept=Beat(nil,GTFaceHop);kept.scene=7;kept.onlyIf=^BOOL{return [host guidePeekKept];};kept.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Kept! Press %@ once more and it’s quiet again."),label];};
  kept.run=^{weak.currentBeat.keys=label;weak.view.keys=label;};kept.until=^BOOL{return ![host guidePeekKept]&&![host guidePeeking];};kept.timeout=40;kept.timeoutTo=@"peek.end";kept.nextTo=@"peek.end";
  GTBeat *p4=Beat(L(@"And quiet again. That’s Peek: color when you want it, gone when you let go."),GTFaceNone);p4.ident=@"peek.end";p4.onlyIf=^BOOL{return seen;};
  return [[@[offer] arrayByAddingObjectsFromArray:flow] arrayByAddingObjectsFromArray:@[set1,setok,none2,p1,p2,p3,twice,kept,p4]];}];
 [cleanups addObject:NSNull.null];

 // 6 Sessions & nights: a five-second sample session by the user's hand; the night look; the schedule (an offer)
 [steps addObject:^NSArray *{
  __block BOOL yes=NO;__block NSInteger hoursStart=-1,startMin=-1,endMin=-1,boostStart=-1;BOOL night=[[host guideValue:@"isNight"] boolValue];
  NSString *(^clock)(NSString *,NSInteger)=^NSString *(NSString *key,NSInteger fallback){id v=[NSUserDefaults.standardUserDefaults objectForKey:key];NSInteger m=v?[v integerValue]:fallback;NSDateComponents *c=[NSDateComponents new];c.hour=m/60;c.minute=m%60;
   NSDateFormatter *f=[NSDateFormatter new];[f setLocalizedDateFormatFromTemplate:@"jmm"];NSDate *d=[NSCalendar.currentCalendar dateFromComponents:c];return d?[f stringFromDate:d]:@"";};
  GTBeat *s1=Beat(L(@"A session: a stretch of focused work with a gentle end."),GTFaceNone);s1.free=YES;
  GTBeat *open=Beat(L(@"Your turn: click the circle, then the first item, Session or break…"),GTFacePress);open.onlyIf=[weak isOff:@"sessionRunning"];open.to=weak.underCircle;open.ringIsCircle=YES;open.lean=YES;open.mark=@"session";open.menuItem=L(@"Session or break…");
  open.until=[weak isOn:@"sessionPanel"];open.nudges=[weak circleNudges];open.onNext=^{[host guideDo:@"openSessionPanel" with:nil];};
  GTBeat *s3=Beat(L(@"The real panel. Session or Break: a break calls you back. Once."),GTFaceNone);s3.onlyIf=[weak isOn:@"sessionPanel"];s3.lean=YES;s3.avoid=[weak frameOf:@"session"];s3.to=[weak beside:@"session"];s3.pointAt=[weak midOf:@"session.tabs"];
  BOOL (^sample)(void)=[weak isOn:@"sessionSample"];__block BOOL sampled=NO;
  BOOL has25=[[host guideValue:@"sessionPresets"] containsObject:@25];
  GTBeat *tryOne=Beat(has25?L(@"Click a length: 25, say. On the tour it lasts just five seconds."):L(@"Click a length, any of them. On the tour it lasts just five seconds."),GTFacePress);tryOne.onlyIf=[weak isOn:@"sessionPanel"];tryOne.avoid=[weak frameOf:@"session"];tryOne.to=[weak beside:@"session"];tryOne.lean=YES;
  tryOne.ring=[weak frameOf:@"session.chips"];tryOne.pointAt=[weak midOf:@"session.chips"];tryOne.until=^BOOL{return [[host guideValue:@"sessionRunning"] boolValue]||![[host guideValue:@"sessionPanel"] boolValue];};
  tryOne.nudges=@[@[@10,has25?L(@"The numbers in the panel: 25 will do. Or Not now, and we go on without it."):L(@"The numbers in the panel: any will do. Or Not now, and we go on without it."),@(GTFaceNone)],@[@40,L(@"Take your time. I’m not going anywhere; I only just got here."),@(GTFaceNone)]];
  tryOne.onNext=^{[host guideDo:@"closeSessionPanel" with:nil];};tryOne.nextTo=@"ses.skip";__weak GTBeat *weakTryOne=tryOne;tryOne.done=^{weakTryOne.doneTo=[[host guideValue:@"sessionRunning"] boolValue]?nil:@"ses.skip";};
  GTBeat *run=Beat(L(@"Started. Watch the circle in the menu bar: it shows the session. A few seconds, this one."),GTFaceHop);run.onlyIf=^BOOL{if(!sample())return NO;sampled=YES;return YES;};run.to=weak.underCircle;run.ring=weak.circleRing;run.ringIsCircle=YES;run.lean=YES;run.pointAt=weak.circleAim;
  run.countdown=YES;run.until=^BOOL{return [[host guideValue:@"sessionOver"] boolValue]||![[host guideValue:@"sessionRunning"] boolValue];};run.timeout=15;
  GTBeat *end=Beat(nil,GTFaceWiggle);end.sayBlock=^NSString *{BOOL is25=[[host guideValue:@"sessionMinutes"] integerValue]==25;  // the glow and the gong only when both are on in Settings → Sessions
   if([[host guideValue:@"sessionGlowAndGong"] boolValue])return is25?L(@"There: the glow, the gong. 25 minutes in five seconds. Don’t tell the clock up there."):L(@"There: the glow, the gong. A whole session in five seconds. Don’t tell the clock up there.");
   return is25?L(@"There: the end. 25 minutes in five seconds. Don’t tell the clock up there."):L(@"There: the end. A whole session in five seconds. Don’t tell the clock up there.");};end.onlyIf=^BOOL{return sampled;};end.faces=@[@[@.8,@(GTFaceHop)]];
  GTBeat *after=Beat(L(@"That was a sample; it won’t be kept. A real one keeps counting past the end, gently."),GTFaceNone);after.onlyIf=^BOOL{return sampled;};after.run=^{[host guideDo:@"endSampleSession" with:nil];};
  GTBeat *skip=Beat(L(@"Not now, then. Sessions wait in the menu, first item. On we go."),GTFaceNone);skip.ident=@"ses.skip";skip.jumpOnly=YES;skip.run=^{[host guideDo:@"closeSessionPanel" with:nil];};
  GTBeat *started=Beat(L(@"A real one, running. It keeps counting while we go on."),GTFaceTilt);started.onlyIf=^BOOL{return [[host guideValue:@"sessionRunning"] boolValue]&&!sample()&&![[host guideValue:@"sessionAway"] boolValue];};started.run=^{[host guideDo:@"closeSessionPanel" with:nil];};
  GTBeat *pause=Beat(L(@"A break instead: it calls you back once, when it’s over. I’ll end this one for the tour."),GTFaceTilt);pause.onlyIf=[weak isOn:@"sessionAway"];pause.run=^{[host guideDo:@"closeSessionPanel" with:nil];};pause.done=^{[host guideDo:@"endSampleSession" with:nil];};
  GTBeat *time=Beat(L(@"It’s night by your schedule, so this is on already. A preview of the present."),GTFaceNone);time.free=YES;time.onlyIf=^BOOL{return night;};time.run=^{[host guideNightPreview:YES];};
  GTBeat *n1=Beat(L(@"At night, a few points warmer. Like this."),GTFaceNone);n1.free=YES;n1.onlyIf=^BOOL{return !night;};n1.run=^{[host guideNightPreview:YES];};n1.pointAt=[weak at:.5 :.4];n1.hold=1.2;
  GTBeat *n3=Beat(L(@"That was Warmer at night. It comes by itself when your night begins."),GTFaceNone);n3.run=^{[host guideNightPreview:NO];};
  GTBeat *offer=Beat(L(@"Warmer evenings on a schedule: want that? I’ll show you where it lives."),GTFaceTilt);offer.ask=@[L(@"Yes, show me"),L(@"Not now")];
  __weak GTBeat *weakOffer=offer;offer.answered=^(NSInteger i){if(i==0)yes=YES;else weakOffer.doneTo=@"night.no";};
  NSArray *flow=[weak settingsFlowFor:0 named:L(@"General") when:^BOOL{return yes;}];
  NSValue *(^side)(void)=[weak beside:@"settings"];NSValue *(^setFrame)(void)=[weak frameOf:@"settings"];
  GTBeat *where=Beat(L(@"Night schedule, in General. Two choices: Sunset to sunrise, or Custom hours."),GTFaceNone);where.onlyIf=^BOOL{return yes;};where.lean=YES;where.avoid=setFrame;where.to=side;where.ring=[weak frameOf:@"settings.nightPopup"];where.pointAt=[weak midOf:@"settings.nightPopup"];
  // what is set already counts: the tour shows it, and goes on if you keep it (it does not insist on a change)
  GTBeat *pick=Beat(nil,GTFaceNone);pick.onlyIf=^BOOL{return yes;};pick.avoid=setFrame;pick.ring=[weak frameOf:@"settings.nightPopup"];
  pick.sayBlock=^NSString *{return [[host guideValue:@"nightHours"] integerValue]==1?L(@"Yours is Custom hours. Fine as it is; you can switch any time."):L(@"Yours is Sunset to sunrise. Fine as it is; you can switch any time.");};
  pick.run=^{hoursStart=[[host guideValue:@"nightHours"] integerValue];};pick.until=^BOOL{return [[host guideValue:@"nightHours"] integerValue]!=hoursStart;};pick.soft=4;
  BOOL (^sunset)(void)=^BOOL{return yes&&[[host guideValue:@"nightHours"] integerValue]==0;};
  NSArray *sun=[weak sunsetBeatsWhen:sunset then:@"night.boost" explain:YES];
  GTBeat *custom=Beat(nil,GTFaceNone);custom.onlyIf=^BOOL{return yes&&[[host guideValue:@"nightHours"] integerValue]==1;};custom.lean=YES;custom.avoid=setFrame;
  custom.sayBlock=^NSString *{return [NSString stringWithFormat:L(@"Your hours: %@ to %@. Change them in the two fields, or keep them."),clock(@"nightStart",22*60),clock(@"nightEnd",7*60)];};
  custom.ring=[weak frameOf:@"settings.hours"];custom.pointAt=[weak midOf:@"settings.hours"];custom.run=^{startMin=[[NSUserDefaults.standardUserDefaults objectForKey:@"nightStart"] integerValue];endMin=[[NSUserDefaults.standardUserDefaults objectForKey:@"nightEnd"] integerValue];};
  custom.until=^BOOL{return [[NSUserDefaults.standardUserDefaults objectForKey:@"nightStart"] integerValue]!=startMin||[[NSUserDefaults.standardUserDefaults objectForKey:@"nightEnd"] integerValue]!=endMin;};custom.soft=6;
  GTBeat *boost=Beat(nil,GTFaceNone);boost.sayBlock=^NSString *{return [[host guideValue:@"nightBoostOn"] boolValue]?L(@"Warmer at night, just below: on for you. Try shows it for a moment."):L(@"Warmer at night, just below: off for you. +13 is a good start; Try shows it.");};boost.ident=@"night.boost";boost.onlyIf=^BOOL{return yes;};boost.avoid=setFrame;
  boost.ring=[weak frameOf:@"settings.boost"];boost.pointAt=[weak midOf:@"settings.boost"];boost.run=^{boostStart=[[host guideValue:@"nightBoost"] integerValue];};boost.until=^BOOL{return [[host guideValue:@"nightBoost"] integerValue]!=boostStart;};boost.soft=10;
  GTBeat *ns=Beat(L(@"And Night Shift itself: Auto, On or Off, in the menu. Auto follows the same night."),GTFaceNone);ns.onlyIf=^BOOL{return yes;};ns.pointAt=weak.circleAim;ns.ring=weak.circleRing;ns.ringIsCircle=YES;
  GTBeat *done=Beat(L(@"Evenings: done."),GTFaceWiggle);done.onlyIf=^BOOL{return yes;};
  done.doneTo=@"next-station";  // a night schedule set up through the offer stays
  GTBeat *no=Beat(L(@"Fine by me. It waits under Settings → General, Night schedule."),GTFaceNone);no.ident=@"night.no";no.jumpOnly=YES;no.doneTo=@"next-station";no.ring=weak.circleRing;no.ringIsCircle=YES;
  // (no line about the panel itself: it shows Session and Break; the guide asks for a length at once)
  NSMutableArray *beats=[NSMutableArray arrayWithArray:@[s1,open,tryOne,run,end,after,skip,started,pause,time,n1,n3,offer]];(void)s3;[beats addObjectsFromArray:flow];[beats addObjectsFromArray:@[where,pick]];[beats addObjectsFromArray:sun];[beats addObjectsFromArray:@[custom,boost,ns,done,no]];
  return beats;}];
 [cleanups addObject:^{[host guideDo:@"closeSessionPanel" with:nil];[host guideDo:@"endSampleSession" with:nil];[host guideNightPreview:NO];}];

 // 7 Your turn: privacy, launch at login (an offer), what stays (ticked) and what goes back, and home through the door
 [steps addObject:^NSArray *{
  __block BOOL yes=NO;__block NSArray *changeList=@[],*keptIds=@[];
  GTBeat *p1=Beat(L(@"No account, no tracking. Not even by me, and I came all this way."),GTFaceNone);p1.scene=5;p1.free=YES;
  GTBeat *p2=Beat(L(@"A connected browser only passes on the address. Never the page."),GTFaceNone);p2.scene=5;p2.onlyIf=^BOOL{return !weak.saidWebPriv;};
  GTBeat *p3=Beat(L(@"Screenshots keep their colors. Quiet for you, normal for everyone else."),GTFaceTilt);p3.scene=5;
  GTBeat *offer=Beat(L(@"Last offer: shall Less Pull open when you log in? Then the quiet is just there."),GTFaceTilt);offer.free=YES;offer.onlyIf=[weak isOff:@"launchAtLogin"];offer.ask=@[L(@"Yes, at login"),L(@"Not now")];
  __weak GTBeat *weakOffer=offer;offer.answered=^(NSInteger i){if(i==0)yes=YES;else weakOffer.doneTo=@"login.no";};
  NSArray *flow=[weak settingsFlowFor:0 named:L(@"General") when:^BOOL{return yes;}];
  GTBeat *move=Beat(L(@"One catch: for that, Less Pull has to live in Applications. Move it there first."),GTFaceTilt);move.onlyIf=^BOOL{return yes&&![[host guideValue:@"inApplications"] boolValue];};move.until=[weak isOn:@"inApplications"];move.soft=60;
  GTBeat *tick=Beat(L(@"General, near the bottom: Launch at login. Tick it."),GTFacePress);tick.onlyIf=^BOOL{return yes;};tick.avoid=[weak frameOf:@"settings"];tick.to=[weak beside:@"settings"];
  tick.ring=[weak frameOf:@"settings.login"];tick.pointAt=[weak midOf:@"settings.login"];tick.until=[weak isOn:@"launchAtLogin"];tick.nudges=[weak nudge:10 say:L(@"The checkbox at the bottom of General: Launch at login.")];tick.nextTo=@"turn";
  GTBeat *ok=Beat(L(@"Done. From now on it’s there before you are."),GTFaceHop);ok.onlyIf=^BOOL{return yes&&[[host guideValue:@"launchAtLogin"] boolValue];};ok.doneTo=@"turn";
  GTBeat *no=Beat(L(@"Sure. The checkbox waits under Settings → General, any time."),GTFaceNone);no.ident=@"login.no";no.jumpOnly=YES;no.ring=weak.circleRing;no.ringIsCircle=YES;
  // what stays: one box per change, none ticked; Done keeps what you ticked and puts the rest back
  GTBeat *turn=Beat(nil,GTFaceNone);turn.ident=@"turn";turn.free=YES;turn.onlyIf=^BOOL{return [host guideChangedSomething];};turn.ask=@[L(@"Done")];turn.ticked=0;turn.tickedSet=^NSIndexSet *{NSMutableIndexSet *set=[NSMutableIndexSet new];NSArray *list=[host guideValue:@"changeList"];[list enumerateObjectsUsingBlock:^(NSDictionary *c,NSUInteger i,BOOL *stop){if([c[@"keep"] boolValue])[set addIndex:i];}];return set;};
  turn.choices=^NSArray *{changeList=[host guideValue:@"changeList"]?:@[];NSMutableArray *labels=[NSMutableArray new];for(NSDictionary *c in changeList)[labels addObject:c[@"label"]];return labels;};
  turn.sayBlock=^NSString *{NSArray *list=[host guideValue:@"changeList"];BOOL some=NO;for(NSDictionary *c in list)if([c[@"keep"] boolValue])some=YES;
   if(some)return L(@"What you set up is ticked to stay. Tick or untick the rest; whatever isn’t ticked goes back.");
   return list.count==1?L(@"You changed one thing on the way. Tick it to keep it; otherwise it goes back."):L(@"You changed a few things on the way. Tick what you keep; the rest goes back.");};
  turn.chosen=^(NSArray<NSNumber *> *ticked){NSMutableArray *ids=[NSMutableArray new];for(NSNumber *n in ticked)if(n.integerValue<(NSInteger)changeList.count)[ids addObject:changeList[n.integerValue][@"id"]];keptIds=ids;};
  turn.answered=^(NSInteger i){[host guideDo:@"keepOnly" with:keptIds];};
  GTBeat *keep=Beat(L(@"Kept, all of it. Your screen, your rules."),GTFaceHop);keep.onlyIf=^BOOL{return changeList.count&&keptIds.count==changeList.count;};
  GTBeat *some=Beat(L(@"Done: what you ticked stays, the rest is back."),GTFaceNone);some.onlyIf=^BOOL{return keptIds.count&&keptIds.count<changeList.count;};
  GTBeat *back=Beat(L(@"Done. Everything as it was before I knocked."),GTFaceNone);back.onlyIf=^BOOL{return changeList.count&&!keptIds.count;};
  NSMutableArray *beats=[NSMutableArray arrayWithObjects:p1,p2,p3,offer,nil];[beats addObjectsFromArray:flow];[beats addObjectsFromArray:@[move,tick,ok,no,turn,keep,some,back]];
  if(GTWebsite){[beats addObject:Beat(L(@"Home now: lesspull.com, the little circle in the corner."),GTFaceNone)];[beats addObject:Beat(L(@"Come by sometime. There’s a drawn Mac to play with, and I’ll act surprised."),GTFaceTilt)];}
  GTBeat *home=Beat(L(@"That’s the tour. Thank you for having me. Enjoy the quiet."),GTFaceWiggle);home.to=^NSValue *{NSPoint p=[weak homePoint];return [NSValue valueWithPoint:NSMakePoint(p.x-120,p.y-130)];};home.home=YES;[beats addObject:home];  // one line, then home through the door
  return beats;}];
 [cleanups addObject:NSNull.null];
 self.steps=steps;self.cleanups=cleanups;
}
@end
