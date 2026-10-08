#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Engine.h"
#import "SwitchingPolicy.h"
#import "WarmthEngine.h"
#import "PausePolicy.h"
#import "ExclusionPolicy.h"
#import "BrowserBridge.h"
#import "Session.h"
#import <QuartzCore/QuartzCore.h>
#import "MenuDismissal.h"
#import <Carbon/Carbon.h>
#import "WarmthCurve.h"
// Peek in color: a global shortcut held down shows the plain display. The shortcut
// is stored as a key code plus Carbon modifiers; there is no default binding.
@interface PeekShortcut : NSObject
+ (BOOL)isValidKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers;
+ (UInt32)carbonModifiers:(NSEventModifierFlags)modifiers;
+ (NSString *)labelForKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers;
+ (NSSet<NSString *> *)systemShortcutKeys;
+ (NSDictionary *)suggestionAvoiding:(NSSet<NSString *> *)taken preferring:(NSArray<NSDictionary *> *)candidates;
+ (NSString *)keyForKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers;
@end
@implementation PeekShortcut
+ (BOOL)isValidKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers {
 NSEventModifierFlags m=modifiers&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift);
 if(keyCode<0||keyCode>127||keyCode==kVK_Escape)return NO;
 return (m&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))!=0; // Shift alone would clash with typing
}
+ (UInt32)carbonModifiers:(NSEventModifierFlags)modifiers {UInt32 c=0;if(modifiers&NSEventModifierFlagCommand)c|=cmdKey;if(modifiers&NSEventModifierFlagControl)c|=controlKey;if(modifiers&NSEventModifierFlagOption)c|=optionKey;if(modifiers&NSEventModifierFlagShift)c|=shiftKey;return c;}
+ (NSString *)keyName:(NSInteger)keyCode {
 NSDictionary *special=@{@(kVK_Space):@"Space",@(kVK_Return):@"↩",@(kVK_Tab):@"⇥",@(kVK_Delete):@"⌫",@(kVK_ForwardDelete):@"⌦",@(kVK_LeftArrow):@"←",@(kVK_RightArrow):@"→",@(kVK_UpArrow):@"↑",@(kVK_DownArrow):@"↓",@(kVK_Home):@"↖",@(kVK_End):@"↘",@(kVK_PageUp):@"⇞",@(kVK_PageDown):@"⇟",@(kVK_F1):@"F1",@(kVK_F2):@"F2",@(kVK_F3):@"F3",@(kVK_F4):@"F4",@(kVK_F5):@"F5",@(kVK_F6):@"F6",@(kVK_F7):@"F7",@(kVK_F8):@"F8",@(kVK_F9):@"F9",@(kVK_F10):@"F10",@(kVK_F11):@"F11",@(kVK_F12):@"F12"};
 if(special[@(keyCode)])return special[@(keyCode)];
 TISInputSourceRef source=TISCopyCurrentKeyboardLayoutInputSource();CFDataRef layout=source?TISGetInputSourceProperty(source,kTISPropertyUnicodeKeyLayoutData):NULL;NSString *name=nil;
 if(layout){UInt32 dead=0;UniChar chars[4];UniCharCount length=0;if(UCKeyTranslate((const UCKeyboardLayout *)CFDataGetBytePtr(layout),(UInt16)keyCode,kUCKeyActionDisplay,0,LMGetKbdType(),kUCKeyTranslateNoDeadKeysBit,&dead,4,&length,chars)==noErr&&length)name=[[NSString stringWithCharacters:chars length:length] uppercaseString];}
 if(source)CFRelease(source);return name.length?name:[NSString stringWithFormat:@"Key %ld",(long)keyCode];
}
+ (NSString *)keyForKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers {return [NSString stringWithFormat:@"%ld/%lu",(long)keyCode,(unsigned long)(modifiers&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift))];}
// The shortcuts macOS itself has enabled (Spotlight, screenshots, input sources…),
// read from the symbolic hot keys preference so a suggestion never collides with them.
+ (NSSet<NSString *> *)systemShortcutKeys {
 NSMutableSet *keys=[NSMutableSet new];NSDictionary *all=[[NSUserDefaults.standardUserDefaults persistentDomainForName:@"com.apple.symbolichotkeys"][@"AppleSymbolicHotKeys"] isKindOfClass:NSDictionary.class]?[NSUserDefaults.standardUserDefaults persistentDomainForName:@"com.apple.symbolichotkeys"][@"AppleSymbolicHotKeys"]:@{};
 for(id entry in all.allValues){if(![entry isKindOfClass:NSDictionary.class]||![entry[@"enabled"] boolValue])continue;NSArray *p=entry[@"value"][@"parameters"];if(![p isKindOfClass:NSArray.class]||p.count<3)continue;NSInteger code=[p[1] integerValue];if(code<0||code>127)continue;[keys addObject:[self keyForKeyCode:code modifiers:[p[2] integerValue]]];}
 return keys;
}
// First candidate that is neither a macOS shortcut nor already taken in Less Pull.
+ (NSDictionary *)suggestionAvoiding:(NSSet<NSString *> *)taken preferring:(NSArray<NSDictionary *> *)candidates {
 NSSet *system=[self systemShortcutKeys];
 for(NSDictionary *c in candidates){NSString *key=[self keyForKeyCode:[c[@"keyCode"] integerValue] modifiers:[c[@"modifiers"] integerValue]];if(![system containsObject:key]&&![taken containsObject:key]&&[self isValidKeyCode:[c[@"keyCode"] integerValue] modifiers:[c[@"modifiers"] integerValue]])return c;}
 return nil;
}
+ (NSString *)labelForKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers {
 NSMutableString *label=[NSMutableString new];if(modifiers&NSEventModifierFlagControl)[label appendString:@"⌃"];if(modifiers&NSEventModifierFlagOption)[label appendString:@"⌥"];if(modifiers&NSEventModifierFlagShift)[label appendString:@"⇧"];if(modifiers&NSEventModifierFlagCommand)[label appendString:@"⌘"];
 [label appendString:[self keyName:keyCode]];return label;
}
@end
// A button that records the next key combination while it has focus.
@interface ShortcutRecorder : NSButton
@property BOOL recording;
@property (copy) void (^recorded)(NSInteger keyCode,NSEventModifierFlags modifiers);
@property (copy) void (^cleared)(void);
@end
@implementation ShortcutRecorder
- (BOOL)acceptsFirstResponder {return YES;}
- (BOOL)becomeFirstResponder {return YES;}
- (BOOL)resignFirstResponder {if(self.recording){self.recording=NO;[self sendAction:self.action to:self.target];}return [super resignFirstResponder];}
- (BOOL)performKeyEquivalent:(NSEvent *)event {if(self.recording){[self keyDown:event];return YES;}return [super performKeyEquivalent:event];}
- (void)keyDown:(NSEvent *)event {
 if(!self.recording){[super keyDown:event];return;}
 NSEventModifierFlags m=event.modifierFlags&NSEventModifierFlagDeviceIndependentFlagsMask;
 if(event.keyCode==kVK_Escape){self.recording=NO;[self sendAction:self.action to:self.target];return;}
 if((event.keyCode==kVK_Delete||event.keyCode==kVK_ForwardDelete)&&!(m&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))){self.recording=NO;if(self.cleared)self.cleared();return;}
 if(![PeekShortcut isValidKeyCode:event.keyCode modifiers:m]){NSBeep();return;}
 self.recording=NO;if(self.recorded)self.recorded(event.keyCode,m);
}
- (void)flagsChanged:(NSEvent *)event {if(!self.recording)[super flagsChanged:event];}
@end
// Update check, phase 1: one HTTPS request to GitHub's releases API, at most once
// a week or on demand. Nothing about the user is sent. Installing stays manual
// until the app is Developer ID signed and notarized.
static NSString *const LessPullReleasesAPI=@"https://api.github.com/repos/Archangeloi89/less-pull/releases/latest";
static NSString *const LessPullReleasesPage=@"https://github.com/Archangeloi89/less-pull/releases";
// The author's links. Empty entries are not shown; fill in Substack, YouTube and X when known.
static NSString *const LessPullWebsite=@"https://jiriarion.com";
static NSString *const LessPullCoffee=@"https://buymeacoffee.com/HsERf62fiZ";
static NSString *const LessPullSubstack=@"https://substack.com/@jiriarion";
static NSString *const LessPullYouTube=@"https://www.youtube.com/@JiriArion";
static NSString *const LessPullX=@"https://x.com/JiriArion";
@interface UpdateCheck : NSObject
+ (NSString *)versionFromTag:(NSString *)tag;
+ (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b;
+ (NSDictionary *)updateFromRelease:(id)release currentVersion:(NSString *)current;
+ (NSInteger)buildFromTag:(NSString *)tag;
+ (NSDictionary *)updateFromRelease:(id)release currentVersion:(NSString *)current currentBuild:(NSInteger)build;
+ (BOOL)metadata:(id)metadata allowsSystem:(NSOperatingSystemVersion)system;
+ (NSString *)metadataURLInRelease:(id)release;
@end
@implementation UpdateCheck
+ (NSString *)versionFromTag:(NSString *)tag {if(![tag isKindOfClass:NSString.class])return nil;NSString *t=[tag stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([t.lowercaseString hasPrefix:@"v"])t=[t substringFromIndex:1];return t.length?t:nil;}
+ (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b {
 NSArray *pa=[a componentsSeparatedByString:@"."],*pb=[b componentsSeparatedByString:@"."];NSUInteger n=MAX(pa.count,pb.count);
 for(NSUInteger i=0;i<n;i++){NSInteger x=i<pa.count?[pa[i] integerValue]:0,y=i<pb.count?[pb[i] integerValue]:0;if(x!=y)return x<y?NSOrderedAscending:NSOrderedDescending;}
 return NSOrderedSame;
}
// Releases are tagged v<version>-<build>, e.g. v1.4.4-17. The version stays 1.4.4
// for good (the author's joke); the build number is what moves.
+ (NSInteger)buildFromTag:(NSString *)tag {
 if(![tag isKindOfClass:NSString.class])return 0;NSRange dash=[tag rangeOfString:@"-" options:NSBackwardsSearch];if(dash.location==NSNotFound)return 0;
 NSString *digits=[tag substringFromIndex:dash.location+1];if(!digits.length||[digits rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound)return 0;return digits.integerValue;
}
+ (NSString *)metadataURLInRelease:(id)release {
 for(id asset in [release[@"assets"] isKindOfClass:NSArray.class]?release[@"assets"]:@[]){if([asset isKindOfClass:NSDictionary.class]&&[asset[@"name"] isEqual:@"lesspull-update.json"]&&[asset[@"browser_download_url"] isKindOfClass:NSString.class]&&[asset[@"browser_download_url"] hasPrefix:@"https://github.com/"])return asset[@"browser_download_url"];}
 return nil;
}
// Only a build made for this macOS is offered: minimumSystemVersion and
// maximumSystemVersion (either optional) bound the running system, major.minor.
+ (BOOL)metadata:(id)metadata allowsSystem:(NSOperatingSystemVersion)system {
 if(![metadata isKindOfClass:NSDictionary.class])return YES;NSString *running=[NSString stringWithFormat:@"%ld.%ld.%ld",(long)system.majorVersion,(long)system.minorVersion,(long)system.patchVersion];
 NSString *minimum=metadata[@"minimumSystemVersion"],*maximum=metadata[@"maximumSystemVersion"];
 if([minimum isKindOfClass:NSString.class]&&minimum.length&&[self compareVersion:running to:minimum]==NSOrderedAscending)return NO;
 if([maximum isKindOfClass:NSString.class]&&maximum.length){NSArray *parts=[maximum componentsSeparatedByString:@"."];NSString *clipped=[[[running componentsSeparatedByString:@"."] subarrayWithRange:NSMakeRange(0,MIN(parts.count,3))] componentsJoinedByString:@"."];if([self compareVersion:clipped to:maximum]==NSOrderedDescending)return NO;}
 return YES;
}
+ (NSDictionary *)updateFromRelease:(id)release currentVersion:(NSString *)current {return [self updateFromRelease:release currentVersion:current currentBuild:0];}
+ (NSDictionary *)updateFromRelease:(id)release currentVersion:(NSString *)current currentBuild:(NSInteger)currentBuild {
 if(![release isKindOfClass:NSDictionary.class]||[release[@"draft"] boolValue]||[release[@"prerelease"] boolValue])return nil;
 NSString *version=[self versionFromTag:release[@"tag_name"]];NSInteger build=[self buildFromTag:release[@"tag_name"]];
 if(build){if(build<=currentBuild)return nil;version=[version substringToIndex:[version rangeOfString:@"-" options:NSBackwardsSearch].location];}
 else if(!version||!current||[self compareVersion:version to:current]!=NSOrderedDescending)return nil;
 NSString *url=[release[@"html_url"] isKindOfClass:NSString.class]&&[release[@"html_url"] hasPrefix:@"https://github.com/"]?release[@"html_url"]:LessPullReleasesPage;
 NSString *notes=[release[@"body"] isKindOfClass:NSString.class]?release[@"body"]:@"";if(notes.length>2000)notes=[[notes substringToIndex:2000] stringByAppendingString:@"…"];
 NSMutableDictionary *update=[@{@"version":version,@"url":url,@"notes":notes,@"build":@(build)} mutableCopy];NSString *metadata=[self metadataURLInRelease:release];if(metadata)update[@"metadata"]=metadata;return update;
}
@end
// The bundle identifier moved from local.nightshiftfilters.app to
// com.jiriarion.lesspull in build 16. Settings are copied once from the old
// preferences domain; the old domain is left in place.
static NSString *const LessPullOldBundleIdentifier=@"local.nightshiftfilters.app";
@interface PreferenceMigration : NSObject
+ (BOOL)migrateFromDomain:(NSString *)oldDomain into:(NSUserDefaults *)defaults;
@end
@implementation PreferenceMigration
+ (BOOL)migrateFromDomain:(NSString *)oldDomain into:(NSUserDefaults *)defaults {
 if([defaults objectForKey:@"unifiedWarmth"]||[defaults objectForKey:@"nightMode"]||[defaults boolForKey:@"migratedPreferences"])return NO;
 NSDictionary *old=[defaults persistentDomainForName:oldDomain];if(!old.count)return NO;
 for(NSString *key in old)if(![defaults objectForKey:key])[defaults setObject:old[key] forKey:key];
 [defaults setBool:YES forKey:@"migratedPreferences"];return YES;
}
@end
@interface ExceptionStack : NSStackView
@end
@implementation ExceptionStack
- (BOOL)isFlipped {return YES;}
@end
// The slider track shows what the slider does: the real neutral -> amber -> red
// ramp of WarmthCurve.h, i.e. what white becomes at each strength.
@interface WarmthSliderCell : NSSliderCell
@end
@implementation WarmthSliderCell
- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
 NSMutableArray *colors=[NSMutableArray new];NSMutableArray *locations=[NSMutableArray new];int steps=24;
 for(int i=0;i<=steps;i++){double gains[3];WarmthGains(3.0*i/steps,gains);[colors addObject:[NSColor colorWithSRGBRed:gains[0] green:gains[1] blue:gains[2] alpha:1]];[locations addObject:@((double)i/steps)];}
 CGFloat stops[steps+1];for(int i=0;i<=steps;i++)stops[i]=[locations[i] doubleValue];
 NSGradient *ramp=[[NSGradient alloc]initWithColors:colors atLocations:stops colorSpace:NSColorSpace.sRGBColorSpace];
 NSRect bar=NSInsetRect(rect,0,(rect.size.height-5)/2);NSBezierPath *path=[NSBezierPath bezierPathWithRoundedRect:bar xRadius:2.5 yRadius:2.5];
 [ramp drawInBezierPath:path angle:0];[[NSColor.labelColor colorWithAlphaComponent:.2] setStroke];path.lineWidth=.5;[path stroke];
}
@end
@interface AppDelegate : NSObject<NSApplicationDelegate,NSMenuDelegate,NSTextFieldDelegate>
@property NSStatusItem *item;
@property NSMenu *statusMenu;
@property BrowserBridge *browserBridge;
@property MenuDismissal *menuDismissal;
@property NSString *website;
@property FilterEngine *engine;
@property NSTimer *timer;
@property NSWindow *settings;
@property NSTextField *statusText;
@property NSButton *autoButton;
@property NSButton *loginButton;
@property NSButton *grayscaleButton,*nightButton,*resumeButton,*endPauseButton,*resetButton;
@property NSPopUpButton *pausePopup;
@property NSTextField *statusDetail;
@property BOOL automatic;
@property NSMutableDictionary *exclusionRules;
@property ExclusionPolicy *exclusion;
@property BOOL excludeGray,excludeNight,excludeWarmth,quitting,animateAppearance;
@property NSTimer *visibilityTimer;
// Per display: where the frontmost app's windows are, and for the other displays the exception of the app on top there (or the defaults).
@property NSSet<NSNumber *> *frontDisplays;
@property NSDictionary<NSNumber *,NSDictionary *> *displayOverrides;
@property NSPopUpButton *peekScopePopup;
@property NSUInteger appearanceGeneration;
@property NSInteger grayOverride,nightOverride;
@property BOOL customWarmth,forcedNightOn;
@property double appWarmth,targetStrength;
@property NSInteger effectiveMode;
@property NSString *foregroundID,*foregroundName,*exclusionError;
@property NSTabViewController *settingsTabs;
@property NSTextField *websiteStatus;
@property NSStackView *exclusionsList,*displaysList;
// Progressive disclosure: views shown only with several displays, and views shown only with Show advanced options.
@property NSMutableArray<NSView *> *multiDisplayViews,*advancedViews;
@property NSMutableSet<NSString *> *expandedRules,*seenRules;
// Sessions: the model, its one-second clock while active, the panel under the icon, the glow windows, the sound playing.
@property Session *session;
@property NSTimer *sessionTimer;
@property NSPanel *sessionPanel;
@property id sessionClickMonitor,sessionKeyMonitor;
@property NSMutableArray<NSWindow *> *glowWindows;
@property NSSound *sessionSound;
@property BOOL sessionBreath,welcomePlaced;
@property NSTextField *sessionPresetsField,*callBackPresetsField;
@property NSTextField *exclusionText;
@property NSRunningApplication *lastExternalApp;
@property SwitchingPolicy *policy;
@property WarmthEngine *warmth;
@property NSInteger selectedMode;
@property NSSlider *warmthSlider;
@property NSTextField *warmthLabel;
@property NSTextField *menuWarmthReadout,*warmthTitle;
@property NSString *status;
@property PausePolicy *pause;
@property BOOL handlingPause;
@property BOOL suppressPauseCancellation;
@property NSTimer *pauseTimer,*eventTimer,*pipelineRecoveryTimer;
@property NSUInteger pipelineEvents,pipelineRestorations;
@property NSWindow *helpWindow;
@property NSString *statusImageName;
@property NSView *welcomeCard;
@property NSDate *pausedUntil; // nil: not paused; distantFuture: until resumed
@property BOOL websiteScopeExact; // menu: whole domain (NO) or this exact page (YES)
@property (nonatomic) BOOL peeking;
@property BOOL peekLocked,peekIgnoreRelease;
// Per display: the display with the window you are using, and the displays whose peek is kept by a double press.
@property uint32_t activeDisplay,peekDisplay;
// The app in front shows on every display (a 3D player, a presenter): its settings and Peek cover all displays.
@property BOOL frontSpansAll,frontPeekSpansAll;
@property NSSet<NSNumber *> *frontPeekDisplays; // explicit displays Peek toggles for the app in front, or nil
@property NSMutableSet<NSNumber *> *peekLockedDisplays;
@property NSTimeInterval lastPeekPress;
@property NSDictionary *availableUpdate;
@property NSString *updateStatus;
@property BOOL checkingUpdates;
@property NSTimer *updateTimer;
@property NSButton *updateCheckbox,*updateButton;
@property NSTextField *updateStatusLabel;
@property NSView *thanksCard;
@property BOOL thanksWanted;
@property EventHotKeyRef peekHotKey;
@property EventHotKeyRef grayscaleHotKey;
@property ShortcutRecorder *peekRecorder,*grayscaleRecorder;
@property NSTextField *peekNote,*loginNote,*grayscaleShortcutNote;
@property NSButton *peekGrayButton,*peekWarmthButton,*peekNightButton;
@property NSPopUpButton *clickPopup,*grayOffPopup;
@property NSButton *grayOnButton;
@property NSDate *grayOffUntil; // nil: not timed off; distantFuture: until Night Shift next changes
@property NSTimer *grayOffTimer;
@property BOOL lastNightForGrayOff;
@property NSTimer *pauseAllTimer;
@property NSMenu *addAppMenu;
@property NSStackView *websiteRulesList;
@property BOOL welcomeWanted;
@property NSStackView *tourCard;
@property NSInteger tourPage;
@property CGFloat tourHeight;
@end
// The warm bloom drawn behind the glow text: a radial gradient from a soft amber center to nothing.
@interface GlowView : NSView
@end
// A small looping drawing for the welcome: a menu bar that is full, with icons tucked behind a »,
// and the circle being dragged toward the clock with ⌘ held. Still under Reduce Motion.
@interface WelcomeHintView : NSView
@property NSTimer *timer;
@property NSTimeInterval start;
@end
@implementation WelcomeHintView
- (NSSize)intrinsicContentSize {return NSMakeSize(420,52);}
- (void)viewDidMoveToWindow {[self.timer invalidate];self.timer=nil;if(!self.window||NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion)return;self.start=NSProcessInfo.processInfo.systemUptime;__weak WelcomeHintView *weak=self;self.timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *t){[weak setNeedsDisplay:YES];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];}
- (void)drawRect:(NSRect)dirty {
 NSRect b=self.bounds;NSRect bar=NSMakeRect(0,b.size.height-30,b.size.width,26);[[NSColor.labelColor colorWithAlphaComponent:.08] setFill];[[NSBezierPath bezierPathWithRoundedRect:bar xRadius:7 yRadius:7] fill];
 double loop=6.0,t=self.timer?fmod(NSProcessInfo.processInfo.systemUptime-self.start,loop)/loop:0.55;  // 0…1 through one loop
 double k=t<.15?0:t<.75?(t-.15)/.6:1;k=k*k*(3-2*k);
 CGFloat y=NSMidY(bar),right=NSMaxX(bar)-10;NSColor *ink=NSColor.labelColor;
 NSDictionary *clock=@{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightMedium],NSForegroundColorAttributeName:ink};NSString *time=@"Thu 9:41";NSSize ts=[time sizeWithAttributes:clock];[time drawAtPoint:NSMakePoint(right-ts.width,y-ts.height/2) withAttributes:clock];
 CGFloat x=right-ts.width-14;for(int i=0;i<3;i++){NSRect d=NSMakeRect(x-12,y-6,12,12);[[ink colorWithAlphaComponent:.6] setFill];[[NSBezierPath bezierPathWithRoundedRect:d xRadius:3 yRadius:3] fill];x-=20;}
 CGFloat chevronX=x-6;NSDictionary *chev=@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:[ink colorWithAlphaComponent:.55]};[@"»" drawAtPoint:NSMakePoint(chevronX-8,y-9) withAttributes:chev];
 CGFloat hiddenStart=NSMinX(bar)+12,circleFrom=hiddenStart+8,circleTo=x-30;
 for(int i=0;i<4;i++){NSRect d=NSMakeRect(hiddenStart+28+i*20,y-6,12,12);[[ink colorWithAlphaComponent:.18] setFill];[[NSBezierPath bezierPathWithRoundedRect:d xRadius:3 yRadius:3] fill];}  // the ones that do not fit, faded
 CGFloat cx=circleFrom+(circleTo-circleFrom)*k;NSRect c=NSMakeRect(cx-7,y-7,14,14);NSBezierPath *o=[NSBezierPath bezierPathWithOvalInRect:c];[NSGraphicsContext saveGraphicsState];NSRect half=c;half.size.width/=2;[[NSBezierPath bezierPathWithRect:half] addClip];[ink setFill];[o fill];[NSGraphicsContext restoreGraphicsState];[ink setStroke];o.lineWidth=1.3;[o stroke];
 // the pointer, with ⌘ held, riding along
 NSBezierPath *arrow=[NSBezierPath new];NSPoint p=NSMakePoint(cx+4,y-5);[arrow moveToPoint:p];[arrow lineToPoint:NSMakePoint(p.x,p.y-13)];[arrow lineToPoint:NSMakePoint(p.x+3.5,p.y-10)];[arrow lineToPoint:NSMakePoint(p.x+6,p.y-15)];[arrow lineToPoint:NSMakePoint(p.x+8,p.y-14)];[arrow lineToPoint:NSMakePoint(p.x+5.5,p.y-9)];[arrow lineToPoint:NSMakePoint(p.x+10,p.y-9)];[arrow closePath];[NSColor.windowBackgroundColor setFill];[arrow fill];[ink setStroke];arrow.lineWidth=1;[arrow stroke];
 NSDictionary *key=@{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightMedium],NSForegroundColorAttributeName:ink};NSRect cap=NSMakeRect(cx+14,y-24,22,16);[[ink colorWithAlphaComponent:.12] setFill];[[NSBezierPath bezierPathWithRoundedRect:cap xRadius:4 yRadius:4] fill];[@"⌘" drawAtPoint:NSMakePoint(cap.origin.x+6,cap.origin.y+1) withAttributes:key];
}
@end
@implementation GlowView
- (void)drawRect:(NSRect)dirty {NSGradient *g=[[NSGradient alloc]initWithColorsAndLocations:[NSColor colorWithSRGBRed:1 green:.78 blue:.52 alpha:.42],0.0,[NSColor colorWithSRGBRed:1 green:.72 blue:.45 alpha:.18],0.45,[NSColor colorWithSRGBRed:1 green:.7 blue:.4 alpha:0],1.0,nil];[g drawInRect:self.bounds relativeCenterPosition:NSZeroPoint];}
@end
// For the tour's exceptions page: a browser window whose site name travels along an arrow up into the
// menu-bar circle, where "Exception for news.example" appears. That is all the extension does. Still under Reduce Motion.
@interface ExtensionHintView : NSView
@property NSTimer *timer;
@property NSTimeInterval start;
@end
@implementation ExtensionHintView
- (NSSize)intrinsicContentSize {return NSMakeSize(420,74);}
- (void)viewDidMoveToWindow {[self.timer invalidate];self.timer=nil;if(!self.window||NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion)return;self.start=NSProcessInfo.processInfo.systemUptime;__weak ExtensionHintView *weak=self;self.timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *t){[weak setNeedsDisplay:YES];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];}
- (void)drawRect:(NSRect)dirty {
 NSRect b=self.bounds;NSColor *ink=NSColor.labelColor;double loop=5.0,t=self.timer?fmod(NSProcessInfo.processInfo.systemUptime-self.start,loop)/loop:0.7;
 // the browser window, bottom left
 NSRect win=NSMakeRect(0,0,200,50);[[ink colorWithAlphaComponent:.08] setFill];[[NSBezierPath bezierPathWithRoundedRect:win xRadius:7 yRadius:7] fill];
 for(int i=0;i<3;i++){[[ink colorWithAlphaComponent:.35] setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8+i*11,38,6,6)] fill];}
 NSRect field=NSMakeRect(44,35,146,12);[[ink colorWithAlphaComponent:.12] setFill];[[NSBezierPath bezierPathWithRoundedRect:field xRadius:4 yRadius:4] fill];
 NSDictionary *small=@{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium],NSForegroundColorAttributeName:[ink colorWithAlphaComponent:.8]};[@"news.example" drawAtPoint:NSMakePoint(50,36) withAttributes:small];
 for(int i=0;i<3;i++){[[ink colorWithAlphaComponent:.14] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(10,24-i*8,160-i*30,4) xRadius:2 yRadius:2] fill];}
 // the menu bar, top right, with the circle and the menu line that appears
 NSRect bar=NSMakeRect(220,b.size.height-24,200,22);[[ink colorWithAlphaComponent:.08] setFill];[[NSBezierPath bezierPathWithRoundedRect:bar xRadius:6 yRadius:6] fill];
 NSPoint cc=NSMakePoint(NSMaxX(bar)-60,NSMidY(bar));NSRect c=NSMakeRect(cc.x-7,cc.y-7,14,14);NSBezierPath *o=[NSBezierPath bezierPathWithOvalInRect:c];[NSGraphicsContext saveGraphicsState];NSRect half=c;half.size.width/=2;[[NSBezierPath bezierPathWithRect:half] addClip];[ink setFill];[o fill];[NSGraphicsContext restoreGraphicsState];[ink setStroke];o.lineWidth=1.3;[o stroke];
 for(int i=0;i<2;i++){[[ink colorWithAlphaComponent:.5] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(NSMaxX(bar)-36+i*16,cc.y-5,10,10) xRadius:3 yRadius:3] fill];}
 // the arrow from the address field to the circle, drawn over time, with the site name riding along it
 NSPoint from=NSMakePoint(NSMaxX(field)+6,NSMidY(field)),to=NSMakePoint(cc.x-10,cc.y-2);double k=t<.1?0:t<.55?(t-.1)/.45:1;k=k*k*(3-2*k);
 NSBezierPath *path=[NSBezierPath new];[path moveToPoint:from];NSPoint ctrl=NSMakePoint((from.x+to.x)/2,to.y+10);NSPoint end=NSMakePoint(from.x+(to.x-from.x)*k,from.y+(to.y-from.y)*k);
 // a quadratic curve evaluated by hand so the drawn part grows
 [path removeAllPoints];NSPoint prev=from;[path moveToPoint:from];for(int i=1;i<=30;i++){double u=(double)i/30*k;NSPoint q=NSMakePoint((1-u)*(1-u)*from.x+2*(1-u)*u*ctrl.x+u*u*to.x,(1-u)*(1-u)*from.y+2*(1-u)*u*ctrl.y+u*u*to.y);[path lineToPoint:q];prev=q;}
 [[ink colorWithAlphaComponent:.6] setStroke];path.lineWidth=1.5;path.lineCapStyle=NSLineCapStyleRound;[path stroke];(void)end;
 if(k>.02){NSRect chip=NSMakeRect(prev.x-30,prev.y+6,60,13);[[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:.9] setFill];[[NSBezierPath bezierPathWithRoundedRect:chip xRadius:6 yRadius:6] fill];NSDictionary *chipText=@{NSFontAttributeName:[NSFont systemFontOfSize:8 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:[NSColor colorWithWhite:.1 alpha:1]};[@"news.example" drawAtPoint:NSMakePoint(chip.origin.x+6,chip.origin.y+2) withAttributes:chipText];}
 double m=t<.6?0:t<.75?(t-.6)/.15:t<.92?1:(1-(t-.92)/.08);if(m>0){NSRect menu=NSMakeRect(cc.x-96,NSMinY(bar)-24,150,18);[[ink colorWithAlphaComponent:.1*m] setFill];[[NSBezierPath bezierPathWithRoundedRect:menu xRadius:5 yRadius:5] fill];NSDictionary *mt=@{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium],NSForegroundColorAttributeName:[ink colorWithAlphaComponent:m]};[@"Exception for news.example  ›" drawAtPoint:NSMakePoint(menu.origin.x+8,menu.origin.y+4) withAttributes:mt];}
}
@end
@implementation AppDelegate
- (PausePolicy *)nightGuard {
 NSBlueStatus s={0};if(![self.engine readNightShiftStatus:&s])return nil;
 PausePolicy *p=[PausePolicy new];p.created=NSDate.date;p.priorOn=YES;p.scheduleMode=s.mode;p.startMinute=s.schedule.from.hour*60+s.schedule.from.minute;p.endMinute=s.schedule.to.hour*60+s.schedule.to.minute;p.nightEnd=[PausePolicy nextMorningForDate:p.created mode:s.mode endMinute:p.endMinute calendar:NSCalendar.currentCalendar];p.expiry=p.nightEnd;return p;
}
- (BOOL)guardUnchanged:(PausePolicy *)p {
 NSBlueStatus s={0};return p&&[self.engine readNightShiftStatus:&s]&&s.mode==p.scheduleMode&&(s.mode!=2||(s.schedule.from.hour*60+s.schedule.from.minute==p.startMinute&&s.schedule.to.hour*60+s.schedule.to.minute==p.endMinute));
}
- (void)persistExclusion {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(self.exclusion.active){NSMutableDictionary *snapshot=[self.exclusion.dictionary mutableCopy];snapshot[@"forcedNightOn"]=@(self.forcedNightOn);[d setObject:snapshot forKey:@"exclusionRecovery"];}else [d removeObjectForKey:@"exclusionRecovery"];
}
- (BOOL)logicalNightShift:(BOOL *)on {
 BOOL actual=NO;BOOL known=[self.engine nightShift:&actual];if(!known)return NO;*on=self.exclusion.active&&self.exclusion.known?self.exclusion.desiredOn:actual;return YES;
}
- (BOOL)requestNightShift:(BOOL)on {
 if(self.exclusion.active&&!self.quitting){[self.exclusion requestOn:on guard:on?[self nightGuard]:nil];[self persistExclusion];BOOL actual=NO;if(![self.engine nightShift:&actual])return NO;return YES;}
 return [self.engine setNightShiftEnabled:on];
}
- (void)reconcileExclusion {
 BOOL actual=NO;BOOL known=[self.engine nightShift:&actual];self.exclusionError=nil;
 if(self.exclusion.active){[self.exclusion observeKnown:known actualOn:actual expectedOn:self.forcedNightOn guard:actual?[self nightGuard]:nil unchanged:[self guardUnchanged:self.exclusion.guard] date:NSDate.date calendar:NSCalendar.currentCalendar];}
 if(self.excludeNight&&!self.exclusion.active){[self.exclusion beginKnown:known on:actual guard:[self nightGuard]];self.forcedNightOn=actual;}
 if(self.exclusion.active){NSBlueStatus schedule={0};if([self.engine readNightShiftStatus:&schedule]&&schedule.mode==2){NSInteger minute=[NSCalendar.currentCalendar component:NSCalendarUnitHour fromDate:NSDate.date]*60+[NSCalendar.currentCalendar component:NSCalendarUnitMinute fromDate:NSDate.date];NSInteger start=schedule.schedule.from.hour*60+schedule.schedule.from.minute,end=schedule.schedule.to.hour*60+schedule.schedule.to.minute;BOOL window=start<end?(minute>=start&&minute<end):(start!=end&&(minute>=start||minute<end));BOOL previous=self.exclusion.desiredOn;[self.exclusion observeScheduleWindow:window];if(!previous&&self.exclusion.desiredOn)self.exclusion.guard=[self nightGuard];}}
 if(self.pause&&self.exclusion.active)[self.exclusion requestOn:NO guard:nil];
 if(self.excludeNight){BOOL target=self.nightOverride==1&&!self.pause;self.forcedNightOn=target;if(known&&actual!=target&&![self.engine setNightShiftEnabled:target])self.exclusionError=@"Could not change Night Shift for this app.";}
 else if(self.exclusion.active){
  if(!known){self.exclusionError=@"Night Shift is unavailable right now; Less Pull will restore it when it can.";return;}
  BOOL restore=!self.pause&&[self.exclusion mayRestoreAt:NSDate.date unchanged:[self guardUnchanged:self.exclusion.guard] calendar:NSCalendar.currentCalendar];
  if(actual!=restore&&![self.engine setNightShiftEnabled:restore]){self.exclusionError=@"Could not restore Night Shift after leaving this app.";return;}
  self.exclusion.active=NO;self.exclusion.guard=nil;
 }
 [self persistExclusion];
}
- (BOOL)hasVisibleWindow:(pid_t)pid {
 CFArrayRef array=CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly|kCGWindowListExcludeDesktopElements,kCGNullWindowID);if(!array)return NO;
 NSArray *windows=CFBridgingRelease(array);
 for(NSDictionary *w in windows){if([w[(id)kCGWindowOwnerPID] intValue]!=pid||[w[(id)kCGWindowLayer] intValue]!=0||[w[(id)kCGWindowAlpha] doubleValue]<=0)continue;CGRect rect=CGRectZero;if(CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds],&rect)&&rect.size.width>=160&&rect.size.height>=100)return YES;}
 return NO;
}
- (void)updateForeground {
 if(self.quitting)return;NSRunningApplication *app=NSWorkspace.sharedWorkspace.frontmostApplication;
 if(![app.bundleIdentifier isEqual:NSBundle.mainBundle.bundleIdentifier])self.lastExternalApp=app;
 self.foregroundID=app.bundleIdentifier?:@"";self.foregroundName=app.localizedName?:@"Current app";
 self.website=nil;NSString *site=nil;NSDictionary *appRule=RuleEnabled(self.exclusionRules[self.foregroundID])?self.exclusionRules[self.foregroundID]:nil;NSDictionary *rule=[self.browserBridge ruleForBrowser:self.foregroundID base:appRule site:&site]?:appRule;self.website=site;if(site)self.foregroundName=site;BOOL hasRule=[rule[@"grayMode"] integerValue]!=0||[rule[@"nightMode"] integerValue]!=0||[rule[@"customWarmth"] boolValue];BOOL visible=hasRule&&[self hasVisibleWindow:app.processIdentifier];
 NSInteger gray=visible?[rule[@"grayMode"] integerValue]:0,night=visible?[rule[@"nightMode"] integerValue]:0;BOOL custom=visible&&[rule[@"customWarmth"] boolValue];double warmth=custom?[rule[@"warmth"] doubleValue]:0;
 if(gray!=self.grayOverride||custom!=self.customWarmth||warmth!=self.appWarmth)self.animateAppearance=YES;
 self.grayOverride=gray;self.nightOverride=night;self.customWarmth=custom;self.appWarmth=warmth;self.excludeGray=gray==2;self.excludeNight=night!=0;self.excludeWarmth=custom&&warmth==0;
 [self updateDisplayMap:app.processIdentifier];BOOL anyRule=self.exclusionRules.count||self.browserBridge.rules.count;hasRule=hasRule||(anyRule&&[self.warmth displays].count>1);
 if(hasRule&&!self.visibilityTimer){self.visibilityTimer=[NSTimer timerWithTimeInterval:.5 target:self selector:@selector(visibilityCheck:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.visibilityTimer forMode:NSRunLoopCommonModes];}
 if(!hasRule){[self.visibilityTimer invalidate];self.visibilityTimer=nil;}
}
- (void)visibilityCheck:(id)sender {NSInteger gray=self.grayOverride,night=self.nightOverride;BOOL custom=self.customWarmth;double warmth=self.appWarmth;NSDictionary *overrides=self.displayOverrides;uint32_t active=self.activeDisplay;[self updateForeground];if(gray!=self.grayOverride||active!=self.activeDisplay||night!=self.nightOverride||custom!=self.customWarmth||warmth!=self.appWarmth||!(overrides==self.displayOverrides||[overrides isEqual:self.displayOverrides]))[self sync];}
// Settings → General → Displays: one choice per connected display. Follows what is on it (the
// default): the app in front, or the app on top there, or your defaults. Always your defaults:
// exceptions never apply there. Always plain: no grayscale and no warmth there, ever.
// Stored by display UUID, so a display keeps its choice when it is plugged in again.
- (NSString *)displayUUID:(uint32_t)display {CFUUIDRef u=CGDisplayCreateUUIDFromDisplayID(display);if(!u)return [NSString stringWithFormat:@"%u",display];NSString *s=CFBridgingRelease(CFUUIDCreateString(NULL,u));CFRelease(u);return s;}
- (NSInteger)displayMode:(uint32_t)display {return [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"displayModes"][[self displayUUID:display]] integerValue];}
- (NSString *)displayName:(uint32_t)display {for(NSScreen *s in NSScreen.screens)if([s.deviceDescription[@"NSScreenNumber"] unsignedIntValue]==display)return s.localizedName;return [NSString stringWithFormat:@"Display %u",display];}
// What to show: multi-display controls with two or more displays (or when asked for), the fine-tuning
// only with Show advanced options. Choices stay saved either way.
- (BOOL)multiDisplay {return [self.warmth displays].count>1||([self advanced]&&[NSUserDefaults.standardUserDefaults boolForKey:@"alwaysShowDisplays"]);}
- (BOOL)advanced {return [NSUserDefaults.standardUserDefaults boolForKey:@"showAdvanced"];}
- (NSView *)multi:(NSView *)v {if(!self.multiDisplayViews)self.multiDisplayViews=[NSMutableArray new];[self.multiDisplayViews addObject:v];v.hidden=![self multiDisplay];return v;}
- (NSView *)adv:(NSView *)v {if(!self.advancedViews)self.advancedViews=[NSMutableArray new];[self.advancedViews addObject:v];v.hidden=![self advanced];return v;}
- (void)applyVisibility {
 BOOL multi=[self multiDisplay],adv=[self advanced];for(NSView *v in self.multiDisplayViews)v.hidden=!multi;for(NSView *v in self.advancedViews)v.hidden=!adv;
 [self rebuildExclusionsList];[self rebuildWebsiteRulesList];[self relayoutSettings];
}
// Hidden views leave the stacks; the tabs then take their new height.
- (void)relayoutSettings {
 if(!self.settingsTabs)return;for(NSTabViewItem *item in self.settingsTabs.tabViewItems){NSView *root=item.viewController.view;NSView *content=root.subviews.firstObject;[content layoutSubtreeIfNeeded];item.viewController.preferredContentSize=NSMakeSize(500,content.fittingSize.height);}
 NSInteger i=self.settingsTabs.selectedTabViewItemIndex;self.settingsTabs.selectedTabViewItemIndex=i==0?1:0;self.settingsTabs.selectedTabViewItemIndex=i;
}
- (void)toggleAdvanced:(NSButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.state==NSControlStateValueOn forKey:@"showAdvanced"];[self applyVisibility];}
- (void)toggleAlwaysDisplays:(NSButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.state==NSControlStateValueOn forKey:@"alwaysShowDisplays"];[self refreshDisplayRows];[self applyVisibility];}
- (NSView *)advancedBlock {
 NSButton *show=[NSButton checkboxWithTitle:@"Show advanced options" target:self action:@selector(toggleAdvanced:)];show.state=[self advanced];[self helpView:show text:@"Shows the fine-tuning in every tab: what Peek turns off, what the mouse buttons do, and display options with one display. Everything keeps working as set when hidden." label:@"Show advanced options"];
 NSButton *always=[NSButton checkboxWithTitle:@"Show display options with one display" target:self action:@selector(toggleAlwaysDisplays:)];always.state=[NSUserDefaults.standardUserDefaults boolForKey:@"alwaysShowDisplays"];[self helpView:always text:@"Display options appear by themselves when two or more displays are connected. Tick this to keep them visible with one display." label:@"Show display options with one display"];
 NSStackView *column=[self column:@[show,[self adv:always],[self adv:[self note:@"Choices for apps, websites and displays stay saved while hidden, and a display keeps its choices when it is plugged in again."]]]];column.spacing=6;return column;
}
- (NSView *)displaysSection {
 NSTextField *title=[NSTextField labelWithString:@"Displays"];title.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.displaysList=[self column:@[]];self.displaysList.spacing=6;[self refreshDisplayRows];
 [self.displaysList.widthAnchor constraintEqualToConstant:452].active=YES;
 NSStackView *section=[self column:@[title,self.displaysList,[self note:@"Each display has its own matrix and its own fade. Follows what is on it: the app in front decides its display; every other display follows the app whose window is on top there, with its exception or your defaults. Peek has its own choice under Shortcuts."]]];section.spacing=6;return section;
}
- (void)refreshDisplayRows {
 NSStackView *list=self.displaysList;if(!list)return;for(NSView *v in list.arrangedSubviews.copy){[list removeArrangedSubview:v];[v removeFromSuperview];}
 NSArray *displays=[self.warmth displays];
 for(NSNumber *dn in displays){uint32_t d=dn.unsignedIntValue;if(!d)continue;
  NSTextField *name=[NSTextField labelWithString:[NSString stringWithFormat:@"%@%@",[self displayName:d],CGDisplayIsMain(d)?@" (main)":@""]];name.lineBreakMode=NSLineBreakByTruncatingTail;[name setContentCompressionResistancePriority:200 forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSPopUpButton *choice=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];[choice addItemsWithTitles:@[@"Follows what is on it",@"Always your defaults",@"Always plain, in color"]];[choice selectItemAtIndex:[self displayMode:d]];choice.tag=d;choice.target=self;choice.action=@selector(displayModeChanged:);[choice.widthAnchor constraintEqualToConstant:220].active=YES;
  [self helpView:choice text:@"What this display shows. Follows what is on it: the app in front, or the app on top here, or your defaults. Always your defaults: exceptions never apply here. Always plain: never grayscale or warmth here." label:[NSString stringWithFormat:@"%@: what it shows",[self displayName:d]]];
  NSStackView *row=[self row:@[name,[self spacer],choice]];[list addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:list.widthAnchor].active=YES;}
 if(displays.count<2){NSTextField *one=[self note:@"One display is connected. Choices for each display appear here when more are connected."];[list addArrangedSubview:one];return;}
 // Some displays draw the arrow pointer in hardware, on top of the picture, so it stays in color there. A slightly larger pointer is drawn into the picture and turns quiet too.
 NSTextField *tip=[self note:@"Arrow pointer still in color on one display? macOS draws the small arrow on top of the picture there. Make the pointer one notch larger and it turns quiet too."];
 NSButton *open=[NSButton buttonWithTitle:@"Pointer Size…" target:self action:@selector(openPointerSize:)];open.bezelStyle=NSBezelStyleInline;[self helpView:open text:@"Opens System Settings → Accessibility → Display, where Pointer size is." label:@"Open pointer size settings"];
 NSStackView *row=[self row:@[tip,open]];row.alignment=NSLayoutAttributeTop;[list addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:list.widthAnchor].active=YES;
}
- (void)openPointerSize:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display"]];}
- (void)displayModeChanged:(NSPopUpButton *)sender {NSMutableDictionary *m=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"displayModes"] mutableCopy]?:[NSMutableDictionary new];NSString *key=[self displayUUID:(uint32_t)sender.tag];if(sender.indexOfSelectedItem)m[key]=@(sender.indexOfSelectedItem);else [m removeObjectForKey:key];[NSUserDefaults.standardUserDefaults setObject:m forKey:@"displayModes"];[self updateForeground];[self sync];}
// Which display shows what: the frontmost app's windows mark its displays. On every other display the
// app whose window is on top decides (its exception, if it has one, or the defaults); an empty display
// shows the defaults. Only the frontmost app's own display carries a website rule.
- (void)updateDisplayMap:(pid_t)frontPid {
 NSArray *displays=[self.warmth displays];self.activeDisplay=CGMainDisplayID();NSDictionary *siteRule=self.website?self.browserBridge.rules[self.website]:nil;self.frontSpansAll=[self.exclusionRules[self.foregroundID][@"allDisplays"] boolValue]||[siteRule[@"allDisplays"] boolValue];id targets=[self peekTargetsOfRule:siteRule]?:[self peekTargetsOfRule:self.exclusionRules[self.foregroundID]];self.frontPeekSpansAll=[targets isEqual:@"all"];self.frontPeekDisplays=nil;
 if([targets isKindOfClass:NSArray.class]){NSMutableSet *ids=[NSMutableSet new];for(NSNumber *dn in displays){uint32_t d=dn.unsignedIntValue;if(d&&[targets containsObject:[self displayUUID:d]])[ids addObject:dn];}self.frontPeekDisplays=ids.count?ids:nil;}if(displays.count<2||![displays.firstObject unsignedIntValue]){self.frontDisplays=nil;self.displayOverrides=@{};return;}
 if(self.frontSpansAll){self.frontDisplays=[NSSet setWithArray:displays];self.displayOverrides=@{};return;}  // this app shows on every display: its settings everywhere
 CFArrayRef array=CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly|kCGWindowListExcludeDesktopElements,kCGNullWindowID);NSArray *windows=array?CFBridgingRelease(array):@[];
 NSMutableDictionary *top=[NSMutableDictionary new];NSMutableSet *front=[NSMutableSet new];
 for(NSDictionary *w in windows){if([w[(id)kCGWindowLayer] intValue]!=0||[w[(id)kCGWindowAlpha] doubleValue]<=0)continue;CGRect rect=CGRectZero;if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)w[(id)kCGWindowBounds],&rect)||rect.size.width<160||rect.size.height<100)continue;
  for(NSNumber *d in displays){if(top[d])continue;CGRect overlap=CGRectIntersection(CGDisplayBounds(d.unsignedIntValue),rect);if(!CGRectIsNull(overlap)&&overlap.size.width>=80&&overlap.size.height>=50){top[d]=w[(id)kCGWindowOwnerPID];if([w[(id)kCGWindowOwnerPID] intValue]==frontPid&&!front.count)[front addObject:d];}}
  if(top.count==displays.count)break;}
 if(front.count)self.activeDisplay=[front.anyObject unsignedIntValue];NSMutableDictionary *overrides=[NSMutableDictionary new];
 for(NSNumber *d in displays){NSInteger mode=[self displayMode:d.unsignedIntValue];
  if(mode){overrides[d]=@{@"grayMode":@0,@"customWarmth":@NO,@"warmth":@0,@"plain":@(mode==2)};continue;}
  NSNumber *pid=top[d];if(pid&&pid.intValue==frontPid){[front addObject:d];continue;}
  NSString *bundle=pid?[NSRunningApplication runningApplicationWithProcessIdentifier:pid.intValue].bundleIdentifier:nil;NSDictionary *rule=bundle&&RuleEnabled(self.exclusionRules[bundle])?self.exclusionRules[bundle]:nil;
  overrides[d]=@{@"grayMode":@([rule[@"grayMode"] integerValue]),@"customWarmth":@([rule[@"customWarmth"] boolValue]),@"warmth":rule[@"warmth"]?:@0};}
 self.frontDisplays=front;self.displayOverrides=overrides;
}
- (void)frontmostChanged:(id)sender {[self sync];}
// The base a website inherits: the global settings as they stand, then the browser's own app exception.
- (NSDictionary *)browserBaseForBundle:(NSString *)browser {
 BOOL night=NO;[self logicalNightShift:&night];NSInteger gray=(self.selectedMode==1||self.selectedMode==100)?1:2,nightMode=night?1:2;double warmth=[self currentWarmth]/3*100;
 NSDictionary *app=browser?self.exclusionRules[browser]:nil;if([app[@"grayMode"] integerValue])gray=[app[@"grayMode"] integerValue];if([app[@"nightMode"] integerValue])nightMode=[app[@"nightMode"] integerValue];if([app[@"customWarmth"] boolValue])warmth=[app[@"warmth"] doubleValue];
 return @{@"grayMode":@(gray),@"nightMode":@(nightMode),@"warmth":@(warmth)};
}
- (NSString *)exclusionSummary {
 NSMutableArray *effects=[NSMutableArray new];if(self.grayOverride)[effects addObject:self.grayOverride==1?@"Grayscale on":@"Grayscale off"];if(self.nightOverride)[effects addObject:self.pause?@"Night Shift off for now":self.nightOverride==1?@"Night Shift on":@"Night Shift off"];if(self.customWarmth)[effects addObject:[NSString stringWithFormat:@"Warmth %.0f%%",self.appWarmth]];
 return effects.count?[NSString stringWithFormat:@"%@: %@",self.foregroundName,[effects componentsJoinedByString:@", "]]:@"Using your default settings";
}
- (NSString *)exclusionHelp {return @"An exception applies while that app is in front with a window open, on all your displays. Each setting can keep the default or get its own value. Your defaults stay saved. If Night Shift is turned off for a while, that wins over an app’s Night Shift On.";}
// An exception can be switched off and keep its settings; a rule without the flag is on.
static BOOL RuleEnabled(NSDictionary *rule) {return rule&&(rule[@"enabled"]==nil||[rule[@"enabled"] boolValue]);}
static BOOL RuleDiffers(NSDictionary *rule) {return [rule[@"grayMode"] integerValue]||[rule[@"nightMode"] integerValue]||[rule[@"customWarmth"] boolValue];}
// Any change away from default switches the exception on; the user can switch it off again.
static NSMutableDictionary *RuleAfterChange(NSDictionary *before,NSMutableDictionary *after) {if(RuleDiffers(after)&&!(RuleDiffers(before)&&!RuleEnabled(before)))after[@"enabled"]=@YES;if(after[@"enabled"]==nil)after[@"enabled"]=@(RuleDiffers(after));return after;}
- (void)saveExclusionRules {[NSUserDefaults.standardUserDefaults setObject:self.exclusionRules forKey:@"appExclusions"];[self sync];}
- (void)ruleChanged:(NSControl *)sender {
 NSString *bundle=sender.identifier;NSMutableDictionary *rule=[self.exclusionRules[bundle] mutableCopy];
 NSDictionary *before=[rule copy];
 if([sender isKindOfClass:NSSegmentedControl.class])rule[sender.tag==0?@"grayMode":@"nightMode"]=@([(NSSegmentedControl *)sender selectedSegment]);
 else if(sender.tag==2)rule[@"customWarmth"]=@([(NSButton *)sender state]==NSControlStateValueOff);
 else if(sender.tag==4)rule[@"enabled"]=@([(NSButton *)sender state]==NSControlStateValueOn);
 else if(sender.tag==5)rule[@"allDisplays"]=@([(NSButton *)sender state]==NSControlStateValueOn);
 else {rule[@"warmth"]=@([(NSSlider *)sender doubleValue]);if([(NSSlider *)sender doubleValue]>0)rule[@"customWarmth"]=@YES;}
 if(sender.tag!=4&&sender.tag!=5)RuleAfterChange(before,rule);
 self.exclusionRules[bundle]=rule;[self saveExclusionRules];if(sender.tag!=3)[self rebuildExclusionsList];else {NSTextField *readout=[sender.superview viewWithTag:99];readout.stringValue=[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]];NSView *top=sender;while(top&&![top.identifier isEqual:bundle])top=top.superview;NSButton *en=[top viewWithTag:4];if([en isKindOfClass:NSButton.class])en.state=RuleEnabled(rule);NSButton *inherit=[sender.superview viewWithTag:2];inherit.state=![rule[@"customWarmth"] boolValue];}
}
// A row opens by itself the first time it is shown with something set in its details; after that the user decides.
- (BOOL)ruleOpen:(NSString *)key rule:(NSDictionary *)rule {
 if(!self.seenRules)self.seenRules=[NSMutableSet new];if(!self.expandedRules)self.expandedRules=[NSMutableSet new];
 if(![self.seenRules containsObject:key]){[self.seenRules addObject:key];if([rule[@"customWarmth"] boolValue]||[rule[@"allDisplays"] boolValue]||[self peekTargetsOfRule:rule]!=nil)[self.expandedRules addObject:key];}
 return [self.expandedRules containsObject:key];
}
- (void)toggleRuleDetails:(NSButton *)sender {NSString *key=sender.identifier;if([self.expandedRules containsObject:key])[self.expandedRules removeObject:key];else [self.expandedRules addObject:key];[self rebuildExclusionsList];[self rebuildWebsiteRulesList];}
- (void)removeRule:(NSButton *)sender {[self.exclusionRules removeObjectForKey:sender.identifier];[self saveExclusionRules];[self rebuildExclusionsList];}
- (void)addAppURL:(NSURL *)url {
 NSBundle *bundle=[NSBundle bundleWithURL:url];NSString *identifier=bundle.bundleIdentifier;if(!identifier||[identifier isEqual:NSBundle.mainBundle.bundleIdentifier])return;
 NSString *name=[NSFileManager.defaultManager displayNameAtPath:url.path];if([name hasSuffix:@".app"])name=[name substringToIndex:name.length-4];
 if(!self.exclusionRules[identifier])self.exclusionRules[identifier]=@{@"name":name,@"grayMode":@0,@"nightMode":@0,@"customWarmth":@NO,@"warmth":@0,@"enabled":@NO};[self saveExclusionRules];[self rebuildExclusionsList];
}
- (void)addExclusionApp:(id)sender {
 NSOpenPanel *panel=[NSOpenPanel openPanel];panel.title=@"Add an app exception";panel.directoryURL=[NSURL fileURLWithPath:@"/Applications"];panel.canChooseDirectories=NO;panel.canChooseFiles=YES;panel.allowedContentTypes=@[UTTypeApplicationBundle];panel.treatsFilePackagesAsDirectories=NO;
 [panel beginSheetModalForWindow:self.settings completionHandler:^(NSModalResponse result){if(result==NSModalResponseOK)[self addAppURL:panel.URL];}];
}
- (void)excludeCurrent:(id)sender {NSURL *url=self.lastExternalApp.bundleURL;NSString *bundle=self.lastExternalApp.bundleIdentifier;[self showExclusions:nil];if(url)[self addAppURL:url];
 for(NSView *row in self.exclusionsList.arrangedSubviews)if([row.identifier isEqual:bundle]){[self.exclusionsList layoutSubtreeIfNeeded];[row scrollRectToVisible:row.bounds];break;}}
