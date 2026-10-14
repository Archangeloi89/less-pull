#import <Foundation/Foundation.h>
#import "Engine.h"
#import "WarmthEngine.h"
#import "WarmthCurve.h"
// Intel and Apple silicon: this build recognizes the private interfaces in its own spelling of BOOL, and both read
// the same values. Hands-off and read-only: nothing on the screen or in Night Shift changes. Needs a Mac with Night
// Shift. Run it once per architecture (arch -arm64, arch -x86_64); the "same on every architecture" lines must match.
extern BOOL LessPullHandsOff;
typedef struct {double m[9];} TestMatrix;
static void check(BOOL x,const char *m){if(!x){fprintf(stderr,"FAIL %s\n",m);exit(1);}}
int main(){@autoreleasepool{
 LessPullHandsOff=YES;BOOL intel=strcmp(@encode(BOOL),"c")==0;
 check(LessPullLayoutMatches(intel?"c20@0:8c16":"B20@0:8B16","B20@0:8B16"),"a BOOL layout matches in this build's spelling");
 check(!LessPullLayoutMatches(intel?"B20@0:8B16":"c20@0:8c16","B20@0:8B16"),"the other architecture's spelling does not");
 check(!LessPullLayoutMatches(intel?"c20@0:8i16":"B20@0:8i16","B20@0:8B16"),"a different argument type is refused");
 check(LessPullLayoutMatches("c24@0:8^{?=ccci{?={?=ii}{?=ii}}Qc}16","B24@0:8^{?=BBBi{?={?=ii}{?=ii}}QB}16")==intel,"Night Shift status layout as Intel spells it");
 check(LessPullLayoutMatches("B24@0:8^{?=BBBi{?={?=ii}{?=ii}}QB}16","B24@0:8^{?=BBBi{?={?=ii}{?=ii}}QB}16")==!intel,"Night Shift status layout as Apple silicon spells it");
 check(!LessPullLayoutMatches(NULL,"B16@0:8")&&!LessPullLayoutMatches("B16@0:8",NULL),"no layout, no match");
 char overlong[300];memset(overlong,'B',299);overlong[299]=0;check(!LessPullLayoutMatches(overlong,overlong),"an overlong layout is refused, not cut short");
 check([LessPullProcessor() containsString:intel?@"x86_64":@"arm64"],"the processor line names this architecture");
 // The real interfaces of this Mac, read only.
 FilterEngine *e=[FilterEngine new];if(e.error)fprintf(stderr,"%s\n",e.error.UTF8String);check(!e.error,"Night Shift and Color Filter interfaces recognized");
 NSBlueStatus s={0};check([e readNightShiftStatus:&s],"Night Shift status reads");
 float strength=-1;check([e nightShiftStrength:&strength]&&strength>=0&&strength<=1,"Night Shift strength reads");
 BOOL on=NO;int type=0;check([e systemFilterEnabled:&on type:&type],"Color Filter reads");
 WarmthEngine *w=[WarmthEngine new];check(!w.error,"screen matrix interface found");
 check([w applyStrength:1.5 grayscale:YES]&&[w restore],"apply and restore, hands-off");  // restore reads the system's own matrix
 NSData *native=[w valueForKey:@"lastMatrix"];check(native.length==sizeof(TestMatrix),"the system's matrix comes back whole");
 TestMatrix m;memcpy(&m,native.bytes,sizeof m);WarmthMatrix3 warm=MakeWarmthMatrix(1.5,YES);
 printf("same on every architecture: Night Shift enabled=%d active=%d mode=%d %02d:%02d-%02d:%02d available=%d strength=%.4f; Color Filter on=%d type=%d\n",s.enabled,s.active,s.mode,s.schedule.from.hour,s.schedule.from.minute,s.schedule.to.hour,s.schedule.to.minute,s.available,strength,on,type);
 printf("same on every architecture: system matrix");for(int i=0;i<9;i++)printf(" %.6f",m.m[i]);printf("\n");
 printf("same on every architecture: warm gray matrix");for(int i=0;i<9;i++)printf(" %.9f",warm.m[i]);printf("\n");
 printf("PASS: %s: BOOL layouts in this build's spelling, Night Shift and Color Filter interfaces recognized and read, the system matrix read whole.\n",intel?"Intel (x86_64)":"Apple silicon (arm64)");
}}
