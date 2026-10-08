#import <Foundation/Foundation.h>
#import "Session.h"
static void check(BOOL ok,const char *m){if(!ok){fprintf(stderr,"FAIL: %s\n",m);exit(1);}}
static NSDate *at(double s){return [NSDate dateWithTimeIntervalSince1970:1000000+s];}
int main(){@autoreleasepool{
 Session *s=[Session new];check(s.state==SessionIdle&&[[s labelAt:at(0)] isEqual:@""],"idle at first");
 [s startMinutes:30 at:at(0)];check(s.state==SessionRunning&&[[s labelAt:at(0)] isEqual:@"30"]&&[[s labelAt:at(61)] isEqual:@"29"]&&[[s labelAt:at(29*60+1)] isEqual:@"1"],"counts the minutes left, rounded up");
 check([s eventsAt:at(100)].count==0,"nothing happens while running");
 NSArray *e=[s eventsAt:at(30*60)];check(e.count==1&&[e[0] isEqual:@"ended"]&&s.state==SessionOver,"the end fires once");check([s eventsAt:at(30*60+1)].count==0,"and not again");
 check([[s labelAt:at(30*60+30)] isEqual:@"-0"]&&[[s labelAt:at(35*60+5)] isEqual:@"-5"],"counts past the end");
 check([s eventsAt:at(34*60+59)].count==0,"no reminder before five minutes");e=[s eventsAt:at(35*60)];check(e.count==1&&[e[0] isEqual:@"reminder"],"a reminder every five minutes");check([s eventsAt:at(36*60)].count==0,"not sooner");
 [s quietFor:10 at:at(36*60)];check([s eventsAt:at(40*60)].count==0&&[s eventsAt:at(46*60)].count==1,"a few more minutes postpones the reminder");
 s.remindEvery=0;check([s eventsAt:at(120*60)].count==0,"never remind when asked");
 [s leaveAt:at(50*60) callBackIn:9];check(s.state==SessionAway&&[[s labelAt:at(50*60)] isEqual:@"9"]&&[[s labelAt:at(58*60+30)] isEqual:@"1"],"away counts to the call back");
 check([s eventsAt:at(58*60)].count==0,"not yet");e=[s eventsAt:at(59*60)];check(e.count==1&&[e[0] isEqual:@"callBack"]&&s.state==SessionIdle,"called back once, then over for good");check([s eventsAt:at(70*60)].count==0,"nothing after");
 [s startMinutes:10 at:at(0)];[s extendMinutes:5];check([[s labelAt:at(0)] isEqual:@"15"]&&s.minutes==15,"extend moves the end");[s eventsAt:at(15*60)];[s extendMinutes:10];check(s.state==SessionRunning&&[[s labelAt:at(15*60)] isEqual:@"10"],"extending an over session runs it again");
 [s leaveAt:at(20*60) callBackIn:0];check(s.state==SessionIdle,"leaving without a call back ends it");
 [s startMinutes:45 at:at(0)];Session *back=[Session fromDictionary:s.dictionary];check(back.state==SessionRunning&&[[back labelAt:at(60)] isEqual:@"44"],"survives a relaunch");check([Session fromDictionary:@{@"state":@7}].state==SessionIdle&&[Session fromDictionary:@{@"state":@1}].state==SessionIdle,"bad saved state is idle");
 [s startMinutes:0 at:at(0)];check(s.minutes==1,"at least a minute");
 puts("PASS: session start, minutes left, end once, count past the end, reminders and quiet, leave and single call back, extend, persistence.");
}}
