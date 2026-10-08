#import <Foundation/Foundation.h>
@interface WarmthEngine : NSObject
@property(nonatomic,copy) NSString *error;
// Per-display mode: the app addresses every connected display on its own; fades run on each
// display's own refresh clock. Off (the default, used by the tests), one matrix goes to all displays.
@property(nonatomic) BOOL perDisplay;
// The displays to address: their CGDirectDisplayIDs, or @[@0] (all displays at once) when perDisplay is off.
- (NSArray<NSNumber *> *)displays;
- (BOOL)applyStrength:(double)strength grayscale:(BOOL)grayscale;
- (BOOL)applyStrength:(double)strength grayscale:(BOOL)grayscale display:(uint32_t)display;
@property(nonatomic,readonly) BOOL transitioning;
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion;
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale display:(uint32_t)display reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion;
// What the engine last set for a display (strength, grayscale), or nil if nothing yet.
- (NSArray<NSNumber *> *)stateForDisplay:(uint32_t)display;
- (void)cancelTransition;
- (BOOL)restore;
- (void)invalidate;
- (NSString *)diagnostics;
@end
