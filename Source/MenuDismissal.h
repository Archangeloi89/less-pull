#import <Cocoa/Cocoa.h>
@interface MenuDismissal : NSObject
@property (weak) NSMenu *menu;
@property id localMonitor,globalMonitor;
- (void)begin:(NSMenu *)menu;
- (void)end;
- (void)cancel;
+ (BOOL)shouldDismissPoint:(NSPoint)point menuFrames:(NSArray<NSValue *> *)frames;
@end
