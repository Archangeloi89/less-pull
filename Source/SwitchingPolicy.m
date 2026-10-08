#import "SwitchingPolicy.h"
@implementation SwitchingPolicy
- (instancetype)init {if((self=[super init]))_overrideMode=-1;return self;}
- (void)observeKnown:(BOOL)known on:(BOOL)on {
 if(!known)return;
 if(self.known&&self.nightShiftOn!=on)self.overrideMode=-1;
 self.known=YES;self.nightShiftOn=on;
}
- (void)selectManual:(NSInteger)mode {self.overrideMode=self.automatic?mode:-1;}
- (void)resume {self.overrideMode=-1;}
- (NSInteger)automaticTarget {return !self.automatic?-1:self.overrideMode>=0?self.overrideMode:!self.known?-1:self.nightShiftOn?16:1;}
@end
