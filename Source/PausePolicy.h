#import <Foundation/Foundation.h>
@interface PausePolicy : NSObject
@property NSDate *expiry;
@property NSDate *created;
@property NSDate *nightEnd;
@property BOOL priorOn;
@property NSInteger scheduleMode,startMinute,endMinute;
@property BOOL untilMorning;
+ (NSDate *)nextMorningForDate:(NSDate *)date mode:(NSInteger)mode endMinute:(NSInteger)end calendar:(NSCalendar *)calendar;
- (BOOL)mayResumeAt:(NSDate *)date calendar:(NSCalendar *)calendar;
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end
