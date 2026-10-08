#define main utility_main
#import "main.m"
#undef main
#import "WarmthCurve.h"
typedef struct{double m[9];} TestMatrix;
@interface PipelineCapture : WarmthEngine
@property NSUInteger writes;
@property NSData *screen;
@end
@implementation PipelineCapture
- (BOOL)send:(TestMatrix)m {self.writes++;self.screen=[NSData dataWithBytes:&m length:sizeof(m)];[self setValue:self.screen forKey:@"lastMatrix"];return YES;}
@end
@interface PipelineApp : AppDelegate
@end
@implementation PipelineApp
- (void)updateForeground {}
- (void)refreshControlsKnown:(BOOL)known nightOn:(BOOL)on {}
@end
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static void run(double t){[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:t]];}
static NSData *identity(){WarmthMatrix3 m=MakeWarmthMatrix(0,NO);return [NSData dataWithBytes:&m length:sizeof(m)];}
int main(){@autoreleasepool{
 [NSApplication sharedApplication];[NSUserDefaults.standardUserDefaults setDouble:0 forKey:@"warmth"];
 PipelineCapture *w=[PipelineCapture new];[w setValue:@NO forKey:@"active"];[w applyStrength:0 grayscale:NO];
 PipelineApp *a=[PipelineApp new];a.warmth=w;a.policy=[SwitchingPolicy new];a.exclusion=[ExclusionPolicy new];a.selectedMode=100;a.animateAppearance=YES;[a sync];[a pipelineChanged:nil];
 run(.58);check(!w.transitioning,"fade has completed before late system reset");w.screen=identity();NSUInteger before=w.writes;
 run(.55);check(w.writes>before&&![w.screen isEqual:identity()],"late pipeline reset repaired after fade completion");check(a.selectedMode==100&&a.effectiveMode==100,"pipeline reset never changes saved or effective grayscale choice");check(a.pipelineRestorations==2,"recovery is bounded to two settled checks");
 NSUInteger settled=w.writes;run(.25);[a sync];check(w.writes==settled,"unchanged idle sync does not reassert matrix");
 [a pipelineChanged:nil];[a pipelineChanged:nil];NSUInteger restorations=a.pipelineRestorations;run(1.1);check(a.pipelineRestorations==restorations+2,"notification burst coalesces recovery");
 a.quitting=YES;[a pipelineChanged:nil];check(a.pipelineRestorations==restorations+2,"quit prevents new recovery work");
 puts("PASS: late pipeline reset after completed fade, persistent grayscale, bounded recovery, coalescing and no idle writes.");
}}
