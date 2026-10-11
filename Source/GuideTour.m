#import "GuideTour.h"
#import "Localize.h"

// ---- One beat: a line, a place to go, something to do, something to wait for.
@interface GTBeat : NSObject
@property(copy) NSString *say;
@property(copy) NSValue *(^to)(void);          // where the guide goes (screen point), nil: stays
@property(copy) void (^run)(void);
@property(copy) BOOL (^onlyIf)(void);          // the beat is skipped when this says NO
@property(copy) BOOL (^until)(void);           // waits for this (polled), up to timeout
@property double timeout,hold;
@property(copy) NSString *timeoutSay;
@property BOOL home;                           // flies back into the menu bar and disappears
@end
@implementation GTBeat @end
static GTBeat *Beat(NSString *say,NSValue *(^to)(void)) {GTBeat *b=[GTBeat new];b.say=say;b.to=to;return b;}

// ---- The guide and its bubble, drawn on a transparent layer over the whole screen.
@interface GuideView : NSView
@property NSPoint pos;            // view coordinates
@property double size,alpha,bubbleAlpha,clock;
@property(copy) NSString *text;
@end
@implementation GuideView
- (BOOL)isFlipped {return NO;}
- (void)drawRect:(NSRect)dirty {
 if(self.alpha<=0.01)return;
 NSPoint p=self.pos;p.y+=sin(self.clock*2.2)*1.6;  // breathing while it talks
 double r=19*self.size;  // a little bigger than the menu-bar circle, so it reads on large screens too
 // the bubble
 if(self.text.length&&self.bubbleAlpha>0.01){
  NSDictionary *a=@{NSFontAttributeName:[NSFont systemFontOfSize:14],NSForegroundColorAttributeName:[NSColor.labelColor colorWithAlphaComponent:self.bubbleAlpha]};
  NSRect t=[self.text boundingRectWithSize:NSMakeSize(260,1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:a];
  NSSize box=NSMakeSize(ceil(t.size.width)+26,ceil(t.size.height)+20);
  BOOL left=p.x+r+14+box.width>NSMaxX(self.bounds)-12, below=p.y-box.height/2<20, above=p.y+box.height/2>NSMaxY(self.bounds)-30;
  NSRect b=NSMakeRect(left?p.x-r-14-box.width:p.x+r+14,p.y-box.height/2,box.width,box.height);
  if(above)b.origin.y=p.y-r-12-box.height,b.origin.x=MIN(MAX(12,p.x-box.width/2),NSMaxX(self.bounds)-box.width-12);
  else if(below)b.origin.y=p.y+r+12;
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh=[NSShadow new];sh.shadowBlurRadius=14;sh.shadowOffset=NSMakeSize(0,-3);sh.shadowColor=[NSColor colorWithWhite:0 alpha:.28*self.bubbleAlpha];[sh set];
  [[NSColor.windowBackgroundColor colorWithAlphaComponent:.97*self.bubbleAlpha] setFill];
  NSBezierPath *bp=[NSBezierPath bezierPathWithRoundedRect:b xRadius:12 yRadius:12];[bp fill];
  [NSGraphicsContext restoreGraphicsState];
  [[NSColor.separatorColor colorWithAlphaComponent:self.bubbleAlpha] setStroke];bp.lineWidth=1;[bp stroke];
  [self.text drawWithRect:NSMakeRect(b.origin.x+13,b.origin.y+10,box.width-26,box.height-20) options:NSStringDrawingUsesLineFragmentOrigin attributes:a];
 }
 // the circle: the menu-bar mark, grown up a little, with a warm glow
 [NSGraphicsContext saveGraphicsState];
 NSColor *ember=[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:self.alpha];
 NSShadow *glow=[NSShadow new];glow.shadowBlurRadius=12*self.size;glow.shadowOffset=NSZeroSize;glow.shadowColor=[ember colorWithAlphaComponent:.55*self.alpha];[glow set];
 NSRect c=NSMakeRect(p.x-r,p.y-r,2*r,2*r);
 [[NSColor colorWithWhite:.16 alpha:self.alpha] setFill];[[NSBezierPath bezierPathWithOvalInRect:c] fill];
 [NSGraphicsContext restoreGraphicsState];
 NSBezierPath *right=[NSBezierPath bezierPath];[right moveToPoint:NSMakePoint(p.x,p.y-r*.72)];[right appendBezierPathWithArcWithCenter:p radius:r*.72 startAngle:-90 endAngle:90];[right closePath];[ember setFill];[right fill];
 NSBezierPath *leftHalf=[NSBezierPath bezierPath];[leftHalf moveToPoint:NSMakePoint(p.x,p.y+r*.72)];[leftHalf appendBezierPathWithArcWithCenter:p radius:r*.72 startAngle:90 endAngle:270];[leftHalf closePath];[[NSColor colorWithWhite:.93 alpha:self.alpha] setFill];[leftHalf fill];
 NSBezierPath *ring=[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(c,1,1)];ring.lineWidth=1.6;[[NSColor colorWithWhite:.96 alpha:.9*self.alpha] setStroke];[ring stroke];
}
@end

@interface GuideTour ()
@property NSPanel *overlay,*strip;
@property GuideView *view;
@property NSTimer *frameTimer,*waitTimer;
@property NSArray<NSArray<GTBeat *> *(^)(void)> *steps;
@property NSArray *cleanups;
@property NSInteger step,beatIndex,generation;
@property NSArray<GTBeat *> *beats;
@property NSPoint from,target;
@property double moveStart,moveDuration;
@property NSTextField *stepLabel;
@property NSButton *slowButton,*backButton,*nextButton;
@property BOOL peekSeen,running;
@end

@implementation GuideTour
- (instancetype)initWithHost:(id<GuideTourHost>)host {if((self=[super init]))_host=host;return self;}
- (double)pace {return self.slow?1.6:1;}
- (BOOL)reduceMotion {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;}
- (NSScreen *)screen {NSRect icon=[self.host guideIconFrame];for(NSScreen *s in NSScreen.screens)if(!NSIsEmptyRect(icon)&&NSIntersectsRect(s.frame,icon))return s;return NSScreen.mainScreen?:NSScreen.screens.firstObject;}
- (NSPoint)local:(NSPoint)screenPoint {return NSMakePoint(screenPoint.x-self.overlay.frame.origin.x,screenPoint.y-self.overlay.frame.origin.y);}
- (NSPoint)iconPoint {NSRect f=[self.host guideIconFrame];return NSIsEmptyRect(f)?NSZeroPoint:NSMakePoint(NSMidX(f),NSMidY(f));}
- (NSValue *)screenFraction:(double)x y:(double)y {NSRect v=self.screen.visibleFrame;return [NSValue valueWithPoint:NSMakePoint(NSMinX(v)+v.size.width*x,NSMinY(v)+v.size.height*y)];}
- (NSValue *)leftOf:(NSRect)f {if(NSIsEmptyRect(f))return [self screenFraction:.5 y:.62];return [NSValue valueWithPoint:NSMakePoint(NSMinX(f)-34,NSMaxY(f)-36)];}

#pragma mark start and end
- (void)start {
 if(self.running)return;self.running=YES;
 NSScreen *s=self.screen;
 self.overlay=[[NSPanel alloc]initWithContentRect:s.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.overlay.opaque=NO;self.overlay.backgroundColor=NSColor.clearColor;self.overlay.ignoresMouseEvents=YES;self.overlay.hasShadow=NO;self.overlay.level=NSStatusWindowLevel+1;
 self.overlay.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;
 self.view=[[GuideView alloc]initWithFrame:(NSRect){NSZeroPoint,s.frame.size}];self.view.size=1;self.overlay.contentView=self.view;[self.overlay setFrame:s.frame display:NO];[self.overlay orderFrontRegardless];
 [self buildStrip];[self buildSteps];
 NSPoint icon=[self iconPoint];NSRect startFrame=[self.host guideStartFrame];
 NSPoint begin=NSEqualPoints(icon,NSZeroPoint)?NSMakePoint(NSMidX(startFrame),NSMaxY(startFrame)-40):icon;
 self.view.pos=self.from=self.target=[self local:begin];self.view.alpha=1;self.view.size=NSEqualPoints(icon,NSZeroPoint)?1:.6;
 self.frameTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(frame:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.frameTimer forMode:NSRunLoopCommonModes];
 [self playStep:0];
}
- (void)stop {[self finish:NO];}
- (void)finish:(BOOL)completed {
 if(!self.running)return;self.running=NO;self.generation++;
 [self runCleanup:self.step];
 [self.frameTimer invalidate];[self.waitTimer invalidate];[self.overlay orderOut:nil];[self.strip orderOut:nil];self.overlay=nil;self.strip=nil;
 [self.host guideLookGray:-1 warmth:-1];[self.host guideFinished:completed];
}
- (void)runCleanup:(NSInteger)step {if(step>=0&&step<(NSInteger)self.cleanups.count){id c=self.cleanups[step];if(c!=NSNull.null)((void(^)(void))c)();}}

#pragma mark the control strip
- (NSButton *)stripButton:(NSString *)title action:(SEL)a {NSButton *b=[NSButton buttonWithTitle:title target:self action:a];b.controlSize=NSControlSizeSmall;b.font=[NSFont systemFontOfSize:NSFont.smallSystemFontSize];b.bezelStyle=NSBezelStyleRounded;return b;}
- (void)buildStrip {
 self.stepLabel=[NSTextField labelWithString:@""];self.stepLabel.font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];self.stepLabel.textColor=NSColor.secondaryLabelColor;
 self.slowButton=[self stripButton:L(@"Slower") action:@selector(toggleSlow:)];self.slowButton.buttonType=NSButtonTypePushOnPushOff;
 self.backButton=[self stripButton:L(@"Back") action:@selector(back:)];self.nextButton=[self stripButton:L(@"Next") action:@selector(next:)];
 NSButton *end=[self stripButton:L(@"End tour") action:@selector(endTour:)];
 NSStackView *row=[NSStackView stackViewWithViews:@[self.stepLabel,self.slowButton,self.backButton,self.nextButton,end]];row.spacing=8;row.edgeInsets=NSEdgeInsetsMake(8,14,8,10);
 NSVisualEffectView *back=[NSVisualEffectView new];back.material=NSVisualEffectMaterialHUDWindow;back.state=NSVisualEffectStateActive;back.wantsLayer=YES;back.layer.cornerRadius=12;
 row.translatesAutoresizingMaskIntoConstraints=NO;[back addSubview:row];[row.leadingAnchor constraintEqualToAnchor:back.leadingAnchor].active=YES;[row.trailingAnchor constraintEqualToAnchor:back.trailingAnchor].active=YES;[row.topAnchor constraintEqualToAnchor:back.topAnchor].active=YES;[row.bottomAnchor constraintEqualToAnchor:back.bottomAnchor].active=YES;
 NSSize size=row.fittingSize;NSRect v=self.screen.visibleFrame;
 self.strip=[[NSPanel alloc]initWithContentRect:NSMakeRect(NSMidX(v)-size.width/2,NSMinY(v)+28,size.width,size.height) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
 self.strip.opaque=NO;self.strip.backgroundColor=NSColor.clearColor;self.strip.hasShadow=YES;self.strip.level=NSStatusWindowLevel+2;self.strip.collectionBehavior=self.overlay.collectionBehavior;self.strip.contentView=back;self.strip.becomesKeyOnlyIfNeeded=YES;
 self.strip.accessibilityLabel=L(@"Tour controls");[self.strip orderFrontRegardless];
}
- (void)updateStrip {self.stepLabel.stringValue=[NSString stringWithFormat:L(@"%ld of %ld"),(long)self.step+1,(long)self.steps.count];self.backButton.enabled=self.step>0;self.nextButton.title=self.step+1>=(NSInteger)self.steps.count?L(@"Done"):L(@"Next");}
- (void)toggleSlow:(NSButton *)sender {self.slow=sender.state==NSControlStateValueOn;[self interject:self.slow?L(@"Okay, slower. I’ll take my time."):L(@"Back to my usual speed.")];}
- (void)next:(id)sender {if(self.step+1>=(NSInteger)self.steps.count){[self finish:YES];return;}[self playStep:self.step+1];}
- (void)back:(id)sender {if(self.step>0)[self playStep:self.step-1];}
- (void)endTour:(id)sender {[self finish:NO];}

#pragma mark moving and talking
- (void)frame:(NSTimer *)t {
 double now=CACurrentMediaTime();GuideView *v=self.view;v.clock=now;
 if(self.moveDuration>0){double k=MIN(1,(now-self.moveStart)/self.moveDuration);double e=k<.5?4*k*k*k:1-pow(-2*k+2,3)/2;  // ease in and out
  NSPoint a=self.from,b=self.target;double arc=sin(M_PI*e)*MIN(80,hypot(b.x-a.x,b.y-a.y)*.18);  // a gentle arc, not a straight line
  v.pos=NSMakePoint(a.x+(b.x-a.x)*e,a.y+(b.y-a.y)*e+arc);if(k>=1)self.moveDuration=0;}
 v.needsDisplay=YES;
}
- (double)moveTo:(NSPoint)screenPoint {
 NSPoint to=[self local:screenPoint];if(NSEqualPoints(to,self.view.pos))return 0;
 if(self.reduceMotion){self.view.pos=self.target=to;self.moveDuration=0;return .2;}
 self.from=self.view.pos;self.target=to;self.moveStart=CACurrentMediaTime();self.moveDuration=MIN(1.6,.45+hypot(to.x-self.from.x,to.y-self.from.y)/1400)*self.pace;return self.moveDuration;
}
- (void)showText:(NSString *)text {
 self.view.text=text;self.view.bubbleAlpha=text.length?1:0;
 if(text.length)NSAccessibilityPostNotificationWithUserInfo(self.overlay,NSAccessibilityAnnouncementRequestedNotification,@{NSAccessibilityAnnouncementKey:text,NSAccessibilityPriorityKey:@(NSAccessibilityPriorityHigh)});
}
- (double)readingTime:(NSString *)text {if(!text.length)return 0;NSUInteger words=[text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet].count;return MAX(2.2,words*.34+.8)*self.pace;}
- (void)interject:(NSString *)text {NSString *before=self.view.text;NSInteger g=self.generation;[self showText:text];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(g==self.generation&&[self.view.text isEqual:text])[self showText:before];});}
- (void)after:(double)seconds do:(void(^)(void))block {NSInteger g=self.generation;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(g==self.generation&&self.running)block();});}

