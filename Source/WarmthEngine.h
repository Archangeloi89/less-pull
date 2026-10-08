#import <Foundation/Foundation.h>
@interface WarmthEngine : NSObject
@property(nonatomic,copy) NSString *error;
- (BOOL)applyStrength:(double)strength grayscale:(BOOL)grayscale;
@property(nonatomic,readonly) BOOL transitioning;
- (void)transitionStrength:(double)strength grayscale:(BOOL)grayscale reduceMotion:(BOOL)reduce duration:(double)duration completion:(void (^)(void))completion;
- (void)cancelTransition;
- (BOOL)restore;
- (void)invalidate;
- (NSString *)diagnostics;
@end
