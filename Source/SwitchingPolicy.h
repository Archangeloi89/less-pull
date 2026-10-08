#import <Foundation/Foundation.h>
@interface SwitchingPolicy : NSObject
@property BOOL automatic;
@property NSInteger overrideMode; // -1 means no override
@property BOOL known;
@property BOOL nightShiftOn;
- (void)observeKnown:(BOOL)known on:(BOOL)on;
- (void)selectManual:(NSInteger)mode;
- (void)resume;
- (NSInteger)automaticTarget;
@end