// "Exception for <App>" in the menu: change the rule for the app in front without
// opening Settings. The first change creates the rule.
- (NSMutableDictionary *)currentAppRuleCreating:(BOOL)create {
 NSString *bundle=self.lastExternalApp.bundleIdentifier;if(!bundle)return nil;if(!self.exclusionRules[bundle]){if(!create)return nil;NSURL *url=self.lastExternalApp.bundleURL;if(url)[self addAppURL:url];}
 return [self.exclusionRules[bundle] mutableCopy];
}
- (void)storeCurrentAppRule:(NSDictionary *)rule {self.exclusionRules[self.lastExternalApp.bundleIdentifier]=rule;[self saveExclusionRules];[self rebuildExclusionsList];}
- (void)currentAppChoice:(NSMenuItem *)sender {NSMutableDictionary *rule=[self currentAppRuleCreating:YES];if(!rule)return;NSDictionary *before=[rule copy];rule[sender.tag/10==0?@"grayMode":@"nightMode"]=@(sender.tag%10);[self storeCurrentAppRule:RuleAfterChange(before,rule)];}
- (void)currentAppWarmthDefault:(NSMenuItem *)sender {NSMutableDictionary *rule=[self currentAppRuleCreating:YES];if(!rule)return;NSDictionary *before=[rule copy];rule[@"customWarmth"]=@(![rule[@"customWarmth"] boolValue]);[self storeCurrentAppRule:RuleAfterChange(before,rule)];}
- (void)currentAppEnabled:(NSMenuItem *)sender {NSMutableDictionary *rule=[self currentAppRuleCreating:YES];if(!rule)return;rule[@"enabled"]=@(!RuleEnabled(rule));[self storeCurrentAppRule:rule];}
- (void)currentAppWarmthChanged:(NSSlider *)sender {NSMutableDictionary *rule=[self currentAppRuleCreating:YES];if(!rule)return;NSDictionary *before=[rule copy];rule[@"customWarmth"]=@YES;rule[@"warmth"]=@(sender.doubleValue);RuleAfterChange(before,rule);[self storeCurrentAppRule:rule];NSTextField *readout=[sender.superview viewWithTag:98];readout.stringValue=[NSString stringWithFormat:@"%.0f%%",sender.doubleValue];}
// "Exception for <website>": the same choices as for an app, for the public tab in
// front. Whole domain (also subdomains) or this exact page; saved through the bridge.
- (NSString *)websiteKeyForTab:(NSDictionary *)tab {return self.websiteScopeExact&&[tab[@"url"] length]?tab[@"url"]:tab[@"site"];}
- (NSDictionary *)websiteRuleForTab:(NSDictionary *)tab {return self.browserBridge.rules[[self websiteKeyForTab:tab]];}
- (void)storeWebsiteRule:(NSDictionary *)rule forTab:(NSDictionary *)tab {
 NSString *key=[self websiteKeyForTab:tab];BOOL exact=[key containsString:@"://"];
 [self.browserBridge handle:@{@"type":@"set",@"scope":exact?@"url":@"domain",@"site":key,@"rule":@{@"grayMode":rule[@"grayMode"]?:@0,@"nightMode":rule[@"nightMode"]?:@0,@"customWarmth":rule[@"customWarmth"]?:@NO,@"warmth":rule[@"warmth"]?:@0,@"enabled":@(RuleEnabled(rule)),@"allDisplays":@([rule[@"allDisplays"] boolValue]),@"peekDisplays":rule[@"peekDisplays"]?:NSNull.null}}];
}
- (NSDictionary *)menuTab {return [self.browserBridge activeContextForBrowser:self.lastExternalApp.bundleIdentifier];}
- (void)websiteScope:(NSMenuItem *)sender {self.websiteScopeExact=sender.tag==1;}
- (void)websiteChoice:(NSMenuItem *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSMutableDictionary *rule=[[self websiteRuleForTab:tab] mutableCopy]?:[NSMutableDictionary new];NSDictionary *before=[rule copy];rule[sender.tag/10==0?@"grayMode":@"nightMode"]=@(sender.tag%10);[self storeWebsiteRule:RuleAfterChange(before,rule) forTab:tab];}
- (void)websiteWarmthDefault:(NSMenuItem *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSMutableDictionary *rule=[[self websiteRuleForTab:tab] mutableCopy]?:[NSMutableDictionary new];NSDictionary *before=[rule copy];rule[@"customWarmth"]=@(![rule[@"customWarmth"] boolValue]);[self storeWebsiteRule:RuleAfterChange(before,rule) forTab:tab];}
- (void)websiteEnabled:(NSMenuItem *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSMutableDictionary *rule=[[self websiteRuleForTab:tab] mutableCopy]?:[NSMutableDictionary new];rule[@"enabled"]=@(!RuleEnabled(rule));[self storeWebsiteRule:rule forTab:tab];}
- (void)websiteWarmthChanged:(NSSlider *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSMutableDictionary *rule=[[self websiteRuleForTab:tab] mutableCopy]?:[NSMutableDictionary new];NSDictionary *before=[rule copy];rule[@"customWarmth"]=@YES;rule[@"warmth"]=@(sender.doubleValue);RuleAfterChange(before,rule);[self storeWebsiteRule:rule forTab:tab];NSTextField *readout=[sender.superview viewWithTag:98];readout.stringValue=[NSString stringWithFormat:@"%.0f%%",sender.doubleValue];}
- (void)websiteRemove:(NSMenuItem *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSString *key=[self websiteKeyForTab:tab];[self.browserBridge handle:@{@"type":@"remove",@"scope":[key containsString:@"://"]?@"url":@"domain",@"site":key}];}
- (NSMenu *)websiteMenuForTab:(NSDictionary *)tab {
 NSMenu *sub=[NSMenu new];if(!self.websiteScopeExact&&!self.browserBridge.rules[tab[@"site"]]&&self.browserBridge.rules[tab[@"url"]?:@""])self.websiteScopeExact=YES;
 NSMenuItem *enabled=[self add:@"Use this exception" action:@selector(websiteEnabled:) to:sub];enabled.state=RuleEnabled([self websiteRuleForTab:tab]);[sub addItem:NSMenuItem.separatorItem];
 NSMenuItem *scopeHead=[[NSMenuItem alloc]initWithTitle:@"Apply to" action:nil keyEquivalent:@""];scopeHead.enabled=NO;[sub addItem:scopeHead];
 NSMenuItem *domain=[self add:[NSString stringWithFormat:@"Whole domain · %@",tab[@"site"]] action:@selector(websiteScope:) to:sub];domain.tag=0;domain.indentationLevel=1;domain.state=!self.websiteScopeExact;
 NSMenuItem *page=[self add:@"This exact page" action:[tab[@"url"] length]?@selector(websiteScope:):nil to:sub];page.tag=1;page.indentationLevel=1;page.state=self.websiteScopeExact;page.enabled=[tab[@"url"] length]>0;
 [sub addItem:NSMenuItem.separatorItem];
 NSDictionary *rule=[self websiteRuleForTab:tab];NSString *key=[self websiteKeyForTab:tab];NSDictionary *inherited=[self.browserBridge inheritedForSite:key browser:self.lastExternalApp.bundleIdentifier];NSArray *words=@[@"",@"On",@"Off"];
 NSArray *titles=@[@"Grayscale",@"Night Shift"],*keys=@[@"grayMode",@"nightMode"];
 for(int i=0;i<2;i++){NSMenuItem *head=[[NSMenuItem alloc]initWithTitle:titles[i] action:nil keyEquivalent:@""];head.enabled=NO;[sub addItem:head];
  NSInteger resolved=[inherited[keys[i]] integerValue];NSArray *choices=@[[NSString stringWithFormat:@"Use default%@",resolved?[NSString stringWithFormat:@" (%@)",words[resolved]]:@""],@"On",@"Off"];
  for(int j=0;j<3;j++){NSMenuItem *item=[self add:choices[j] action:@selector(websiteChoice:) to:sub];item.tag=i*10+j;item.indentationLevel=1;item.state=[rule[keys[i]] integerValue]==j;}
  [sub addItem:NSMenuItem.separatorItem];}
 BOOL custom=[rule[@"customWarmth"] boolValue];double inheritedWarmth=[inherited[@"warmth"] doubleValue];
 NSMenuItem *inherit=[self add:[NSString stringWithFormat:@"Use default warmth (%@)",inheritedWarmth>0?[NSString stringWithFormat:@"%.0f%%",inheritedWarmth]:@"Off"] action:@selector(websiteWarmthDefault:) to:sub];inherit.state=!custom;
 NSMenuItem *sliderItem=[NSMenuItem new];NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,260,54)];
 NSTextField *label=[NSTextField labelWithString:[NSString stringWithFormat:@"Extra Warmth for %@",self.websiteScopeExact?@"this page":tab[@"site"]]];label.font=[NSFont systemFontOfSize:12];label.frame=NSMakeRect(18,34,190,16);label.lineBreakMode=NSLineBreakByTruncatingTail;[view addSubview:label];
 NSTextField *readout=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];readout.tag=98;readout.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];readout.alignment=NSTextAlignmentRight;readout.frame=NSMakeRect(204,34,40,16);[view addSubview:readout];
 NSSlider *slider=[self warmthSliderWithValue:[rule[@"warmth"] doubleValue] action:@selector(websiteWarmthChanged:)];slider.frame=NSMakeRect(18,6,226,26);[self helpView:slider text:@"Extra Warmth for this website, from Off to Red." label:[NSString stringWithFormat:@"Extra Warmth for %@, percent",key]];[view addSubview:slider];
 sliderItem.view=view;[sub addItem:sliderItem];[sub addItem:NSMenuItem.separatorItem];
 if([self multiDisplay]){NSMenuItem *span=[self add:@"On every display" action:@selector(websiteAllDisplays:) to:sub];span.state=[rule[@"allDisplays"] boolValue];
  NSMenuItem *peekSpan=[self add:[NSString stringWithFormat:@"Peek toggles: %@",[self peekTargetsLabel:rule]] action:nil to:sub];peekSpan.submenu=[self peekDisplaysMenuForKey:key website:YES];[sub addItem:NSMenuItem.separatorItem];}
 if(rule){[self add:@"Remove this exception" action:@selector(websiteRemove:) to:sub];}
 [self add:@"All website exceptions…" action:@selector(showWebsites:) to:sub];
 return sub;
}
- (NSMenu *)currentAppMenu {
 NSMenu *sub=[NSMenu new];NSDictionary *rule=[self currentAppRuleCreating:NO];NSString *name=self.lastExternalApp.localizedName?:@"this app";
 NSMenuItem *enabled=[self add:@"Use this exception" action:@selector(currentAppEnabled:) to:sub];enabled.state=RuleEnabled(rule);[sub addItem:NSMenuItem.separatorItem];
 NSArray *titles=@[@"Grayscale",@"Night Shift"],*keys=@[@"grayMode",@"nightMode"],*choices=@[@"Use default",@"On",@"Off"];
 for(int i=0;i<2;i++){NSMenuItem *head=[[NSMenuItem alloc]initWithTitle:titles[i] action:nil keyEquivalent:@""];head.enabled=NO;[sub addItem:head];
  for(int j=0;j<3;j++){NSMenuItem *item=[self add:choices[j] action:@selector(currentAppChoice:) to:sub];item.tag=i*10+j;item.indentationLevel=1;item.state=[rule[keys[i]] integerValue]==j;}
  [sub addItem:NSMenuItem.separatorItem];}
 BOOL custom=[rule[@"customWarmth"] boolValue];NSMenuItem *inherit=[self add:@"Use default warmth" action:@selector(currentAppWarmthDefault:) to:sub];inherit.state=!custom;
 NSMenuItem *sliderItem=[NSMenuItem new];NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,260,54)];
 NSTextField *label=[NSTextField labelWithString:[NSString stringWithFormat:@"Extra Warmth for %@",name]];label.font=[NSFont systemFontOfSize:12];label.frame=NSMakeRect(18,34,190,16);label.lineBreakMode=NSLineBreakByTruncatingTail;[view addSubview:label];
 NSTextField *readout=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];readout.tag=98;readout.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];readout.alignment=NSTextAlignmentRight;readout.frame=NSMakeRect(204,34,40,16);[view addSubview:readout];
 NSSlider *slider=[self warmthSliderWithValue:[rule[@"warmth"] doubleValue] action:@selector(currentAppWarmthChanged:)];slider.frame=NSMakeRect(18,6,226,26);[self helpView:slider text:[NSString stringWithFormat:@"Extra Warmth for %@, from Off to Red.",name] label:[NSString stringWithFormat:@"Extra Warmth for %@, percent",name]];[view addSubview:slider];
 sliderItem.view=view;[sub addItem:sliderItem];[sub addItem:NSMenuItem.separatorItem];
 if([self multiDisplay]){NSMenuItem *span=[self add:@"On every display" action:@selector(currentAppAllDisplays:) to:sub];span.state=[rule[@"allDisplays"] boolValue];
  NSMenuItem *peekSpan=[self add:[NSString stringWithFormat:@"Peek toggles: %@",[self peekTargetsLabel:rule]] action:nil to:sub];peekSpan.submenu=[self peekDisplaysMenuForBundle:self.lastExternalApp.bundleIdentifier];[sub addItem:NSMenuItem.separatorItem];}
 [self add:@"More in Settings…" action:@selector(excludeCurrent:) to:sub];
 return sub;
}
// Which displays Peek toggles while an app is in front: nil = the display under the pointer,
// @"all" = every display, or an array of display UUIDs (any set of connected displays).
- (id)peekTargetsOfRule:(NSDictionary *)rule {id t=rule[@"peekDisplays"];if([t isKindOfClass:NSArray.class]&&[t count])return t;if([t isEqual:@"all"]||[rule[@"peekAllDisplays"] boolValue])return @"all";return nil;}
- (NSString *)peekTargetsLabel:(NSDictionary *)rule {id t=[self peekTargetsOfRule:rule];if(!t)return @"The display under the pointer";if([t isEqual:@"all"])return @"All displays";
 NSMutableArray *names=[NSMutableArray new];for(NSNumber *dn in [self.warmth displays]){uint32_t d=dn.unsignedIntValue;if(d&&[t containsObject:[self displayUUID:d]])[names addObject:[self displayName:d]];}
 NSUInteger missing=[t count]-names.count;if(missing)[names addObject:[NSString stringWithFormat:@"%lu not connected",(unsigned long)missing]];return names.count?[names componentsJoinedByString:@", "]:@"The display under the pointer";}
