#import <Cocoa/Cocoa.h>
// The tour on the real Mac: the Less Pull circle leaves the menu bar, flies over the screen with a face and a pointy
// side, opens little cards with animated scenes, shows each thing for real (Grayscale and warmth only as a passing
// look, never saved), and goes home. GuideTour plays the steps; the app supplies what is real through GuideTourHost.

@class GuideTour;
@protocol GuideTourHost <NSObject>
- (NSRect)guideIconFrame;                 // the menu-bar circle in screen coordinates; NSZeroRect while macOS hides it
- (NSRect)guideStartFrame;                // where the guide first appears (the welcome card, or the Settings window)
- (NSRect)guideSettingsFrame;             // the Settings window, so cards and bubbles keep clear of the tour controls in it
- (NSView *)guideScene:(NSInteger)kind;   // an animated drawing (the app's tour scenes), shown inside a card
- (void)guideLookGray:(NSInteger)gray warmth:(double)strength;  // a passing look: gray -1 none, 0 color, 1 gray; strength < 0 none
- (NSRect)guideShowExceptionPanel;        // opens the exception panel for the app in front; its frame, or NSZeroRect
- (void)guideHideExceptionPanel;
- (NSRect)guideShowSessionPanel;
- (void)guideHideSessionPanel;
- (void)guideNightPreview:(BOOL)on;
- (NSString *)guidePeekLabel;             // the Peek shortcut as shown (e.g. ⌥A), nil when there is none
- (BOOL)guidePeeking;
- (BOOL)guidePeekKept;                   // the peek was kept with a double press
- (BOOL)guideHasNotch;                   // the screen with the menu-bar circle has a notch
- (NSRect)guideControlFrame:(NSString *)which;  // "card", "slower" or "next" in the Settings window, screen coordinates
- (void)guideSpotEmpty:(BOOL)empty;      // while the guide is out, the menu bar shows its empty spot (a dotted circle)
- (void)guideProgress:(GuideTour *)tour;  // step or pace changed: update the tour controls in the Settings window
- (void)guideFinished:(BOOL)completed;    // the tour ended (completed or skipped); everything it showed is already put back
@end

@interface GuideTour : NSObject
@property(weak) id<GuideTourHost> host;
@property(nonatomic,readonly) BOOL slow;
@property(nonatomic,readonly) NSInteger step,stepCount;
- (instancetype)initWithHost:(id<GuideTourHost>)host;
- (void)start;
- (void)next;
- (void)back;
- (void)toggleSlow;
- (void)endEarly;  // End tour: a short goodbye, then home
- (void)stop;     // ends at once and puts everything back
@end
