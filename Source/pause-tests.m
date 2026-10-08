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
 NSDate *dst=[PausePolicy nextMorningForDate:date(@"2026-10-24 23:00") mode:1 endMinute:0 calendar:c];CHECK([dst isEqual:date(@"2026-10-25 07:00")]);
 puts("PASS: custom overnight schedule, morning cutoff, early resume, conservative daytime protection, persisted expiry, previous-off protection, local DST morning.");return 0;
}}
