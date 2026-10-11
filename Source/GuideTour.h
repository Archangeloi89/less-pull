#import <Cocoa/Cocoa.h>
// The tour on the real Mac: the Less Pull circle leaves the menu bar, flies over the screen, talks in a small
// bubble, shows each thing for real (Grayscale and warmth only as a passing look, never saved), and goes home.
// GuideTour plays the steps; the app supplies what is real through GuideTourHost.

@protocol GuideTourHost <NSObject>
- (NSRect)guideIconFrame;                 // the menu-bar circle in screen coordinates; NSZeroRect while macOS hides it
- (NSRect)guideStartFrame;                // where the guide first appears (the welcome card, or the Settings window)
- (void)guideLookGray:(NSInteger)gray warmth:(double)strength;  // a passing look: gray -1 none, 0 color, 1 gray; strength < 0 none
- (NSRect)guideShowExceptionPanel;        // opens the exception panel for the app in front; its frame, or NSZeroRect
- (void)guideHideExceptionPanel;
- (NSRect)guideShowSessionPanel;
- (void)guideHideSessionPanel;
- (void)guideNightPreview:(BOOL)on;
- (NSString *)guidePeekLabel;             // the Peek shortcut as shown (e.g. ⌥A), nil when there is none
- (BOOL)guidePeeking;
- (void)guideFinished:(BOOL)completed;    // the tour ended (completed or skipped); everything it showed is already put back
@end

@interface GuideTour : NSObject
@property(weak) id<GuideTourHost> host;
@property(nonatomic) BOOL slow;
- (instancetype)initWithHost:(id<GuideTourHost>)host;
- (void)start;
- (void)stop;     // ends at once and puts everything back
@end
