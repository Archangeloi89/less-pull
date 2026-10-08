#import "WarmthEngine.h"
#import <dlfcn.h>
#import <math.h>
#import "WarmthCurve.h"
typedef struct {double m[9];} FilterMatrix;
static CFTypeRef (*copyFilter)(BOOL,BOOL,unsigned long);
static FilterMatrix (*getMatrix)(CFTypeRef);
static int (*setAdjustments)(CFDictionaryRef);
static CFStringRef matrixKey;
@interface WarmthEngine ()
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
 copyFilter=dlsym(ma,"MADisplayFilterCopySystemFilter");getMatrix=dlsym(ma,"MADisplayFilterGetMatrix");setAdjustments=dlsym(sl,"SLSSetAccessibilityAdjustments");CFStringRef *key=dlsym(sl,"kSLSAccessibilityAdjustmentMatrix");matrixKey=key?*key:NULL;
 if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey)self.error=@"Custom monochrome matrix unavailable on this macOS.";
 }
 return self;
}
- (BOOL)send:(FilterMatrix)matrix {
 float values[9];for(int i=0;i<9;i++)values[i]=matrix.m[i];
 NSData *data=[NSData dataWithBytes:values length:sizeof(values)];NSDictionary *dict=@{(__bridge NSString *)matrixKey:data};
 int result=setAdjustments((__bridge CFDictionaryRef)dict);
 self.lastRequest=result;
 if(result==0)self.lastMatrix=[NSData dataWithBytes:&matrix length:sizeof(matrix)];
 if(result!=0){self.error=[NSString stringWithFormat:@"The display did not accept the change (%d).",result];return NO;}
 return YES;
}
- (BOOL)transitioning {return self.transitionTimer!=nil;}
- (void)cancelTransition {[self.transitionTimer invalidate];self.transitionTimer=nil;self.transitionCompletion=nil;}
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion {
 [self cancelTransition];if(!copyFilter||!getMatrix||!setAdjustments||!matrixKey){self.error=@"Display transition unavailable.";completion();return;}
 FilterMatrix from;if(self.active&&self.lastMatrix.length==sizeof(from))memcpy(&from,self.lastMatrix.bytes,sizeof(from));else {CFTypeRef filter=copyFilter(NO,YES,0);if(!filter){completion();return;}from=getMatrix(filter);CFRelease(filter);}
 WarmthMatrix3 target=MakeWarmthMatrix(strength,grayscale);FilterMatrix to;memcpy(to.m,target.m,sizeof(to.m));
 self.active=YES;self.strength=strength;self.grayscale=grayscale;self.cacheValid=NO;[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"customMatrixActive"];
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
 FilterMatrix matrix=getMatrix(filter);CFRelease(filter);BOOL ok=[self send:matrix];if(ok){self.active=NO;[NSUserDefaults.standardUserDefaults setBool:NO forKey:@"customMatrixActive"];}return ok;
}
- (void)invalidate {self.cacheValid=NO;}
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
