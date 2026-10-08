#import <Foundation/Foundation.h>
@interface BrowserBridge : NSObject
@property NSMutableDictionary *rules,*contexts;
@property (copy) void (^changed)(void);
@property int listener;
- (void)start;
- (void)stop;
- (NSDictionary *)handle:(NSDictionary *)message;
- (NSDictionary *)ruleForBrowser:(NSString *)browser base:(NSDictionary *)base site:(NSString **)site;
+ (NSString *)socketPath;
@end
