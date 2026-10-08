// Explicit, reversible integration test. Changes only Color Filters, then restores the starting mode.
#import "Engine.h"
int main(){@autoreleasepool{
 FilterEngine *engine=[FilterEngine new]; NSInteger original=engine.currentMode;
 if(original!=0&&original!=1&&original!=16){fprintf(stderr,"Select Grayscale or Color Tint before testing.\n");return 2;}
 BOOL passed=YES;
 for(NSNumber *mode in @[@1,@16,@0,@16,@1]){
  BOOL ok=[engine applyMode:mode.integerValue];
  printf("%ld: %s (includes tint preservation)\n",mode.longValue,ok?"PASS":"FAIL");passed &=ok;
 }
 BOOL restored=[engine applyMode:original];printf("Restore: %s\n",restored?"PASS":"FAIL");
 return passed&&restored?0:1;
}}
