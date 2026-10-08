#import <Foundation/Foundation.h>
typedef struct { int hour, minute; } NSTimePair;
typedef struct { BOOL active, enabled, sunSchedulePermitted; int mode; struct { NSTimePair from,to; } schedule; unsigned long long disableFlags; BOOL available; } NSBlueStatus;
@interface NSObject (NightShiftPrivate)
- (BOOL)getBlueLightStatus:(NSBlueStatus *)status;
- (BOOL)supported;
- (BOOL)setEnabled:(BOOL)enabled;
- (void)setStatusNotificationBlock:(id)block;
@end
@interface FilterEngine : NSObject
@property(nonatomic,strong) id client;
@property(nonatomic,copy) NSString *error;
@property(nonatomic,copy) void (^changed)(void);
- (BOOL)nightShift:(BOOL *)enabled;
- (BOOL)readNightShiftStatus:(NSBlueStatus *)status;
- (BOOL)setNightShiftEnabled:(BOOL)enabled;
- (BOOL)applyMode:(NSInteger)mode; // 0 Natural, 1 Grayscale, 16 saved tint
- (NSInteger)currentMode;
- (NSString *)diagnostics;
@end
