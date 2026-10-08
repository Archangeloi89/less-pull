#import "PausePolicy.h"
@implementation PausePolicy
+ (NSDate *)nextMorningForDate:(NSDate *)date mode:(NSInteger)mode endMinute:(NSInteger)end calendar:(NSCalendar *)calendar {
 NSInteger minute=(mode==2&&end>=0&&end<1440)?end:420;
 NSDateComponents *parts=[NSDateComponents new];parts.hour=minute/60;parts.minute=minute%60;parts.second=0;
 return [calendar nextDateAfterDate:date matchingComponents:parts options:NSCalendarMatchNextTime];
}
- (BOOL)mayResumeAt:(NSDate *)date calendar:(NSCalendar *)calendar {
 if(!self.priorOn||!self.created||!self.nightEnd||[date compare:self.nightEnd]!=NSOrderedAscending)return NO;
 NSInteger minute=[calendar component:NSCalendarUnitHour fromDate:date]*60+[calendar component:NSCalendarUnitMinute fromDate:date];
 if(self.scheduleMode==2){
  if(self.startMinute==self.endMinute)return NO;
  return self.startMinute<self.endMinute?(minute>=self.startMinute&&minute<self.endMinute):(minute>=self.startMinute||minute<self.endMinute);
 }
 if(self.scheduleMode==1)return minute>=1080||minute<420; // Conservative fallback; true sunrise is not exposed.
 if(self.scheduleMode==0)return [date timeIntervalSinceDate:self.created]<=4*3600+60; // Previously manually enabled, no schedule.
 return NO;
}
- (NSDictionary *)dictionary {return @{@"expiry":self.expiry,@"created":self.created,@"nightEnd":self.nightEnd,@"priorOn":@(self.priorOn),@"mode":@(self.scheduleMode),@"start":@(self.startMinute),@"end":@(self.endMinute),@"morning":@(self.untilMorning)};}
+ (instancetype)fromDictionary:(NSDictionary *)d {
 if(![d isKindOfClass:NSDictionary.class]||![d[@"expiry"] isKindOfClass:NSDate.class]||![d[@"created"] isKindOfClass:NSDate.class]||![d[@"nightEnd"] isKindOfClass:NSDate.class])return nil;
 PausePolicy *p=[self new];p.expiry=d[@"expiry"];p.created=d[@"created"];p.nightEnd=d[@"nightEnd"];p.priorOn=[d[@"priorOn"] boolValue];p.scheduleMode=[d[@"mode"] integerValue];p.startMinute=[d[@"start"] integerValue];p.endMinute=[d[@"end"] integerValue];p.untilMorning=[d[@"morning"] boolValue];return p;
}
@end