- (NSMenu *)peekDisplaysMenuForBundle:(NSString *)bundle {return [self peekDisplaysMenuForKey:bundle website:NO];}
- (NSMenu *)peekDisplaysMenuForKey:(NSString *)key website:(BOOL)website {
 NSMenu *m=[NSMenu new];NSDictionary *rule=website?self.browserBridge.rules[key]:self.exclusionRules[key];id t=[self peekTargetsOfRule:rule];
 NSMenuItem *pointer=[self add:@"The display under the pointer" action:@selector(peekDisplaysChoice:) to:m];pointer.representedObject=@"pointer";pointer.identifier=key;pointer.tag=website;pointer.state=t==nil;
 NSMenuItem *all=[self add:@"All displays" action:@selector(peekDisplaysChoice:) to:m];all.representedObject=@"all";all.identifier=key;all.tag=website;all.state=[t isEqual:@"all"];[m addItem:NSMenuItem.separatorItem];
 NSMenuItem *head=[[NSMenuItem alloc]initWithTitle:@"Or any of these" action:nil keyEquivalent:@""];head.enabled=NO;[m addItem:head];
 for(NSNumber *dn in [self.warmth displays]){uint32_t d=dn.unsignedIntValue;if(!d)continue;NSString *uuid=[self displayUUID:d];NSMenuItem *item=[self add:[self displayName:d] action:@selector(peekDisplaysChoice:) to:m];item.representedObject=uuid;item.identifier=key;item.tag=website;item.indentationLevel=1;item.state=[t isKindOfClass:NSArray.class]&&[t containsObject:uuid];}
 return m;
}
- (void)peekDisplaysChoice:(NSMenuItem *)sender {
 NSString *key=sender.identifier;BOOL website=sender.tag==1;NSMutableDictionary *rule=[(website?self.browserBridge.rules[key]:self.exclusionRules[key]) mutableCopy];
 if(!rule){if(website){NSDictionary *tab=[self menuTab];if(!tab||![[self websiteKeyForTab:tab] isEqual:key])return;rule=[NSMutableDictionary new];}else {if(![key isEqual:self.lastExternalApp.bundleIdentifier])return;rule=[self currentAppRuleCreating:YES];if(!rule)return;}}
 id choice=sender.representedObject;[rule removeObjectForKey:@"peekAllDisplays"];
 if([choice isEqual:@"pointer"])[rule removeObjectForKey:@"peekDisplays"];
 else if([choice isEqual:@"all"])rule[@"peekDisplays"]=@"all";
 else {NSMutableArray *set=[[self peekTargetsOfRule:rule] isKindOfClass:NSArray.class]?[rule[@"peekDisplays"] mutableCopy]:[NSMutableArray new];if([set containsObject:choice])[set removeObject:choice];else [set addObject:choice];if(set.count)rule[@"peekDisplays"]=set;else [rule removeObjectForKey:@"peekDisplays"];}
 if(website){[self.browserBridge handle:@{@"type":@"set",@"scope":[key containsString:@"://"]?@"url":@"domain",@"site":key,@"rule":rule}];[self rebuildWebsiteRulesList];}
 else {self.exclusionRules[key]=rule;[self saveExclusionRules];[self rebuildExclusionsList];}
}
- (void)websiteAllDisplays:(NSMenuItem *)sender {NSDictionary *tab=[self menuTab];if(!tab)return;NSMutableDictionary *rule=[[self websiteRuleForTab:tab] mutableCopy]?:[NSMutableDictionary new];rule[@"allDisplays"]=@(![rule[@"allDisplays"] boolValue]);[self storeWebsiteRule:rule forTab:tab];}
- (void)currentAppAllDisplays:(NSMenuItem *)sender {NSMutableDictionary *rule=[self currentAppRuleCreating:YES];if(!rule)return;rule[@"allDisplays"]=@(![rule[@"allDisplays"] boolValue]);[self storeCurrentAppRule:rule];}
// One App Exceptions row: name and Remove, the two choices, and the app's own warmth.
- (NSView *)exceptionRowForBundle:(NSString *)bundle rule:(NSDictionary *)rule {
 NSTextField *name=[NSTextField labelWithString:rule[@"name"]?:bundle];name.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];name.toolTip=bundle;name.lineBreakMode=NSLineBreakByTruncatingTail;[name setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
 NSImageView *icon=[NSImageView imageViewWithImage:[self iconForBundle:bundle]];[icon.widthAnchor constraintEqualToConstant:28].active=YES;[icon.heightAnchor constraintEqualToConstant:28].active=YES;icon.accessibilityLabel=[NSString stringWithFormat:@"%@ icon",rule[@"name"]];
 NSButton *remove=[NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeRule:)];remove.identifier=bundle;remove.bezelStyle=NSBezelStyleInline;[self helpView:remove text:@"Remove this exception. The app then uses your default settings." label:[NSString stringWithFormat:@"Remove %@ exception",rule[@"name"]]];
 NSButton *enable=[NSButton checkboxWithTitle:@"Use this exception" target:self action:@selector(ruleChanged:)];enable.identifier=bundle;enable.tag=4;enable.state=RuleEnabled(rule);enable.font=[NSFont systemFontOfSize:12];[self helpView:enable text:@"Off keeps the settings below but does not apply them. Changing a setting away from default switches it on again." label:[NSString stringWithFormat:@"Use the exception for %@",rule[@"name"]]];enable.tag=4;
 BOOL open=[self ruleOpen:bundle rule:rule];
 NSButton *more=[NSButton buttonWithTitle:open?@"Less":@"More" target:self action:@selector(toggleRuleDetails:)];more.identifier=bundle;more.tag=7;more.bezelStyle=NSBezelStyleInline;more.font=[NSFont systemFontOfSize:11];[self helpView:more text:@"Warmth for this app and, with several displays, which displays it covers." label:[NSString stringWithFormat:@"%@ — more settings",rule[@"name"]]];
 NSStackView *header=[self row:@[icon,name,[self spacer],enable,more,remove]];
 NSMutableArray *choices=[NSMutableArray new];NSArray *titles=@[@"Grayscale",@"Night Shift"];
 for(int i=0;i<2;i++){NSTextField *label=[NSTextField labelWithString:titles[i]];NSSegmentedControl *choice=[NSSegmentedControl segmentedControlWithLabels:@[@"Default",@"On",@"Off"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(ruleChanged:)];choice.selectedSegment=[rule[i==0?@"grayMode":@"nightMode"] integerValue];choice.identifier=bundle;choice.tag=i;for(int k=0;k<3;k++)[choice setWidth:44 forSegment:k];[self helpView:choice text:[self exclusionHelp] label:[NSString stringWithFormat:@"%@ — %@",rule[@"name"],titles[i]]];[choices addObject:label];[choices addObject:choice];}
 NSStackView *modes=[self row:choices];modes.spacing=6;[modes setCustomSpacing:14 afterView:choices[1]];
 NSButton *inherit=[NSButton checkboxWithTitle:@"Use default warmth" target:self action:@selector(ruleChanged:)];inherit.identifier=bundle;inherit.tag=2;inherit.state=![rule[@"customWarmth"] boolValue];[self helpView:inherit text:@"Uncheck to give this app its own Extra Warmth. Off adds no warmth; 100% is red. Your default warmth stays saved." label:[NSString stringWithFormat:@"%@ — Use default warmth",rule[@"name"]]];
 NSSlider *slider=[self warmthSliderWithValue:[rule[@"warmth"] doubleValue] action:@selector(ruleChanged:)];slider.identifier=bundle;slider.tag=3;[slider.widthAnchor constraintGreaterThanOrEqualToConstant:180].active=YES;[slider setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[self helpView:slider text:@"Extra Warmth for this app, from Off to Red." label:[NSString stringWithFormat:@"%@ — Extra Warmth percent",rule[@"name"]]];
 NSTextField *percent=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];percent.tag=99;percent.alignment=NSTextAlignmentRight;percent.font=[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];[percent.widthAnchor constraintEqualToConstant:44].active=YES;
 NSStackView *warmth=[self row:@[inherit,slider,percent]];
 NSButton *span=[NSButton checkboxWithTitle:@"On every display" target:self action:@selector(ruleChanged:)];span.identifier=bundle;span.tag=5;span.state=[rule[@"allDisplays"] boolValue];span.font=[NSFont systemFontOfSize:12];[self helpView:span text:@"For an app whose picture also shows on another display, such as a 3D player or a presenter: while it is in front, its settings cover every display, not only the one its window is on. Works whether or not the exception is used." label:[NSString stringWithFormat:@"%@ — On every display",rule[@"name"]]];
 NSTextField *peekLabel=[NSTextField labelWithString:@"Peek toggles:"];peekLabel.font=[NSFont systemFontOfSize:12];
 NSPopUpButton *peekPick=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:YES];peekPick.font=[NSFont systemFontOfSize:12];[peekPick.widthAnchor constraintEqualToConstant:200].active=YES;
 NSMenu *pickMenu=[self peekDisplaysMenuForBundle:bundle];[pickMenu insertItem:[[NSMenuItem alloc]initWithTitle:[self peekTargetsLabel:rule] action:nil keyEquivalent:@""] atIndex:0];peekPick.menu=pickMenu;
 [self helpView:peekPick text:@"Which displays Peek toggles while this app is in front: the display under the pointer, all displays, or any set of connected displays you tick. Works whether or not the exception is used." label:[NSString stringWithFormat:@"%@ — Peek toggles",rule[@"name"]]];
 NSStackView *spans=[self row:@[span,[self spacer],peekLabel,peekPick]];spans.spacing=6;spans.hidden=![self multiDisplay];
 NSStackView *details=[self column:@[warmth,spans]];details.spacing=8;details.hidden=!open;
 NSStackView *row=[self column:@[header,modes,details]];row.spacing=8;row.edgeInsets=NSEdgeInsetsMake(10,10,10,10);row.identifier=bundle;[header.widthAnchor constraintEqualToAnchor:row.widthAnchor constant:-20].active=YES;[details.widthAnchor constraintEqualToAnchor:row.widthAnchor constant:-20].active=YES;[warmth.widthAnchor constraintEqualToAnchor:details.widthAnchor].active=YES;[spans.widthAnchor constraintEqualToAnchor:details.widthAnchor].active=YES;
 return row;
}
- (NSImage *)menuIconForBundle:(NSString *)bundle {NSImage *icon=[[self iconForBundle:bundle] copy];icon.size=NSMakeSize(16,16);return icon;}
- (NSImage *)iconForBundle:(NSString *)bundle {
 NSURL *url=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundle];NSImage *icon=url?[NSWorkspace.sharedWorkspace iconForFile:url.path]:[NSWorkspace.sharedWorkspace iconForContentType:UTTypeApplicationBundle];return icon;
}
// "Add app…" lists the apps running now, with icons, then the file picker.
- (void)menuNeedsUpdate:(NSMenu *)menu {
 if(menu!=self.addAppMenu)return;[menu removeAllItems];[menu addItemWithTitle:@"Add app…" action:nil keyEquivalent:@""];
 NSArray *running=[NSWorkspace.sharedWorkspace.runningApplications sortedArrayUsingComparator:^NSComparisonResult(NSRunningApplication *a,NSRunningApplication *b){return [a.localizedName?:@"" localizedCaseInsensitiveCompare:b.localizedName?:@""];}];
 for(NSRunningApplication *app in running){if(app.activationPolicy!=NSApplicationActivationPolicyRegular||!app.bundleIdentifier||!app.bundleURL||[app.bundleIdentifier isEqual:NSBundle.mainBundle.bundleIdentifier]||self.exclusionRules[app.bundleIdentifier])continue;
  NSMenuItem *item=[[NSMenuItem alloc]initWithTitle:app.localizedName?:app.bundleIdentifier action:@selector(addRunningApp:) keyEquivalent:@""];item.target=self;item.representedObject=app.bundleURL;NSImage *icon=[app.icon copy];icon.size=NSMakeSize(16,16);item.image=icon;[menu addItem:item];}
 if(menu.numberOfItems>1)[menu addItem:NSMenuItem.separatorItem];
 NSMenuItem *other=[[NSMenuItem alloc]initWithTitle:@"Choose another app…" action:@selector(addExclusionApp:) keyEquivalent:@""];other.target=self;[menu addItem:other];
}
- (void)addRunningApp:(NSMenuItem *)sender {if(sender.representedObject)[self addAppURL:sender.representedObject];}
- (void)rebuildExclusionsList {
 if(!self.exclusionsList)return;for(NSView *v in self.exclusionsList.arrangedSubviews.copy){[self.exclusionsList removeArrangedSubview:v];[v removeFromSuperview];}
 NSArray *keys=[self.exclusionRules.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [self.exclusionRules[a][@"name"] localizedCaseInsensitiveCompare:self.exclusionRules[b][@"name"]];}];
 if(!keys.count){NSTextField *empty=[NSTextField labelWithString:@"No exceptions yet. Add an app, then choose its display settings."];empty.textColor=NSColor.secondaryLabelColor;NSStackView *pad=[self column:@[empty]];pad.edgeInsets=NSEdgeInsetsMake(10,10,10,10);[self.exclusionsList addArrangedSubview:pad];}
 BOOL first=YES;for(NSString *bundle in keys){if(!first){NSBox *line=[self separator];[self.exclusionsList addArrangedSubview:line];[line.widthAnchor constraintEqualToAnchor:self.exclusionsList.widthAnchor].active=YES;}first=NO;NSView *row=[self exceptionRowForBundle:bundle rule:self.exclusionRules[bundle]];[self.exclusionsList addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:self.exclusionsList.widthAnchor].active=YES;}
}
- (void)showExclusions:(id)sender {[self showSettings:nil];self.settingsTabs.selectedTabViewItemIndex=2;}
- (void)showWebsites:(id)sender {[self showSettings:nil];self.settingsTabs.selectedTabViewItemIndex=3;}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
 if([NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier].count>1||[NSRunningApplication runningApplicationsWithBundleIdentifier:LessPullOldBundleIdentifier].count>0){[NSApp terminate:nil];return;}
 BOOL migrated=[PreferenceMigration migrateFromDomain:LessPullOldBundleIdentifier into:NSUserDefaults.standardUserDefaults];
 NSMenu *main=[NSMenu new],*application=[NSMenu new];NSMenuItem *root=[NSMenuItem new];root.submenu=application;[main addItem:root];NSMenuItem *quit=[[NSMenuItem alloc]initWithTitle:@"Quit Less Pull" action:@selector(terminate:) keyEquivalent:@"q"];quit.target=NSApp;[application addItem:quit];NSMenuItem *settingsShortcut=[[NSMenuItem alloc]initWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];settingsShortcut.target=self;[application insertItem:settingsShortcut atIndex:0];NSApp.mainMenu=main;
 self.exclusionRules=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"appExclusions"] mutableCopy]?:[NSMutableDictionary new];self.exclusion=[ExclusionPolicy fromDictionary:[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"]]?:[ExclusionPolicy new];
 self.forcedNightOn=[[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"] objectForKey:@"forcedNightOn"] boolValue];self.engine=[FilterEngine new];self.warmth=[WarmthEngine new];self.warmth.perDisplay=YES;[self.warmth restore];self.selectedMode=self.engine.currentMode;
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
 // The welcome window is for brand-new users only. Anyone with saved settings from an
 // earlier version gets the marker silently; it is not a user setting.
 BOOL firstLaunch=!migrated&&![d objectForKey:@"welcomeShown"]&&![d objectForKey:@"nightMode"]&&![d objectForKey:@"unifiedWarmth"]&&![d objectForKey:@"warmth"];
 [d setBool:YES forKey:@"welcomeShown"];
 // New users get the two shortcuts set for them (Option-A to peek, Option-Command-G to toggle),
 // each only if it is free on this Mac and keyboard; the tour shows which ones. Changeable under Shortcuts.
 if(firstLaunch)for(NSString *key in @[@"peekShortcut",@"grayscaleShortcut"]){if(![d objectForKey:key]){NSDictionary *pick=[self suggestedShortcutFor:key];if(pick)[d setObject:pick forKey:key];}}
 [d registerDefaults:@{@"automatic":@YES,@"overrideMode":@(-1),@"warmth":@0,@"nightMode":@101,@"manualMode":@1,@"checkForUpdates":@YES,@"peekActiveDisplayOnly":@YES,@"sessionPresets":@[@25,@45,@60,@90],@"callBackPresets":@[@5,@9,@13,@33],@"sessionRemindEvery":@0,@"sessionSound":@YES,@"sessionGlow":@YES}];self.peekLockedDisplays=[NSMutableSet new];
 self.availableUpdate=[d dictionaryForKey:@"availableUpdate"];
 if([d integerForKey:@"nightMode"]==16)[d setInteger:100 forKey:@"nightMode"];
 if([d integerForKey:@"manualMode"]==16)[d setInteger:100 forKey:@"manualMode"];
 if([d integerForKey:@"overrideMode"]==16)[d setInteger:100 forKey:@"overrideMode"];
 self.pause=[PausePolicy fromDictionary:[d dictionaryForKey:@"nightShiftPause"]];
 if(self.pause&&[NSDate.date compare:self.pause.expiry]==NSOrderedAscending){BOOL on=NO;if([self.engine nightShift:&on]&&on)[self.engine setNightShiftEnabled:NO];}
 if(![d objectForKey:@"warmthGrayscale"])[d setDouble:[d doubleForKey:@"warmth"] forKey:@"warmthGrayscale"];
 [d registerDefaults:@{@"warmthColor":@0}];
 if(![d boolForKey:@"unifiedWarmth"]){NSString *key=[d integerForKey:@"nightMode"]==101?@"warmthColor":@"warmthGrayscale";[d setDouble:[d doubleForKey:key] forKey:@"warmth"];[d setBool:YES forKey:@"unifiedWarmth"];}
 if([d integerForKey:@"nightMode"]==1)[d setInteger:100 forKey:@"nightMode"];
 self.automatic=[d boolForKey:@"automatic"];
 self.selectedMode=[d integerForKey:self.automatic?@"nightMode":@"manualMode"];
 self.policy=[SwitchingPolicy new];self.policy.automatic=self.automatic;
 self.policy.overrideMode=[d integerForKey:@"overrideMode"];
 self.policy.known=[d boolForKey:@"lastNightShiftKnown"];self.policy.nightShiftOn=[d boolForKey:@"lastNightShiftOn"];
 self.browserBridge=[BrowserBridge new];__weak AppDelegate *browserOwner=self;self.browserBridge.changed=^{[browserOwner sync];[browserOwner rebuildWebsiteRulesList];};self.browserBridge.defaults=^NSDictionary *(NSString *browser){return [browserOwner browserBaseForBundle:browser];};[self.browserBridge start];
 // The icon's place in the menu bar is macOS's: new items go to the left end of the third-party items, and the
 // "Preferred Position" preference is not honored on current macOS (tested with many values). The user ⌘-drags it.
 self.item=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];self.item.autosaveName=@"LessPull";self.item.button.imagePosition=NSImageLeft;self.item.button.imageHugsTitle=YES;
 self.item.button.image=[self menuBarImage:@"menubar-grayscale" symbol:@"circle.lefthalf.filled"];
 self.item.button.toolTip=@"Less Pull";
 NSMenu *menu=[NSMenu new];menu.delegate=self;self.statusMenu=menu;self.item.button.target=self;self.item.button.action=@selector(statusItemClicked:);[self.item.button sendActionOn:NSEventMaskLeftMouseUp|NSEventMaskRightMouseUp];
 __weak AppDelegate *weak=self;self.engine.changed=^{[weak pipelineChanged:nil];};
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(pipelineChanged:) name:NSWorkspaceDidWakeNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(pipelineChanged:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(displaysChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(pipelineChanged:) name:NSWorkspaceScreensDidWakeNotification object:nil];
 [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(pipelineChanged:) name:@"com.apple.screenIsUnlocked" object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(frontmostChanged:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(frontmostChanged:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
 [self restoreLessPullPause];[self scheduleLessPullPauseTimer];[self restoreGrayscaleOff];[self scheduleGrayscaleOffTimer];[self restoreSession];{NSArray *args=NSProcessInfo.processInfo.arguments;NSUInteger i=[args indexOfObject:@"--session"];if(i!=NSNotFound&&i+1<args.count)[self startSessionMinutes:[args[i+1] integerValue]];if([args containsObject:@"--session-soon"]){[self.session startMinutes:1 at:[NSDate dateWithTimeIntervalSinceNow:-54]];[self persistSession];[self scheduleSessionTimer];}if([args containsObject:@"--session-panel"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self showSessionPanelMode:nil];});if([args containsObject:@"--session-start-panel"])dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self showSessionPanelMode:@"start"];});}[self registerPeekShortcut];[self scheduleUpdateChecks];[self noteFirstLaunch];[self updateForeground];[self restartTimer];[self schedulePauseTimer];[self sync];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--settings"])[self showSettings:nil];
 // First launch: Settings opens with a one-time welcome card above the real controls.
 self.welcomeWanted=firstLaunch||[NSProcessInfo.processInfo.arguments containsObject:@"--welcome"];if(self.welcomeWanted)[self showSettings:nil];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--menu-test"]){[self showSettings:nil];main.itemArray.firstObject.submenu=self.statusMenu;}

}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {[self showSettings:nil];return YES;}
// The supplied menu-bar images are black on transparent; as template images they
// follow the menu-bar appearance. The SF Symbol remains the fallback.
- (NSImage *)menuBarImage:(NSString *)name symbol:(NSString *)symbol {
 NSImage *image=[NSBundle.mainBundle imageForResource:name];if(image){image.template=YES;image.accessibilityDescription=@"Less Pull";return image;}
 return [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@"Less Pull"];
}
// Half-filled circle while grayscale is showing, outline while color is showing,
// pause mark while Night Shift is timed off.
- (void)updateStatusIcon {
 BOOL gray=self.effectiveMode==100||self.effectiveMode==1;double strength=round(self.targetStrength*20)/20;
 BOOL paused=self.pause!=nil||self.pausedUntil!=nil;NSDate *now=NSDate.date;NSString *label=[self.session labelAt:now];double ring=[self sessionRing:now];BOOL over=self.session.state==SessionOver,away=self.session.state==SessionAway;
 NSString *name=[NSString stringWithFormat:@"%@ update=%d session=%@ %.2f %d %d %d",paused?@"paused":[NSString stringWithFormat:@"gray=%d warmth=%.2f",gray,strength],self.availableUpdate!=nil,label,ring,over,away,self.sessionBreath];
 if([name isEqual:self.statusImageName])return;self.statusImageName=name;
 self.item.button.image=[self withUpdateDot:paused?[self menuBarImage:@"menubar-paused" symbol:@"pause.circle"]:[self statusImageGray:gray warmth:strength ring:ring over:over away:away]];
 NSColor *ink=over?[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:(self.sessionBreath?1:.55)]:away?NSColor.secondaryLabelColor:NSColor.labelColor;
 self.item.button.attributedTitle=[[NSAttributedString alloc]initWithString:label.length?[@" " stringByAppendingString:[label stringByReplacingOccurrencesOfString:@"-" withString:@"−"]]:@"" attributes:@{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium],NSForegroundColorAttributeName:ink,NSBaselineOffsetAttributeName:@1}];
 self.item.button.accessibilityLabel=label.length?[NSString stringWithFormat:@"Less Pull, session %@ %@",over?@"over by":away?@"away, back in":@"",label]:@"Less Pull";
}
// Drawn rather than a template image so the right half can carry the warmth
// color: the left half fills while grayscale shows, the right half takes the
// ramp color (light orange to red) for the warmth in effect. Under the full red
// filter the warm half is much darker than the white half, so both stay visible.
// A small dot at the top right of the icon while a newer version is known.
- (NSImage *)withUpdateDot:(NSImage *)base {
 if(!self.availableUpdate)return base;BOOL template=base.template;
 NSImage *image=[NSImage imageWithSize:base.size flipped:NO drawingHandler:^BOOL(NSRect rect){[base drawInRect:rect];NSRect dot=NSMakeRect(rect.size.width-6,rect.size.height-6,5,5);[NSColor.labelColor setFill];[[NSBezierPath bezierPathWithOvalInRect:dot] fill];return YES;}];
 image.template=template;image.accessibilityDescription=[base.accessibilityDescription stringByAppendingString:@", update available"];return image;
}
- (NSImage *)statusImageGray:(BOOL)gray warmth:(double)strength {return [self statusImageGray:gray warmth:strength ring:-1 over:NO away:NO];}
// With a session: a thin ring around the circle fills as the session runs (warm once it is over, quiet while away).
- (NSImage *)statusImageGray:(BOOL)gray warmth:(double)strength ring:(double)ring over:(BOOL)over away:(BOOL)away {
 NSImage *image=[NSImage imageWithSize:NSMakeSize(18,18) flipped:NO drawingHandler:^BOOL(NSRect rect){
  NSRect circle=NSInsetRect(rect,ring>=0?3.5:2,ring>=0?3.5:2);NSColor *ink=NSColor.labelColor;NSBezierPath *outline=[NSBezierPath bezierPathWithOvalInRect:circle];
  if(ring>=0){NSBezierPath *track=[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rect,1,1)];track.lineWidth=1;[[ink colorWithAlphaComponent:.25] setStroke];[track stroke];
   NSBezierPath *arc=[NSBezierPath new];[arc appendBezierPathWithArcWithCenter:NSMakePoint(9,9) radius:8 startAngle:90 endAngle:90-360*(over?1:MAX(.02,MIN(1,ring))) clockwise:YES];arc.lineWidth=1.5;arc.lineCapStyle=NSLineCapStyleRound;[(over?[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:1]:away?[ink colorWithAlphaComponent:.5]:ink) setStroke];[arc stroke];}
  NSRect left=circle,right=circle;left.size.width/=2;right.size.width/=2;right.origin.x+=right.size.width;
  if(gray){[NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRect:left] addClip];[ink setFill];[outline fill];[NSGraphicsContext restoreGraphicsState];}
  if(strength>0){double gains[3];WarmthGains(strength,gains);[NSGraphicsContext saveGraphicsState];[[NSBezierPath bezierPathWithRect:right] addClip];[[NSColor colorWithSRGBRed:gains[0] green:gains[1] blue:gains[2] alpha:1] setFill];[outline fill];[NSGraphicsContext restoreGraphicsState];}
  [ink setStroke];outline.lineWidth=1.5;[outline stroke];return YES;}];
 image.template=NO;image.accessibilityDescription=[NSString stringWithFormat:@"Less Pull: %@%@",gray?@"grayscale":@"color",strength>0?[NSString stringWithFormat:@", warmth %.0f%%",strength/3*100]:@""];return image;
}
// ---- Sessions: a length you choose, a gentle end, time counted past it, one call back after you leave.
- (double)sessionRing:(NSDate *)now {Session *s=self.session;if(s.state==SessionRunning)return 1-MAX(0,[s remainingAt:now])/MAX(1,s.minutes*60.0);if(s.state==SessionOver)return 1;if(s.state==SessionAway)return 1-MAX(0,[s remainingAt:now])/MAX(1,[s.callBackAt timeIntervalSinceDate:s.start?:now]);return -1;}
- (NSArray<NSNumber *> *)sessionPresets:(NSString *)key fallback:(NSArray *)fallback {NSArray *a=[NSUserDefaults.standardUserDefaults arrayForKey:key];NSMutableArray *out=[NSMutableArray new];for(id n in a)if([n respondsToSelector:@selector(integerValue)]&&[n integerValue]>0&&[n integerValue]<=24*60)[out addObject:@([n integerValue])];return out.count?out:fallback;}
- (void)restoreSession {self.session=[Session fromDictionary:[NSUserDefaults.standardUserDefaults dictionaryForKey:@"session"]];self.session.remindEvery=[NSUserDefaults.standardUserDefaults integerForKey:@"sessionRemindEvery"];[self scheduleSessionTimer];}
- (void)persistSession {if(self.session.state==SessionIdle)[NSUserDefaults.standardUserDefaults removeObjectForKey:@"session"];else [NSUserDefaults.standardUserDefaults setObject:self.session.dictionary forKey:@"session"];}
- (void)scheduleSessionTimer {[self.sessionTimer invalidate];self.sessionTimer=nil;if(self.session.state==SessionIdle)return;self.sessionTimer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(sessionTick) userInfo:nil repeats:YES];self.sessionTimer.tolerance=.2;[NSRunLoop.mainRunLoop addTimer:self.sessionTimer forMode:NSRunLoopCommonModes];}
- (void)sessionTick {
 NSDate *now=NSDate.date;NSArray *events=[self.session eventsAt:now];if(self.session.state==SessionOver&&!self.sessionPanel.visible)self.sessionBreath=!self.sessionBreath;else self.sessionBreath=YES;
 for(NSString *e in events){
  if([e isEqual:@"ended"]){[self glow:[NSString stringWithFormat:@"That was %ld minute%@.",(long)self.session.minutes,self.session.minutes==1?@"":@"s"] sound:@"session-end"];}
  else if([e isEqual:@"reminder"]){NSInteger past=(NSInteger)floor(-[self.session remainingAt:now]/60);[self glow:[NSString stringWithFormat:@"%ld minute%@ past.",(long)past,past==1?@"":@"s"] sound:@"session-remind"];}
  else if([e isEqual:@"callBack"]){[self glow:@"Welcome back." sound:@"session-back"];[self closeSessionPanel];}}
 if(events.count)[self persistSession];[self updateStatusIcon];if(self.sessionPanel.visible){if(events.count&&self.session.state!=SessionIdle)[self showSessionPanelMode:nil];else [self refreshSessionPanel];}if(self.session.state==SessionIdle)[self scheduleSessionTimer];
}
- (void)startSession:(NSMenuItem *)sender {[self startSessionMinutes:sender.tag];[self closeSessionPanel];}
- (void)openStartPanel:(id)sender {dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.15*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self showSessionPanelMode:@"start"];});}
- (void)startSessionMinutes:(NSInteger)minutes {[self.session startMinutes:minutes at:NSDate.date];self.session.remindEvery=[NSUserDefaults.standardUserDefaults integerForKey:@"sessionRemindEvery"];[self persistSession];[self scheduleSessionTimer];self.statusImageName=nil;[self updateStatusIcon];}
- (void)endSession:(id)sender {[self.session stop];[self persistSession];[self scheduleSessionTimer];[self closeSessionPanel];self.statusImageName=nil;[self updateStatusIcon];}
- (void)extendSession:(id)sender {[self.session extendMinutes:10];[self persistSession];self.statusImageName=nil;[self updateStatusIcon];[self refreshSessionPanel];}
- (void)sessionQuiet:(id)sender {[self.session quietFor:5 at:NSDate.date];[self persistSession];[self closeSessionPanel];}
- (void)sessionLeaving:(id)sender {[self showSessionPanelMode:@"callback"];}
- (void)sessionCallBack:(NSButton *)sender {[self.session leaveAt:NSDate.date callBackIn:sender.tag];[self persistSession];[self scheduleSessionTimer];[self closeSessionPanel];self.statusImageName=nil;[self updateStatusIcon];}
- (void)sessionBack:(id)sender {[self endSession:sender];}
- (void)showSessionsFromPanel:(id)sender {[self closeSessionPanel];[self showSessions:nil];}
// The glow: a soft warm bloom on every display for three seconds with one line of text, no focus, no click needed.
- (void)glow:(NSString *)text sound:(NSString *)sound {
 if([NSUserDefaults.standardUserDefaults boolForKey:@"sessionSound"]){NSString *path=[NSBundle.mainBundle pathForResource:sound ofType:@"wav"];if(path){self.sessionSound=[[NSSound alloc]initWithContentsOfFile:path byReference:YES];self.sessionSound.volume=.7;[self.sessionSound play];}}
 if(![NSUserDefaults.standardUserDefaults boolForKey:@"sessionGlow"])return;
 for(NSWindow *w in self.glowWindows)[w orderOut:nil];self.glowWindows=[NSMutableArray new];BOOL reduce=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
 for(NSScreen *screen in NSScreen.screens){
  NSWindow *w=[[NSWindow alloc]initWithContentRect:screen.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO screen:screen];w.opaque=NO;w.backgroundColor=NSColor.clearColor;w.ignoresMouseEvents=YES;w.level=NSStatusWindowLevel;w.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorIgnoresCycle;w.hasShadow=NO;w.releasedWhenClosed=NO;
  NSView *bloom=[[GlowView alloc]initWithFrame:w.contentView.bounds];bloom.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;[w.contentView addSubview:bloom];
  NSTextField *label=[NSTextField labelWithString:text];label.font=[NSFont systemFontOfSize:34 weight:NSFontWeightLight];label.textColor=[NSColor colorWithWhite:1 alpha:.92];label.alignment=NSTextAlignmentCenter;[label sizeToFit];label.frame=NSMakeRect((w.frame.size.width-label.frame.size.width)/2,w.frame.size.height*.56,label.frame.size.width,label.frame.size.height);label.shadow=[NSShadow new];label.shadow.shadowBlurRadius=14;label.shadow.shadowColor=[NSColor colorWithWhite:0 alpha:.45];[w.contentView addSubview:label];
  w.alphaValue=0;[w orderFrontRegardless];[self.glowWindows addObject:w];
  if(reduce){w.alphaValue=1;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(2.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[w orderOut:nil];});continue;}
  [NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.9;c.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];w.animator.alphaValue=1;} completionHandler:^{dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=1.4;c.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];w.animator.alphaValue=0;} completionHandler:^{[w orderOut:nil];}];});}];
 }
}
// The panel under the icon: the time, and a few buttons that fade in. A click anywhere else closes it.
- (void)toggleSessionPanel {if(self.sessionPanel.visible)[self closeSessionPanel];else [self showSessionPanelMode:nil];}
- (NSButton *)panelButton:(NSString *)title action:(SEL)action prominent:(BOOL)prominent {NSButton *b=[NSButton buttonWithTitle:title target:self action:action];b.bezelStyle=NSBezelStyleRounded;b.controlSize=NSControlSizeLarge;if(prominent)b.keyEquivalent=@"\r";[self helpView:b text:title label:title];return b;}
- (NSView *)sessionPanelContentMode:(NSString *)mode {
 Session *s=self.session;NSDate *now=NSDate.date;NSTimeInterval r=[s remainingAt:now];NSInteger abs_=(NSInteger)fabs(r);
 NSString *big=[NSString stringWithFormat:@"%@%ld:%02ld",(s.state==SessionOver||(r<0&&s.state!=SessionAway))?@"−":@"",(long)abs_/60,(long)abs_%60];
 NSTextField *time=[NSTextField labelWithString:big];time.font=[NSFont monospacedDigitSystemFontOfSize:30 weight:NSFontWeightLight];time.alignment=NSTextAlignmentCenter;time.textColor=s.state==SessionOver?[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:1]:NSColor.labelColor;time.identifier=@"time";
 NSString *mins=[NSString stringWithFormat:@"%ld minute%@",(long)s.minutes,s.minutes==1?@"":@"s"];NSString *subtitle=s.state==SessionRunning?[NSString stringWithFormat:@"of %@",mins]:s.state==SessionOver?[NSString stringWithFormat:@"That was %@.",mins]:@"until the call back";
 NSTextField *sub=[NSTextField labelWithString:subtitle];sub.font=[NSFont systemFontOfSize:13];sub.textColor=NSColor.secondaryLabelColor;sub.alignment=NSTextAlignmentCenter;
 NSMutableArray *buttons=[NSMutableArray new];
 if([mode isEqual:@"start"]){time.stringValue=@"A session";time.font=[NSFont systemFontOfSize:22 weight:NSFontWeightLight];time.textColor=NSColor.labelColor;sub.stringValue=@"Focused work with a gentle end. How long?";
  NSMutableArray *chips=[NSMutableArray new];for(NSNumber *m in [self sessionPresets:@"sessionPresets" fallback:@[@25,@45,@60,@90]]){NSButton *c=[self panelButton:[NSString stringWithFormat:@"%@ min",m] action:@selector(startSession:) prominent:NO];c.tag=m.integerValue;[chips addObject:c];}
  [buttons addObjectsFromArray:[self chipRows:chips]];
  NSButton *gear=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Session settings"] target:self action:@selector(showSessionsFromPanel:)];gear.bezelStyle=NSBezelStyleInline;gear.bordered=NO;[self helpView:gear text:@"Change the lengths, reminders, sound and glow under Settings → Sessions." label:@"Session settings"];
  NSButton *later=[self panelButton:@"Not now" action:@selector(closeSessionPanel) prominent:NO];later.bezelStyle=NSBezelStyleInline;later.controlSize=NSControlSizeRegular;[buttons addObject:[self row:@[[self spacer],later,gear]]];}
 else if([mode isEqual:@"callback"]){sub.stringValue=@"Call me back in";time.stringValue=@"Leaving now.";time.font=[NSFont systemFontOfSize:22 weight:NSFontWeightLight];time.textColor=NSColor.labelColor;
  NSMutableArray *chips=[NSMutableArray new];for(NSNumber *m in [self sessionPresets:@"callBackPresets" fallback:@[@5,@9,@13,@33]]){NSButton *c=[self panelButton:[NSString stringWithFormat:@"%@ min",m] action:@selector(sessionCallBack:) prominent:NO];c.tag=m.integerValue;[chips addObject:c];}
  [buttons addObjectsFromArray:[self chipRows:chips]];
  NSButton *none=[self panelButton:@"Not today" action:@selector(sessionCallBack:) prominent:NO];none.tag=0;none.bezelStyle=NSBezelStyleInline;none.controlSize=NSControlSizeRegular;[buttons addObject:[self row:@[[self spacer],none,[self spacer]]]];}
 else if(s.state==SessionRunning){[buttons addObject:[self row:@[[self spacer],[self panelButton:@"End session" action:@selector(endSession:) prominent:NO],[self spacer]]]];}
 else if(s.state==SessionOver){NSTextField *ask=[NSTextField labelWithString:@"Leaving? Call me back in"];ask.font=[NSFont systemFontOfSize:12];ask.textColor=NSColor.secondaryLabelColor;ask.alignment=NSTextAlignmentCenter;[buttons addObject:ask];
  NSMutableArray *chips=[NSMutableArray new];for(NSNumber *m in [self sessionPresets:@"callBackPresets" fallback:@[@5,@9,@13,@33]]){NSButton *c=[self panelButton:[NSString stringWithFormat:@"%@ min",m] action:@selector(sessionCallBack:) prominent:NO];c.tag=m.integerValue;[chips addObject:c];}
  [buttons addObjectsFromArray:[self chipRows:chips]];
  NSButton *keep=[self panelButton:@"Keep going" action:@selector(closeSessionPanel) prominent:NO];NSButton *quiet=[self panelButton:@"Leave quietly" action:@selector(sessionCallBack:) prominent:NO];quiet.tag=0;quiet.bezelStyle=NSBezelStyleInline;quiet.controlSize=NSControlSizeRegular;[self helpView:quiet text:@"End the session without a call back." label:@"Leave quietly"];
  NSButton *gear=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Session settings"] target:self action:@selector(showSessionsFromPanel:)];gear.bezelStyle=NSBezelStyleInline;gear.bordered=NO;[self helpView:gear text:@"Change the call-back times, reminders, sound and glow under Settings → Sessions." label:@"Session settings"];
  [buttons addObject:[self row:@[keep,[self spacer],quiet,gear]]];}
 else if(s.state==SessionAway){[buttons addObject:[self row:@[[self spacer],[self panelButton:@"I’m back" action:@selector(sessionBack:) prominent:NO],[self spacer]]]];}
 NSMutableArray *parts=[NSMutableArray arrayWithObjects:time,sub,nil];[parts addObjectsFromArray:buttons];
 NSStackView *column=[self column:parts];column.alignment=NSLayoutAttributeCenterX;column.spacing=10;column.edgeInsets=NSEdgeInsetsMake(18,18,16,18);[column setCustomSpacing:2 afterView:time];[column setCustomSpacing:16 afterView:sub];
 for(NSView *v in buttons){[v.widthAnchor constraintEqualToAnchor:column.widthAnchor constant:-36].active=YES;}
 return column;
}
- (void)showSessionPanelMode:(NSString *)mode {
 if(self.session.state==SessionIdle&&![mode isEqual:@"start"])return;NSView *content=[self sessionPanelContentMode:mode];
 if(!self.sessionPanel){NSPanel *p=[[NSPanel alloc]initWithContentRect:NSMakeRect(0,0,320,150) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];p.opaque=NO;p.backgroundColor=NSColor.clearColor;p.level=NSPopUpMenuWindowLevel;p.hasShadow=YES;p.releasedWhenClosed=NO;p.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorTransient;p.becomesKeyOnlyIfNeeded=YES;
  NSVisualEffectView *back=[NSVisualEffectView new];back.material=NSVisualEffectMaterialPopover;back.blendingMode=NSVisualEffectBlendingModeBehindWindow;back.state=NSVisualEffectStateActive;back.wantsLayer=YES;back.layer.cornerRadius=14;back.layer.masksToBounds=YES;p.contentView=back;self.sessionPanel=p;}
 NSView *back=self.sessionPanel.contentView;NSView *old=back.subviews.firstObject;content.translatesAutoresizingMaskIntoConstraints=NO;[back addSubview:content];
 [NSLayoutConstraint activateConstraints:@[[content.leadingAnchor constraintEqualToAnchor:back.leadingAnchor],[content.trailingAnchor constraintEqualToAnchor:back.trailingAnchor],[content.topAnchor constraintEqualToAnchor:back.topAnchor],[content.widthAnchor constraintEqualToConstant:320]]];
 [content layoutSubtreeIfNeeded];NSSize size=NSMakeSize(320,content.fittingSize.height);
 NSRect anchor=self.item.button.window.frame;NSRect frame=NSMakeRect(NSMidX(anchor)-size.width/2,anchor.origin.y-size.height-6,size.width,size.height);NSScreen *screen=self.item.button.window.screen?:NSScreen.mainScreen;if(NSMaxX(frame)>NSMaxX(screen.visibleFrame)-8)frame.origin.x=NSMaxX(screen.visibleFrame)-8-size.width;
 BOOL reduce=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
 if(old){content.alphaValue=0;[self.sessionPanel setFrame:frame display:YES animate:NO];[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=reduce?0:.3;old.animator.alphaValue=0;content.animator.alphaValue=1;} completionHandler:^{[old removeFromSuperview];}];}
 else {NSRect start=[self sessionPanelOrigin:frame];[self.sessionPanel setFrame:reduce?frame:start display:NO];self.sessionPanel.alphaValue=reduce?1:0;[self.sessionPanel orderFrontRegardless];
  for(NSView *v in [(NSStackView *)content arrangedSubviews])v.alphaValue=reduce?1:0;
  if(!reduce){[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.32;c.timingFunction=[CAMediaTimingFunction functionWithControlPoints:.2 :.9 :.3 :1];self.sessionPanel.animator.alphaValue=1;[self.sessionPanel.animator setFrame:frame display:YES];} completionHandler:nil];
   NSInteger k=0;for(NSView *v in [(NSStackView *)content arrangedSubviews]){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((.12+.05*k)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.26;v.animator.alphaValue=1;} completionHandler:nil];});k++;}}
  __weak AppDelegate *weak=self;self.sessionClickMonitor=[NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^(NSEvent *e){[weak closeSessionPanel];}];
  self.sessionKeyMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *e){if(e.keyCode==53){[weak closeSessionPanel];return nil;}return e;}];}
}
// The panel's resting place when closed: a small rectangle at the icon, so it grows out of it and folds back into it.
- (NSRect)sessionPanelOrigin:(NSRect)frame {NSRect icon=self.item.button.window.frame;CGFloat w=MAX(40,icon.size.width),h=22;return NSMakeRect(NSMidX(icon)-w/2,NSMinY(icon)+2,w,h);}
- (void)refreshSessionPanel {if(!self.sessionPanel.visible)return;NSView *content=self.sessionPanel.contentView.subviews.lastObject;NSTextField *time=(NSTextField *)[content viewWithTag:0];for(NSView *v in [(NSStackView *)content arrangedSubviews])if([v.identifier isEqual:@"time"]&&[v isKindOfClass:NSTextField.class]){time=(NSTextField *)v;NSTimeInterval r=[self.session remainingAt:NSDate.date];NSInteger a=(NSInteger)fabs(r);if(![time.stringValue hasPrefix:@"Leaving"])time.stringValue=[NSString stringWithFormat:@"%@%ld:%02ld",(self.session.state==SessionOver||(r<0&&self.session.state!=SessionAway))?@"−":@"",(long)a/60,(long)a%60];}}
- (void)closeSessionPanel {
 if(self.sessionClickMonitor){[NSEvent removeMonitor:self.sessionClickMonitor];self.sessionClickMonitor=nil;}if(self.sessionKeyMonitor){[NSEvent removeMonitor:self.sessionKeyMonitor];self.sessionKeyMonitor=nil;}
 NSPanel *p=self.sessionPanel;if(!p.visible)return;BOOL reduce=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;NSRect into=[self sessionPanelOrigin:p.frame];
 for(NSView *v in p.contentView.subviews)v.alphaValue=reduce?v.alphaValue:0;
 [NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=reduce?0:.26;c.timingFunction=[CAMediaTimingFunction functionWithControlPoints:.4 :0 :.8 :.4];p.animator.alphaValue=0;if(!reduce)[p.animator setFrame:into display:YES];} completionHandler:^{[p orderOut:nil];for(NSView *v in p.contentView.subviews.copy)[v removeFromSuperview];}];
}
- (void)restartTimer {
 [self.timer invalidate];double t=60;self.timer=[NSTimer timerWithTimeInterval:t target:self selector:@selector(periodicSync) userInfo:nil repeats:YES];
 [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
// Once a minute the matrix is sent again even if nothing changed: the system can replace
// it without telling us, and the display then shows color while Grayscale is ticked.
- (void)periodicSync {if(!self.warmth.transitioning)[self.warmth invalidate];[self.browserBridge expireContexts];[self sync];}
- (void)pipelineChanged:(id)sender {
 if(self.quitting)return;
 self.pipelineEvents++;
 [self.warmth invalidate];[self.eventTimer invalidate];[self.pipelineRecoveryTimer invalidate];
 // A system display change may settle after our current fade completes. Invalidate
 // at recovery time too: a completed fade otherwise marks the old request cached.
 self.eventTimer=[NSTimer timerWithTimeInterval:.25 target:self selector:@selector(restorePipeline:) userInfo:nil repeats:NO];[NSRunLoop.mainRunLoop addTimer:self.eventTimer forMode:NSRunLoopCommonModes];
 self.pipelineRecoveryTimer=[NSTimer timerWithTimeInterval:1 target:self selector:@selector(restorePipeline:) userInfo:nil repeats:NO];[NSRunLoop.mainRunLoop addTimer:self.pipelineRecoveryTimer forMode:NSRunLoopCommonModes];
}
- (void)restorePipeline:(id)sender {
 if(self.quitting)return;
 [self.warmth invalidate];self.pipelineRestorations++;[self sync];
}
- (void)schedulePauseTimer {
 [self.pauseTimer invalidate];self.pauseTimer=nil;if(!self.pause)return;
 self.pauseTimer=[NSTimer timerWithTimeInterval:fmax(.1,[self.pause.expiry timeIntervalSinceNow]) target:self selector:@selector(sync) userInfo:nil repeats:NO];[NSRunLoop.mainRunLoop addTimer:self.pauseTimer forMode:NSRunLoopCommonModes];
}
- (void)savePolicy {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
 if([d integerForKey:@"overrideMode"]!=self.policy.overrideMode)[d setInteger:self.policy.overrideMode forKey:@"overrideMode"];
 if([d boolForKey:@"lastNightShiftKnown"]!=self.policy.known)[d setBool:self.policy.known forKey:@"lastNightShiftKnown"];
 if([d boolForKey:@"lastNightShiftOn"]!=self.policy.nightShiftOn)[d setBool:self.policy.nightShiftOn forKey:@"lastNightShiftOn"];
}
- (void)sync {
 [self checkPause];
 [self updateForeground];[self checkLessPullPause];[self checkGrayscaleOff];
 if(self.peeking&&[[self peekEffects][@"nightShift"] boolValue]){self.nightOverride=2;self.excludeNight=YES;}
 if(self.pausedUntil){if(self.grayOverride||self.nightOverride||self.customWarmth)self.animateAppearance=YES;self.grayOverride=0;self.nightOverride=0;self.customWarmth=NO;self.appWarmth=0;self.excludeGray=NO;self.excludeNight=NO;self.excludeWarmth=NO;}[self reconcileExclusion];
 BOOL on=NO;BOOL known=[self logicalNightShift:&on];
 self.policy.automatic=self.automatic;[self.policy observeKnown:known on:on];[self savePolicy];
 NSInteger target=self.automatic?[NSUserDefaults.standardUserDefaults integerForKey:@"nightMode"]:self.selectedMode;
 if(![self applyMode:target])self.status=self.warmth.error?:@"Could not confirm the display change. Trying again.";
 else self.status=[NSString stringWithFormat:@"%@ · Extra Warmth %@ · Night Shift %@",[self modeName:target],self.automatic?@"follows Night Shift":@"set by hand",known?(on?@"on":@"off"):@"unavailable"];
 if(self.pause)self.status=[self.status stringByAppendingFormat:@" · Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.exclusionError)self.status=self.exclusionError;
 [self refreshControlsKnown:known nightOn:on];
 NSArray *arguments=NSProcessInfo.processInfo.arguments;NSUInteger testIndex=[arguments indexOfObject:@"--test-state-path"];if(testIndex!=NSNotFound&&testIndex+1<arguments.count){BOOL actual=NO;[self.engine nightShift:&actual];NSDictionary *state=@{@"front":self.foregroundID?:@"",@"grayOverride":@(self.grayOverride),@"nightOverride":@(self.nightOverride),@"customWarmth":@(self.customWarmth),@"effectiveMode":@(self.effectiveMode),@"strength":@(self.targetStrength),@"logicalNight":@(on),@"actualNight":@(actual),@"override":@(self.policy.overrideMode),@"transitioning":@(self.warmth.transitioning),@"pause":@(self.pause!=nil)};[[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil] writeToFile:arguments[testIndex+1] atomically:YES];}

}
- (NSSlider *)warmthSliderWithValue:(double)value action:(SEL)action {
 NSSlider *slider=[NSSlider new];slider.cell=[WarmthSliderCell new];slider.minValue=0;slider.maxValue=100;slider.doubleValue=value;slider.target=self;slider.action=action;slider.continuous=YES;slider.numberOfTickMarks=5;slider.allowsTickMarkValuesOnly=NO;slider.sliderType=NSSliderTypeLinear;return slider;
}
- (NSString *)modeName:(NSInteger)mode {return mode==101?@"Color":mode==100?@"Grayscale":mode==0?@"Natural Colors":mode==1?@"Grayscale":mode==16?@"System Color Tint":@"Other filter";}
- (NSString *)autoHelp {return @"On: Extra Warmth is added only while Night Shift is on, and there is none in the daytime. Off: Extra Warmth stays on all day. Grayscale and your Night Shift schedule are not affected. If you move the slider yourself while following, that warmth stays until Night Shift next changes, or until you choose Resume Following.";}
- (NSString *)followHelpKnown:(BOOL)known nightOn:(BOOL)on {
 NSString *availability=!known?@"Night Shift cannot be read right now; your choice is kept. ":@"";
 return [availability stringByAppendingString:self.autoHelp];
}
- (NSString *)grayHelp {return @"Shows everything in shades of gray, day and night. Night Shift does not change this. Exceptions for apps and websites can.";}
- (NSString *)warmthHelp {return @"Adds warmth on top of Night Shift: Off adds none, 100% is red. The percentage is Less Pull’s own scale. When warmth follows Night Shift, the amount you set is used at night.";}
- (NSString *)nightHelp {return @"Turns Night Shift on or off now. Your Night Shift schedule in System Settings stays as it is and may change it again later.";}
- (NSString *)pauseHelp {return @"Turns Night Shift off for a while and back on afterwards, if your schedule still wants it on. Grayscale stays as it is. Quitting Less Pull ends the timed off.";}
- (void)helpView:(NSView *)view text:(NSString *)text label:(NSString *)label {view.toolTip=text;view.accessibilityHelp=text;if(label)view.accessibilityLabel=label;}
- (NSString *)appearanceSummary {
 NSString *name=[self modeName:self.effectiveMode];double percent=self.targetStrength/3*100;
 return [NSString stringWithFormat:@"%@ · Warmth %@",name,percent>0?[NSString stringWithFormat:@"%.0f%%",percent]:@"Off"];
}
- (NSString *)automationSummaryKnown:(BOOL)known nightOn:(BOOL)on {
 if(self.pausedUntil)return [[self lessPullPauseLabel] stringByAppendingString:@" · the plain display, settings kept"];
 if(self.grayOffUntil)return [self grayOffLabel];
 if(self.pause)return [NSString stringWithFormat:@"Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.exclusion.active){BOOL actual=NO;[self.engine nightShift:&actual];return [NSString stringWithFormat:@"Night Shift %@ for %@ · usually %@",actual?@"on":@"off",self.foregroundName,self.exclusion.desiredOn?@"on":@"off"];}
 if(self.automatic&&self.policy.overrideMode>=0)return @"Warmth set by hand until Night Shift next changes";
 return [NSString stringWithFormat:@"%@ · Night Shift %@",self.automatic?@"Warmth follows Night Shift":@"Warmth set by hand",known?(on?@"on":@"off"):@"unavailable"];
}
- (void)refreshControlsKnown:(BOOL)known nightOn:(BOOL)on {
 NSString *summary=[self appearanceSummary],*detail=[self automationSummaryKnown:known nightOn:on];
 BOOL failed=[self.status containsString:@"Could not"]||[self.status containsString:@"unavailable"]||[self.status containsString:@"unsupported"];
 self.statusText.stringValue=failed?self.status:summary;self.statusDetail.stringValue=detail;self.websiteStatus.stringValue=[self websiteStatusLine];self.exclusionText.stringValue=[self exclusionSummary];self.exclusionText.toolTip=[self exclusionHelp];self.exclusionText.accessibilityHelp=[self exclusionHelp];
 BOOL actualOn=NO;BOOL actualKnown=[self.engine nightShift:&actualOn];
 self.item.button.toolTip=[NSString stringWithFormat:@"%@\n%@\nClick for Grayscale, Extra Warmth and Night Shift.",summary,detail];[self updateStatusIcon];
 self.autoButton.state=self.automatic;self.autoButton.enabled=actualKnown;[self helpView:self.autoButton text:[self followHelpKnown:actualKnown nightOn:actualOn] label:@"Extra Warmth follows Night Shift"];self.nightButton.state=actualKnown&&actualOn;self.nightButton.enabled=known;
 self.nightButton.state=self.exclusion.active?on:(actualKnown&&actualOn);
 self.nightButton.title=known?(self.exclusion.active?(on?@"Default Night Shift: On":@"Default Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable";[self helpView:self.nightButton text:self.exclusion.active?[[self exclusionHelp] stringByAppendingString:@" This changes your default; the app in front keeps its own Night Shift exception."]:self.nightHelp label:nil];
 self.grayscaleButton.state=self.selectedMode==1||self.selectedMode==100;
 self.grayscaleButton.title=self.grayOverride?@"Default Grayscale":@"Grayscale";self.grayOnButton.hidden=self.grayOffUntil==nil;self.grayOffPopup.hidden=self.grayOffUntil!=nil||!self.grayscaleButton.state;self.grayOnButton.toolTip=[self grayOffLabel];if(self.clickPopup)[self.clickPopup selectItemAtIndex:[self leftClickToggles]?1:0];
 self.resumeButton.hidden=!(self.automatic&&self.policy.overrideMode>=0);
 self.endPauseButton.title=[self canResumePause]?@"Turn Night Shift back on":@"End timed off";[self helpView:self.endPauseButton text:[self endPauseHelp] label:self.endPauseButton.title];self.endPauseButton.hidden=self.pause==nil;self.pausePopup.hidden=self.pause!=nil;self.pausePopup.enabled=known&&(on||actualOn);
 self.resetButton.enabled=[self currentWarmth]>0;
 self.warmthSlider.doubleValue=[self currentWarmth]/3*100;NSString *percent=[NSString stringWithFormat:@"%.0f%%",[self currentWarmth]/3*100];self.warmthLabel.stringValue=percent;self.menuWarmthReadout.stringValue=percent;
 self.warmthLabel.accessibilityLabel=[NSString stringWithFormat:@"Extra Warmth %@",percent];
 self.warmthTitle.stringValue=self.customWarmth?@"Default Extra Warmth":(self.automatic&&self.policy.overrideMode<0&&known&&!on)?@"Extra Warmth · used at night":@"Extra Warmth";
 self.statusText.toolTip=self.status;self.statusDetail.toolTip=self.autoHelp;
 if(self.pausePopup)[self populatePausePopup];
}
- (NSMenuItem *)add:(NSString *)title action:(SEL)action to:(NSMenu *)menu {
 NSMenuItem *i=[[NSMenuItem alloc]initWithTitle:title action:action keyEquivalent:@""];i.target=self;
 NSString *help=nil;
 if(action==@selector(toggleAuto:))help=self.autoHelp;
 else if(action==@selector(toggleGrayscale:))help=self.grayHelp;
 else if(action==@selector(grayscaleOff:))help=[self grayOffHelp];
 else if(action==@selector(toggleNightShift:))help=self.nightHelp;
 else if(action==@selector(pauseNightShift:))help=self.pauseHelp;
 else if(action==@selector(endPauseNow:))help=[self endPauseHelp];
 else if(action==@selector(resume:))help=@"Go back to following Night Shift now.";
 else if(action==@selector(showSettings:)){help=@"Open all Less Pull settings, exceptions and help.";i.keyEquivalent=@",";}
 else if(action==@selector(showHelp:))help=@"A short guide to Less Pull.";
 else if(action==@selector(diagnostics:))help=@"Technical details for troubleshooting.";
 else if(action==@selector(reportProblem:))help=@"Open a new GitHub issue with the technical details filled in.";
 else if(action==@selector(showTour:))help=@"The short tour from the first launch, again.";
 else if(action==@selector(quit:)){help=@"Quit Less Pull. The display returns to normal and Night Shift follows its schedule again.";i.keyEquivalent=@"q";}
 // Menu items carry no tooltips: on macOS a tooltip competes with the submenu. Settings and Help explain.
 (void)help;[menu addItem:i];return i;
}
- (NSString *)morningPauseTitle {
 NSBlueStatus s={0};[self.engine readNightShiftStatus:&s];NSDate *morning=[PausePolicy nextMorningForDate:NSDate.date mode:s.mode endMinute:s.schedule.to.hour*60+s.schedule.to.minute calendar:NSCalendar.currentCalendar];
 return [NSString stringWithFormat:@"Off until morning · %@",[self timeLabel:morning]];
}
- (void)populatePauses:(NSMenu *)menu {
 for(NSArray *pair in @[@[@"Off for 1 hour",@1],@[@"Off for 4 hours",@4],@[[self morningPauseTitle],@0]]){NSMenuItem *i=[self add:pair[0] action:@selector(pauseNightShift:) to:menu];i.tag=[pair[1] integerValue];}
}
- (void)populatePausePopup {
 [self.pausePopup removeAllItems];[self.pausePopup addItemWithTitle:@"Turn Night Shift off for…"];[self populatePauses:self.pausePopup.menu];
}
- (void)menuDidClose:(NSMenu *)menu {if(menu!=self.statusMenu)return;[self.menuDismissal end];self.item.menu=nil;}
- (void)menuWillOpen:(NSMenu *)menu {
 if(menu!=self.statusMenu)return;if(!self.menuDismissal)self.menuDismissal=[MenuDismissal new];[self.menuDismissal begin:menu];
 [self sync];[menu removeAllItems];BOOL on=NO;BOOL known=[self logicalNightShift:&on];BOOL actualOn=NO;BOOL actualKnown=[self.engine nightShift:&actualOn];
 Session *session=self.session;
 if(session.state==SessionIdle){[self add:@"Start a session…" action:@selector(openStartPanel:) to:menu];}
 else {NSDate *now=NSDate.date;NSString *line=session.state==SessionRunning?[NSString stringWithFormat:@"Session · %@ min left",[session labelAt:now]]:session.state==SessionOver?[NSString stringWithFormat:@"Session over · %@ min past",[[session labelAt:now] substringFromIndex:1]]:[NSString stringWithFormat:@"Away · back in %@ min",[session labelAt:now]];
  NSMenuItem *head=[[NSMenuItem alloc]initWithTitle:line action:nil keyEquivalent:@""];head.enabled=NO;[menu addItem:head];
  if(session.state==SessionOver)[self add:@"Leaving now…" action:@selector(sessionLeaving:) to:menu];
  [self add:session.state==SessionAway?@"I’m back":@"End session" action:@selector(endSession:) to:menu];}
 [menu addItem:NSMenuItem.separatorItem];
 [self add:[self menuStatusLine] action:nil to:menu];
 [menu addItem:NSMenuItem.separatorItem];
 NSMenuItem *gray=[self add:self.grayOverride?@"Default Grayscale":@"Grayscale" action:@selector(toggleGrayscale:) to:menu];gray.state=self.selectedMode==1||self.selectedMode==100;
 if(self.grayOffUntil){[self add:@"Grayscale back on now" action:@selector(grayscaleBackOn:) to:menu];}
 else if(gray.state){NSMenuItem *off=[self add:@"Grayscale off for" action:nil to:menu];off.submenu=[NSMenu new];[self populateGrayscaleOff:off.submenu];}
 NSMenuItem *sliderItem=[NSMenuItem new];NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,300,78)];
 NSTextField *label=[NSTextField labelWithString:self.customWarmth?@"Default Extra Warmth":(self.automatic&&self.policy.overrideMode<0&&known&&!on)?@"Extra Warmth · used at night":@"Extra Warmth"];label.frame=NSMakeRect(18,54,210,18);[self helpView:label text:self.warmthHelp label:nil];[view addSubview:label];
 self.menuWarmthReadout=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[self currentWarmth]/3*100]];self.menuWarmthReadout.frame=NSMakeRect(242,54,48,18);self.menuWarmthReadout.alignment=NSTextAlignmentRight;[self helpView:self.menuWarmthReadout text:self.warmthHelp label:@"Extra Warmth percentage"];[view addSubview:self.menuWarmthReadout];
 NSSlider *slider=[self warmthSliderWithValue:[self currentWarmth]/3*100 action:@selector(warmthChanged:)];slider.frame=NSMakeRect(18,26,260,26);[self helpView:slider text:self.warmthHelp label:@"Extra Warmth, percent"];[view addSubview:slider];
 for(int i=0;i<5;i++){NSTextField *r=[NSTextField labelWithString:@[@"Off",@"25",@"50",@"75",@"Red"][i]];r.font=[NSFont systemFontOfSize:10];r.alignment=NSTextAlignmentCenter;r.frame=NSMakeRect(28+60*i-20,4,40,16);[view addSubview:r];}
 [self helpView:view text:self.warmthHelp label:nil];sliderItem.view=view;[menu addItem:sliderItem];
 [menu addItem:NSMenuItem.separatorItem];
 // Everything about Night Shift lives in one submenu: on/off now, off for a while,
 // and whether Extra Warmth follows it.
 NSString *nightTitle=known?(self.exclusion.active?(on?@"Default Night Shift: On":@"Default Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable";
 NSMenuItem *night=[self add:nightTitle action:nil to:menu];night.state=known&&on;night.enabled=known;
 if(known){night.submenu=[NSMenu new];
  [self add:on?@"Turn Off":@"Turn On" action:@selector(toggleNightShift:) to:night.submenu];
  if(self.pause)[self add:[self canResumePause]?@"Turn Night Shift back on":@"End timed off" action:@selector(endPauseNow:) to:night.submenu];
  else if(on||actualOn){[night.submenu addItem:NSMenuItem.separatorItem];[self populatePauses:night.submenu];}
  [night.submenu addItem:NSMenuItem.separatorItem];
  NSMenuItem *automatic=[self add:@"Extra Warmth follows Night Shift" action:@selector(toggleAuto:) to:night.submenu];automatic.state=self.automatic;automatic.enabled=actualKnown;
  if(self.automatic&&self.policy.overrideMode>=0)[self add:@"Resume Following" action:@selector(resume:) to:night.submenu];}
 if(self.pausedUntil){[self add:@"Resume Less Pull" action:@selector(resumeLessPull:) to:menu];}
 else {NSMenuItem *pauseAll=[self add:@"Pause Less Pull" action:nil to:menu];pauseAll.submenu=[NSMenu new];for(NSArray *pair in @[@[@"For 15 minutes",@15],@[@"For 1 hour",@60],@[@"Until I resume",@0]]){NSMenuItem *i=[self add:pair[0] action:@selector(pauseLessPull:) to:pauseAll.submenu];i.tag=[pair[1] integerValue];}}
 [menu addItem:NSMenuItem.separatorItem];
 if(self.lastExternalApp.bundleIdentifier){NSDictionary *appRule=self.exclusionRules[self.lastExternalApp.bundleIdentifier];NSMenuItem *current=[self add:[NSString stringWithFormat:@"Exception for %@",self.lastExternalApp.localizedName?:@"current app"] action:nil to:menu];current.submenu=[self currentAppMenu];current.image=[self menuIconForBundle:self.lastExternalApp.bundleIdentifier];current.state=RuleEnabled(appRule)&&RuleDiffers(appRule);}
 if(self.availableUpdate){[self add:[NSString stringWithFormat:@"Update available: %@…",[[self updateLabel:self.availableUpdate] stringByReplacingOccurrencesOfString:@"Version " withString:@""]] action:@selector(showUpdate:) to:menu];}
 NSDictionary *tab=[self.browserBridge activeContextForBrowser:self.lastExternalApp.bundleIdentifier];
 if(tab){NSMenuItem *site=[self add:[NSString stringWithFormat:@"Exception for %@",tab[@"site"]] action:nil to:menu];site.submenu=[self websiteMenuForTab:tab];site.image=[NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];NSDictionary *siteRule=[self websiteRuleForTab:tab];site.state=RuleEnabled(siteRule)&&RuleDiffers(siteRule);}
 [self add:@"Settings…" action:@selector(showSettings:) to:menu];
 [menu addItem:NSMenuItem.separatorItem];
 [self add:@"Quit" action:@selector(quit:) to:menu];
}
// One line for the menu: what the display shows now, plus a timed off or an active exception.
- (NSString *)menuStatusLine {
 NSString *line=[self appearanceSummary];
 if(self.pausedUntil)return [self lessPullPauseLabel];
 if(self.peekLocked)return @"Peeking · press the shortcut to return";
 if(self.peekLockedDisplays.count)return self.peekLockedDisplays.count>1?@"Peeking on several displays · press the shortcut on each to return":@"Peeking on one display · press the shortcut there to return";
 if(self.grayOffUntil)line=[NSString stringWithFormat:@"%@ · %@",line,[self grayOffLabel]];
 if(self.pause)return [line stringByAppendingFormat:@" · Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.grayOverride||self.nightOverride||self.customWarmth)return [line stringByAppendingFormat:@" · %@ exception",self.foregroundName];
 if(self.automatic&&self.policy.overrideMode>=0)return [line stringByAppendingString:@" · set by hand"];
 return line;
}
// Pause Less Pull: the plain display for a while. Saved settings and rules stay
// untouched; Night Shift is left alone; it resumes with the normal fade and
// survives a relaunch.
// Carbon hot keys deliver pressed and released events without Accessibility permission.
static OSStatus PeekHotKeyHandler(EventHandlerCallRef next,EventRef event,void *userData) {
 AppDelegate *owner=(__bridge AppDelegate *)userData;UInt32 kind=GetEventKind(event);EventHotKeyID hotKeyID={0};GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(hotKeyID),NULL,&hotKeyID);
 dispatch_async(dispatch_get_main_queue(),^{if(hotKeyID.id==2){if(kind==kEventHotKeyPressed)[owner toggleGrayscale:nil];}else [owner peekKeyPressed:kind==kEventHotKeyPressed at:NSDate.timeIntervalSinceReferenceDate];});return noErr;
}
- (void)setPeeking:(BOOL)peeking {if(_peeking==peeking)return;_peeking=peeking;self.animateAppearance=YES;[self sync];}
// Hold the shortcut to peek; a quick double press keeps the peek on; one more press lets go.
// Per display (the default): a press peeks the display with the window you are using; a quick
// double press keeps that display plain; the next press there lets it go. Other displays can be
// kept the same way later, so each one is toggled on its own. All displays: one lock for all.
// Per-display handling applies with the per-display scope, and always when the app in front has its own Peek choice.
- (BOOL)peeksPerDisplay {if([[self.warmth displays].firstObject unsignedIntValue]==0)return NO;return [NSUserDefaults.standardUserDefaults boolForKey:@"peekActiveDisplayOnly"]||self.frontPeekDisplays!=nil||self.frontPeekSpansAll;}
// The display under the mouse pointer: where you are looking, no click needed.
- (uint32_t)displayUnderMouse {NSPoint p=NSEvent.mouseLocation;CGPoint cg=CGPointMake(p.x,CGDisplayBounds(CGMainDisplayID()).size.height-p.y);CGDirectDisplayID id=0;uint32_t n=0;if(CGGetDisplaysWithPoint(cg,1,&id,&n)==kCGErrorSuccess&&n)return id;return self.activeDisplay?:CGMainDisplayID();}
- (void)peekKeyPressed:(BOOL)pressed at:(NSTimeInterval)now {
 if(pressed)[self updateForeground];
 if(pressed&&[self peeksPerDisplay]){
  self.peekDisplay=[self displayUnderMouse];
  NSSet *targets=self.frontPeekSpansAll?[NSSet setWithArray:[self.warmth displays]]:self.frontPeekDisplays?:[NSSet setWithObject:@(self.peekDisplay)];
  if([targets isSubsetOfSet:self.peekLockedDisplays]){[self.peekLockedDisplays minusSet:targets];self.peekIgnoreRelease=YES;_peeking=NO;self.animateAppearance=YES;[self sync];return;}
  if(now-self.lastPeekPress<0.45)[self.peekLockedDisplays unionSet:targets];
  self.lastPeekPress=now;self.animateAppearance=YES;_peeking=YES;[self sync];return;
 }
 if(pressed){
  if(self.peekLocked){self.peekLocked=NO;self.peekIgnoreRelease=YES;self.peeking=NO;return;}
  if(now-self.lastPeekPress<0.45)self.peekLocked=YES;
  self.lastPeekPress=now;self.peeking=YES;return;
 }
 if(self.peekIgnoreRelease){self.peekIgnoreRelease=NO;return;}
 if(!self.peekLocked)self.peeking=NO;
}
// Two global shortcuts: Peek in color (held) and Toggle Grayscale (pressed). Both
// are optional and recorded by the user; Suggest picks a free combination.
// Tolerates numbers stored as strings (hand-edited preferences) by reading through integerValue.
- (NSDictionary *)shortcutForKey:(NSString *)key {NSDictionary *s=[NSUserDefaults.standardUserDefaults dictionaryForKey:key];if(![s[@"keyCode"] respondsToSelector:@selector(integerValue)]||![s[@"modifiers"] respondsToSelector:@selector(integerValue)])return nil;NSInteger code=[s[@"keyCode"] integerValue];NSEventModifierFlags mods=(NSEventModifierFlags)[s[@"modifiers"] integerValue];return [PeekShortcut isValidKeyCode:code modifiers:mods]?@{@"keyCode":@(code),@"modifiers":@(mods)}:nil;}
- (NSDictionary *)peekShortcut {return [self shortcutForKey:@"peekShortcut"];}
- (EventHotKeyRef)registerShortcut:(NSDictionary *)s identifier:(UInt32)identifier {if(!s)return NULL;EventHotKeyID hotKeyID={.signature='LsPl',.id=identifier};EventHotKeyRef ref=NULL;return RegisterEventHotKey((UInt32)[s[@"keyCode"] integerValue],[PeekShortcut carbonModifiers:[s[@"modifiers"] integerValue]],hotKeyID,GetApplicationEventTarget(),0,&ref)==noErr?ref:NULL;}
- (void)registerPeekShortcut {
 static BOOL installed=NO;if(!installed){installed=YES;EventTypeSpec kinds[2]={{kEventClassKeyboard,kEventHotKeyPressed},{kEventClassKeyboard,kEventHotKeyReleased}};InstallApplicationEventHandler(PeekHotKeyHandler,2,kinds,(__bridge void *)self,NULL);}
 if(self.peekHotKey){UnregisterEventHotKey(self.peekHotKey);self.peekHotKey=NULL;}if(self.grayscaleHotKey){UnregisterEventHotKey(self.grayscaleHotKey);self.grayscaleHotKey=NULL;}self.peekLocked=NO;self.peekIgnoreRelease=NO;self.peeking=NO;
 self.peekHotKey=[self registerShortcut:[self peekShortcut] identifier:1];self.grayscaleHotKey=[self registerShortcut:[self shortcutForKey:@"grayscaleShortcut"] identifier:2];
}
- (void)saveShortcut:(NSString *)key keyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(keyCode<0)[d removeObjectForKey:key];else [d setObject:@{@"keyCode":@(keyCode),@"modifiers":@(modifiers&NSEventModifierFlagDeviceIndependentFlagsMask)} forKey:key];
 [self registerPeekShortcut];[self refreshPeekRecorder:nil];
}
- (void)savePeekShortcutKeyCode:(NSInteger)keyCode modifiers:(NSEventModifierFlags)modifiers {[self saveShortcut:@"peekShortcut" keyCode:keyCode modifiers:modifiers];}
- (NSSet *)takenShortcutKeysExcept:(NSString *)key {NSMutableSet *taken=[NSMutableSet new];for(NSString *k in @[@"peekShortcut",@"grayscaleShortcut"]){if([k isEqual:key])continue;NSDictionary *s=[self shortcutForKey:k];if(s)[taken addObject:[PeekShortcut keyForKeyCode:[s[@"keyCode"] integerValue] modifiers:[s[@"modifiers"] integerValue]]];}return taken;}
- (NSDictionary *)suggestedShortcutFor:(NSString *)key {
 // Left-hand only: Control and Option under the left pinky and ring finger, the key under the index finger.
 // The author's own choices first (Option-A to peek, Option-Command-G to toggle), then left-hand fallbacks.
 NSEventModifierFlags co=NSEventModifierFlagControl|NSEventModifierFlagOption,oc=NSEventModifierFlagOption|NSEventModifierFlagCommand;NSArray *peek=@[@{@"keyCode":@(kVK_ANSI_A),@"modifiers":@(NSEventModifierFlagOption)},@{@"keyCode":@(kVK_ANSI_C),@"modifiers":@(co)},@{@"keyCode":@(kVK_ANSI_V),@"modifiers":@(co)},@{@"keyCode":@(kVK_ANSI_X),@"modifiers":@(co)}];
 NSArray *gray=@[@{@"keyCode":@(kVK_ANSI_G),@"modifiers":@(oc)},@{@"keyCode":@(kVK_ANSI_G),@"modifiers":@(co)},@{@"keyCode":@(kVK_ANSI_F),@"modifiers":@(co)},@{@"keyCode":@(kVK_ANSI_D),@"modifiers":@(co)}];
 return [PeekShortcut suggestionAvoiding:[self takenShortcutKeysExcept:key] preferring:[key isEqual:@"peekShortcut"]?peek:gray];
}
- (void)suggestShortcut:(NSButton *)sender {NSString *key=sender.identifier;NSDictionary *s=[self suggestedShortcutFor:key];if(!s){NSBeep();return;}[self saveShortcut:key keyCode:[s[@"keyCode"] integerValue] modifiers:[s[@"modifiers"] integerValue]];}
- (void)refreshRecorder:(ShortcutRecorder *)recorder key:(NSString *)key registered:(BOOL)registered note:(NSTextField *)note idle:(NSString *)idle active:(NSString *)active name:(NSString *)name {
 NSDictionary *s=[self shortcutForKey:key];NSDictionary *suggested=[self suggestedShortcutFor:key];NSString *hint=suggested?[NSString stringWithFormat:@" Suggest picks %@, which is free of macOS shortcuts.",[PeekShortcut labelForKeyCode:[suggested[@"keyCode"] integerValue] modifiers:[suggested[@"modifiers"] integerValue]]]:@"";
 if(recorder.recording){recorder.title=@"Press keys…";note.stringValue=@"Press the keys to use, with ⌘, ⌃ or ⌥. Esc cancels; ⌫ removes the shortcut.";}
 else {recorder.title=s?[PeekShortcut labelForKeyCode:[s[@"keyCode"] integerValue] modifiers:[s[@"modifiers"] integerValue]]:@"Record Shortcut";note.stringValue=s?(registered?active:@"That shortcut could not be registered; it may be taken by another app. Click to choose another."):[idle stringByAppendingString:hint];}
 recorder.accessibilityLabel=[NSString stringWithFormat:@"%@ shortcut: %@",name,s?recorder.title:@"none"];
}
- (void)refreshPeekRecorder:(id)sender {
 [self refreshRecorder:self.peekRecorder key:@"peekShortcut" registered:self.peekHotKey!=NULL note:self.peekNote idle:@"Hold a shortcut to see the plain display; let go to return. Press it twice quickly to keep the plain display until you press it again. Nothing is saved." active:@"Hold the shortcut to see the plain display; let go to return. Press it twice quickly to keep it; press once more to return. Click to change it." name:@"Peek in color"];
 [self refreshRecorder:self.grayscaleRecorder key:@"grayscaleShortcut" registered:self.grayscaleHotKey!=NULL note:self.grayscaleShortcutNote idle:@"Press a shortcut to turn Grayscale on or off from anywhere." active:@"Press the shortcut to turn Grayscale on or off from anywhere. Click to change it." name:@"Toggle Grayscale"];
 NSDictionary *effects=[self peekEffects];self.peekGrayButton.state=[effects[@"grayscale"] boolValue];self.peekWarmthButton.state=[effects[@"warmth"] boolValue];self.peekNightButton.state=[effects[@"nightShift"] boolValue];
}
- (void)startRecording:(ShortcutRecorder *)sender {if(sender.recording){sender.recording=NO;[self refreshPeekRecorder:nil];return;}sender.recording=YES;[sender.window makeFirstResponder:sender];[self refreshPeekRecorder:nil];}
// What Peek turns off while held: Grayscale and Extra Warmth by default; Night Shift if wanted.
- (NSDictionary *)peekEffects {NSDictionary *e=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"peekEffects"];return e?:@{@"grayscale":@YES,@"warmth":@YES,@"nightShift":@NO};}
- (void)peekScopeChanged:(NSPopUpButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.indexOfSelectedItem==1 forKey:@"peekActiveDisplayOnly"];[self.peekLockedDisplays removeAllObjects];self.peekLocked=NO;self.animateAppearance=YES;[self sync];}
- (void)peekEffectChanged:(NSButton *)sender {NSMutableDictionary *e=[[self peekEffects] mutableCopy];e[sender.identifier]=@(sender.state==NSControlStateValueOn);[NSUserDefaults.standardUserDefaults setObject:e forKey:@"peekEffects"];if(self.peeking){self.animateAppearance=YES;[self sync];}}
- (void)scheduleUpdateChecks {
 [self.updateTimer invalidate];self.updateTimer=[NSTimer timerWithTimeInterval:3600 target:self selector:@selector(maybeCheckForUpdates) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
 [self performSelector:@selector(maybeCheckForUpdates) withObject:nil afterDelay:30];
}
- (void)maybeCheckForUpdates {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(![d boolForKey:@"checkForUpdates"])return;NSDate *last=[d objectForKey:@"lastUpdateCheck"];
 if(![last isKindOfClass:NSDate.class]||[NSDate.date timeIntervalSinceDate:last]>=86400)[self runUpdateCheckManual:NO];
}
- (void)checkForUpdatesNow:(id)sender {[self runUpdateCheckManual:YES];}
- (void)runUpdateCheckManual:(BOOL)manual {
 if(self.checkingUpdates)return;self.checkingUpdates=YES;self.updateStatus=@"Checking…";[self refreshUpdateControls];
 NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;configuration.timeoutIntervalForRequest=15;configuration.HTTPAdditionalHeaders=@{@"Accept":@"application/vnd.github+json"};
 NSURLSession *session=[NSURLSession sessionWithConfiguration:configuration];__weak AppDelegate *weak=self;
 [[session dataTaskWithURL:[NSURL URLWithString:LessPullReleasesAPI] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){dispatch_async(dispatch_get_main_queue(),^{[weak finishUpdateCheckData:data response:response error:error manual:manual];});[session finishTasksAndInvalidate];}] resume];
}
- (void)finishUpdateCheckData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error manual:(BOOL)manual {
 self.checkingUpdates=NO;NSUserDefaults *d=NSUserDefaults.standardUserDefaults;NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;
 if(error||status!=200){self.updateStatus=status==404?@"Could not find the release list; it is not public yet.":@"Could not reach GitHub. Try again later.";[self refreshUpdateControls];if(manual)[self showUpdateStatusAlert];return;}
[d setObject:NSDate.date forKey:@"lastUpdateCheck"];id release=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
 NSDictionary *update=[UpdateCheck updateFromRelease:release currentVersion:[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] currentBuild:[[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue]];
 if(update[@"metadata"]){ // a newer build: one more request tells whether it is made for this macOS
  self.checkingUpdates=YES;NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;configuration.timeoutIntervalForRequest=15;NSURLSession *session=[NSURLSession sessionWithConfiguration:configuration];__weak AppDelegate *weak=self;
  [[session dataTaskWithURL:[NSURL URLWithString:update[@"metadata"]] completionHandler:^(NSData *meta,NSURLResponse *metaResponse,NSError *metaError){id parsed=meta?[NSJSONSerialization JSONObjectWithData:meta options:0 error:nil]:nil;dispatch_async(dispatch_get_main_queue(),^{[weak finishUpdate:update metadata:parsed manual:manual];});[session finishTasksAndInvalidate];}] resume];return;}
 [self finishUpdate:update metadata:nil manual:manual];
}
- (void)finishUpdate:(NSDictionary *)candidate metadata:(id)metadata manual:(BOOL)manual {
 self.checkingUpdates=NO;NSUserDefaults *d=NSUserDefaults.standardUserDefaults;BOOL compatible=[UpdateCheck metadata:metadata allowsSystem:NSProcessInfo.processInfo.operatingSystemVersion];NSDictionary *update=compatible?candidate:nil;
 self.availableUpdate=update;if(update)[d setObject:update forKey:@"availableUpdate"];else [d removeObjectForKey:@"availableUpdate"];
 NSString *label=[self updateLabel:candidate];
 self.updateStatus=update?[NSString stringWithFormat:@"%@ is available.",label]:candidate?[NSString stringWithFormat:@"%@ exists but is made for another macOS version, so it is not offered.",label]:@"Less Pull is up to date.";[self refreshUpdateControls];[self refreshControlsKnown:NO nightOn:NO];[self sync];
 if(manual){if(update)[self showUpdate:nil];else [self showUpdateStatusAlert];}
}
- (NSString *)updateLabel:(NSDictionary *)update {return [update[@"build"] integerValue]?[NSString stringWithFormat:@"Version %@ (build %ld)",update[@"version"],(long)[update[@"build"] integerValue]]:[NSString stringWithFormat:@"Version %@",update[@"version"]];}
- (NSString *)runningVersionLabel {return [NSString stringWithFormat:@"%@ (build %@)",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];}
- (void)showUpdateStatusAlert {NSAlert *a=[NSAlert new];a.messageText=self.updateStatus?:@"";a.informativeText=[NSString stringWithFormat:@"This is Less Pull %@.",[self runningVersionLabel]];[NSApp activateIgnoringOtherApps:YES];[a runModal];}
- (void)showUpdate:(id)sender {
 NSDictionary *update=self.availableUpdate;if(!update)return;NSAlert *a=[NSAlert new];a.messageText=[NSString stringWithFormat:@"Less Pull %@ is available",[[self updateLabel:update] stringByReplacingOccurrencesOfString:@"Version " withString:@""]];
 a.informativeText=[NSString stringWithFormat:@"You have %@.\n\n%@\n\nInstalling is still by hand: download the new version, quit Less Pull, and replace it in Applications. Your settings and exceptions are kept.",[self runningVersionLabel],[update[@"notes"] length]?update[@"notes"]:@"No release notes were provided."];
 [a addButtonWithTitle:@"Open Download Page"];[a addButtonWithTitle:@"Later"];[NSApp activateIgnoringOtherApps:YES];if([a runModal]==NSAlertFirstButtonReturn)[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:update[@"url"]]];
}
- (void)toggleUpdateChecks:(NSButton *)sender {[NSUserDefaults.standardUserDefaults setBool:sender.state==NSControlStateValueOn forKey:@"checkForUpdates"];[self refreshUpdateControls];}
- (void)refreshUpdateControls {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;self.updateCheckbox.state=[d boolForKey:@"checkForUpdates"];self.updateButton.enabled=!self.checkingUpdates;
 NSDate *last=[d objectForKey:@"lastUpdateCheck"];NSString *when=[last isKindOfClass:NSDate.class]?[NSDateFormatter localizedStringFromDate:last dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle]:nil;
 NSString *status=self.updateStatus?:(self.availableUpdate?[NSString stringWithFormat:@"%@ is available.",[self updateLabel:self.availableUpdate]]:(when?@"Less Pull was up to date at the last check.":@"Not checked yet."));
 self.updateStatusLabel.stringValue=when?[NSString stringWithFormat:@"%@ Last checked %@.",status,when]:status;
}
// Grayscale off for a while: 1 hour, 4 hours, or until Night Shift next changes.
// The saved Grayscale choice is untouched and comes back by itself.
- (NSString *)grayOffHelp {return @"Shows color for a while, then Grayscale comes back by itself. Your Grayscale setting stays saved; exceptions still apply.";}
- (void)persistGrayscaleOff {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(self.grayOffUntil)[d setObject:@{@"until":@([self.grayOffUntil isEqualToDate:NSDate.distantFuture]?0:self.grayOffUntil.timeIntervalSince1970)} forKey:@"grayscaleOff"];else [d removeObjectForKey:@"grayscaleOff"];}
- (void)restoreGrayscaleOff {NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"grayscaleOff"];if(!saved){self.grayOffUntil=nil;return;}double until=[saved[@"until"] doubleValue];self.grayOffUntil=until==0?NSDate.distantFuture:[NSDate dateWithTimeIntervalSince1970:until];if([self.grayOffUntil timeIntervalSinceNow]<=0){self.grayOffUntil=nil;[self persistGrayscaleOff];}BOOL on=NO;[self logicalNightShift:&on];self.lastNightForGrayOff=on;}
- (void)scheduleGrayscaleOffTimer {[self.grayOffTimer invalidate];self.grayOffTimer=nil;if(!self.grayOffUntil||[self.grayOffUntil isEqualToDate:NSDate.distantFuture])return;self.grayOffTimer=[NSTimer timerWithTimeInterval:fmax(.1,[self.grayOffUntil timeIntervalSinceNow]) target:self selector:@selector(sync) userInfo:nil repeats:NO];[NSRunLoop.mainRunLoop addTimer:self.grayOffTimer forMode:NSRunLoopCommonModes];}
- (void)checkGrayscaleOff {
 BOOL on=NO;BOOL known=[self logicalNightShift:&on];
 if(self.grayOffUntil&&([self.grayOffUntil timeIntervalSinceNow]<=0||([self.grayOffUntil isEqualToDate:NSDate.distantFuture]&&known&&on!=self.lastNightForGrayOff))){self.grayOffUntil=nil;[self persistGrayscaleOff];self.animateAppearance=YES;}
 if(known)self.lastNightForGrayOff=on;
}
- (void)grayscaleOffForMinutes:(NSInteger)minutes {BOOL on=NO;[self logicalNightShift:&on];self.lastNightForGrayOff=on;self.grayOffUntil=minutes>0?[NSDate dateWithTimeIntervalSinceNow:minutes*60]:NSDate.distantFuture;[self persistGrayscaleOff];[self scheduleGrayscaleOffTimer];self.animateAppearance=YES;[self sync];}
- (void)grayscaleOff:(NSMenuItem *)sender {[self grayscaleOffForMinutes:sender.tag];}
- (void)grayscaleBackOn:(id)sender {self.grayOffUntil=nil;[self persistGrayscaleOff];[self scheduleGrayscaleOffTimer];self.animateAppearance=YES;[self sync];}
- (NSString *)grayOffLabel {return !self.grayOffUntil?@"":[self.grayOffUntil isEqualToDate:NSDate.distantFuture]?@"Grayscale off until Night Shift changes":[NSString stringWithFormat:@"Grayscale off until %@",[self timeLabel:self.grayOffUntil]];}
- (void)populateGrayscaleOff:(NSMenu *)menu {for(NSArray *pair in @[@[@"Off for 1 hour",@60],@[@"Off for 4 hours",@240],@[@"Off until Night Shift changes",@0]]){NSMenuItem *i=[self add:pair[0] action:@selector(grayscaleOff:) to:menu];i.tag=[pair[1] integerValue];}}
- (void)populateGrayscaleOffPopup {[self.grayOffPopup removeAllItems];[self.grayOffPopup addItemWithTitle:@"Turn Grayscale off for…"];[self populateGrayscaleOff:self.grayOffPopup.menu];}
// Clicking the menu-bar icon: the menu on the left button and a Grayscale toggle on the
// right button by default; the preference swaps them.
- (BOOL)leftClickToggles {return [NSUserDefaults.standardUserDefaults integerForKey:@"iconClick"]==1;}
- (void)statusItemClicked:(id)sender {
 NSEvent *event=NSApp.currentEvent;BOOL secondary=event.type==NSEventTypeRightMouseUp||event.type==NSEventTypeRightMouseDown||(event.modifierFlags&NSEventModifierFlagControl);
 BOOL toggle=[self leftClickToggles]?!secondary:secondary;
 if(self.session.state!=SessionIdle){if(!toggle){[self toggleSessionPanel];return;}[self closeSessionPanel];self.item.menu=self.statusMenu;[self.item.button performClick:nil];return;}
 if(toggle){[self toggleGrayscale:nil];return;}
 self.item.menu=self.statusMenu;[self.item.button performClick:nil];
}
- (void)clickBehaviorChanged:(NSPopUpButton *)sender {[NSUserDefaults.standardUserDefaults setInteger:sender.indexOfSelectedItem forKey:@"iconClick"];[self refreshControlsKnown:NO nightOn:NO];[self sync];}
- (NSString *)pauseLessPullHelp {return @"Shows the plain display for a while: color and no added warmth. Night Shift is left alone. Your settings and exceptions are kept.";}
- (void)persistLessPullPause {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(self.pausedUntil)[d setObject:@{@"until":@([self.pausedUntil isEqualToDate:NSDate.distantFuture]?0:self.pausedUntil.timeIntervalSince1970)} forKey:@"lessPullPause"];else [d removeObjectForKey:@"lessPullPause"];}
- (void)restoreLessPullPause {
 NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"lessPullPause"];if(!saved){self.pausedUntil=nil;return;}
 double until=[saved[@"until"] doubleValue];self.pausedUntil=until==0?NSDate.distantFuture:[NSDate dateWithTimeIntervalSince1970:until];
 if([self.pausedUntil timeIntervalSinceNow]<=0){self.pausedUntil=nil;[self persistLessPullPause];}
}
- (void)scheduleLessPullPauseTimer {
 [self.pauseAllTimer invalidate];self.pauseAllTimer=nil;if(!self.pausedUntil||[self.pausedUntil isEqualToDate:NSDate.distantFuture])return;
 self.pauseAllTimer=[NSTimer timerWithTimeInterval:fmax(.1,[self.pausedUntil timeIntervalSinceNow]) target:self selector:@selector(sync) userInfo:nil repeats:NO];[NSRunLoop.mainRunLoop addTimer:self.pauseAllTimer forMode:NSRunLoopCommonModes];
}
- (void)checkLessPullPause {if(self.pausedUntil&&[self.pausedUntil timeIntervalSinceNow]<=0){self.pausedUntil=nil;[self persistLessPullPause];self.animateAppearance=YES;}}
- (void)pauseLessPullForMinutes:(NSInteger)minutes {self.pausedUntil=minutes>0?[NSDate dateWithTimeIntervalSinceNow:minutes*60]:NSDate.distantFuture;[self persistLessPullPause];[self scheduleLessPullPauseTimer];self.animateAppearance=YES;[self sync];}
- (void)pauseLessPull:(NSMenuItem *)sender {[self pauseLessPullForMinutes:sender.tag];}
- (void)resumeLessPull:(id)sender {self.pausedUntil=nil;[self persistLessPullPause];[self scheduleLessPullPauseTimer];self.animateAppearance=YES;[self sync];}
- (NSString *)lessPullPauseLabel {return !self.pausedUntil?@"":[self.pausedUntil isEqualToDate:NSDate.distantFuture]?@"Paused until you resume":[NSString stringWithFormat:@"Paused until %@",[self timeLabel:self.pausedUntil]];}
- (void)toggleNightShift:(id)sender {
 self.pause=nil;[self.pauseTimer invalidate];self.pauseTimer=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"nightShiftPause"];
 BOOL before=NO;BOOL known=[self logicalNightShift:&before];
 if(!known||![self requestNightShift:!before]){[self nightShiftFailure];return;}
 // Turning Night Shift on or off here is your doing, not the schedule's: the warmth you set by hand stays.
 // (A scheduled change still ends the override, as "follows Night Shift" promises.)
 NSInteger keep=self.policy.overrideMode;[self.policy observeKnown:known on:!before];if(keep>=0)self.policy.overrideMode=keep;[self savePolicy];
 [self sync];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.7*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
 BOOL after=NO;if(![self logicalNightShift:&after]||after==before)[self nightShiftFailure];if(keep>=0&&self.policy.overrideMode<0)self.policy.overrideMode=keep;[self sync];
 });
}
- (NSString *)timeLabel:(NSDate *)date {NSDateFormatter *f=[NSDateFormatter new];f.dateStyle=NSDateFormatterNoStyle;f.timeStyle=NSDateFormatterShortStyle;return [f stringFromDate:date];}
- (void)pauseNightShift:(NSMenuItem *)sender {
 BOOL on=NO,actual=NO;NSBlueStatus s={0};if(![self logicalNightShift:&on]||![self.engine nightShift:&actual]||(!on&&!actual)||![self.engine readNightShiftStatus:&s]){[self nightShiftFailure];return;}
 PausePolicy *p=[PausePolicy new];p.created=NSDate.date;p.priorOn=on;p.scheduleMode=s.mode;p.startMinute=s.schedule.from.hour*60+s.schedule.from.minute;p.endMinute=s.schedule.to.hour*60+s.schedule.to.minute;p.untilMorning=sender.tag==0;
 p.nightEnd=[PausePolicy nextMorningForDate:p.created mode:s.mode endMinute:p.endMinute calendar:NSCalendar.currentCalendar];
 p.expiry=p.untilMorning?p.nightEnd:[p.created dateByAddingTimeInterval:sender.tag*3600];
 self.pause=p;if(![self requestNightShift:NO]){self.pause=nil;[self nightShiftFailure];return;}
 self.pause=p;[self schedulePauseTimer];self.suppressPauseCancellation=YES;[NSUserDefaults.standardUserDefaults setObject:p.dictionary forKey:@"nightShiftPause"];[self sync];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{self.suppressPauseCancellation=NO;if(self.pause!=p)return;BOOL now=YES;if(![self logicalNightShift:&now]||now){self.pause=nil;[self.pauseTimer invalidate];self.pauseTimer=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"nightShiftPause"];[self nightShiftFailure];}[self sync];});
}
- (void)checkPause {
 if(!self.pause||self.handlingPause)return;self.handlingPause=YES;
 if([NSDate.date compare:self.pause.expiry]!=NSOrderedAscending)[self endPauseNow:nil];
 else {BOOL on=NO;if(!self.suppressPauseCancellation&&[self logicalNightShift:&on]&&on){self.pause=nil;[self.pauseTimer invalidate];self.pauseTimer=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"nightShiftPause"];}}
 self.handlingPause=NO;
}
- (BOOL)canResumePause {
 PausePolicy *p=self.pause;if(!p)return NO;NSBlueStatus s={0};BOOL on=NO;
 BOOL unchanged=[self.engine readNightShiftStatus:&s]&&s.mode==p.scheduleMode&&(s.mode!=2||(s.schedule.from.hour*60+s.schedule.from.minute==p.startMinute&&s.schedule.to.hour*60+s.schedule.to.minute==p.endMinute));
 return unchanged&&[self logicalNightShift:&on]&&!on&&[p mayResumeAt:NSDate.date calendar:NSCalendar.currentCalendar];
}
- (NSString *)endPauseHelp {if(self.nightOverride)return @"Ends the timed off. Night Shift comes back if your schedule wants it on, and the app in front keeps its own Night Shift exception.";return [self canResumePause]?@"Ends the timed off and turns Night Shift back on now.":@"Ends the timed off. Night Shift stays off because your schedule does not want it on right now.";}
- (void)endPauseNow:(id)sender {
 PausePolicy *p=self.pause;if(!p)return;self.pause=nil;[self.pauseTimer invalidate];self.pauseTimer=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"nightShiftPause"];
 NSBlueStatus s={0};BOOL on=NO;BOOL unchanged=[self.engine readNightShiftStatus:&s]&&s.mode==p.scheduleMode&&(s.mode!=2||(s.schedule.from.hour*60+s.schedule.from.minute==p.startMinute&&s.schedule.to.hour*60+s.schedule.to.minute==p.endMinute));
 if(unchanged&&[self logicalNightShift:&on]&&!on&&[p mayResumeAt:NSDate.date calendar:NSCalendar.currentCalendar]){
 if(![self requestNightShift:YES])[self nightShiftFailure];
 else dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{BOOL active=NO;if(![self logicalNightShift:&active]||!active)[self nightShiftFailure];});
 }
 if(sender)[self sync];
}
- (void)nightShiftFailure {
 NSAlert *alert=[NSAlert new];alert.messageText=@"Night Shift could not be changed";
 alert.informativeText=@"Check System Settings → Displays → Night Shift. This display, HDR mode or another display app may be preventing it. Your schedule and settings were not changed.";[NSApp activateIgnoringOtherApps:YES];[alert runModal];
}
- (void)enableAutomatic:(BOOL)value {self.automatic=value;self.policy.automatic=value;[self.policy resume];[self savePolicy];[NSUserDefaults.standardUserDefaults setBool:value forKey:@"automatic"];[self sync];}
- (BOOL)validateMenuItem:(NSMenuItem *)item {if(item.action==@selector(toggleAuto:)){BOOL on=NO;return [self.engine nightShift:&on];}return YES;}
- (void)toggleAuto:(id)sender {BOOL on=NO;if([self.engine nightShift:&on])[self enableAutomatic:!self.automatic];}
- (void)manual:(NSMenuItem *)sender {
 if(sender.tag==101||sender.tag==1||sender.tag==100)[NSUserDefaults.standardUserDefaults setInteger:sender.tag forKey:@"nightMode"];
 BOOL on=NO;BOOL known=[self logicalNightShift:&on];[self.policy observeKnown:known on:on];
 [self savePolicy];
 if(![self applyMode:sender.tag]){NSAlert *a=[NSAlert new];a.messageText=@"The display change could not be confirmed";a.informativeText=self.warmth.error?:@"Check System Settings → Accessibility → Display → Color Filters. Your settings were not changed.";[a runModal];}
 [NSUserDefaults.standardUserDefaults setInteger:self.selectedMode forKey:@"manualMode"];
 [self sync];
}
- (void)resume:(id)sender {[self.policy resume];[self savePolicy];[self sync];}
// Settings window building blocks: Auto Layout stacks, one short note under each
// control that is not obvious.
- (NSTextField *)note:(NSString *)text {NSTextField *n=[NSTextField wrappingLabelWithString:text];n.font=[NSFont systemFontOfSize:11];n.textColor=NSColor.secondaryLabelColor;n.preferredMaxLayoutWidth=440;return n;}
- (NSStackView *)column:(NSArray<NSView *> *)views {NSStackView *s=[NSStackView stackViewWithViews:views];s.orientation=NSUserInterfaceLayoutOrientationVertical;s.alignment=NSLayoutAttributeLeading;s.spacing=12;return s;}
- (NSStackView *)row:(NSArray<NSView *> *)views {NSStackView *s=[NSStackView stackViewWithViews:views];s.orientation=NSUserInterfaceLayoutOrientationHorizontal;s.alignment=NSLayoutAttributeCenterY;s.spacing=8;return s;}
- (NSView *)spacer {NSView *v=[NSView new];[v setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[v setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];return v;}
- (NSBox *)separator {NSBox *b=[NSBox new];b.boxType=NSBoxSeparator;return b;}
- (NSTabViewItem *)tab:(NSString *)title symbol:(NSString *)symbol content:(NSStackView *)content {
 content.edgeInsets=NSEdgeInsetsMake(20,24,20,24);content.translatesAutoresizingMaskIntoConstraints=NO;
 // The standard window material: translucent like System Settings when transparency is on, solid under Reduce transparency.
 NSViewController *controller=[NSViewController new];NSVisualEffectView *root=[NSVisualEffectView new];root.material=NSVisualEffectMaterialWindowBackground;root.blendingMode=NSVisualEffectBlendingModeBehindWindow;root.state=NSVisualEffectStateFollowsWindowActiveState;[root addSubview:content];
 [NSLayoutConstraint activateConstraints:@[[content.topAnchor constraintEqualToAnchor:root.topAnchor],[content.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],[content.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],[content.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],[root.widthAnchor constraintEqualToConstant:500]]];
 // Rows, separators and lists span the column; a view marked fixed keeps its own width.
 for(NSView *v in content.arrangedSubviews)if(([v isKindOfClass:NSStackView.class]&&![v.identifier isEqual:@"fixed"])||[v isKindOfClass:NSBox.class]||[v isKindOfClass:NSScrollView.class])[v.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-48].active=YES;
 controller.view=root;controller.title=title;[root layoutSubtreeIfNeeded];controller.preferredContentSize=root.fittingSize;
 NSTabViewItem *item=[NSTabViewItem tabViewItemWithViewController:controller];item.label=title;item.image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];return item;
}
- (NSStackView *)generalTab {
 self.statusText=[NSTextField labelWithString:@""];self.statusText.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
 self.statusDetail=[NSTextField labelWithString:@""];self.statusDetail.font=[NSFont systemFontOfSize:12];self.statusDetail.textColor=NSColor.secondaryLabelColor;
 self.grayscaleButton=[NSButton checkboxWithTitle:@"Grayscale" target:self action:@selector(toggleGrayscale:)];[self helpView:self.grayscaleButton text:self.grayHelp label:@"Grayscale"];
 self.grayOffPopup=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:YES];[self.grayOffPopup.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:self.grayOffPopup text:[self grayOffHelp] label:@"Turn Grayscale off for…"];[self populateGrayscaleOffPopup];
 self.grayOnButton=[NSButton buttonWithTitle:@"Grayscale back on now" target:self action:@selector(grayscaleBackOn:)];[self.grayOnButton.widthAnchor constraintEqualToConstant:220].active=YES;self.grayOnButton.hidden=YES;[self helpView:self.grayOnButton text:@"End the timed off and show Grayscale again now." label:@"Grayscale back on now"];
 self.warmthTitle=[NSTextField labelWithString:@"Extra Warmth"];self.warmthTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];[self helpView:self.warmthTitle text:self.warmthHelp label:nil];
 self.resetButton=[NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetWarmth:)];self.resetButton.bezelStyle=NSBezelStyleInline;[self helpView:self.resetButton text:@"Set Extra Warmth to Off. Grayscale and Night Shift stay as they are." label:@"Reset Extra Warmth"];
 self.warmthSlider=[self warmthSliderWithValue:[self currentWarmth]/3*100 action:@selector(warmthChanged:)];[self.warmthSlider setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[self helpView:self.warmthSlider text:self.warmthHelp label:@"Extra Warmth, percent"];
 self.warmthLabel=[NSTextField labelWithString:@""];self.warmthLabel.alignment=NSTextAlignmentRight;self.warmthLabel.font=[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightMedium];[self.warmthLabel.widthAnchor constraintEqualToConstant:56].active=YES;[self helpView:self.warmthLabel text:self.warmthHelp label:@"Extra Warmth percentage"];
 NSMutableArray *ticks=[NSMutableArray new];for(NSString *t in @[@"Off",@"25",@"50",@"75",@"Red"]){NSTextField *r=[NSTextField labelWithString:t];r.font=[NSFont systemFontOfSize:10];r.textColor=NSColor.secondaryLabelColor;r.alignment=NSTextAlignmentCenter;[r.widthAnchor constraintEqualToConstant:30].active=YES;[ticks addObject:r];}
 NSStackView *tickRow=[self row:ticks];tickRow.distribution=NSStackViewDistributionEqualSpacing;
 self.nightButton=[NSButton checkboxWithTitle:@"Night Shift" target:self action:@selector(toggleNightShift:)];[self helpView:self.nightButton text:self.nightHelp label:@"Night Shift"];
 self.pausePopup=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:YES];[self.pausePopup.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:self.pausePopup text:self.pauseHelp label:@"Turn Night Shift off for…"];
 self.endPauseButton=[NSButton buttonWithTitle:@"End timed off" target:self action:@selector(endPauseNow:)];self.endPauseButton.hidden=YES;[self.endPauseButton.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:self.endPauseButton text:self.pauseHelp label:@"End timed off"];
 self.autoButton=[NSButton checkboxWithTitle:@"Extra Warmth follows Night Shift" target:self action:@selector(toggleAuto:)];[self helpView:self.autoButton text:self.autoHelp label:@"Extra Warmth follows Night Shift"];
 self.resumeButton=[NSButton buttonWithTitle:@"Resume Following" target:self action:@selector(resume:)];[self helpView:self.resumeButton text:@"Go back to following Night Shift now." label:@"Resume Following Now"];
 self.loginButton=[NSButton checkboxWithTitle:@"Launch at login" target:self action:@selector(login:)];[self helpView:self.loginButton text:@"Open Less Pull when you sign in to your Mac. Install it in Applications first." label:@"Launch at login"];
 self.loginNote=[self note:@"Less Pull moved its settings to a new home with this update. If you had Launch at login on, check it again here; an older entry may remain in System Settings → Login Items and can be removed there."];self.loginNote.hidden=!([NSUserDefaults.standardUserDefaults boolForKey:@"migratedPreferences"]&&SMAppService.mainAppService.status!=SMAppServiceStatusEnabled);
