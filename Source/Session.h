#import <Foundation/Foundation.h>
// A focus session: a length you choose, a gentle end, time counted past the end, an optional
// "call me back" once you leave. Pure state and time arithmetic; the app does the sounds and glow.
typedef NS_ENUM(NSInteger,SessionState){SessionIdle,SessionRunning,SessionOver,SessionAway};
@interface Session : NSObject
@property(readonly) SessionState state;
@property(readonly) NSDate *start,*end,*callBackAt;
@property(readonly) NSInteger minutes;       // the length chosen
@property NSInteger remindEvery;             // minutes between reminders after the end; 0 = never
@property(readonly) NSDate *lastReminder;
- (void)startMinutes:(NSInteger)minutes at:(NSDate *)now;
- (void)extendMinutes:(NSInteger)minutes;    // while running or over: moves the end
- (void)quietFor:(NSInteger)minutes at:(NSDate *)now;  // over: no reminder for a while
- (void)leaveAt:(NSDate *)now callBackIn:(NSInteger)minutes;  // 0 = no call back, straight to idle
- (void)stop;
// What happened since the last check: @"ended", @"reminder", @"callBack". Advances state.
- (NSArray<NSString *> *)eventsAt:(NSDate *)now;
- (NSTimeInterval)remainingAt:(NSDate *)now;  // seconds; negative past the end; to the call back while away
- (NSString *)labelAt:(NSDate *)now;          // "25", "-5" (past the end), "9" (away), "" idle
- (NSDictionary *)dictionary;
+ (instancetype)fromDictionary:(NSDictionary *)d;
@end
