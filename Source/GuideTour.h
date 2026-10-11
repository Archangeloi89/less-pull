#import <Cocoa/Cocoa.h>
// The tour on the real Mac: the Less Pull circle leaves the menu bar, flies over the screen with a face and a pointy
// side, opens little cards with animated scenes, shows each thing for real (Grayscale and warmth only as a passing
// look, never saved), and goes home. Seven stations; a small floating bar shows them, with Slower, Next and End tour.
// GuideTour plays the stations; the app supplies what is real through GuideTourHost.

@class GuideTour;
@protocol GuideTourHost <NSObject>
- (NSRect)guideIconFrame;                 // the menu-bar circle in screen coordinates; NSZeroRect while macOS hides it
- (NSRect)guideStartFrame;                // where the tour starts (the welcome card, or the Settings window)
- (NSView *)guideScene:(NSInteger)kind;   // an animated drawing (the app's tour scenes), shown inside a card
- (void)guideLookGray:(NSInteger)gray warmth:(double)strength;  // a passing look: gray -1 none, 0 color, 1 gray; strength < 0 none
- (NSRect)guideShowExceptionPanel;        // opens the exception panel for the app in front; its frame, or NSZeroRect
- (void)guideHideExceptionPanel;
- (NSRect)guideShowSessionPanel;
- (void)guideHideSessionPanel;
- (void)guideNightPreview:(BOOL)on;
- (NSString *)guidePeekLabel;             // the Peek shortcut as shown (e.g. ⌥A), nil when there is none
- (BOOL)guidePeeking;
- (BOOL)guidePeekKept;                    // the peek was kept with a double press
- (BOOL)guideHasNotch;                    // the screen with the menu-bar circle has a notch
- (void)guideSpotEmpty:(BOOL)empty;       // while the guide is out, the menu bar shows its empty spot (a dotted circle)
- (void)guideFinished:(BOOL)completed;    // the tour ended (completed or ended early); everything it showed is already put back
@end

@interface GuideTour : NSObject
@property(weak) id<GuideTourHost> host;
@property(nonatomic,readonly) BOOL slow;
@property(nonatomic,readonly) NSInteger step,stepCount;
- (instancetype)initWithHost:(id<GuideTourHost>)host;
- (void)start;
- (void)next;                  // continue: ends a wait for your hands, or goes on to the next station
- (void)back;                  // the station before
- (void)jumpTo:(NSInteger)station;
- (void)toggleSlow;
- (void)endEarly;              // End tour: at once
- (void)stop;                  // ends at once and puts everything back, without a word
@end