// Shortcuts tab: Peek in color, Toggle Grayscale, and what clicking the icon does.
 NSMutableArray *views=[NSMutableArray new];
 if(self.welcomeWanted){self.welcomeCard=[self welcomeCardView];[views addObject:self.welcomeCard];}
 if(self.thanksWanted){self.thanksCard=[self thanksCardView];[views addObject:self.thanksCard];}
 [views addObjectsFromArray:@[self.statusText,self.statusDetail,[self separator],
  [self row:@[self.grayscaleButton,[self spacer],self.grayOffPopup,self.grayOnButton]],[self note:@"Shades of gray, day and night. Exceptions for apps and websites can show color. Off for a while brings it back by itself."],
  [self row:@[self.warmthTitle,[self spacer],self.resetButton]],[self row:@[self.warmthSlider,self.warmthLabel]],tickRow,[self note:@"Adds warmth on top of Night Shift, from Off to Red."],[self separator],
  [self row:@[self.nightButton,[self spacer],self.pausePopup,self.endPauseButton]],[self note:@"Turns Night Shift on or off now; your schedule in System Settings stays as it is."],
  [self row:@[self.autoButton,[self spacer],self.resumeButton]],[self note:@"On: Extra Warmth only while Night Shift is on, none in the daytime. Off: Extra Warmth stays on all day."],[self separator],
  self.loginButton,self.loginNote,[self multi:[self separator]],[self multi:[self displaysSection]],[self separator],[self advancedBlock]]];
 NSStackView *column=[self column:views];
 tickRow.identifier=@"fixed";[tickRow.widthAnchor constraintEqualToAnchor:self.warmthSlider.widthAnchor].active=YES;
 NSUInteger base=(self.welcomeCard?1:0)+(self.thanksCard?1:0);[column setCustomSpacing:4 afterView:self.statusText];[column setCustomSpacing:4 afterView:column.arrangedSubviews[base+3]];[column setCustomSpacing:6 afterView:column.arrangedSubviews[base+5]];[column setCustomSpacing:2 afterView:column.arrangedSubviews[base+6]];[column setCustomSpacing:6 afterView:tickRow];[column setCustomSpacing:4 afterView:column.arrangedSubviews[base+10]];[column setCustomSpacing:4 afterView:column.arrangedSubviews[base+12]];
 return column;
}
- (NSStackView *)shortcutsTab {
 NSTextField *clickTitle=[NSTextField labelWithString:@"Left-clicking the menu-bar icon"];clickTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.clickPopup=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];[self.clickPopup addItemsWithTitles:@[@"Opens the menu",@"Toggles Grayscale"]];self.clickPopup.target=self;self.clickPopup.action=@selector(clickBehaviorChanged:);[self.clickPopup.widthAnchor constraintEqualToConstant:200].active=YES;[self helpView:self.clickPopup text:@"What the left and right mouse buttons do on the menu-bar icon. Control-click counts as a right-click." label:@"Clicking the menu-bar icon"];
 NSTextField *grayShortcutTitle=[NSTextField labelWithString:@"Toggle Grayscale shortcut"];grayShortcutTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.grayscaleRecorder=[ShortcutRecorder new];self.grayscaleRecorder.bezelStyle=NSBezelStyleRounded;self.grayscaleRecorder.title=@"Record Shortcut";self.grayscaleRecorder.target=self;self.grayscaleRecorder.action=@selector(startRecording:);[self.grayscaleRecorder.widthAnchor constraintGreaterThanOrEqualToConstant:150].active=YES;
 __weak AppDelegate *weakGray=self;self.grayscaleRecorder.recorded=^(NSInteger keyCode,NSEventModifierFlags modifiers){[weakGray saveShortcut:@"grayscaleShortcut" keyCode:keyCode modifiers:modifiers];};self.grayscaleRecorder.cleared=^{[weakGray saveShortcut:@"grayscaleShortcut" keyCode:-1 modifiers:0];};
 [self helpView:self.grayscaleRecorder text:@"Click, then press the keys to use. Press them anywhere to turn Grayscale on or off." label:@"Toggle Grayscale shortcut"];
 NSButton *suggestGray=[NSButton buttonWithTitle:@"Suggest" target:self action:@selector(suggestShortcut:)];suggestGray.identifier=@"grayscaleShortcut";suggestGray.bezelStyle=NSBezelStyleInline;[self helpView:suggestGray text:@"Pick a shortcut that is free of macOS shortcuts and of Less Pull’s other shortcut." label:@"Suggest a Toggle Grayscale shortcut"];
 self.grayscaleShortcutNote=[self note:@""];
 NSButton *suggestPeek=[NSButton buttonWithTitle:@"Suggest" target:self action:@selector(suggestShortcut:)];suggestPeek.identifier=@"peekShortcut";suggestPeek.bezelStyle=NSBezelStyleInline;[self helpView:suggestPeek text:@"Pick a shortcut that is free of macOS shortcuts and of Less Pull’s other shortcut." label:@"Suggest a Peek in color shortcut"];
 self.peekGrayButton=[NSButton checkboxWithTitle:@"Grayscale" target:self action:@selector(peekEffectChanged:)];self.peekGrayButton.identifier=@"grayscale";self.peekWarmthButton=[NSButton checkboxWithTitle:@"Extra Warmth" target:self action:@selector(peekEffectChanged:)];self.peekWarmthButton.identifier=@"warmth";self.peekNightButton=[NSButton checkboxWithTitle:@"Night Shift" target:self action:@selector(peekEffectChanged:)];self.peekNightButton.identifier=@"nightShift";
 for(NSButton *b in @[self.peekGrayButton,self.peekWarmthButton,self.peekNightButton])[self helpView:b text:@"Turned off while you hold the Peek shortcut." label:[NSString stringWithFormat:@"While peeking, turn off %@",b.title]];
 NSTextField *peekEffectsLabel=[NSTextField labelWithString:@"While peeking, turn off:"];peekEffectsLabel.font=[NSFont systemFontOfSize:12];
 NSTextField *peekScopeLabel=[NSTextField labelWithString:@"Peek on:"];peekScopeLabel.font=[NSFont systemFontOfSize:12];
 self.peekScopePopup=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];[self.peekScopePopup addItemsWithTitles:@[@"All displays",@"The display under the mouse pointer"]];self.peekScopePopup.target=self;self.peekScopePopup.action=@selector(peekScopeChanged:);[self.peekScopePopup selectItemAtIndex:[NSUserDefaults.standardUserDefaults boolForKey:@"peekActiveDisplayOnly"]?1:0];[self helpView:self.peekScopePopup text:@"With more than one display: peek only on the display under the mouse pointer (a double press keeps that display plain; the next press there lets go, so each display is toggled on its own), or everywhere at once." label:@"Peek on"];
 NSTextField *peekTitle=[NSTextField labelWithString:@"Peek in color"];peekTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.peekRecorder=[ShortcutRecorder new];self.peekRecorder.bezelStyle=NSBezelStyleRounded;self.peekRecorder.title=@"Record Shortcut";self.peekRecorder.target=self;self.peekRecorder.action=@selector(startRecording:);[self.peekRecorder.widthAnchor constraintGreaterThanOrEqualToConstant:150].active=YES;
 __weak AppDelegate *weakSelf=self;self.peekRecorder.recorded=^(NSInteger keyCode,NSEventModifierFlags modifiers){[weakSelf savePeekShortcutKeyCode:keyCode modifiers:modifiers];};self.peekRecorder.cleared=^{[weakSelf savePeekShortcutKeyCode:-1 modifiers:0];};
 [self helpView:self.peekRecorder text:@"Click, then press the keys to use. Hold them to see the plain display; let go to return." label:@"Peek in color shortcut"];
 self.peekNote=[self note:@""];
 NSStackView *column=[self column:@[[self row:@[peekTitle,[self spacer],suggestPeek,self.peekRecorder]],self.peekNote,[self adv:[self row:@[peekEffectsLabel,self.peekGrayButton,self.peekWarmthButton,self.peekNightButton]]],[self multi:[self row:@[peekScopeLabel,self.peekScopePopup]]],[self separator],
  [self row:@[grayShortcutTitle,[self spacer],suggestGray,self.grayscaleRecorder]],self.grayscaleShortcutNote,[self adv:[self separator]],
  [self adv:[self row:@[clickTitle,[self spacer],self.clickPopup]]],[self adv:[self note:@"With Opens the menu, a right-click (or Control-click) toggles Grayscale. With Toggles Grayscale, a right-click opens the menu."]]]];
 [column setCustomSpacing:4 afterView:column.arrangedSubviews[0]];[column setCustomSpacing:6 afterView:column.arrangedSubviews[1]];[column setCustomSpacing:4 afterView:column.arrangedSubviews[5]];[column setCustomSpacing:4 afterView:column.arrangedSubviews[8]];[self refreshPeekRecorder:nil];
 return column;
}
- (void)showSessions:(id)sender {[self showSettings:nil];self.settingsTabs.selectedTabViewItemIndex=2;}
- (NSString *)minutesList:(NSString *)key fallback:(NSArray *)fallback {NSMutableArray *parts=[NSMutableArray new];for(NSNumber *m in [self sessionPresets:key fallback:fallback])[parts addObject:m.stringValue];return [parts componentsJoinedByString:@", "];}
// Saved as you type (no Return needed); the field is tidied when you leave it.
- (void)savePresets:(NSTextField *)sender tidy:(BOOL)tidy {NSMutableArray *list=[NSMutableArray new];for(NSString *part in [sender.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", ;"]]){NSInteger v=part.integerValue;if(v>0&&v<=24*60&&![list containsObject:@(v)])[list addObject:@(v)];}
 NSString *key=sender.identifier;NSArray *fallback=[key isEqual:@"sessionPresets"]?@[@25,@45,@60,@90]:@[@5,@9,@13,@33];if(list.count)[NSUserDefaults.standardUserDefaults setObject:list forKey:key];else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];if(tidy)sender.stringValue=[self minutesList:key fallback:fallback];}
