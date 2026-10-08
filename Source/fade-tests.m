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
static void check(BOOL x,const char *m){if(!x){fprintf(stderr,"FAIL %s\n",m);exit(1);}}
static void run(double t){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:t]];}
int main(){@autoreleasepool{
 CaptureWarmth *w=[CaptureWarmth new];__block int completed=0;
 [w transitionStrength:0 grayscale:NO reduceMotion:YES duration:.5 completion:^{completed++;}];check(!w.transitioning&&completed==1,"Reduce Motion immediate");
 NSUInteger before=w.writes;[w applyStrength:0 grayscale:NO];check(w.writes==before,"no duplicate endpoint write after Instant");
 w.writes=0;[w transitionStrength:1 grayscale:YES reduceMotion:NO duration:.5 completion:^{completed++;}];run(.2);check(w.transitioning&&w.writes>1&&completed==1,"finite fade starts");NSData *mid=w.matrix;
 [w transitionStrength:0 grayscale:NO reduceMotion:NO duration:.5 completion:^{completed++;}];check([[w valueForKey:@"transitionFrom"] isEqual:mid],"rapid switch rebases from current matrix");run(.6);check(!w.transitioning&&completed==2,"old completion cancelled and timer stops");TestMatrix m;memcpy(&m,w.matrix.bytes,sizeof(m));WarmthMatrix3 identity=MakeWarmthMatrix(0,NO);for(int i=0;i<9;i++)check(fabs(m.m[i]-identity.m[i])<1e-9,"identity endpoint");NSUInteger count=w.writes;run(.15);check(count==w.writes,"no idle frames");
 [w transitionStrength:3 grayscale:NO reduceMotion:NO duration:0 completion:^{completed++;}];check(!w.transitioning&&completed==3,"Instant setting");
 [w transitionStrength:0 grayscale:YES reduceMotion:NO duration:2 completion:^{completed++;}];run(.1);[w cancelTransition];check(!w.transitioning&&completed==3,"quit cancellation");puts("PASS: finite .5s interpolation, rapid rebase/cancel, endpoints, no idle frames, Instant, Reduce Motion.");
}}
