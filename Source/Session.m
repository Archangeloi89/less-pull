#import "Session.h"
@interface Session ()
@property SessionState state;
@property NSDate *start,*end,*callBackAt,*lastReminder,*leftAt;
@property NSInteger minutes;
@end
@implementation Session
- (instancetype)init {if((self=[super init]))self.remindEvery=5;return self;}
- (void)startMinutes:(NSInteger)minutes at:(NSDate *)now {minutes=MAX(1,MIN(minutes,24*60));self.minutes=minutes;self.start=now;self.end=[now dateByAddingTimeInterval:minutes*60];self.callBackAt=nil;self.lastReminder=nil;self.state=SessionRunning;}
- (void)extendMinutes:(NSInteger)minutes {if(self.state!=SessionRunning&&self.state!=SessionOver)return;self.end=[self.end dateByAddingTimeInterval:minutes*60];self.minutes+=minutes;if(self.state==SessionOver){self.state=SessionRunning;self.lastReminder=nil;}}
- (void)quietFor:(NSInteger)minutes at:(NSDate *)now {if(self.state!=SessionOver)return;self.lastReminder=[now dateByAddingTimeInterval:MAX(0,minutes-self.remindEvery)*60];}
- (void)leaveAt:(NSDate *)now callBackIn:(NSInteger)minutes {if(minutes<=0){[self stop];return;}self.callBackAt=[now dateByAddingTimeInterval:minutes*60];self.leftAt=now;self.state=SessionAway;}
- (void)stop {self.state=SessionIdle;self.start=self.end=self.callBackAt=self.lastReminder=self.leftAt=nil;self.minutes=0;}
- (NSArray<NSString *> *)eventsAt:(NSDate *)now {
 NSMutableArray *events=[NSMutableArray new];
 if(self.state==SessionRunning&&[now compare:self.end]!=NSOrderedAscending){self.state=SessionOver;self.lastReminder=self.end;[events addObject:@"ended"];}
 if(self.state==SessionOver&&self.remindEvery>0&&[now timeIntervalSinceDate:self.lastReminder]>=self.remindEvery*60){self.lastReminder=now;[events addObject:@"reminder"];}
 if(self.state==SessionAway&&[now compare:self.callBackAt]!=NSOrderedAscending){[self stop];[events addObject:@"callBack"];}
 return events;
}
- (NSTimeInterval)remainingAt:(NSDate *)now {switch(self.state){case SessionRunning:case SessionOver:return [self.end timeIntervalSinceDate:now];case SessionAway:return [self.callBackAt timeIntervalSinceDate:now];default:return 0;}}
- (NSString *)labelAt:(NSDate *)now {
 if(self.state==SessionIdle)return @"";NSTimeInterval r=[self remainingAt:now];
 if(self.state==SessionOver||r<0)return [NSString stringWithFormat:@"-%ld",(long)floor(-r/60)];  // the count past the end: 0, then 1, 2 … shown with a minus
 return [NSString stringWithFormat:@"%ld",(long)ceil(r/60)];
}
- (NSDictionary *)dictionary {NSMutableDictionary *d=[@{@"state":@(self.state),@"minutes":@(self.minutes),@"remindEvery":@(self.remindEvery)} mutableCopy];if(self.start)d[@"start"]=@(self.start.timeIntervalSince1970);if(self.end)d[@"end"]=@(self.end.timeIntervalSince1970);if(self.callBackAt)d[@"callBackAt"]=@(self.callBackAt.timeIntervalSince1970);if(self.lastReminder)d[@"lastReminder"]=@(self.lastReminder.timeIntervalSince1970);if(self.leftAt)d[@"leftAt"]=@(self.leftAt.timeIntervalSince1970);return d;}
+ (instancetype)fromDictionary:(NSDictionary *)d {
 Session *s=[Session new];if(![d isKindOfClass:NSDictionary.class])return s;NSInteger state=[d[@"state"] integerValue];if(state<SessionIdle||state>SessionAway)return s;
 s.state=state;s.minutes=[d[@"minutes"] integerValue];if(d[@"remindEvery"])s.remindEvery=[d[@"remindEvery"] integerValue];
 if(d[@"start"])s.start=[NSDate dateWithTimeIntervalSince1970:[d[@"start"] doubleValue]];if(d[@"end"])s.end=[NSDate dateWithTimeIntervalSince1970:[d[@"end"] doubleValue]];if(d[@"callBackAt"])s.callBackAt=[NSDate dateWithTimeIntervalSince1970:[d[@"callBackAt"] doubleValue]];if(d[@"lastReminder"])s.lastReminder=[NSDate dateWithTimeIntervalSince1970:[d[@"lastReminder"] doubleValue]];if(d[@"leftAt"])s.leftAt=[NSDate dateWithTimeIntervalSince1970:[d[@"leftAt"] doubleValue]];
 if((s.state==SessionRunning||s.state==SessionOver)&&!s.end)[s stop];if(s.state==SessionAway&&!s.callBackAt)[s stop];if(s.state==SessionAway&&!s.leftAt)s.leftAt=s.end?:NSDate.date;return s;
}
@end
