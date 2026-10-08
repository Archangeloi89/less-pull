#import <Foundation/Foundation.h>
#import "PausePolicy.h"
// Temporary Night Shift suppression owns only its own off write. Actual off while
// suppressed cannot reveal an external off request; app controls update desiredOn.
@interface ExclusionPolicy : NSObject
@property BOOL active,known,desiredOn,scheduleWindowKnown,scheduleWindowOn;
@property PausePolicy *guard;
- (void)beginKnown:(BOOL)known on:(BOOL)on guard:(PausePolicy *)guard;
- (void)observeKnown:(BOOL)known actualOn:(BOOL)on expectedOn:(BOOL)expected guard:(PausePolicy *)guard unchanged:(BOOL)unchanged date:(NSDate *)date calendar:(NSCalendar *)calendar;
- (void)observeScheduleWindow:(BOOL)windowOn;
- (void)requestOn:(BOOL)on guard:(PausePolicy *)guard;
- (BOOL)mayRestoreAt:(NSDate *)date unchanged:(BOOL)unchanged calendar:(NSCalendar *)calendar;
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;
@end