#pragma mark the steps
- (void)playStep:(NSInteger)i {
 [self runCleanup:self.step];self.generation++;[self.waitTimer invalidate];
 self.step=i;self.beats=self.steps[i]();self.beatIndex=0;[self updateStrip];[self playBeat];
}
- (void)playBeat {
 if(!self.running)return;
 if(self.beatIndex>=(NSInteger)self.beats.count){if(self.step+1<(NSInteger)self.steps.count)[self playStep:self.step+1];else [self finish:YES];return;}
 GTBeat *b=self.beats[self.beatIndex];
 if(b.onlyIf&&!b.onlyIf()){self.beatIndex++;[self playBeat];return;}
 if(b.run)b.run();
 double travel=0;
 if(b.home){NSPoint icon=[self iconPoint];if(!NSEqualPoints(icon,NSZeroPoint))travel=[self moveTo:icon];
  [self showText:b.say];[self after:MAX(travel,[self readingTime:b.say]) do:^{[self showText:nil];[self shrinkAndEnd];}];return;}
 if(b.to){NSValue *v=b.to();if(v)travel=[self moveTo:v.pointValue];}
 [self showText:b.say];
 double wait=MAX(travel+.3,[self readingTime:b.say])+b.hold*self.pace;
 void (^advance)(void)=^{self.beatIndex++;[self playBeat];};
 if(!b.until){[self after:wait do:advance];return;}
 // wait for something real, with a friendly line if it takes a while
 double started=CACurrentMediaTime();NSInteger g=self.generation;__weak GuideTour *weak=self;
 [self.waitTimer invalidate];
 self.waitTimer=[NSTimer timerWithTimeInterval:.15 repeats:YES block:^(NSTimer *t){GuideTour *s=weak;if(!s||g!=s.generation||!s.running){[t invalidate];return;}
  if(b.until()){[t invalidate];[s after:.4 do:advance];return;}
  if(b.timeout>0&&CACurrentMediaTime()-started>b.timeout*s.pace){[t invalidate];if(b.timeoutSay.length){[s showText:b.timeoutSay];[s after:[s readingTime:b.timeoutSay] do:advance];}else advance();}}];
 [NSRunLoop.mainRunLoop addTimer:self.waitTimer forMode:NSRunLoopCommonModes];
}
- (void)shrinkAndEnd {
 if(self.reduceMotion){[self finish:YES];return;}
 double start=CACurrentMediaTime();__weak GuideTour *weak=self;
 NSTimer *t=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){GuideTour *s=weak;if(!s||!s.running){[timer invalidate];return;}double k=MIN(1,(CACurrentMediaTime()-start)/.45);s.view.size=1-.6*k;s.view.alpha=1-k;if(k>=1){[timer invalidate];[s finish:YES];}}];
 [NSRunLoop.mainRunLoop addTimer:t forMode:NSRunLoopCommonModes];
}
- (void)buildSteps {
 __weak GuideTour *weak=self;id<GuideTourHost> host=self.host;
 NSValue *(^nearStart)(void)=^NSValue *{NSRect f=[host guideStartFrame];NSRect v=weak.screen.visibleFrame;double x=NSMaxX(f)+44<NSMaxX(v)-300?NSMaxX(f)+44:NSMinX(f)+60;return [NSValue valueWithPoint:NSMakePoint(x,NSMaxY(f)-90)];};
 NSValue *(^nearStrip)(void)=^NSValue *{NSRect f=weak.strip.frame;return [NSValue valueWithPoint:NSMakePoint(NSMinX(f)-30,NSMaxY(f)+24)];};
 NSValue *(^belowIcon)(void)=^NSValue *{NSPoint p=[weak iconPoint];return NSEqualPoints(p,NSZeroPoint)?nil:[NSValue valueWithPoint:NSMakePoint(p.x,p.y-34)];};
 NSValue *(^middle)(void)=^NSValue *{return [weak screenFraction:.42 y:.6];};
 BOOL (^iconShown)(void)=^BOOL{return !NSIsEmptyRect([host guideIconFrame]);};
 __block NSRect panel=NSZeroRect;
 NSMutableArray *steps=[NSMutableArray new],*cleanups=[NSMutableArray new];
 // 1 hello
 [steps addObject:^NSArray *{GTBeat *hi=Beat(L(@"Hi! I’m the circle from your menu bar. I’ll show you around."),nearStart);GTBeat *slow=Beat(L(@"Too quick for you? Press Slower down here. I won’t mind."),nearStrip);return @[hi,slow];}];
 [cleanups addObject:NSNull.null];
 // 2 home, and help when the menu bar hides it
 [steps addObject:^NSArray *{
  GTBeat *home=Beat(L(@"That’s my home, up here. One click opens the menu."),belowIcon);home.onlyIf=iconShown;
  GTBeat *hidden=Beat(L(@"Hm. I can’t see my home. The menu bar is full, or the notch is in the way."),^NSValue *{return [weak screenFraction:.82 y:.9];});hidden.onlyIf=^BOOL{return !iconShown();};
  GTBeat *drag=Beat(L(@"Click » in the menu bar to show hidden icons, then hold ⌘ and drag the circle toward the clock. I’ll wait."),nil);drag.onlyIf=^BOOL{return !iconShown();};drag.until=iconShown;drag.timeout=45;drag.timeoutSay=L(@"No rush. You can do it later; the menu bar keeps my place.");
  GTBeat *found=Beat(L(@"There it is. Much better."),belowIcon);found.onlyIf=^BOOL{return iconShown()&&!home.onlyIf();};
  return @[home,hidden,drag,found];}];
 [cleanups addObject:NSNull.null];
 // 3 grayscale, for real, for a moment
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"Watch. Grayscale takes the color out of everything."),middle);a.run=^{[host guideLookGray:1 warmth:0];};GTBeat *b=Beat(L(@"Quieter, isn’t it?"),nil);b.hold=.6;return @[a,b];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 4 warmth
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"And warmth: from a touch of amber…"),nil);a.run=^{[host guideLookGray:-1 warmth:.6];};GTBeat *b=Beat(L(@"…all the way to red."),nil);b.run=^{[host guideLookGray:-1 warmth:2.4];};GTBeat *c=Beat(L(@"You choose how much. I’ll put yours back."),nil);c.run=^{[host guideLookGray:-1 warmth:-1];};return @[a,b,c];}];
 [cleanups addObject:^{[host guideLookGray:-1 warmth:-1];}];
 // 5 exceptions: the real panel
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"Some apps need color. Give them an exception, right from the menu."),^NSValue *{return [weak leftOf:panel];});a.run=^{panel=[host guideShowExceptionPanel];};GTBeat *b=Beat(L(@"Change only what should differ. The rest follows your defaults."),nil);return @[a,b];}];
 [cleanups addObject:^{[host guideHideExceptionPanel];panel=NSZeroRect;}];
 // 6 peek, hands-on
 [steps addObject:^NSArray *{
  NSString *key=[host guidePeekLabel];if(!key)return @[Beat(L(@"Need color for a moment? Set a Peek shortcut under Shortcuts, and hold it."),middle)];
  weak.peekSeen=NO;
  GTBeat *ask=Beat([NSString stringWithFormat:L(@"Your turn. Hold %@."),key],middle);ask.until=^BOOL{BOOL p=[host guidePeeking];if(p)weak.peekSeen=YES;return p;};ask.timeout=25;ask.timeoutSay=[NSString stringWithFormat:L(@"No rush. Hold %@ whenever you need color."),key];
  GTBeat *color=Beat(L(@"Color, for as long as you hold it."),nil);color.onlyIf=^BOOL{return weak.peekSeen;};color.until=^BOOL{return ![host guidePeeking];};color.timeout=20;
  GTBeat *done=Beat(L(@"And quiet again. Natural talent."),nil);done.onlyIf=^BOOL{return weak.peekSeen;};
  return @[ask,color,done];}];
 [cleanups addObject:NSNull.null];
 // 7 session or break: the real panel
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"Need to focus? A session ends gently, with a glow and a soft sound."),^NSValue *{return [weak leftOf:panel];});a.run=^{panel=[host guideShowSessionPanel];};GTBeat *b=Beat(L(@"Need to step away? A break calls you back once."),nil);return @[a,b];}];
 [cleanups addObject:^{[host guideHideSessionPanel];panel=NSZeroRect;}];
 // 8 night
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"At night, a little warmer. Like this."),middle);a.run=^{[host guideNightPreview:YES];};a.hold=1.2;return @[a];}];
 [cleanups addObject:^{[host guideNightPreview:NO];}];
 // 9 private
 [steps addObject:^NSArray *{return @[Beat(L(@"No account, no tracking. What happens on your Mac stays on your Mac."),middle)];}];
 [cleanups addObject:NSNull.null];
 // 10 goodbye, back into the menu bar
 [steps addObject:^NSArray *{GTBeat *a=Beat(L(@"That’s it from me. I’ll be up in the menu bar. Enjoy the quiet."),nil);a.home=YES;return @[a];}];
 [cleanups addObject:NSNull.null];
 self.steps=steps;self.cleanups=cleanups;
}
@end
