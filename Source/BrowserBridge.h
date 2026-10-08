#import <Foundation/Foundation.h>
@interface BrowserBridge : NSObject
@property NSMutableDictionary *rules,*contexts;
@property (copy) void (^changed)(void);
// What a site inherits before its own rule: the app supplies the browser-level base.
@property (copy) NSDictionary *(^defaults)(NSString *browser);
- (NSDictionary *)inheritedForSite:(NSString *)site browser:(NSString *)browser;
@property int listener;
- (void)start;
- (void)stop;
- (NSDictionary *)handle:(NSDictionary *)message;
- (NSDictionary *)ruleForBrowser:(NSString *)browser base:(NSDictionary *)base site:(NSString **)site;
+ (NSString *)socketPath;
@end
