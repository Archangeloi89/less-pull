#import "WarmthEngine.h"
#import <dlfcn.h>
#import <math.h>
#import "WarmthCurve.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
typedef struct {double m[9];} FilterMatrix;
static CFTypeRef (*copyFilter)(BOOL,BOOL,unsigned long);
static FilterMatrix (*getMatrix)(CFTypeRef);
static int (*setAdjustments)(CFDictionaryRef);
static CFStringRef matrixKey,targetKey;
// One display's own matrix, cache and running fade. Fades tick on the display's refresh clock
// (CVDisplayLink), so every step lands on a frame, at 60 Hz or 120 Hz alike.
@interface DisplayState : NSObject
@property uint32_t display;
@property double strength;
@property BOOL grayscale,cacheValid,known;
@property NSData *lastMatrix,*from,*to;
@property NSTimeInterval start,duration;
@property CVDisplayLinkRef link;
@property NSTimer *timer;
@property(copy) void (^completion)(void);
@end
@implementation DisplayState
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)stop {if(self.link){CVDisplayLinkStop(self.link);CVDisplayLinkRelease(self.link);self.link=NULL;}[self.timer invalidate];self.timer=nil;self.completion=nil;}
#pragma clang diagnostic pop
- (BOOL)fading {return self.link!=NULL||self.timer!=nil;}
- (void)dealloc {[self stop];}
@end
@interface WarmthEngine ()
@property NSMutableDictionary<NSNumber *,DisplayState *> *states;
@property BOOL active;
@property NSTimer *transitionTimer;
@property NSData *lastMatrix;
@property NSTimeInterval transitionStart,transitionDuration;
@property NSData *transitionFrom,*transitionTo;
@property(copy) void (^transitionCompletion)(void);
@property double strength;
@property int lastRequest;
@property BOOL cacheValid,grayscale;
@end
@implementation WarmthEngine
- (instancetype)init {
 if((self=[super init])){
 self.active=[NSUserDefaults.standardUserDefaults boolForKey:@"customMatrixActive"];
 void *ma=dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility",RTLD_NOW);
 void *sl=dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",RTLD_NOW);
 copyFilter=dlsym(ma,"MADisplayFilterCopySystemFilter");getMatrix=dlsym(ma,"MADisplayFilterGetMatrix");setAdjustments=dlsym(sl,"SLSSetAccessibilityAdjustments");CFStringRef *key=dlsym(sl,"kSLSAccessibilityAdjustmentMatrix");matrixKey=key?*key:NULL;CFStringRef *target=dlsym(sl,"kSLSAccessibilityTargetDisplay");targetKey=target?*target:NULL;self.states=[NSMutableDictionary new];
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey)self.error=@"Custom monochrome matrix unavailable on this macOS.";
 }
 return self;
}
__attribute__((weak)) BOOL LessPullHandsOff=NO;  // --hands-off: a test copy leaves the displays to the installed app
- (BOOL)send:(FilterMatrix)matrix {
 if(LessPullHandsOff){self.lastRequest=0;self.lastMatrix=[NSData dataWithBytes:&matrix length:sizeof(matrix)];return YES;}
 float values[9];for(int i=0;i<9;i++)values[i]=matrix.m[i];
 NSData *data=[NSData dataWithBytes:values length:sizeof(values)];NSDictionary *dict=@{(__bridge NSString *)matrixKey:data};
 int result=setAdjustments((__bridge CFDictionaryRef)dict);
 self.lastRequest=result;
 if(result==0)self.lastMatrix=[NSData dataWithBytes:&matrix length:sizeof(matrix)];
 if(result!=0){self.error=[NSString stringWithFormat:@"The display did not accept the change (%d).",result];return NO;}
 return YES;
}
// A matrix for one display. The system call takes a target display; a send without one
// (display 0) addresses all displays and replaces every per-display matrix.
- (BOOL)sendMatrix:(FilterMatrix)matrix toDisplay:(uint32_t)display {
 if(!display)return [self send:matrix];
 if(LessPullHandsOff)return YES;
 if(!targetKey){self.error=@"Per-display matrices are unavailable on this macOS.";return NO;}
 float values[9];for(int i=0;i<9;i++)values[i]=matrix.m[i];
 NSDictionary *dict=@{(__bridge NSString *)matrixKey:[NSData dataWithBytes:values length:sizeof(values)],(__bridge NSString *)targetKey:@(display)};
 int result=setAdjustments((__bridge CFDictionaryRef)dict);self.lastRequest=result;
 if(result!=0){self.error=[NSString stringWithFormat:@"Display %u did not accept the change (%d).",display,result];return NO;}
 return YES;
}
- (NSArray<NSNumber *> *)displays {
 if(!self.perDisplay)return @[@0];
 uint32_t count=0;CGDirectDisplayID ids[32];if(CGGetActiveDisplayList(32,ids,&count)!=kCGErrorSuccess||!count)return @[@0];
 NSMutableArray *list=[NSMutableArray new];for(uint32_t i=0;i<count;i++)[list addObject:@(ids[i])];
 for(NSNumber *known in self.states.allKeys)if(![list containsObject:known])[self.states removeObjectForKey:known];  // unplugged
 return list;
}
- (DisplayState *)stateFor:(uint32_t)display {DisplayState *s=self.states[@(display)];if(!s){s=[DisplayState new];s.display=display;self.states[@(display)]=s;}return s;}
- (NSArray<NSNumber *> *)stateForDisplay:(uint32_t)display {DisplayState *s=self.states[@(display)];return s.known?@[@(s.strength),@(s.grayscale)]:nil;}
- (BOOL)applyStrength:(double)strength grayscale:(BOOL)grayscale display:(uint32_t)display {
 if(!display)return [self applyStrength:strength grayscale:grayscale];
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey)return NO;
 strength=fmax(0,fmin(strength,3));DisplayState *s=[self stateFor:display];
 if(s.known&&s.cacheValid&&s.strength==strength&&s.grayscale==grayscale)return YES;
 WarmthMatrix3 composed=MakeWarmthMatrix(strength,grayscale);FilterMatrix matrix;memcpy(matrix.m,composed.m,sizeof(matrix.m));
 self.active=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"customMatrixActive"];
 BOOL ok=[self sendMatrix:matrix toDisplay:display];if(ok){s.lastMatrix=[NSData dataWithBytes:&matrix length:sizeof(matrix)];s.strength=strength;s.grayscale=grayscale;s.known=YES;self.error=nil;}s.cacheValid=ok;return ok;
}
- (void)tickDisplay:(DisplayState *)s {
 if(!s.fading)return;double t=fmin(1,(NSProcessInfo.processInfo.systemUptime-s.start)/s.duration);double blend=t*t*(3-2*t);
 FilterMatrix from,to,m;memcpy(&from,s.from.bytes,sizeof(from));memcpy(&to,s.to.bytes,sizeof(to));for(int i=0;i<9;i++)m.m[i]=from.m[i]+(to.m[i]-from.m[i])*blend;
 BOOL sent=[self sendMatrix:m toDisplay:s.display];if(sent)s.lastMatrix=[NSData dataWithBytes:&m length:sizeof(m)];
 if(t>=1){s.cacheValid=sent;void (^completion)(void)=s.completion;[s stop];if(completion)completion();}
}
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale display:(uint32_t)display reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion {
 if(!display)return [self transitionStrength:strength grayscale:grayscale reduceMotion:reduce duration:duration completion:completion];
 DisplayState *s=[self stateFor:display];[s stop];
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey||!targetKey){self.error=@"Display transition unavailable.";completion();return;}
 FilterMatrix from;if(s.lastMatrix.length==sizeof(from))memcpy(&from,s.lastMatrix.bytes,sizeof(from));else {CFTypeRef filter=copyFilter(NO,YES,0);if(!filter){completion();return;}from=getMatrix(filter);CFRelease(filter);}
 WarmthMatrix3 target=MakeWarmthMatrix(strength,grayscale);FilterMatrix to;memcpy(to.m,target.m,sizeof(to.m));
 self.active=YES;s.strength=strength;s.grayscale=grayscale;s.known=YES;s.cacheValid=NO;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"customMatrixActive"];
 if(reduce||duration<=0){BOOL ok=[self sendMatrix:to toDisplay:display];if(ok)s.lastMatrix=[NSData dataWithBytes:&to length:sizeof(to)];s.cacheValid=ok;completion();return;}
 s.from=[NSData dataWithBytes:&from length:sizeof(from)];s.to=[NSData dataWithBytes:&to length:sizeof(to)];s.completion=completion;s.start=NSProcessInfo.processInfo.systemUptime;s.duration=fmax(.05,fmin(2,duration));
 // The display's own clock: one step per refresh. Falls back to a 60 Hz timer if the link cannot be made.
 CVDisplayLinkRef link=NULL;__weak WarmthEngine *weak=self;__weak DisplayState *weakState=s;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
 if(CVDisplayLinkCreateWithCGDisplay(display,&link)==kCVReturnSuccess&&link){
  CVDisplayLinkSetOutputHandler(link,^CVReturn(CVDisplayLinkRef l,const CVTimeStamp *now,const CVTimeStamp *out,CVOptionFlags f,CVOptionFlags *o){dispatch_async(dispatch_get_main_queue(),^{DisplayState *st=weakState;if(st&&st.link==l)[weak tickDisplay:st];});return kCVReturnSuccess;});
  s.link=link;if(CVDisplayLinkStart(link)!=kCVReturnSuccess){CVDisplayLinkRelease(link);s.link=NULL;}
 }
