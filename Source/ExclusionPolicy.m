#import "ExclusionPolicy.h"
@implementation ExclusionPolicy
- (void)beginKnown:(BOOL)known on:(BOOL)on guard:(PausePolicy *)guard {self.active=YES;self.scheduleWindowKnown=NO;self.known=known;self.desiredOn=known&&on;self.guard=self.desiredOn?guard:nil;}
- (void)observeKnown:(BOOL)known actualOn:(BOOL)on expectedOn:(BOOL)expected guard:(PausePolicy *)guard unchanged:(BOOL)unchanged date:(NSDate *)date calendar:(NSCalendar *)calendar {
 if(!known)return;self.known=YES;
 if(on!=expected){self.desiredOn=on;self.guard=on?guard:nil;return;}
 if(self.desiredOn&&(!unchanged||![self.guard mayResumeAt:date calendar:calendar])){self.desiredOn=NO;self.guard=nil;}
}
- (void)observeScheduleWindow:(BOOL)windowOn {if(self.scheduleWindowKnown&&self.scheduleWindowOn!=windowOn)self.desiredOn=windowOn;self.scheduleWindowKnown=YES;self.scheduleWindowOn=windowOn;}
- (void)requestOn:(BOOL)on guard:(PausePolicy *)guard {self.known=YES;self.desiredOn=on;self.guard=on?guard:nil;}
- (BOOL)mayRestoreAt:(NSDate *)date unchanged:(BOOL)unchanged calendar:(NSCalendar *)calendar {return self.known&&self.desiredOn&&unchanged&&[self.guard mayResumeAt:date calendar:calendar];}
- (NSDictionary *)dictionary {NSMutableDictionary *d=[@{@"active":@(self.active),@"known":@(self.known),@"desiredOn":@(self.desiredOn),@"windowKnown":@(self.scheduleWindowKnown),@"windowOn":@(self.scheduleWindowOn)} mutableCopy];if(self.guard)d[@"guard"]=self.guard.dictionary;return d;}
+ (instancetype)fromDictionary:(NSDictionary *)d {if(![d isKindOfClass:NSDictionary.class]||![d[@"active"] boolValue])return nil;ExclusionPolicy *p=[self new];p.active=YES;p.known=[d[@"known"] boolValue];p.desiredOn=[d[@"desiredOn"] boolValue];p.scheduleWindowKnown=[d[@"windowKnown"] boolValue];p.scheduleWindowOn=[d[@"windowOn"] boolValue];p.guard=[PausePolicy fromDictionary:d[@"guard"]];return p;}
@end