- (void)presetsChanged:(NSTextField *)sender {[self savePresets:sender tidy:YES];}
- (void)controlTextDidChange:(NSNotification *)note {NSTextField *f=note.object;if([f isKindOfClass:NSTextField.class]&&([f.identifier isEqual:@"sessionPresets"]||[f.identifier isEqual:@"callBackPresets"]))[self savePresets:f tidy:NO];}
- (void)controlTextDidEndEditing:(NSNotification *)note {NSTextField *f=note.object;if([f isKindOfClass:NSTextField.class]&&([f.identifier isEqual:@"sessionPresets"]||[f.identifier isEqual:@"callBackPresets"]))[self savePresets:f tidy:YES];}
// Chips in rows of up to five, so any number of lengths fits the panel.
- (NSArray<NSView *> *)chipRows:(NSArray<NSButton *> *)chips {NSUInteger per=chips.count<=4?4:5;NSMutableArray *rows=[NSMutableArray new];for(NSUInteger i=0;i<chips.count;i+=per){NSMutableArray *items=[[chips subarrayWithRange:NSMakeRange(i,MIN(per,chips.count-i))] mutableCopy];while(items.count<per)[items addObject:[NSView new]];NSStackView *r=[self row:items];r.spacing=6;r.distribution=NSStackViewDistributionFillEqually;[rows addObject:r];}return rows;}
- (void)sessionOptionChanged:(NSControl *)sender {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if([sender.identifier isEqual:@"remind"]){NSInteger v=[(NSPopUpButton *)sender selectedTag];[d setInteger:v forKey:@"sessionRemindEvery"];self.session.remindEvery=v;[self persistSession];}else [d setBool:[(NSButton *)sender state]==NSControlStateValueOn forKey:sender.identifier];}
- (void)trySessionSound:(id)sender {[self glow:@"That was 30 minutes." sound:@"session-end"];}
- (NSStackView *)sessionsTab {
 NSTextField *intro=[NSTextField wrappingLabelWithString:@"A session is a stretch of focused work with a gentle end. Start one from the menu. The icon shows the minutes left; at the end, a soft glow and a calm sound, and the count goes on past the end so you can finish your thought. When you leave, Less Pull can call you back once."];intro.preferredMaxLayoutWidth=452;
 NSTextField *lengthsLabel=[NSTextField labelWithString:@"Session lengths"];lengthsLabel.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.sessionPresetsField=[NSTextField textFieldWithString:[self minutesList:@"sessionPresets" fallback:@[@25,@45,@60,@90]]];self.sessionPresetsField.identifier=@"sessionPresets";self.sessionPresetsField.target=self;self.sessionPresetsField.action=@selector(presetsChanged:);self.sessionPresetsField.delegate=self;self.sessionPresetsField.placeholderString=@"25, 45, 60, 90";[self.sessionPresetsField.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:self.sessionPresetsField text:@"Minutes, separated by commas. These appear under Start a session in the menu." label:@"Session lengths in minutes"];
 NSTextField *backLabel=[NSTextField labelWithString:@"Call me back in"];backLabel.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 self.callBackPresetsField=[NSTextField textFieldWithString:[self minutesList:@"callBackPresets" fallback:@[@5,@9,@13,@33]]];self.callBackPresetsField.identifier=@"callBackPresets";self.callBackPresetsField.target=self;self.callBackPresetsField.action=@selector(presetsChanged:);self.callBackPresetsField.delegate=self;self.callBackPresetsField.placeholderString=@"5, 9, 13, 33";[self.callBackPresetsField.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:self.callBackPresetsField text:@"Minutes, separated by commas. Offered when you leave after a session; you are called back once." label:@"Call me back in, minutes"];
 NSTextField *remindLabel=[NSTextField labelWithString:@"After the end, remind me"];remindLabel.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 NSPopUpButton *remind=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];for(NSArray *pair in @[@[@"Never",@0],@[@"Every 3 minutes",@3],@[@"Every 5 minutes",@5],@[@"Every 10 minutes",@10],@[@"Every 15 minutes",@15]]){[remind addItemWithTitle:pair[0]];remind.lastItem.tag=[pair[1] integerValue];}[remind selectItemWithTag:[NSUserDefaults.standardUserDefaults integerForKey:@"sessionRemindEvery"]];remind.identifier=@"remind";remind.target=self;remind.action=@selector(sessionOptionChanged:);[remind.widthAnchor constraintEqualToConstant:220].active=YES;[self helpView:remind text:@"A quieter glow and sound while the session runs past its end, until you leave or end it." label:@"Remind me after the end"];
 NSButton *sound=[NSButton checkboxWithTitle:@"Play a calm sound" target:self action:@selector(sessionOptionChanged:)];sound.identifier=@"sessionSound";sound.state=[NSUserDefaults.standardUserDefaults boolForKey:@"sessionSound"];[self helpView:sound text:@"A soft bell at the end, quieter for reminders, two rising notes for the call back." label:@"Play a calm sound"];
 NSButton *glow=[NSButton checkboxWithTitle:@"Show a gentle glow" target:self action:@selector(sessionOptionChanged:)];glow.identifier=@"sessionGlow";glow.state=[NSUserDefaults.standardUserDefaults boolForKey:@"sessionGlow"];[self helpView:glow text:@"A warm bloom across the screen for three seconds, with one line of text. It never takes focus and never blocks a click." label:@"Show a gentle glow"];
 NSButton *try=[NSButton buttonWithTitle:@"Try it" target:self action:@selector(trySessionSound:)];try.bezelStyle=NSBezelStyleInline;[self helpView:try text:@"Shows the glow and plays the sound once, as at the end of a session." label:@"Try the glow and sound"];
 NSStackView *column=[self column:@[intro,[self separator],[self row:@[lengthsLabel,[self spacer],self.sessionPresetsField]],[self note:@"Minutes, separated by commas. These appear under Start a session in the menu."],
  [self row:@[backLabel,[self spacer],self.callBackPresetsField]],[self note:@"Offered when you choose Leaving now. You are called back once, then the session is over for good."],[self separator],
  [self row:@[remindLabel,[self spacer],remind]],[self row:@[sound,glow,[self spacer],try]],[self note:@"While a session runs, a click on the icon opens the session panel; the other mouse button opens the menu. The Peek and Toggle shortcuts keep working."]]];
 [column setCustomSpacing:4 afterView:column.arrangedSubviews[2]];[column setCustomSpacing:4 afterView:column.arrangedSubviews[4]];return column;
}
- (NSStackView *)appsTab {
 NSTextField *intro=[NSTextField wrappingLabelWithString:@"Give an app its own display settings. They apply while that app is in front with a window open; your default settings stay saved."];intro.preferredMaxLayoutWidth=452;
 self.exclusionText=[self note:@"Using your default settings"];
 NSScrollView *scroll=[NSScrollView new];scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;[scroll.heightAnchor constraintEqualToConstant:300].active=YES;
 self.exclusionsList=[ExceptionStack new];self.exclusionsList.orientation=NSUserInterfaceLayoutOrientationVertical;self.exclusionsList.alignment=NSLayoutAttributeLeading;self.exclusionsList.spacing=0;self.exclusionsList.translatesAutoresizingMaskIntoConstraints=NO;scroll.documentView=self.exclusionsList;[self.exclusionsList.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active=YES;
 NSPopUpButton *add=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:YES];self.addAppMenu=add.menu;add.menu.delegate=self;[add.menu addItemWithTitle:@"Add app…" action:nil keyEquivalent:@""];[add.widthAnchor constraintEqualToConstant:150].active=YES;[self helpView:add text:@"Pick one of the apps running now, or choose another app." label:@"Add an app exception"];
 NSStackView *column=[self column:@[intro,self.exclusionText,scroll,[self row:@[add,[self spacer]]],[self note:@"If Night Shift is turned off for a while, that wins over an app’s Night Shift On. Grayscale Off, warmth Off and Night Shift Off together show the plain display."]]];
 [column setCustomSpacing:6 afterView:intro];
 return column;
}
- (NSStackView *)websitesTab {
 NSTextField *intro=[NSTextField wrappingLabelWithString:@"Websites can have their own settings through the Less Pull browser extension, for Safari, Brave, Chrome, Firefox, Opera and Edge. With a website in front, the menu-bar menu offers “Exception for that site”, like it does for apps; the extension itself has no buttons."];intro.preferredMaxLayoutWidth=452;
 self.websiteStatus=[self note:@""];
 NSButton *install=[NSButton buttonWithTitle:@"Install Browser Extension…" target:self action:@selector(installBrowserExtension:)];[self helpView:install text:@"Add the Less Pull extension to your browser so websites can have their own settings. Less Pull must stay open." label:@"Install Browser Extension"];
 NSTextField *savedTitle=[NSTextField labelWithString:@"Saved website exceptions"];savedTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
 NSScrollView *scroll=[NSScrollView new];scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;[scroll.heightAnchor constraintEqualToConstant:300].active=YES;
 self.websiteRulesList=[ExceptionStack new];self.websiteRulesList.orientation=NSUserInterfaceLayoutOrientationVertical;self.websiteRulesList.alignment=NSLayoutAttributeLeading;self.websiteRulesList.spacing=0;self.websiteRulesList.translatesAutoresizingMaskIntoConstraints=NO;scroll.documentView=self.websiteRulesList;[self.websiteRulesList.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active=YES;
 NSStackView *column=[self column:@[intro,[self row:@[install,[self spacer]]],self.websiteStatus,[self separator],savedTitle,scroll,[self note:@"Change a website’s settings here or from the menu while the site is in front. Less Pull must stay open for website exceptions to work; private tabs are left alone."]]];
 [column setCustomSpacing:4 afterView:column.arrangedSubviews[1]];[column setCustomSpacing:6 afterView:savedTitle];[self rebuildWebsiteRulesList];
 return column;
}
// Saved website rules only (domains and exact pages), never the tab that is open now.
- (NSString *)websiteRuleSummary:(NSDictionary *)rule {
 NSMutableArray *parts=[NSMutableArray new];if(!RuleEnabled(rule))[parts addObject:@"Off"];NSArray *words=@[@"default",@"on",@"off"];
 [parts addObject:[NSString stringWithFormat:@"Grayscale %@",words[MIN(2,MAX(0,[rule[@"grayMode"] integerValue]))]]];[parts addObject:[NSString stringWithFormat:@"Night Shift %@",words[MIN(2,MAX(0,[rule[@"nightMode"] integerValue]))]]];
 [parts addObject:[rule[@"customWarmth"] boolValue]?([rule[@"warmth"] doubleValue]>0?[NSString stringWithFormat:@"Warmth %.0f%%",[rule[@"warmth"] doubleValue]]:@"Warmth off"):@"Warmth default"];
 return [parts componentsJoinedByString:@" · "];
}
// A website row in Settings: the same controls as an app row; changes go through the bridge.
- (void)websiteRowChanged:(NSControl *)sender {
 NSString *key=sender.identifier;NSMutableDictionary *rule=[self.browserBridge.rules[key] mutableCopy];if(!rule)return;NSDictionary *before=[rule copy];
 if([sender isKindOfClass:NSSegmentedControl.class])rule[sender.tag==0?@"grayMode":@"nightMode"]=@([(NSSegmentedControl *)sender selectedSegment]);
 else if(sender.tag==2)rule[@"customWarmth"]=@([(NSButton *)sender state]==NSControlStateValueOff);
 else if(sender.tag==4)rule[@"enabled"]=@([(NSButton *)sender state]==NSControlStateValueOn);
 else if(sender.tag==5)rule[@"allDisplays"]=@([(NSButton *)sender state]==NSControlStateValueOn);
 else {rule[@"warmth"]=@([(NSSlider *)sender doubleValue]);if([(NSSlider *)sender doubleValue]>0)rule[@"customWarmth"]=@YES;}
 if(sender.tag!=4&&sender.tag!=5)RuleAfterChange(before,rule);
 [self.browserBridge handle:@{@"type":@"set",@"scope":[key containsString:@"://"]?@"url":@"domain",@"site":key,@"rule":rule}];
 if(sender.tag!=3)[self rebuildWebsiteRulesList];else {NSTextField *readout=[sender.superview viewWithTag:99];readout.stringValue=[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]];NSButton *inherit=[sender.superview viewWithTag:2];inherit.state=![rule[@"customWarmth"] boolValue];NSView *top=sender;while(top&&![top.identifier isEqual:key])top=top.superview;NSButton *en=[top viewWithTag:4];if([en isKindOfClass:NSButton.class])en.state=RuleEnabled(rule);}
}
- (NSView *)websiteRowForKey:(NSString *)key rule:(NSDictionary *)rule {
 BOOL exact=[key containsString:@"://"];NSTextField *name=[NSTextField labelWithString:key];name.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];name.lineBreakMode=NSLineBreakByTruncatingMiddle;name.toolTip=key;[name setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
 NSImageView *icon=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:exact?@"doc.text":@"globe" accessibilityDescription:exact?@"Exact page":@"Whole domain"]];[icon.widthAnchor constraintEqualToConstant:20].active=YES;
 NSButton *enable=[NSButton checkboxWithTitle:@"Use this exception" target:self action:@selector(websiteRowChanged:)];enable.identifier=key;enable.tag=4;enable.state=RuleEnabled(rule);enable.font=[NSFont systemFontOfSize:12];[self helpView:enable text:@"Off keeps the settings below but does not apply them. Changing a setting away from default switches it on again." label:[NSString stringWithFormat:@"Use the exception for %@",key]];
 NSButton *remove=[NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeWebsiteRule:)];remove.identifier=key;remove.bezelStyle=NSBezelStyleInline;[self helpView:remove text:@"Remove this website exception. The site then uses the inherited settings." label:[NSString stringWithFormat:@"Remove exception for %@",key]];
 BOOL open=[self ruleOpen:key rule:rule];
 NSButton *more=[NSButton buttonWithTitle:open?@"Less":@"More" target:self action:@selector(toggleRuleDetails:)];more.identifier=key;more.tag=7;more.bezelStyle=NSBezelStyleInline;more.font=[NSFont systemFontOfSize:11];[self helpView:more text:@"Warmth for this site and, with several displays, which displays it covers." label:[NSString stringWithFormat:@"%@ — more settings",key]];
 NSStackView *header=[self row:@[icon,name,[self spacer],enable,more,remove]];
 NSTextField *kind=[self note:exact?@"Exact page":@"Whole domain, including subdomains"];
 NSDictionary *inherited=[self.browserBridge inheritedForSite:key browser:nil];NSArray *words=@[@"",@"On",@"Off"];NSMutableArray *choices=[NSMutableArray new];NSArray *titles=@[@"Grayscale",@"Night Shift"];
 for(int i=0;i<2;i++){NSTextField *label=[NSTextField labelWithString:titles[i]];NSInteger resolved=[inherited[i==0?@"grayMode":@"nightMode"] integerValue];NSSegmentedControl *choice=[NSSegmentedControl segmentedControlWithLabels:@[resolved?[NSString stringWithFormat:@"Default (%@)",words[resolved]]:@"Default",@"On",@"Off"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(websiteRowChanged:)];choice.selectedSegment=[rule[i==0?@"grayMode":@"nightMode"] integerValue];choice.identifier=key;choice.tag=i;choice.controlSize=NSControlSizeSmall;choice.font=[NSFont systemFontOfSize:11];[choice setWidth:resolved?70:46 forSegment:0];[choice setWidth:30 forSegment:1];[choice setWidth:30 forSegment:2];[self helpView:choice text:@"Default keeps what the site inherits." label:[NSString stringWithFormat:@"%@ — %@",key,titles[i]]];[choices addObject:label];[choices addObject:choice];}
 NSStackView *modes=[self row:choices];modes.spacing=6;[modes setCustomSpacing:14 afterView:choices[1]];
 double inheritedWarmth=[inherited[@"warmth"] doubleValue];NSButton *inherit=[NSButton checkboxWithTitle:[NSString stringWithFormat:@"Use default warmth (%@)",inheritedWarmth>0?[NSString stringWithFormat:@"%.0f%%",inheritedWarmth]:@"Off"] target:self action:@selector(websiteRowChanged:)];inherit.identifier=key;inherit.tag=2;inherit.state=![rule[@"customWarmth"] boolValue];[self helpView:inherit text:@"Uncheck, or move the slider, to give this site its own Extra Warmth." label:[NSString stringWithFormat:@"%@ — Use default warmth",key]];
 NSSlider *slider=[self warmthSliderWithValue:[rule[@"warmth"] doubleValue] action:@selector(websiteRowChanged:)];slider.identifier=key;slider.tag=3;[slider.widthAnchor constraintGreaterThanOrEqualToConstant:160].active=YES;[slider setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];[self helpView:slider text:@"Extra Warmth for this site, from Off to Red." label:[NSString stringWithFormat:@"%@ — Extra Warmth percent",key]];
 NSTextField *percent=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];percent.tag=99;percent.alignment=NSTextAlignmentRight;percent.font=[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];[percent.widthAnchor constraintEqualToConstant:44].active=YES;
 NSStackView *warmth=[self row:@[inherit,slider,percent]];
 NSButton *span=[NSButton checkboxWithTitle:@"On every display" target:self action:@selector(websiteRowChanged:)];span.identifier=key;span.tag=5;span.state=[rule[@"allDisplays"] boolValue];span.font=[NSFont systemFontOfSize:12];[self helpView:span text:@"While this site is in front, its settings cover every display, not only the one the browser window is on." label:[NSString stringWithFormat:@"%@ — On every display",key]];
 NSTextField *peekLabel=[NSTextField labelWithString:@"Peek toggles:"];peekLabel.font=[NSFont systemFontOfSize:12];
 NSPopUpButton *peekPick=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:YES];peekPick.font=[NSFont systemFontOfSize:12];[peekPick.widthAnchor constraintEqualToConstant:200].active=YES;
 NSMenu *pickMenu=[self peekDisplaysMenuForKey:key website:YES];[pickMenu insertItem:[[NSMenuItem alloc]initWithTitle:[self peekTargetsLabel:rule] action:nil keyEquivalent:@""] atIndex:0];peekPick.menu=pickMenu;[self helpView:peekPick text:@"Which displays Peek toggles while this site is in front." label:[NSString stringWithFormat:@"%@ — Peek toggles",key]];
 NSStackView *spans=[self row:@[span,[self spacer],peekLabel,peekPick]];spans.spacing=6;spans.hidden=![self multiDisplay];
 NSStackView *details=[self column:@[warmth,spans]];details.spacing=8;details.hidden=!open;
 NSStackView *row=[self column:@[header,kind,modes,details]];row.spacing=6;row.edgeInsets=NSEdgeInsetsMake(10,10,10,10);row.identifier=key;[header.widthAnchor constraintEqualToAnchor:row.widthAnchor constant:-20].active=YES;[details.widthAnchor constraintEqualToAnchor:row.widthAnchor constant:-20].active=YES;[warmth.widthAnchor constraintEqualToAnchor:details.widthAnchor].active=YES;[spans.widthAnchor constraintEqualToAnchor:details.widthAnchor].active=YES;
 return row;
}
- (void)rebuildWebsiteRulesList {
 if(!self.websiteRulesList)return;for(NSView *v in self.websiteRulesList.arrangedSubviews.copy){[self.websiteRulesList removeArrangedSubview:v];[v removeFromSuperview];}
 NSArray *keys=[self.browserBridge.rules.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
 if(!keys.count){NSTextField *empty=[NSTextField labelWithString:@"No website exceptions yet. With a website in front, use “Exception for …” in the menu."];empty.textColor=NSColor.secondaryLabelColor;NSStackView *pad=[self column:@[empty]];pad.edgeInsets=NSEdgeInsetsMake(10,10,10,10);[self.websiteRulesList addArrangedSubview:pad];}
 BOOL first=YES;for(NSString *key in keys){if(!first){NSBox *line=[self separator];[self.websiteRulesList addArrangedSubview:line];[line.widthAnchor constraintEqualToAnchor:self.websiteRulesList.widthAnchor].active=YES;}first=NO;
  NSView *row=[self websiteRowForKey:key rule:self.browserBridge.rules[key]];
  [self.websiteRulesList addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:self.websiteRulesList.widthAnchor].active=YES;}
}
- (void)removeWebsiteRule:(NSButton *)sender {NSString *key=sender.identifier;if(!key)return;[self.browserBridge handle:@{@"type":@"remove",@"scope":[key containsString:@"://"]?@"url":@"domain",@"site":key}];[self rebuildWebsiteRulesList];}
// A thank-you card in Settings → General: the first time Settings is opened after 14
// days of use, never on its own. Support and Remind me are the prominent choices;
// Don't show again is quiet. Remind me repeats monthly; the others end it.
- (void)noteFirstLaunch {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if(![d objectForKey:@"firstLaunchDate"])[d setObject:NSDate.date forKey:@"firstLaunchDate"];}
- (BOOL)thanksDue {
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;if([NSProcessInfo.processInfo.arguments containsObject:@"--thanks"])return YES;if([d boolForKey:@"thanksDismissed"])return NO;
 NSDate *first=[d objectForKey:@"firstLaunchDate"],*next=[d objectForKey:@"thanksNextDate"];NSDate *due=[next isKindOfClass:NSDate.class]?next:[[first isKindOfClass:NSDate.class]?first:NSDate.date dateByAddingTimeInterval:14*86400];
 return [NSDate.date compare:due]!=NSOrderedAscending;
}
- (NSView *)thanksCardView {
 NSTextField *title=[NSTextField labelWithString:@"Are you enjoying Less Pull?"];title.font=[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
 NSTextField *body=[NSTextField wrappingLabelWithString:@"This app is a gift from the universe to you. It has been fully funded by life.\n\nMy future projects and my work are still being developed, and they benefit from any kind of support: a contribution, telling a friend, or whatever you choose. Thanks for being part of life and making it more beautiful for everyone.\n\n— Jiri Arion Rose"];body.preferredMaxLayoutWidth=404;
 NSButton *support=[NSButton buttonWithTitle:@"Support my work" target:self action:@selector(thanksSupport:)];support.keyEquivalent=@"\r";[self helpView:support text:@"Open buymeacoffee.com/HsERf62fiZ in your default browser." label:@"Support my work — Buy me a coffee"];
 NSButton *later=[NSButton buttonWithTitle:@"Remind me in a month" target:self action:@selector(thanksLater:)];[self helpView:later text:@"Hide this and show it again in about a month." label:@"Remind me in a month"];
 NSButton *never=[NSButton buttonWithTitle:@"Don’t show again" target:self action:@selector(thanksNever:)];never.bezelStyle=NSBezelStyleInline;never.font=[NSFont systemFontOfSize:11];[self helpView:never text:@"Hide this for good." label:@"Don’t show this again"];
 NSMutableArray *links=[NSMutableArray new];for(NSButton *b in [self authorLinkButtons])if(![b.identifier isEqual:LessPullCoffee]){b.font=[NSFont systemFontOfSize:11];[links addObject:b];}
 NSStackView *linkRow=[self row:links];linkRow.spacing=4;NSStackView *buttons=[self row:@[support,later,[self spacer],never]];buttons.spacing=8;
 NSStackView *card=[self column:@[title,body,buttons,linkRow]];card.spacing=10;card.edgeInsets=NSEdgeInsetsMake(14,14,12,14);card.wantsLayer=YES;card.layer.cornerRadius=8;card.layer.backgroundColor=[NSColor.labelColor colorWithAlphaComponent:.06].CGColor;
 for(NSView *v in card.arrangedSubviews)if([v isKindOfClass:NSStackView.class])[v.widthAnchor constraintEqualToAnchor:card.widthAnchor constant:-28].active=YES;
 return card;
}
- (void)removeThanksCard {NSView *card=self.thanksCard;if(!card)return;NSStackView *column=(NSStackView *)card.superview;[column removeArrangedSubview:card];[card removeFromSuperview];self.thanksCard=nil;self.thanksWanted=NO;[column layoutSubtreeIfNeeded];self.settingsTabs.tabViewItems.firstObject.viewController.preferredContentSize=NSMakeSize(500,column.fittingSize.height);self.settingsTabs.selectedTabViewItemIndex=1;self.settingsTabs.selectedTabViewItemIndex=0;}
- (void)thanksSupport:(id)sender {[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"thanksDismissed"];[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:LessPullCoffee]];[self removeThanksCard];}
- (void)thanksLater:(id)sender {[NSUserDefaults.standardUserDefaults setObject:[NSDate.date dateByAddingTimeInterval:30*86400] forKey:@"thanksNextDate"];[self removeThanksCard];}
- (void)thanksNever:(id)sender {[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"thanksDismissed"];[NSUserDefaults.standardUserDefaults removeObjectForKey:@"thanksNextDate"];[self removeThanksCard];}
- (NSStackView *)aboutTab {
 NSImageView *icon=[NSImageView imageViewWithImage:NSApp.applicationIconImage];[icon.widthAnchor constraintEqualToConstant:64].active=YES;[icon.heightAnchor constraintEqualToConstant:64].active=YES;icon.accessibilityLabel=@"Less Pull app icon";
 NSTextField *name=[NSTextField labelWithString:@"Less Pull"];name.font=[NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
 NSTextField *version=[NSTextField labelWithString:[NSString stringWithFormat:@"Version %@",[self runningVersionLabel]]];version.textColor=NSColor.secondaryLabelColor;version.toolTip=@"It will always be 1.4.4. The build number is what changes.";version.accessibilityHelp=version.toolTip;
 NSTextField *credit=[NSTextField labelWithString:@"© 2026 Jiri Arion Rose"];credit.font=[NSFont systemFontOfSize:11];credit.textColor=NSColor.secondaryLabelColor;
 NSTextField *forever=[NSTextField labelWithString:@"It will always be 1.4.4. The build number is what changes."];forever.font=[NSFont systemFontOfSize:10];forever.textColor=NSColor.tertiaryLabelColor;
 NSStackView *identity=[self column:@[name,version,forever,credit]];identity.spacing=2;
 NSButton *help=[NSButton buttonWithTitle:@"Help" target:self action:@selector(showHelp:)];[self helpView:help text:@"A short guide to Less Pull." label:@"Help"];
 NSButton *diagnostics=[NSButton buttonWithTitle:@"Diagnostics…" target:self action:@selector(diagnostics:)];[self helpView:diagnostics text:@"Technical details for troubleshooting." label:@"Diagnostics"];
 NSButton *tour=[NSButton buttonWithTitle:@"Tour" target:self action:@selector(showTour:)];[self helpView:tour text:@"The short tour from the first launch, again." label:@"Show the tour"];
 NSButton *report=[NSButton buttonWithTitle:@"Report a Problem…" target:self action:@selector(reportProblem:)];[self helpView:report text:@"Opens a new issue on GitHub with the build number, your macOS version and the diagnostics filled in. Nothing is sent until you submit it there." label:@"Report a problem"];
 NSButton *licenses=[NSButton buttonWithTitle:@"Licenses" target:self action:@selector(showLicenses:)];[self helpView:licenses text:@"Show the app and source license files included with Less Pull." label:@"Show licenses"];
 self.updateCheckbox=[NSButton checkboxWithTitle:@"Check for updates automatically" target:self action:@selector(toggleUpdateChecks:)];[self helpView:self.updateCheckbox text:@"Once a day, Less Pull asks GitHub whether a newer build exists. Nothing about you is sent." label:@"Check for updates automatically"];
 self.updateButton=[NSButton buttonWithTitle:@"Check for Updates…" target:self action:@selector(checkForUpdatesNow:)];[self helpView:self.updateButton text:@"Ask GitHub now whether a newer version exists." label:@"Check for Updates"];
 self.updateStatusLabel=[self note:@""];
 NSStackView *column=[self column:@[[self row:@[icon,identity]],[self row:[self authorLinkButtons]],[self separator],[self row:@[help,tour,diagnostics,report,licenses]],[self separator],self.updateCheckbox,[self note:@"Once a day, one request to GitHub asks whether a newer build exists; a second one reads which macOS versions it is made for, so only builds for your macOS are offered. Nothing about you is sent, and you can turn this off."],[self row:@[self.updateButton,[self spacer]]],self.updateStatusLabel,[self note:@"Everything else stays on this Mac: no account, no analytics, no network service. The browser extension talks only to the app."]]];
 [(NSStackView *)column.arrangedSubviews[0] setSpacing:16];[column setCustomSpacing:4 afterView:self.updateCheckbox];[column setCustomSpacing:4 afterView:column.arrangedSubviews[7]];[self refreshUpdateControls];
 return column;
}
- (NSString *)websiteStatusLine {
 NSMutableArray *browsers=[NSMutableArray new];for(NSString *browser in self.browserBridge.contexts){NSDictionary *c=self.browserBridge.contexts[browser];if([NSDate.date timeIntervalSinceDate:c[@"time"]?:NSDate.distantPast]<=65)[browsers addObject:@{@"com.brave.Browser":@"Brave",@"org.mozilla.firefox":@"Firefox",@"com.operasoftware.Opera":@"Opera",@"com.microsoft.edgemac":@"Edge",@"com.apple.Safari":@"Safari"}[browser]?:@"Chrome"];}
 return browsers.count?[NSString stringWithFormat:@"Extension connected in %@.",[browsers componentsJoinedByString:@" and "]]:@"The extension is not connected right now. Open a browser with the extension installed.";
}
// The welcome card: a short welcome, then a tour of the few things that matter most, page by
// page in the same card at the same size, so nothing jumps. Skip tour is always at hand.
- (NSView *)welcomeCardView {
 NSStackView *card=[self column:@[]];card.edgeInsets=NSEdgeInsetsMake(14,14,12,14);card.wantsLayer=YES;card.layer.cornerRadius=8;card.layer.backgroundColor=[NSColor.labelColor colorWithAlphaComponent:.06].CGColor;
 self.tourCard=card;self.tourPage=0;self.tourHeight=0;[self showTourPage:0 animated:NO];return card;
}
- (NSView *)tourSymbol:(NSString *)name label:(NSString *)label {
 NSImage *image=[NSImage imageWithSystemSymbolName:name accessibilityDescription:label];image=[image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:30 weight:NSFontWeightLight]];
 NSImageView *v=[NSImageView imageViewWithImage:image];v.contentTintColor=[NSColor colorWithSRGBRed:.93 green:.55 blue:.28 alpha:1];[v.widthAnchor constraintEqualToConstant:44].active=YES;[v.heightAnchor constraintEqualToConstant:44].active=YES;v.accessibilityLabel=label;return v;
}
- (NSView *)tourPageView:(NSInteger)page {
 NSArray *titles=@[@"Welcome to Less Pull",@"The screen, quieter",@"Color where it matters",@"A peek, when you need it",@"Yours, and nobody else’s"];
 NSDictionary *peek=[self shortcutForKey:@"peekShortcut"],*toggle=[self shortcutForKey:@"grayscaleShortcut"];
 NSString *peekLabel=peek?[PeekShortcut labelForKeyCode:[peek[@"keyCode"] integerValue] modifiers:[peek[@"modifiers"] integerValue]]:@"the Peek shortcut",*toggleLabel=toggle?[PeekShortcut labelForKeyCode:[toggle[@"keyCode"] integerValue] modifiers:[toggle[@"modifiers"] integerValue]]:@"The Toggle Grayscale shortcut";
 NSArray *texts=@[@"You have arrived somewhere quieter.\n\nLess Pull takes the color out of your screen, so it pulls at you less — a little like stepping out of a loud room into a still one, or leaving the devices behind for a day outside. What matters is still here. It just stops shouting.\n\nWarmth is the second step, and not decoration: from amber to red it takes the blue out of the light, makes the screen quieter still, and puts you back in charge of how your screen speaks to you: how loudly tools and content may push, and what light reaches your eyes — and through them, your mind. Keep color only for the few apps and websites that truly need it.",
  @"Click the circle in the menu bar, at the top right of your screen. Grayscale takes the color out of everything. Extra Warmth takes the blue out of the light, from a touch of amber all the way to red.\n\nEvery change fades in over half a second, on every display you have.",
  @"A photo app, a video site, a chart: some things need color. Choose Exception for the app you are in, right in the menu, and set only what should differ. Everything else stays quiet.\n\nWebsites work the same way once the small browser extension connects. It lives under Websites.",
  [NSString stringWithFormat:@"Hold %@ and the screen is in color for exactly as long as you hold it. Press it twice quickly to keep it; one more press returns.\n\n%@ turns Grayscale on or off.\n\nBoth are set for you now. Change them under Shortcuts whenever you like.",peekLabel,toggleLabel],
  @"No account, no analytics, nothing leaves your Mac. The addresses of websites you visit pass through memory and are never stored.\n\nAnd because Less Pull changes the display itself, not the picture, screenshots, recordings and screen sharing keep their normal colors."];
 NSArray *symbols=@[@"",@"circle.lefthalf.filled",@"globe",@"eye",@"lock.shield"];
 NSTextField *title=[NSTextField labelWithString:titles[page]];title.font=[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
 NSTextField *text=[NSTextField wrappingLabelWithString:texts[page]];text.preferredMaxLayoutWidth=page==0?404:346;  // next to the symbol on the tour pages
 NSMutableArray *parts=[NSMutableArray arrayWithObject:title];
 if(page==0){NSImageView *icon=[NSImageView imageViewWithImage:[self statusImageGray:YES warmth:0]];[icon.widthAnchor constraintEqualToConstant:18].active=YES;[icon.heightAnchor constraintEqualToConstant:18].active=YES;icon.accessibilityLabel=@"The Less Pull menu-bar icon";
  NSTextField *where=[NSTextField wrappingLabelWithString:@"This is your icon; it is right above this window, fading in and out for a moment. On a small screen the menu bar fills up, and what does not fit is hidden, or tucked behind a » by a menu-bar tool. Hold ⌘ and drag the circle toward the clock to keep it in view."];where.preferredMaxLayoutWidth=376;NSStackView *iconRow=[self row:@[icon,where]];iconRow.alignment=NSLayoutAttributeTop;WelcomeHintView *hint=[WelcomeHintView new];hint.accessibilityLabel=@"A menu bar that is full: hold the Command key and drag the circle toward the clock";[parts addObjectsFromArray:@[text,iconRow,hint]];}
 else if(page==2){text.preferredMaxLayoutWidth=404;ExtensionHintView *hint=[ExtensionHintView new];hint.accessibilityLabel=@"A browser window; its site travels along an arrow into the menu-bar circle, where Exception for that site appears";[parts addObjectsFromArray:@[hint,text]];}
 else {NSStackView *body=[self row:@[[self tourSymbol:symbols[page] label:titles[page]],text]];body.alignment=NSLayoutAttributeTop;body.spacing=14;[parts addObject:body];}
 NSView *fill=[NSView new];[fill setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];[parts addObject:fill];
 NSButton *skip=[NSButton buttonWithTitle:@"Skip tour" target:self action:@selector(dismissWelcome:)];skip.bezelStyle=NSBezelStyleInline;skip.font=[NSFont systemFontOfSize:11];[self helpView:skip text:@"Close the welcome and the tour. You can open the tour again from the About tab." label:@"Skip tour"];
 NSMutableArray *nav=[NSMutableArray new];
 if(page==0){NSButton *start=[NSButton buttonWithTitle:@"Start tour" target:self action:@selector(tourNext:)];start.keyEquivalent=@"\r";[self helpView:start text:@"A tour of four short pages, right here." label:@"Start tour"];[nav addObjectsFromArray:@[[self spacer],skip,start]];}
 else {NSButton *back=[NSButton buttonWithTitle:@"Back" target:self action:@selector(tourBack:)];[self helpView:back text:@"The previous page." label:@"Back"];
  NSTextField *step=[NSTextField labelWithString:[NSString stringWithFormat:@"%ld of 4",(long)page]];step.font=[NSFont systemFontOfSize:11];step.textColor=NSColor.secondaryLabelColor;
  BOOL last=page==4;NSButton *next=[NSButton buttonWithTitle:last?@"Done":@"Next" target:self action:last?@selector(dismissWelcome:):@selector(tourNext:)];next.keyEquivalent=@"\r";[self helpView:next text:last?@"Close the tour.":@"The next page." label:next.title];
  [nav addObjectsFromArray:@[back,[self spacer],step,[self spacer]]];if(!last)[nav addObject:skip];[nav addObject:next];}
 [parts addObject:[self row:nav]];
 NSStackView *column=[self column:parts];column.spacing=8;return column;
}
- (void)showTourPage:(NSInteger)page animated:(BOOL)animated {
 NSStackView *card=self.tourCard;if(!card)return;NSView *old=card.arrangedSubviews.firstObject;NSStackView *next=(NSStackView *)[self tourPageView:page];self.tourPage=page;
 [card addArrangedSubview:next];[next.widthAnchor constraintEqualToAnchor:card.widthAnchor constant:-28].active=YES;for(NSView *v in next.arrangedSubviews)if([v isKindOfClass:NSStackView.class])[v.widthAnchor constraintEqualToAnchor:next.widthAnchor].active=YES;
 if(old){[card removeArrangedSubview:old];[old removeFromSuperview];}
 if(!self.tourHeight){[card layoutSubtreeIfNeeded];self.tourHeight=card.fittingSize.height;[card.heightAnchor constraintEqualToConstant:self.tourHeight].active=YES;}  // the welcome page sets the size; every page keeps it
 else [next.heightAnchor constraintEqualToConstant:self.tourHeight-26].active=YES;
 if(animated&&!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion){next.alphaValue=0;[NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx){ctx.duration=.5;next.animator.alphaValue=1;} completionHandler:nil];}
 if(self.settings)[self.settings makeFirstResponder:nil];
}
- (void)tourNext:(id)sender {if(self.tourPage<4)[self showTourPage:self.tourPage+1 animated:YES];}
- (void)tourBack:(id)sender {if(self.tourPage>0)[self showTourPage:self.tourPage-1 animated:YES];}
// Reopens the welcome and tour from the About tab: the window is rebuilt with the card in place.
// Where the icon is: the welcome opens under it, and the icon fades in and out a few times.
- (void)placeSettingsUnderIcon {
 NSWindow *bar=self.item.button.window;if(!bar||!self.settings)return;NSRect icon=bar.frame;NSScreen *screen=bar.screen?:NSScreen.mainScreen;NSRect f=self.settings.frame;
 f.origin.x=MIN(NSMaxX(screen.visibleFrame)-f.size.width-8,MAX(screen.visibleFrame.origin.x+8,NSMidX(icon)-f.size.width+60));f.origin.y=icon.origin.y-f.size.height-10;[self.settings setFrame:f display:YES];
 NSView *button=self.item.button;if(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion)return;
 for(int k=0;k<4;k++){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((0.6+k*1.2)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.5;button.animator.alphaValue=.25;} completionHandler:^{[NSAnimationContext runAnimationGroup:^(NSAnimationContext *c){c.duration=.6;button.animator.alphaValue=1;} completionHandler:nil];}];});}
}
- (void)showTour:(id)sender {[self.settings close];self.settings=nil;self.welcomeWanted=YES;[self showSettings:nil];}
- (void)dismissWelcome:(id)sender {
 NSView *card=self.welcomeCard;if(!card)return;self.tourCard=nil;NSStackView *column=(NSStackView *)card.superview;
 [column removeArrangedSubview:card];[card removeFromSuperview];self.welcomeCard=nil;self.welcomeWanted=NO;
 // The tab's root view echoes its frame as fitting size; measure the column, then
 // reselect the tab so the tab controller applies the smaller size to the window.
 [column layoutSubtreeIfNeeded];self.settingsTabs.tabViewItems.firstObject.viewController.preferredContentSize=NSMakeSize(500,column.fittingSize.height);
 self.settingsTabs.selectedTabViewItemIndex=1;self.settingsTabs.selectedTabViewItemIndex=0;
}
// A prefilled GitHub issue: build, macOS and the diagnostics text, which names no apps or websites.
- (void)reportProblem:(id)sender {
 NSOperatingSystemVersion v=NSProcessInfo.processInfo.operatingSystemVersion;NSString *build=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]?:@"?";
 NSString *body=[NSString stringWithFormat:@"**What happened**\n\n(what you saw, and what you expected)\n\n**Steps**\n\n1. \n\n**Setup**\n\nLess Pull 1.4.4 build %@, macOS %ld.%ld.%ld, %lu display(s)\n\n<details><summary>Diagnostics</summary>\n\n```\n%@\n%@\n```\n</details>\n",build,(long)v.majorVersion,(long)v.minorVersion,(long)v.patchVersion,(unsigned long)[self.warmth displays].count,self.engine.diagnostics?:@"",self.warmth.diagnostics?:@""];
 NSCharacterSet *allowed=NSCharacterSet.URLQueryAllowedCharacterSet;NSString *title=[[NSString stringWithFormat:@"Build %@: ",build] stringByAddingPercentEncodingWithAllowedCharacters:allowed];NSString *encoded=[[body stringByAddingPercentEncodingWithAllowedCharacters:allowed] stringByReplacingOccurrencesOfString:@"&" withString:@"%%26"];
 NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/Archangeloi89/less-pull/issues/new?title=%@&body=%@",title,encoded]];if(url)[NSWorkspace.sharedWorkspace openURL:url];
}
- (void)showLicenses:(id)sender {NSURL *folder=NSBundle.mainBundle.resourceURL;[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[[folder URLByAppendingPathComponent:@"LICENSE-APP.txt"],[folder URLByAppendingPathComponent:@"LICENSE-SOURCE.txt"]]];}
- (void)showSettings:(id)sender {
 if(!self.settings){
  self.thanksWanted=!self.welcomeWanted&&[self thanksDue];
  self.multiDisplayViews=[NSMutableArray new];self.advancedViews=[NSMutableArray new];if(!self.expandedRules)self.expandedRules=[NSMutableSet new];
  self.settingsTabs=[NSTabViewController new];self.settingsTabs.tabStyle=NSTabViewControllerTabStyleToolbar;self.settingsTabs.transitionOptions=NSViewControllerTransitionNone;
  [self.settingsTabs addTabViewItem:[self tab:@"General" symbol:@"circle.lefthalf.filled" content:[self generalTab]]];
  [self.settingsTabs addTabViewItem:[self tab:@"Shortcuts" symbol:@"keyboard" content:[self shortcutsTab]]];
  [self.settingsTabs addTabViewItem:[self tab:@"Sessions" symbol:@"timer" content:[self sessionsTab]]];
  [self.settingsTabs addTabViewItem:[self tab:@"Apps" symbol:@"macwindow" content:[self appsTab]]];
  [self.settingsTabs addTabViewItem:[self tab:@"Websites" symbol:@"globe" content:[self websitesTab]]];
  [self.settingsTabs addTabViewItem:[self tab:@"About" symbol:@"info.circle" content:[self aboutTab]]];
  self.settings=[NSWindow windowWithContentViewController:self.settingsTabs];self.settings.styleMask=NSWindowStyleMaskTitled|NSWindowStyleMaskClosable;self.settings.title=@"Less Pull";self.settings.releasedWhenClosed=NO;if(@available(macOS 11,*))self.settings.toolbarStyle=NSWindowToolbarStylePreference;
  self.settings.initialFirstResponder=self.grayscaleButton;[self.settings center];
 }
 self.loginButton.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;[self rebuildExclusionsList];[self sync];[NSApp activateIgnoringOtherApps:YES];[self.settings makeKeyAndOrderFront:nil];if(self.welcomeWanted&&self.welcomeCard){BOOL first=!self.welcomePlaced;self.welcomePlaced=YES;if(first){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.45*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[self placeSettingsUnderIcon];});}}
}
// Before anything is installed: what the extension can see, in plain words.
- (BOOL)confirmExtensionData {
 NSAlert *a=[NSAlert new];a.messageText=@"What the browser extension can see";
 a.informativeText=@"The extension reads the address and title of your tabs, so Less Pull knows which website is in front. Your browser will call this “browsing history”.\n\nIt cannot read or change what is on a page, see what you type, or reach your passwords, cookies or forms. It has no buttons and no network connection of its own; it talks only to the Less Pull app on this Mac. Private tabs are never reported.\n\nWhat is kept: only the website exceptions you save, on this Mac. The address of the site in front is held in memory, never written to disk, overwritten by the next one, and dropped when the browser disconnects or stops reporting.";
 [a addButtonWithTitle:@"Continue"];[a addButtonWithTitle:@"Cancel"];[a addButtonWithTitle:@"Read the Privacy Page"];[NSApp activateIgnoringOtherApps:YES];NSModalResponse r=[a runModal];
 if(r==NSAlertThirdButtonReturn){[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/Archangeloi89/less-pull/blob/main/docs/PRIVACY.md"]];return NO;}
 return r==NSAlertFirstButtonReturn;
}
- (void)installBrowserExtension:(id)sender {
 if(![self confirmExtensionData])return;
 NSAlert *choose=[NSAlert new];choose.messageText=@"Install Browser Extension";choose.informativeText=@"Choose your browser. Less Pull will connect to it and open its extensions page. Until the extension is in the stores, it is loaded from the folder inside the app. Less Pull must stay open for website exceptions to work.";[choose addButtonWithTitle:@"Safari"];[choose addButtonWithTitle:@"Brave"];[choose addButtonWithTitle:@"Chrome"];[choose addButtonWithTitle:@"Firefox"];[choose addButtonWithTitle:@"Opera"];[choose addButtonWithTitle:@"Edge"];[choose addButtonWithTitle:@"Cancel"];[NSApp activateIgnoringOtherApps:YES];NSModalResponse choice=[choose runModal];
 if(choice==NSAlertFirstButtonReturn){[self installSafariExtension];return;}choice-=1;
 NSArray *browsers=@[@[@"Brave",@"com.brave.Browser",@"brave://extensions"],@[@"Chrome",@"com.google.Chrome",@"chrome://extensions"],@[@"Firefox",@"org.mozilla.firefox",@"about:debugging#/runtime/this-firefox"],@[@"Opera",@"com.operasoftware.Opera",@"opera://extensions"],@[@"Edge",@"com.microsoft.edgemac",@"edge://extensions"]];NSInteger index=choice-NSAlertFirstButtonReturn;if(index<0||index>4)return;
 NSString *browser=browsers[index][0],*identifier=browsers[index][1];BOOL firefox=index==2;NSURL *browserURL=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier];if(!browserURL){NSAlert *missing=[NSAlert new];missing.messageText=[browser stringByAppendingString:@" is not installed"];missing.informativeText=@"Install the browser, then return to Browser Extension setup.";[missing runModal];return;}
 NSTask *setup=[NSTask new];setup.executableURL=[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Contents/MacOS/LessPullBrowserHost"];setup.arguments=@[@"--install"];setup.standardOutput=[NSPipe pipe];setup.standardError=[NSPipe pipe];NSError *error=nil;BOOL started=[setup launchAndReturnError:&error];if(started)[setup waitUntilExit];if(!started||setup.terminationStatus!=0){NSAlert *failed=[NSAlert new];failed.messageText=@"Browser setup could not finish";failed.informativeText=error.localizedDescription?:@"Try again from a permanent local copy of Less Pull. The local bridge could not be registered.";[failed runModal];return;}
 NSURL *folder=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:firefox?@"Browser Extension (Firefox)":@"Browser Extension"];[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[folder]];
 [NSWorkspace.sharedWorkspace openURLs:@[[NSURL URLWithString:browsers[index][2]]] withApplicationAtURL:browserURL configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:nil];
 NSAlert *guide=[NSAlert new];guide.messageText=[NSString stringWithFormat:@"Finish installation in %@",browser];
 guide.informativeText=firefox?@"1. On the page that opened, click Load Temporary Add-on….\n2. Select manifest.json in the Browser Extension (Firefox) folder shown in Finder.\n\nFirefox removes temporary add-ons when it quits; load it again next time, or use Firefox Developer Edition with signing turned off. The extension has no buttons: with a website in front, use “Exception for …” in the Less Pull menu. Keep Less Pull where it is installed; run this setup again if you move it.":@"1. Turn on Developer mode on the Extensions page.\n2. Click Load unpacked.\n3. Select the Browser Extension folder shown in Finder.\n\nThe extension has no buttons: with a website in front, use “Exception for …” in the Less Pull menu. Keep Less Pull where it is installed; run this setup again if you move it.";
 [guide addButtonWithTitle:@"Done"];[guide addButtonWithTitle:@"Copy extension folder path"];[NSApp activateIgnoringOtherApps:YES];if([guide runModal]==NSAlertSecondButtonReturn){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:folder.path forType:NSPasteboardTypeString];}
}
// Safari: the extension lives in a small companion app inside Less Pull. Opening it
// once registers the extension; Safari then lists it under Settings → Extensions.
- (void)installSafariExtension {
 NSURL *companion=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Less Pull for Safari.app"];
 if(![NSFileManager.defaultManager fileExistsAtPath:companion.path]){NSAlert *missing=[NSAlert new];missing.messageText=@"The Safari extension is not in this build";missing.informativeText=@"This copy of Less Pull was built without Xcode, so the Safari companion app is missing. A build with Xcode includes it.";[missing runModal];return;}
 [NSWorkspace.sharedWorkspace openURL:companion];
 NSAlert *guide=[NSAlert new];guide.messageText=@"Finish installation in Safari";guide.informativeText=@"1. The Less Pull for Safari app opens; click its Open Safari Settings button.\n2. Until this build is signed by Apple, Safari needs Allow Unsigned Extensions from the Develop menu (turn on the Develop menu under Settings → Advanced). That choice lasts until Safari quits.\n3. Turn on Less Pull in Settings → Extensions and allow it on all websites.\n\nThe extension has no buttons: with a website in front, use “Exception for …” in the Less Pull menu. Keep Less Pull where it is installed.";[guide addButtonWithTitle:@"Done"];[NSApp activateIgnoringOtherApps:YES];[guide runModal];
}
- (void)openWebsite:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:LessPullWebsite]];}
- (void)openSupport:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:LessPullCoffee]];}
- (void)openLink:(NSButton *)sender {if(sender.identifier.length)[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:sender.identifier]];}
// Link buttons for the About tab and the thanks window; empty addresses are skipped.
- (NSArray<NSButton *> *)authorLinkButtons {
 NSMutableArray *buttons=[NSMutableArray new];
 for(NSArray *link in @[@[@"jiriarion.com",LessPullWebsite,@"Open jiriarion.com in your default browser.",@"Visit Jiri Arion Rose’s website"],@[@"Buy me a coffee",LessPullCoffee,@"Open buymeacoffee.com/HsERf62fiZ in your default browser.",@"Support Jiri Arion Rose — Buy me a coffee"],@[@"Substack",LessPullSubstack,@"Open Jiri Arion Rose’s Substack in your default browser.",@"Jiri Arion Rose on Substack"],@[@"YouTube",LessPullYouTube,@"Open Jiri Arion Rose’s YouTube channel in your default browser.",@"Jiri Arion Rose on YouTube"],@[@"X",LessPullX,@"Open Jiri Arion Rose on X in your default browser.",@"Jiri Arion Rose on X"]]){
  if(![link[1] length])continue;NSButton *b=[NSButton buttonWithTitle:link[0] target:self action:@selector(openLink:)];b.identifier=link[1];b.bezelStyle=NSBezelStyleInline;b.contentTintColor=NSColor.linkColor;[self helpView:b text:link[2] label:link[3]];[buttons addObject:b];}
 return buttons;
}
- (NSArray<NSArray<NSString *> *> *)helpSections {
 return @[
  @[@"What Less Pull does",@"Less Pull takes the color out of your screen so it pulls at your attention less. You can add warmth, from amber to red, and keep color where you need it."],
  @[@"Grayscale",@"Shows everything in shades of gray, day and night. Turn it off to see color again."],
  @[@"Extra Warmth",@"Adds warmth on top of Night Shift. Off adds none; 100% is red. The slider is in the menu and in Settings."],
  @[@"Night Shift",@"Less Pull can turn Night Shift on or off now, or off for a while; your schedule in System Settings stays as it is. With “Extra Warmth follows Night Shift” on, the warmth you set is added only while Night Shift is on, and there is none in the daytime. With it off, Extra Warmth stays on all day. If you move the slider by hand while following, that warmth stays until Night Shift next changes, or until you choose Resume Following."],
  @[@"Exceptions for apps",@"Give an app its own settings in Settings → Apps, or choose “Exception for …” in the menu. They apply while that app is in front with a window open. Each setting can keep the default or get its own value. “Use this exception” switches a rule off and keeps its settings; changing a setting away from default switches it on again."],
  @[@"Exceptions for websites",@"Install the browser extension from Settings, for Safari, Brave, Chrome, Firefox, Opera or Edge. It only connects the browser; it has no buttons. With a website in front, the menu offers “Exception for that site”, for the whole domain or one exact page. Pages inherit from their domain, and domains from the browser’s app exception. Several browsers can use it at the same time; private tabs are left alone."],
  @[@"Peek in color",@"Record a shortcut in Settings → Shortcuts, or let Suggest pick one that is free. Hold it to see the plain display; let go and Less Pull fades back. Press it twice quickly to keep the plain display; one more press returns. Choose there what peeking turns off: Grayscale, Extra Warmth, and Night Shift if you like. Nothing is saved and no exception is made."],
  @[@"Grayscale off for a while",@"In the menu or in Settings, turn Grayscale off for 1 hour, 4 hours, or until Night Shift next changes. It comes back by itself; your setting stays saved."],
  @[@"The menu-bar icon and shortcuts",@"By default a click opens the menu and a right-click (or Control-click) toggles Grayscale; Settings → Shortcuts can swap the two. A Toggle Grayscale shortcut can be recorded there as well."],
  @[@"Pausing",@"Pause Less Pull shows the plain display for 15 minutes, an hour, or until you resume: color and no added warmth, with Night Shift left alone. Your settings and exceptions are kept, and the menu-bar icon shows a pause mark."],
  @[@"Quitting",@"Quitting returns the display to normal and lets Night Shift follow its schedule again. Your settings and exceptions are kept."],
  @[@"Updates",@"Once a day Less Pull asks GitHub whether a newer build exists, and only offers builds made for your macOS version; the menu-bar icon then shows a small dot and the menu offers “Update available”. Nothing about you is sent. Turn it off in Settings → About."],
  @[@"Something not working?",@"Diagnostics shows technical details you can include when asking for help. Nothing is sent anywhere."]];
}
- (void)showHelp:(id)sender {
 if(!self.helpWindow){
  self.helpWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,440,520) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];self.helpWindow.title=@"Less Pull Help";self.helpWindow.releasedWhenClosed=NO;self.helpWindow.minSize=NSMakeSize(360,320);
  NSMutableAttributedString *text=[NSMutableAttributedString new];NSMutableParagraphStyle *body=[NSMutableParagraphStyle new];body.paragraphSpacing=14;body.lineHeightMultiple=1.15;NSMutableParagraphStyle *head=[NSMutableParagraphStyle new];head.paragraphSpacing=4;
  for(NSArray *section in [self helpSections]){[text appendAttributedString:[[NSAttributedString alloc]initWithString:[section[0] stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NSColor.labelColor,NSParagraphStyleAttributeName:head}]];[text appendAttributedString:[[NSAttributedString alloc]initWithString:[section[1] stringByAppendingString:@"\n"] attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13],NSForegroundColorAttributeName:NSColor.labelColor,NSParagraphStyleAttributeName:body}]];}
  NSScrollView *scroll=[NSTextView scrollableTextView];NSTextView *view=scroll.documentView;view.editable=NO;view.selectable=YES;view.textContainerInset=NSMakeSize(16,16);view.drawsBackground=NO;[view.textStorage setAttributedString:text];view.accessibilityLabel=@"Less Pull Help";scroll.drawsBackground=NO;scroll.translatesAutoresizingMaskIntoConstraints=NO;
  NSButton *diagnostics=[NSButton buttonWithTitle:@"Diagnostics…" target:self action:@selector(diagnostics:)];diagnostics.translatesAutoresizingMaskIntoConstraints=NO;[self helpView:diagnostics text:@"Technical details for troubleshooting." label:@"Diagnostics"];
  NSView *content=self.helpWindow.contentView;[content addSubview:scroll];[content addSubview:diagnostics];
  [NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:content.topAnchor],[scroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[scroll.bottomAnchor constraintEqualToAnchor:diagnostics.topAnchor constant:-12],[diagnostics.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],[diagnostics.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16]]];
  [self.helpWindow center];
 }
 [NSApp activateIgnoringOtherApps:YES];[self.helpWindow makeKeyAndOrderFront:nil];
}
- (void)login:(NSButton *)sender {
 NSError *error=nil;
 if(sender.state==NSControlStateValueOn)[SMAppService.mainAppService registerAndReturnError:&error];else [SMAppService.mainAppService unregisterAndReturnError:&error];
 if(error){NSAlert *a=[NSAlert new];a.messageText=@"Login setting needs attention";a.informativeText=error.localizedDescription;[a runModal];}
 sender.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;if(sender.state==NSControlStateValueOn)self.loginNote.hidden=YES;
}
- (void)resetWarmth:(id)sender {NSSlider *slider=[NSSlider new];slider.doubleValue=0;[self warmthChanged:slider];}
- (void)diagnostics:(id)sender {NSAlert *a=[NSAlert new];a.messageText=@"Diagnostics";NSString *betterDisplay=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"pro.betterdisplay.BetterDisplay"].count?@"\nBetterDisplay is running; it can change how displays look. HDR state is not read.":@"";a.informativeText=[NSString stringWithFormat:@"Less Pull %@ (%@)\n\n%@\n%@\nDisplays: %lu, each with its own matrix\nDisplay events: %lu; recoveries: %lu\nGrayscale setting: %@; grayscale showing now: %@; exception active: %@%@\n\nNight Shift drives “Extra Warmth follows Night Shift”; it does not prove the display looks warmer.",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"],self.engine.diagnostics,self.warmth.diagnostics,(unsigned long)[self.warmth displays].count,(unsigned long)self.pipelineEvents,(unsigned long)self.pipelineRestorations,(self.selectedMode==100||self.selectedMode==1)?@"On":@"Off",(self.effectiveMode==100||self.effectiveMode==1)?@"On":@"Off",(self.grayOverride||self.customWarmth)?@"yes":@"no",betterDisplay];[NSApp activateIgnoringOtherApps:YES];[a runModal];}
- (NSString *)warmthKey {return @"warmth";}
- (double)currentWarmth {return [NSUserDefaults.standardUserDefaults doubleForKey:[self warmthKey]];}
- (BOOL)applyMode:(NSInteger)mode {
 // A timed Grayscale off shows color at the global level; exceptions still apply on top.
 NSInteger effective=self.grayOverride==1?100:self.grayOverride==2?101:(self.grayOffUntil?101:mode);
 BOOL nightOn=NO;BOOL known=[self logicalNightShift:&nightOn];
 BOOL warmthOff=self.automatic&&self.policy.overrideMode<0&&known&&!nightOn;
 double strength=self.customWarmth?self.appWarmth/100*3:((mode==100||mode==101)&&!warmthOff?[self currentWarmth]:0);
 if(self.pausedUntil){effective=101;strength=0;}
 else if(self.peeking){NSDictionary *e=[self peekEffects];if([e[@"grayscale"] boolValue])effective=101;if([e[@"warmth"] boolValue])strength=0;}
 if(mode!=self.selectedMode||effective!=self.effectiveMode||strength!=self.targetStrength)self.animateAppearance=YES;
 self.targetStrength=strength;
 BOOL gray=effective==100||effective==1;
 NSArray *displays=[self.warmth displays];
 if(displays.count>1||[displays.firstObject unsignedIntValue]){ // one matrix per display, each fading on its own clock
  BOOL peekActiveOnly=[NSUserDefaults.standardUserDefaults boolForKey:@"peekActiveDisplayOnly"],reduce=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion,ok=YES;
  if(self.animateAppearance&&!self.quitting&&self.engine.class==FilterEngine.class)NSLog(@"Less Pull appearance: global=%ld effective=%ld warmth=%.3f exception=%d following=%d displays=%lu",(long)mode,(long)effective,strength,(self.grayOverride||self.customWarmth),self.automatic,(unsigned long)displays.count);
  self.animateAppearance=NO;self.selectedMode=mode;self.effectiveMode=effective;
  for(NSNumber *dn in displays){uint32_t d=dn.unsignedIntValue;NSDictionary *o=self.displayOverrides[dn];
   NSInteger g=o?[o[@"grayMode"] integerValue]:self.grayOverride;BOOL custom=o?[o[@"customWarmth"] boolValue]:self.customWarmth;double w=o?[o[@"warmth"] doubleValue]:self.appWarmth;
   NSInteger eff=g==1?100:g==2?101:(self.grayOffUntil?101:mode);double str=custom?w/100*3:((mode==100||mode==101)&&!warmthOff?[self currentWarmth]:0);
   if([o[@"plain"] boolValue]){eff=101;str=0;}
   BOOL peekHere=(self.peeking&&(self.frontPeekDisplays?[self.frontPeekDisplays containsObject:dn]:(self.frontPeekSpansAll||!peekActiveOnly||d==self.peekDisplay)))||[self.peekLockedDisplays containsObject:dn];
   if(self.pausedUntil){eff=101;str=0;}else if(peekHere){NSDictionary *e=[self peekEffects];if([e[@"grayscale"] boolValue])eff=101;if([e[@"warmth"] boolValue])str=0;}
   BOOL grayHere=eff==100||eff==1;NSArray *last=[self.warmth stateForDisplay:d];
   if(last&&([last[0] doubleValue]!=str||[last[1] boolValue]!=grayHere)&&!self.quitting){__weak AppDelegate *weak=self;[self.warmth transitionStrength:str grayscale:grayHere display:d reduceMotion:reduce duration:0.5 completion:^{[weak.warmth applyStrength:str grayscale:grayHere display:d];}];}
   else if(!last||![self.warmth transitioning]){if(![self.warmth applyStrength:str grayscale:grayHere display:d])ok=NO;}
  }
  return ok;
 }
 if(self.animateAppearance&&!self.quitting){if(self.engine.class==FilterEngine.class)NSLog(@"Less Pull appearance: global=%ld effective=%ld warmth=%.3f exception=%d following=%d",(long)mode,(long)effective,strength,(self.grayOverride||self.customWarmth),self.automatic);self.animateAppearance=NO;NSUInteger generation=++self.appearanceGeneration;self.selectedMode=mode;self.effectiveMode=effective;
  [self.warmth transitionStrength:strength grayscale:gray reduceMotion:NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion duration:0.5 completion:^{if(generation!=self.appearanceGeneration)return;[self.warmth applyStrength:strength grayscale:gray];}];return YES;
 }
 if(self.warmth.transitioning)return YES;
 BOOL ok=[self.warmth applyStrength:strength grayscale:gray];
 if(ok){self.selectedMode=mode;self.effectiveMode=effective;}return ok;
}
- (void)toggleGrayscale:(id)sender {NSMenuItem *item=[NSMenuItem new];item.tag=(self.selectedMode==1||self.selectedMode==100)?101:100;[self manual:item];}
- (void)refreshProfiles {self.grayscaleButton.state=self.selectedMode==1||self.selectedMode==100;
 self.grayscaleButton.title=self.grayOverride?@"Default Grayscale":@"Grayscale";}
- (void)warmthChanged:(NSSlider *)sender {
 [NSUserDefaults.standardUserDefaults setDouble:sender.doubleValue/100*3 forKey:@"warmth"];self.warmthSlider.doubleValue=sender.doubleValue;
 [self.policy selectManual:self.selectedMode];[self savePolicy];
 NSMenuItem *item=[NSMenuItem new];item.tag=(self.selectedMode==1||self.selectedMode==100)?100:101;[self manual:item];
}
- (void)displaysChanged:(id)sender {[self pipelineChanged:sender];[self refreshDisplayRows];[self applyVisibility];}
- (void)applicationWillTerminate:(NSNotification *)note {self.quitting=YES;if(self.peekHotKey)UnregisterEventHotKey(self.peekHotKey);if(self.grayscaleHotKey)UnregisterEventHotKey(self.grayscaleHotKey);[self.grayOffTimer invalidate];[self.pauseAllTimer invalidate];[self.eventTimer invalidate];[self.pipelineRecoveryTimer invalidate];[self.menuDismissal end];[self.browserBridge stop];[self.warmth cancelTransition];[self endPauseNow:nil];self.excludeNight=NO;[self reconcileExclusion];if(self.grayOverride||self.customWarmth){self.grayOverride=0;self.customWarmth=NO;self.excludeGray=NO;self.excludeWarmth=NO;self.animateAppearance=NO;[self.warmth cancelTransition];[self applyMode:self.selectedMode];}[self.warmth restore];}
- (void)quit:(id)sender {[NSApp terminate:nil];}
@end
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc>1&&strcmp(argv[1],"--diagnostics")==0){FilterEngine *e=[FilterEngine new];puts(e.diagnostics.UTF8String);return e.error?1:0;}
 NSApplication *app=NSApplication.sharedApplication;AppDelegate *delegate=[AppDelegate new];app.delegate=delegate;
 // --regular keeps a Dock icon so UI automation can reach a test build; production is a menu-bar-only app.
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--regular"])[app setActivationPolicy:NSApplicationActivationPolicyAccessory];[app run];
}return 0;}