#pragma clang diagnostic pop
 if(!s.link){s.timer=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *t){DisplayState *st=weakState;if(st)[weak tickDisplay:st];}];[NSRunLoop.mainRunLoop addTimer:s.timer forMode:NSRunLoopCommonModes];}
}
- (BOOL)transitioning {if(self.transitionTimer)return YES;for(DisplayState *s in self.states.allValues)if(s.fading)return YES;return NO;}
- (void)cancelTransition {[self.transitionTimer invalidate];self.transitionTimer=nil;self.transitionCompletion=nil;for(DisplayState *s in self.states.allValues)[s stop];}
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion {
 [self cancelTransition];if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey){self.error=@"Display transition unavailable.";completion();return;}
 FilterMatrix from;if(self.active&&self.lastMatrix.length==sizeof(from))memcpy(&from,self.lastMatrix.bytes,sizeof(from));else {CFTypeRef filter=copyFilter(NO,YES,0);if(!filter){completion();return;}from=getMatrix(filter);CFRelease(filter);}
 WarmthMatrix3 target=MakeWarmthMatrix(strength,grayscale);FilterMatrix to;memcpy(to.m,target.m,sizeof(to.m));
 self.active=YES;self.strength=strength;self.grayscale=grayscale;self.cacheValid=NO;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"customMatrixActive"];for(DisplayState *st in self.states.allValues){[st stop];st.known=NO;}
 if(reduce||duration<=0){self.cacheValid=[self send:to];completion();return;}
 self.transitionFrom=[NSData dataWithBytes:&from length:sizeof(from)];self.transitionTo=[NSData dataWithBytes:&to length:sizeof(to)];self.transitionCompletion=completion;self.transitionStart=NSProcessInfo.processInfo.systemUptime;self.transitionDuration=fmax(.05,fmin(2,duration));
 self.transitionTimer=[NSTimer timerWithTimeInterval:1.0/60 target:self selector:@selector(transitionTick:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.transitionTimer forMode:NSRunLoopCommonModes];
}
- (void)transitionTick:(id)sender {
 double t=fmin(1,(NSProcessInfo.processInfo.systemUptime-self.transitionStart)/self.transitionDuration);double blend=t*t*(3-2*t);FilterMatrix from,to,m;memcpy(&from,self.transitionFrom.bytes,sizeof(from));memcpy(&to,self.transitionTo.bytes,sizeof(to));for(int i=0;i<9;i++)m.m[i]=from.m[i]+(to.m[i]-from.m[i])*blend;
 BOOL sent=[self send:m];if(t>=1){self.cacheValid=sent;void (^completion)(void)=self.transitionCompletion;[self cancelTransition];if(completion)completion();}
}
- (BOOL)restore {
 [self cancelTransition];
 if(!self.active)return YES;
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey)return NO;
 CFTypeRef filter=copyFilter(NO,YES,0);if(!filter){self.error=@"Could not restore the native filter matrix.";return NO;}
 FilterMatrix matrix=getMatrix(filter);CFRelease(filter);BOOL ok=[self send:matrix];if(ok){self.active=NO;[self.states removeAllObjects];[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"customMatrixActive"];}return ok;
}
- (void)invalidate {self.cacheValid=NO;for(DisplayState *s in self.states.allValues)s.cacheValid=NO;}
- (BOOL)applyStrength:(double)strength grayscale:(BOOL)grayscale {
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey)return NO;
 strength=fmax(0,fmin(strength,3));
 if(self.active&&self.cacheValid&&self.strength==strength&&self.grayscale==grayscale)return YES;
 self.strength=strength;self.grayscale=grayscale;self.error=nil;
 // Replace the system's grayscale matrix with a rank-one warm monochrome matrix.
 // Each output still depends on the same luminance; only its channel gain differs.
 // Unlike a gamma LUT applied before grayscale, this retains amber chromaticity.
 WarmthMatrix3 composed=MakeWarmthMatrix(strength,grayscale);FilterMatrix matrix;memcpy(matrix.m,composed.m,sizeof(matrix.m));
 self.active=YES;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"customMatrixActive"];BOOL ok=[self send:matrix];self.cacheValid=ok;return ok;
}
- (NSString *)diagnostics {
 double gains[3];WarmthGains(self.strength,gains);
 return [NSString stringWithFormat:@"Extra Warmth: %@; last request result=%d\nStrength %.2f / 3.00; output gains R=%.3f G=%.3f B=%.3f\nDisplay appearance requires visual verification; request success is not an optical measurement.\n%@",self.active?@"applied by Less Pull":@"not applied",self.lastRequest,self.strength,gains[0],gains[1],gains[2],self.error?:@""];
}
@end
