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
- (NSRect)guideSettingsFrame;             // the Settings window the tour started from (it turns into the tour bar and back); NSZeroRect: none
- (NSImage *)guideSettingsSnapshot;       // how it looks, for the change into the bar
- (void)guideShowSettings:(BOOL)show;
- (BOOL)guideChangedSomething;            // the user changed a setting on the tour (the playing field)
- (void)guideKeepChanges:(BOOL)keep;      // the answer at the end: keep what was set, or put everything back
- (id)guideValue:(NSString *)key;         // what is real now (menuOpen, paused, warmth, frontApp, appException, site, browsers, …)
- (NSRect)guideFrame:(NSString *)key;     // where a real thing is on screen (icon, menu, menu.warmth, panel.gray, session.notnow, …)
- (void)guideDo:(NSString *)action with:(id)argument;  // the few things the guide does itself (pause, mark, the setups you said yes to)
- (void)guideFinished:(BOOL)completed;    // the tour ended (completed or ended early); everything it showed is already put back
@end

@interface GuideTour : NSObject
@property(weak) id<GuideTourHost> host;
@property(nonatomic,readonly) BOOL slow;
@property(nonatomic,readonly) NSInteger step,stepCount;
- (instancetype)initWithHost:(id<GuideTourHost>)host;
- (void)start;
- (void)startHelper:(NSString *)kind with:(id)argument;  // one thing outside the tour: @"browser" (a browser dictionary: id, name) or @"sunset"
- (void)next;                  // continue: ends a wait for your hands, or goes on to the next station
- (void)back;                  // the stop before
- (void)lineBack;              // ←: one line back, within the stop
- (void)arrowKey:(NSInteger)direction;  // the real ← (-1) or → (1) key, while the tour has them
- (void)jumpTo:(NSInteger)station;
- (void)toggleSlow;
- (void)endEarly;              // End tour: at once
- (void)stop;                  // ends at once and puts everything back, without a word
- (NSString *)debugState;      // for tests: where the tip, the bubble and the ring are now (screen coordinates)
- (void)debugPark;             // for tests: goes to its waiting spot by the tour bar with a browser line
- (void)debugTick:(NSInteger)box;  // for tests: ticks a box in the question that is up
- (void)debugAnswer:(NSInteger)button;
- (void)debugPoke;             // for tests: a click on the guide  // for tests: presses an answer button of the question that is up
@end
