#import <Cocoa/Cocoa.h>
#import "WarmthEngine.h"
#import "WarmthCurve.h"
#import <math.h>
typedef struct {double m[9];} TestMatrix;
@interface CaptureWarmth : WarmthEngine
@property NSUInteger writes;
@property NSData *matrix;
@end
@implementation CaptureWarmth
- (BOOL)send:(TestMatrix)m {self.writes++;self.matrix=[NSData dataWithBytes:&m length:sizeof(m)];[self setValue:self.matrix forKey:@"lastMatrix"];return YES;}
@end
// Per-display mode: every display gets its own matrix; the fake records sends per display.
@interface DisplayCapture : WarmthEngine
@property NSMutableDictionary *writes,*last;
@end
@implementation DisplayCapture
- (NSArray<NSNumber *> *)displays {return @[@11,@22];}
- (BOOL)sendMatrix:(TestMatrix)m toDisplay:(uint32_t)d {if(!self.writes){self.writes=[NSMutableDictionary new];self.last=[NSMutableDictionary new];}self.writes[@(d)]=@([self.writes[@(d)] intValue]+1);self.last[@(d)]=[NSData dataWithBytes:&m length:sizeof(m)];return YES;}
@end
static void check(BOOL x,const char *m){if(!x){fprintf(stderr,"FAIL %s\n",m);exit(1);}}
static void run(double t){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:t]];}
int main(){@autoreleasepool{
 CaptureWarmth *w=[CaptureWarmth new];__block int completed=0;
 [w transitionStrength:0 grayscale:NO reduceMotion:YES duration:.5 completion:^{completed++;}];check(!w.transitioning&&completed==1,"Reduce Motion immediate");
 NSUInteger before=w.writes;[w applyStrength:0 grayscale:NO];check(w.writes==before,"no duplicate endpoint write after Instant");
 w.writes=0;[w transitionStrength:1 grayscale:YES reduceMotion:NO duration:.5 completion:^{completed++;}];run(.2);check(w.transitioning&&w.writes>1&&completed==1,"finite fade starts");NSData *mid=w.matrix;
 [w transitionStrength:0 grayscale:NO reduceMotion:NO duration:.5 completion:^{completed++;}];check([[w valueForKey:@"transitionFrom"] isEqual:mid],"rapid switch rebases from current matrix");run(.6);check(!w.transitioning&&completed==2,"old completion cancelled and timer stops");TestMatrix m;memcpy(&m,w.matrix.bytes,sizeof(m));WarmthMatrix3 identity=MakeWarmthMatrix(0,NO);for(int i=0;i<9;i++)check(fabs(m.m[i]-identity.m[i])<1e-9,"identity endpoint");NSUInteger count=w.writes;run(.15);check(count==w.writes,"no idle frames");
 [w transitionStrength:3 grayscale:NO reduceMotion:NO duration:0 completion:^{completed++;}];check(!w.transitioning&&completed==3,"Instant setting");
 [w transitionStrength:0 grayscale:YES reduceMotion:NO duration:2 completion:^{completed++;}];run(.1);[w cancelTransition];check(!w.transitioning&&completed==3,"quit cancellation");
 DisplayCapture *dc=[DisplayCapture new];dc.perDisplay=YES;check([dc displays].count==2,"two displays listed");
 check([dc applyStrength:1 grayscale:YES display:11]&&[dc applyStrength:0 grayscale:NO display:22],"apply per display");check([dc.writes[@11] intValue]==1&&[dc.writes[@22] intValue]==1,"one send per display");
 check([dc applyStrength:1 grayscale:YES display:11]&&[dc.writes[@11] intValue]==1,"cached per display: no duplicate send");
 check([[dc stateForDisplay:22][1] boolValue]==NO&&[[dc stateForDisplay:11][1] boolValue]==YES&&![dc stateForDisplay:33],"per-display state reported");
 __block int done=0;[dc transitionStrength:0 grayscale:NO display:11 reduceMotion:NO duration:.3 completion:^{done++;}];check(dc.transitioning,"display fade runs");run(.5);
 check(!dc.transitioning&&done==1&&[dc.writes[@11] intValue]>5&&[dc.writes[@22] intValue]==1,"display 11 faded over several frames while display 22 was untouched");
 TestMatrix end;memcpy(&end,[dc.last[@11] bytes],sizeof(end));WarmthMatrix3 plain=MakeWarmthMatrix(0,NO);for(int i=0;i<9;i++)check(fabs(end.m[i]-plain.m[i])<1e-9,"display fade ends on its target");
 [dc invalidate];check([dc applyStrength:0 grayscale:NO display:11]&&[dc.writes[@11] intValue]>6,"invalidate re-sends per display");
 [dc transitionStrength:1 grayscale:YES display:22 reduceMotion:YES duration:.5 completion:^{done++;}];check(done==2&&[dc.writes[@22] intValue]==2,"Reduce Motion per display is immediate");puts("PASS: finite .5s interpolation, rapid rebase/cancel, endpoints, no idle frames, Instant, Reduce Motion; per-display apply, cache, independent fades, invalidate.");
}}
