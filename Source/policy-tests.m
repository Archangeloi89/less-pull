#import "SwitchingPolicy.h"
#define CHECK(condition) do { if(!(condition)){fprintf(stderr,"FAIL line %d\n",__LINE__);return 1;} } while(0)
int main(){@autoreleasepool{
 SwitchingPolicy *p=[SwitchingPolicy new];p.automatic=YES;CHECK(p.automaticTarget==-1);
 [p observeKnown:YES on:NO];CHECK(p.automaticTarget==1);
 for(NSNumber *mode in @[@0,@1,@100,@101]){[p selectManual:mode.integerValue];CHECK(p.automatic);CHECK(p.automaticTarget==mode.integerValue);[p observeKnown:NO on:YES];CHECK(p.automaticTarget==mode.integerValue);[p observeKnown:YES on:NO];CHECK(p.automaticTarget==mode.integerValue);[p observeKnown:YES on:YES];CHECK(p.overrideMode==-1&&p.automaticTarget==16);[p observeKnown:YES on:NO];}
 [p selectManual:0];[p resume];CHECK(p.automaticTarget==1);
 p.automatic=NO;[p selectManual:16];[p observeKnown:YES on:YES];CHECK(p.automaticTarget==-1);
 p.automatic=YES;[p resume];CHECK(p.automaticTarget==16);
 puts("PASS: all manual modes, same-state notifications, missing status, both transitions, resume, Auto off.");return 0;
}}
