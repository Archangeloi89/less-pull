#import "PausePolicy.h"
#define CHECK(x) do{if(!(x)){fprintf(stderr,"FAIL line %d\n",__LINE__);return 1;}}while(0)
static NSDate *date(NSString *s){NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyy-MM-dd HH:mm";f.timeZone=[NSTimeZone timeZoneWithName:@"Europe/Zurich"];return [f dateFromString:s];}
int main(){@autoreleasepool{
 NSCalendar *c=[[NSCalendar alloc]initWithCalendarIdentifier:NSCalendarIdentifierGregorian];c.timeZone=[NSTimeZone timeZoneWithName:@"Europe/Zurich"];
 PausePolicy *p=[PausePolicy new];p.created=date(@"2026-10-07 22:00");p.expiry=date(@"2026-10-08 02:00");p.priorOn=YES;p.scheduleMode=2;p.startMinute=1260;p.endMinute=420;p.nightEnd=[PausePolicy nextMorningForDate:p.created mode:2 endMinute:420 calendar:c];
 CHECK([p.nightEnd isEqual:date(@"2026-10-08 07:00")]);CHECK([p mayResumeAt:p.expiry calendar:c]);CHECK(![p mayResumeAt:date(@"2026-10-08 08:00") calendar:c]);
 PausePolicy *restored=[PausePolicy fromDictionary:p.dictionary];CHECK([restored.expiry isEqual:p.expiry]&&[restored mayResumeAt:p.expiry calendar:c]);
 p.untilMorning=YES;CHECK([p mayResumeAt:date(@"2026-10-07 23:00") calendar:c]);CHECK(![p mayResumeAt:p.nightEnd calendar:c]);
 p.scheduleMode=1;CHECK([p mayResumeAt:date(@"2026-10-08 02:00") calendar:c]);CHECK(![p mayResumeAt:date(@"2026-10-08 12:00") calendar:c]);p.priorOn=NO;CHECK(![p mayResumeAt:p.expiry calendar:c]);
 // a night of 07:00 to 06:59 (a friend's Mac, 19 Oct): one minute of day, often slept through; after it, the new night counts
 PausePolicy *q=[PausePolicy new];q.created=date(@"2026-10-18 23:00");q.priorOn=YES;q.scheduleMode=2;q.startMinute=420;q.endMinute=419;q.nightEnd=[PausePolicy nextMorningForDate:q.created mode:2 endMinute:419 calendar:c];q.expiry=q.nightEnd;
 CHECK([q.nightEnd isEqual:date(@"2026-10-19 06:59")]);CHECK([q mayResumeAt:date(@"2026-10-19 03:00") calendar:c]);CHECK(![q mayResumeAt:date(@"2026-10-19 06:59") calendar:c]);CHECK([q mayResumeAt:date(@"2026-10-19 07:30") calendar:c]);CHECK([q mayResumeAt:date(@"2026-10-19 15:00") calendar:c]);
 NSDate *dst=[PausePolicy nextMorningForDate:date(@"2026-10-24 23:00") mode:1 endMinute:0 calendar:c];CHECK([dst isEqual:date(@"2026-10-25 07:00")]);
 puts("PASS: custom overnight schedule, morning cutoff, early resume, conservative daytime protection, persisted expiry, previous-off protection, local DST morning, a night of 07:00 to 06:59.");return 0;
}}
