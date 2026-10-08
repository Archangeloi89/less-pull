#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Engine.h"
#import "SwitchingPolicy.h"
#import "WarmthEngine.h"
#import "PausePolicy.h"
#import "ExclusionPolicy.h"
#import "BrowserBridge.h"
#import "MenuDismissal.h"
@interface ExceptionStack : NSStackView
@end
@implementation ExceptionStack
- (BOOL)isFlipped {return YES;}
@end
@interface AppDelegate : NSObject <NSApplicationDelegate,NSMenuDelegate>
@property NSStatusItem *item;
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
@property NSUInteger appearanceGeneration;
@property NSInteger grayOverride,nightOverride;
@property BOOL customWarmth,forcedNightOn;
@property double appWarmth,targetStrength;
@property NSInteger effectiveMode;
@property NSString *foregroundID,*foregroundName,*exclusionError;
@property NSWindow *exclusionsWindow;
@property NSStackView *exclusionsList;
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
@property NSWindow *helpWindow,*welcomeWindow;
@property NSButton *welcomeSwitch;
@property NSButton *welcomeLogin;
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
 self.website=nil;NSString *site=nil;NSDictionary *rule=[self.browserBridge ruleForBrowser:self.foregroundID base:self.exclusionRules[self.foregroundID] site:&site]?:self.exclusionRules[self.foregroundID];self.website=site;if(site)self.foregroundName=site;BOOL hasRule=[rule[@"grayMode"] integerValue]!=0||[rule[@"nightMode"] integerValue]!=0||[rule[@"customWarmth"] boolValue];BOOL visible=hasRule&&[self hasVisibleWindow:app.processIdentifier];
 NSInteger gray=visible?[rule[@"grayMode"] integerValue]:0,night=visible?[rule[@"nightMode"] integerValue]:0;BOOL custom=visible&&[rule[@"customWarmth"] boolValue];double warmth=custom?[rule[@"warmth"] doubleValue]:0;
 if(gray!=self.grayOverride||custom!=self.customWarmth||warmth!=self.appWarmth)self.animateAppearance=YES;
 self.grayOverride=gray;self.nightOverride=night;self.customWarmth=custom;self.appWarmth=warmth;self.excludeGray=gray==2;self.excludeNight=night!=0;self.excludeWarmth=custom&&warmth==0;
 if(hasRule&&!self.visibilityTimer){self.visibilityTimer=[NSTimer timerWithTimeInterval:.5 target:self selector:@selector(visibilityCheck:) userInfo:nil repeats:YES];[NSRunLoop.mainRunLoop addTimer:self.visibilityTimer forMode:NSRunLoopCommonModes];}
 if(!hasRule){[self.visibilityTimer invalidate];self.visibilityTimer=nil;}
}
- (void)visibilityCheck:(id)sender {NSInteger gray=self.grayOverride,night=self.nightOverride;BOOL custom=self.customWarmth;double warmth=self.appWarmth;[self updateForeground];if(gray!=self.grayOverride||night!=self.nightOverride||custom!=self.customWarmth||warmth!=self.appWarmth)[self sync];}
- (void)frontmostChanged:(id)sender {[self sync];}
- (NSString *)exclusionSummary {
 NSMutableArray *effects=[NSMutableArray new];if(self.grayOverride)[effects addObject:self.grayOverride==1?@"Grayscale on":@"Grayscale off"];if(self.nightOverride)[effects addObject:self.pause?@"Night Shift off for now":self.nightOverride==1?@"Night Shift on":@"Night Shift off"];if(self.customWarmth)[effects addObject:[NSString stringWithFormat:@"Warmth %.0f%%",self.appWarmth]];
 return effects.count?[NSString stringWithFormat:@"%@: %@",self.foregroundName,[effects componentsJoinedByString:@", "]]:@"Using your default settings";
}
- (NSString *)exclusionHelp {return @"An exception applies while that app is in front with a window open, on all your displays. Each setting can keep the default or get its own value. Your defaults stay saved. If Night Shift is turned off for a while, that wins over an app’s Night Shift On.";}
- (void)saveExclusionRules {[NSUserDefaults.standardUserDefaults setObject:self.exclusionRules forKey:@"appExclusions"];[self sync];}
- (void)ruleChanged:(NSControl *)sender {
 NSString *bundle=sender.identifier;NSMutableDictionary *rule=[self.exclusionRules[bundle] mutableCopy];
 if([sender isKindOfClass:NSPopUpButton.class])rule[sender.tag==0?@"grayMode":@"nightMode"]=@([(NSPopUpButton *)sender indexOfSelectedItem]);
 else if(sender.tag==2)rule[@"customWarmth"]=@([(NSButton *)sender state]==NSControlStateValueOff);
 else rule[@"warmth"]=@([(NSSlider *)sender doubleValue]);
 self.exclusionRules[bundle]=rule;[self saveExclusionRules];if(sender.tag!=3)[self rebuildExclusionsList];else {NSTextField *readout=[sender.superview viewWithTag:99];readout.stringValue=[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]];}
}
- (void)removeRule:(NSButton *)sender {[self.exclusionRules removeObjectForKey:sender.identifier];[self saveExclusionRules];[self rebuildExclusionsList];}
- (void)addAppURL:(NSURL *)url {
 NSBundle *bundle=[NSBundle bundleWithURL:url];NSString *identifier=bundle.bundleIdentifier;if(!identifier||[identifier isEqual:NSBundle.mainBundle.bundleIdentifier])return;
 NSString *name=[NSFileManager.defaultManager displayNameAtPath:url.path];if([name hasSuffix:@".app"])name=[name substringToIndex:name.length-4];
 if(!self.exclusionRules[identifier])self.exclusionRules[identifier]=@{@"name":name,@"grayMode":@0,@"nightMode":@0,@"customWarmth":@NO,@"warmth":@0};[self saveExclusionRules];[self rebuildExclusionsList];
}
- (void)addExclusionApp:(id)sender {
 NSOpenPanel *panel=[NSOpenPanel openPanel];panel.title=@"Add an app exception";panel.directoryURL=[NSURL fileURLWithPath:@"/Applications"];panel.canChooseDirectories=NO;panel.canChooseFiles=YES;panel.allowedContentTypes=@[UTTypeApplicationBundle];panel.treatsFilePackagesAsDirectories=NO;
 [panel beginSheetModalForWindow:self.exclusionsWindow completionHandler:^(NSModalResponse result){if(result==NSModalResponseOK)[self addAppURL:panel.URL];}];
}
- (void)excludeCurrent:(id)sender {NSURL *url=self.lastExternalApp.bundleURL;[self showExclusions:nil];if(url)[self addAppURL:url];}
- (void)rebuildExclusionsList {
 if(!self.exclusionsList)return;for(NSView *v in self.exclusionsList.arrangedSubviews.copy){[self.exclusionsList removeArrangedSubview:v];[v removeFromSuperview];}
 NSArray *keys=[self.exclusionRules.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [self.exclusionRules[a][@"name"] localizedCaseInsensitiveCompare:self.exclusionRules[b][@"name"]];}];
 if(!keys.count){NSTextField *empty=[NSTextField labelWithString:@"No exceptions yet. Add an app, then choose its display settings."];[self.exclusionsList addArrangedSubview:empty];}
 for(NSString *bundle in keys){NSDictionary *rule=self.exclusionRules[bundle];NSView *row=[[NSView alloc]initWithFrame:NSMakeRect(0,0,620,142)];[row.heightAnchor constraintEqualToConstant:142].active=YES;[row.widthAnchor constraintEqualToConstant:620].active=YES;
 NSTextField *name=[NSTextField labelWithString:rule[@"name"]?:bundle];name.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];name.frame=NSMakeRect(8,112,480,20);name.toolTip=bundle;[row addSubview:name];
 NSArray *titles=@[@"Grayscale",@"Night Shift"];
 for(int i=0;i<2;i++){NSTextField *label=[NSTextField labelWithString:titles[i]];label.frame=NSMakeRect(8+i*300,77,80,20);[row addSubview:label];NSPopUpButton *choice=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(90+i*300,72,210,28) pullsDown:NO];[choice addItemsWithTitles:@[@"Use default",@"On",@"Off"]];[choice selectItemAtIndex:[rule[i==0?@"grayMode":@"nightMode"] integerValue]];choice.target=self;choice.action=@selector(ruleChanged:);choice.identifier=bundle;choice.tag=i;[self helpView:choice text:[self exclusionHelp] label:[NSString stringWithFormat:@"%@ — %@",rule[@"name"],titles[i]]];[row addSubview:choice];}
 NSButton *inherit=[NSButton checkboxWithTitle:@"Use default warmth" target:self action:@selector(ruleChanged:)];inherit.frame=NSMakeRect(8,35,160,26);inherit.identifier=bundle;inherit.tag=2;inherit.state=![rule[@"customWarmth"] boolValue];[self helpView:inherit text:@"Uncheck to give this app its own Extra Warmth. Off adds no warmth; 100% is red. Your default warmth stays saved." label:[NSString stringWithFormat:@"%@ — Use default warmth",rule[@"name"]]];[row addSubview:inherit];
 NSSlider *slider=[NSSlider sliderWithValue:[rule[@"warmth"] doubleValue] minValue:0 maxValue:100 target:self action:@selector(ruleChanged:)];slider.frame=NSMakeRect(185,34,325,28);slider.identifier=bundle;slider.tag=3;slider.continuous=YES;slider.enabled=[rule[@"customWarmth"] boolValue];slider.numberOfTickMarks=5;[self helpView:slider text:@"Extra Warmth for this app, from Off to Red." label:[NSString stringWithFormat:@"%@ — Extra Warmth percent",rule[@"name"]]];[row addSubview:slider];
 NSTextField *percent=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];percent.tag=99;percent.frame=NSMakeRect(536,37,76,24);[row addSubview:percent];NSTextField *off=[NSTextField labelWithString:@"Off"];off.font=[NSFont systemFontOfSize:10];off.frame=NSMakeRect(185,15,40,16);[row addSubview:off];NSTextField *red=[NSTextField labelWithString:@"Red"];red.font=[NSFont systemFontOfSize:10];red.alignment=NSTextAlignmentRight;red.frame=NSMakeRect(470,15,40,16);[row addSubview:red];
 NSButton *remove=[NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeRule:)];remove.identifier=bundle;remove.frame=NSMakeRect(536,109,76,26);[self helpView:remove text:@"Remove this exception. The app then uses your default settings." label:[NSString stringWithFormat:@"Remove %@ exception",rule[@"name"]]];[row addSubview:remove];[self.exclusionsList addArrangedSubview:row];}
}
- (void)showExclusions:(id)sender {
 if(!self.exclusionsWindow){self.exclusionsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,680,510) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];self.exclusionsWindow.title=@"App Exceptions";self.exclusionsWindow.releasedWhenClosed=NO;self.exclusionsWindow.minSize=NSMakeSize(680,480);
 NSTextField *intro=[NSTextField wrappingLabelWithString:@"Give an app its own display settings. They apply while that app is in front with a window open; your default settings stay saved."];intro.frame=NSMakeRect(24,446,632,44);intro.autoresizingMask=NSViewMinYMargin|NSViewWidthSizable;[self.exclusionsWindow.contentView addSubview:intro];
 NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(24,142,632,294)];scroll.hasVerticalScroller=YES;scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.exclusionsList=[ExceptionStack new];self.exclusionsList.orientation=NSUserInterfaceLayoutOrientationVertical;self.exclusionsList.alignment=NSLayoutAttributeLeading;self.exclusionsList.spacing=8;self.exclusionsList.edgeInsets=NSEdgeInsetsMake(8,0,8,0);scroll.documentView=self.exclusionsList;self.exclusionsList.translatesAutoresizingMaskIntoConstraints=NO;[self.exclusionsList.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active=YES;[self.exclusionsWindow.contentView addSubview:scroll];
 NSButton *add=[NSButton buttonWithTitle:@"Add app…" target:self action:@selector(addExclusionApp:)];add.frame=NSMakeRect(24,36,110,28);[self.exclusionsWindow.contentView addSubview:add];
 NSTextField *note=[NSTextField wrappingLabelWithString:@"If Night Shift is turned off for a while, that wins over an app’s Night Shift On. Grayscale Off, warmth Off and Night Shift Off together show the plain display; True Tone and other display tools are separate."];note.font=[NSFont systemFontOfSize:10];note.textColor=NSColor.secondaryLabelColor;note.frame=NSMakeRect(150,22,506,48);note.autoresizingMask=NSViewWidthSizable;[self.exclusionsWindow.contentView addSubview:note];[self.exclusionsWindow center];}
 [self rebuildExclusionsList];[NSApp activateIgnoringOtherApps:YES];[self.exclusionsWindow makeKeyAndOrderFront:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
 if([NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier].count>1){[NSApp terminate:nil];return;}
 NSMenu *main=[NSMenu new],*application=[NSMenu new];NSMenuItem *root=[NSMenuItem new];root.submenu=application;[main addItem:root];NSMenuItem *quit=[[NSMenuItem alloc]initWithTitle:@"Quit Less Pull" action:@selector(terminate:) keyEquivalent:@"q"];quit.target=NSApp;[application addItem:quit];NSMenuItem *settingsShortcut=[[NSMenuItem alloc]initWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];settingsShortcut.target=self;[application insertItem:settingsShortcut atIndex:0];NSApp.mainMenu=main;
 self.exclusionRules=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"appExclusions"] mutableCopy]?:[NSMutableDictionary new];self.exclusion=[ExclusionPolicy fromDictionary:[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"]]?:[ExclusionPolicy new];
 self.forcedNightOn=[[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"] objectForKey:@"forcedNightOn"] boolValue];self.engine=[FilterEngine new];self.warmth=[WarmthEngine new];[self.warmth restore];self.selectedMode=self.engine.currentMode;
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
 // The welcome window is for brand-new users only. Anyone with saved settings from an
 // earlier version gets the marker silently; it is not a user setting.
 BOOL firstLaunch=![d objectForKey:@"welcomeShown"]&&![d objectForKey:@"nightMode"]&&![d objectForKey:@"unifiedWarmth"]&&![d objectForKey:@"warmth"];
 [d setBool:YES forKey:@"welcomeShown"];
 [d registerDefaults:@{@"automatic":@YES,@"overrideMode":@(-1),@"warmth":@0,@"nightMode":@101,@"manualMode":@1}];
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
 self.browserBridge=[BrowserBridge new];__weak AppDelegate *browserOwner=self;self.browserBridge.changed=^{[browserOwner sync];};[self.browserBridge start];
 self.item=[NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
 self.item.button.image=[self menuBarImage:@"menubar-grayscale" symbol:@"circle.lefthalf.filled"];
 self.item.button.toolTip=@"Less Pull";
 NSMenu *menu=[NSMenu new];menu.delegate=self;self.item.menu=menu;
 __weak AppDelegate *weak=self;self.engine.changed=^{[weak pipelineChanged:nil];};
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(pipelineChanged:) name:NSWorkspaceDidWakeNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(pipelineChanged:) name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(displaysChanged:) name:NSApplicationDidChangeScreenParametersNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(frontmostChanged:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
 [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(frontmostChanged:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
 [self updateForeground];[self restartTimer];[self schedulePauseTimer];[self sync];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--settings"])[self showSettings:nil];
 if(firstLaunch||[NSProcessInfo.processInfo.arguments containsObject:@"--welcome"])[self showWelcome:nil];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--menu-test"]){[self showSettings:nil];main.itemArray.firstObject.submenu=self.item.menu;}

}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {[self showSettings:nil];return YES;}
// The supplied menu-bar images are black on transparent; as template images they
// follow the menu-bar appearance. The SF Symbol remains the fallback.
- (NSImage *)menuBarImage:(NSString *)name symbol:(NSString *)symbol {
 NSImage *image=[NSBundle.mainBundle imageForResource:name];if(image){image.template=YES;image.accessibilityDescription=@"Less Pull";return image;}
 return [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:@"Less Pull"];
}
- (void)restartTimer {
 [self.timer invalidate];double t=60;self.timer=[NSTimer timerWithTimeInterval:t target:self selector:@selector(sync) userInfo:nil repeats:YES];
 [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
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
 [self updateForeground];[self reconcileExclusion];
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
- (NSString *)modeName:(NSInteger)mode {return mode==101?@"Color":mode==100?@"Grayscale":mode==0?@"Natural Colors":mode==1?@"Grayscale":mode==16?@"System Color Tint":@"Other filter";}
- (NSString *)autoHelp {return @"Extra Warmth comes on with Night Shift and goes away when Night Shift turns off. Grayscale and your Night Shift schedule are not affected. If you move the slider yourself, that warmth stays until Night Shift next changes, or until you choose Resume Following.";}
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
 if(self.pause)return [NSString stringWithFormat:@"Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.exclusion.active){BOOL actual=NO;[self.engine nightShift:&actual];return [NSString stringWithFormat:@"Night Shift %@ for %@ · usually %@",actual?@"on":@"off",self.foregroundName,self.exclusion.desiredOn?@"on":@"off"];}
 if(self.automatic&&self.policy.overrideMode>=0)return @"Warmth set by hand until Night Shift next changes";
 return [NSString stringWithFormat:@"%@ · Night Shift %@",self.automatic?@"Warmth follows Night Shift":@"Warmth set by hand",known?(on?@"on":@"off"):@"unavailable"];
}
- (void)refreshControlsKnown:(BOOL)known nightOn:(BOOL)on {
 NSString *summary=[self appearanceSummary],*detail=[self automationSummaryKnown:known nightOn:on];
 BOOL failed=[self.status containsString:@"Could not"]||[self.status containsString:@"unavailable"]||[self.status containsString:@"unsupported"];
 self.statusText.stringValue=failed?self.status:summary;self.statusDetail.stringValue=detail;self.exclusionText.stringValue=[self exclusionSummary];self.exclusionText.toolTip=[self exclusionHelp];self.exclusionText.accessibilityHelp=[self exclusionHelp];
 BOOL actualOn=NO;BOOL actualKnown=[self.engine nightShift:&actualOn];
 self.item.button.toolTip=[NSString stringWithFormat:@"%@\n%@\nClick for Grayscale, Extra Warmth and Night Shift.",summary,detail];
 self.autoButton.state=self.automatic;self.autoButton.enabled=actualKnown;[self helpView:self.autoButton text:[self followHelpKnown:actualKnown nightOn:actualOn] label:@"Extra Warmth follows Night Shift"];self.nightButton.state=actualKnown&&actualOn;self.nightButton.enabled=known;
 self.nightButton.state=self.exclusion.active?on:(actualKnown&&actualOn);
 self.nightButton.title=known?(self.exclusion.active?(on?@"Default Night Shift: On":@"Default Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable";[self helpView:self.nightButton text:self.exclusion.active?[[self exclusionHelp] stringByAppendingString:@" This changes your default; the app in front keeps its own Night Shift exception."]:self.nightHelp label:nil];
 BOOL grayscaleOn=self.selectedMode==1||self.selectedMode==100;self.grayscaleButton.state=grayscaleOn;if(self.welcomeSwitch.state!=grayscaleOn)self.welcomeSwitch.state=grayscaleOn;
 self.grayscaleButton.title=self.grayOverride?@"Default Grayscale":@"Grayscale";
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
 else if(action==@selector(toggleNightShift:))help=self.nightHelp;
 else if(action==@selector(pauseNightShift:))help=self.pauseHelp;
 else if(action==@selector(endPauseNow:))help=[self endPauseHelp];
 else if(action==@selector(resume:))help=@"Go back to following Night Shift now.";
 else if(action==@selector(showSettings:)){help=@"Open all Less Pull settings, exceptions and help.";i.keyEquivalent=@",";}
 else if(action==@selector(showAbout:))help=@"Version, copyright and the author’s links.";
 else if(action==@selector(showHelp:))help=@"A short guide to Less Pull.";
 else if(action==@selector(diagnostics:))help=@"Technical details for troubleshooting.";
 else if(action==@selector(quit:)){help=@"Quit Less Pull. The display returns to normal and Night Shift follows its schedule again.";i.keyEquivalent=@"q";}
 i.toolTip=help;[menu addItem:i];return i;
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
- (void)menuDidClose:(NSMenu *)menu {[self.menuDismissal end];}
- (void)menuWillOpen:(NSMenu *)menu {
 if(!self.menuDismissal)self.menuDismissal=[MenuDismissal new];[self.menuDismissal begin:menu];
 [self sync];[menu removeAllItems];BOOL on=NO;BOOL known=[self logicalNightShift:&on];BOOL actualOn=NO;BOOL actualKnown=[self.engine nightShift:&actualOn];
 NSMenuItem *summary=[self add:[self menuStatusLine] action:nil to:menu];summary.toolTip=[NSString stringWithFormat:@"%@\n%@",[self automationSummaryKnown:known nightOn:on],[self exclusionSummary]];
 [menu addItem:NSMenuItem.separatorItem];
 NSMenuItem *gray=[self add:self.grayOverride?@"Default Grayscale":@"Grayscale" action:@selector(toggleGrayscale:) to:menu];gray.state=self.selectedMode==1||self.selectedMode==100;
 NSMenuItem *sliderItem=[NSMenuItem new];NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,300,78)];
 NSTextField *label=[NSTextField labelWithString:self.customWarmth?@"Default Extra Warmth":(self.automatic&&self.policy.overrideMode<0&&known&&!on)?@"Extra Warmth · used at night":@"Extra Warmth"];label.frame=NSMakeRect(18,54,210,18);[self helpView:label text:self.warmthHelp label:nil];[view addSubview:label];
 self.menuWarmthReadout=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[self currentWarmth]/3*100]];self.menuWarmthReadout.frame=NSMakeRect(242,54,48,18);self.menuWarmthReadout.alignment=NSTextAlignmentRight;[self helpView:self.menuWarmthReadout text:self.warmthHelp label:@"Extra Warmth percentage"];[view addSubview:self.menuWarmthReadout];
 NSSlider *slider=[NSSlider sliderWithValue:[self currentWarmth]/3*100 minValue:0 maxValue:100 target:self action:@selector(warmthChanged:)];slider.frame=NSMakeRect(18,26,260,26);slider.continuous=YES;slider.numberOfTickMarks=5;slider.allowsTickMarkValuesOnly=NO;[self helpView:slider text:self.warmthHelp label:@"Extra Warmth, percent"];[view addSubview:slider];
 for(int i=0;i<5;i++){NSTextField *r=[NSTextField labelWithString:@[@"Off",@"25",@"50",@"75",@"Red"][i]];r.font=[NSFont systemFontOfSize:10];r.alignment=NSTextAlignmentCenter;r.frame=NSMakeRect(28+60*i-20,4,40,16);[view addSubview:r];}
 [self helpView:view text:self.warmthHelp label:nil];sliderItem.view=view;sliderItem.toolTip=self.warmthHelp;[menu addItem:sliderItem];
 [menu addItem:NSMenuItem.separatorItem];
 // Everything about Night Shift lives in one submenu: on/off now, off for a while,
 // and whether Extra Warmth follows it.
 NSString *nightTitle=known?(self.exclusion.active?(on?@"Default Night Shift: On":@"Default Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable";
 NSMenuItem *night=[self add:nightTitle action:nil to:menu];night.state=known&&on;night.enabled=known;night.toolTip=self.exclusion.active?@"Your default Night Shift setting. The app in front keeps its own Night Shift exception.":self.nightHelp;
 if(known){night.submenu=[NSMenu new];
  [self add:on?@"Turn Off":@"Turn On" action:@selector(toggleNightShift:) to:night.submenu];
  if(self.pause)[self add:[self canResumePause]?@"Turn Night Shift back on":@"End timed off" action:@selector(endPauseNow:) to:night.submenu];
  else if(on||actualOn){[night.submenu addItem:NSMenuItem.separatorItem];[self populatePauses:night.submenu];}
  [night.submenu addItem:NSMenuItem.separatorItem];
  NSMenuItem *automatic=[self add:@"Extra Warmth follows Night Shift" action:@selector(toggleAuto:) to:night.submenu];automatic.state=self.automatic;automatic.enabled=actualKnown;automatic.toolTip=[self followHelpKnown:actualKnown nightOn:actualOn];
  if(self.automatic&&self.policy.overrideMode>=0)[self add:@"Resume Following" action:@selector(resume:) to:night.submenu];}
 [menu addItem:NSMenuItem.separatorItem];
 if(self.lastExternalApp.bundleIdentifier){NSMenuItem *current=[self add:[NSString stringWithFormat:@"Exception for %@…",self.lastExternalApp.localizedName?:@"current app"] action:@selector(excludeCurrent:) to:menu];current.toolTip=[self exclusionSummary];}
 [self add:@"Settings…" action:@selector(showSettings:) to:menu];
 [menu addItem:NSMenuItem.separatorItem];
 [self add:@"Quit" action:@selector(quit:) to:menu];
}
// One line for the menu: what the display shows now, plus a timed off or an active exception.
- (NSString *)menuStatusLine {
 NSString *line=[self appearanceSummary];
 if(self.pause)return [line stringByAppendingFormat:@" · Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.grayOverride||self.nightOverride||self.customWarmth)return [line stringByAppendingFormat:@" · %@ exception",self.foregroundName];
 if(self.automatic&&self.policy.overrideMode>=0)return [line stringByAppendingString:@" · set by hand"];
 return line;
}
- (void)toggleNightShift:(id)sender {
 self.pause=nil;[self.pauseTimer invalidate];self.pauseTimer=nil;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"nightShiftPause"];
 BOOL before=NO;BOOL known=[self logicalNightShift:&before];
 if(!known||![self requestNightShift:!before]){[self nightShiftFailure];return;}
 [self sync];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.7*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
 BOOL after=NO;if(![self logicalNightShift:&after]||after==before)[self nightShiftFailure];[self sync];
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
- (NSTextField *)label:(NSString *)text y:(CGFloat)y height:(CGFloat)height {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.frame=NSMakeRect(24,y,432,height);[self.settings.contentView addSubview:label];return label;
}
- (void)separatorAt:(CGFloat)y {NSBox *line=[[NSBox alloc]initWithFrame:NSMakeRect(24,y,432,1)];line.boxType=NSBoxSeparator;[self.settings.contentView addSubview:line];}
- (void)showSettings:(id)sender {
 if(!self.settings){
 self.settings=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,480,526) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];self.settings.title=@"Less Pull";self.settings.releasedWhenClosed=NO;
 self.statusText=[self label:@"" y:366 height:32];self.statusText.font=[NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
 self.statusDetail=[self label:@"" y:338 height:24];self.statusDetail.font=[NSFont systemFontOfSize:12];self.statusDetail.textColor=NSColor.secondaryLabelColor;
 [self separatorAt:324];
 self.grayscaleButton=[NSButton checkboxWithTitle:@"Grayscale" target:self action:@selector(toggleGrayscale:)];self.grayscaleButton.frame=NSMakeRect(24,284,430,26);[self helpView:self.grayscaleButton text:self.grayHelp label:@"Grayscale"];[self.settings.contentView addSubview:self.grayscaleButton];
 self.warmthTitle=[self label:@"Extra Warmth" y:246 height:24];self.warmthTitle.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];[self helpView:self.warmthTitle text:self.warmthHelp label:nil];
 self.resetButton=[NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetWarmth:)];self.resetButton.bezelStyle=NSBezelStyleInline;self.resetButton.frame=NSMakeRect(395,244,60,24);[self helpView:self.resetButton text:@"Set Extra Warmth to Off. Grayscale and Night Shift stay as they are." label:@"Reset Extra Warmth"];[self.settings.contentView addSubview:self.resetButton];
 self.warmthSlider=[NSSlider sliderWithValue:[self currentWarmth]/3*100 minValue:0 maxValue:100 target:self action:@selector(warmthChanged:)];self.warmthSlider.frame=NSMakeRect(24,214,340,26);self.warmthSlider.continuous=YES;self.warmthSlider.numberOfTickMarks=5;self.warmthSlider.allowsTickMarkValuesOnly=NO;[self helpView:self.warmthSlider text:self.warmthHelp label:@"Extra Warmth, percent"];[self.settings.contentView addSubview:self.warmthSlider];
 for(int i=0;i<5;i++){NSTextField *r=[NSTextField labelWithString:@[@"Off",@"25",@"50",@"75",@"Red"][i]];r.font=[NSFont systemFontOfSize:10];r.alignment=NSTextAlignmentCenter;r.frame=NSMakeRect(34+80*i-20,190,40,18);[self.settings.contentView addSubview:r];}
 self.warmthLabel=[NSTextField labelWithString:@""];self.warmthLabel.frame=NSMakeRect(388,214,65,24);self.warmthLabel.alignment=NSTextAlignmentRight;self.warmthLabel.font=[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightMedium];[self helpView:self.warmthLabel text:self.warmthHelp label:@"Extra Warmth percentage"];[self.settings.contentView addSubview:self.warmthLabel];
 [self separatorAt:176];
 self.nightButton=[NSButton checkboxWithTitle:@"Night Shift" target:self action:@selector(toggleNightShift:)];self.nightButton.frame=NSMakeRect(24,134,198,26);[self helpView:self.nightButton text:self.nightHelp label:@"Night Shift"];[self.settings.contentView addSubview:self.nightButton];
 self.pausePopup=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(226,134,230,26) pullsDown:YES];[self helpView:self.pausePopup text:self.pauseHelp label:@"Turn Night Shift off for…"];[self.settings.contentView addSubview:self.pausePopup];
 self.endPauseButton=[NSButton buttonWithTitle:@"End timed pause" target:self action:@selector(endPauseNow:)];self.endPauseButton.frame=NSMakeRect(226,134,230,26);[self helpView:self.endPauseButton text:self.pauseHelp label:@"End timed pause"];[self.settings.contentView addSubview:self.endPauseButton];
 self.autoButton=[NSButton checkboxWithTitle:@"Extra Warmth follows Night Shift" target:self action:@selector(toggleAuto:)];self.autoButton.frame=NSMakeRect(24,96,285,26);[self helpView:self.autoButton text:self.autoHelp label:@"Extra Warmth follows Night Shift"];[self.settings.contentView addSubview:self.autoButton];
 self.resumeButton=[NSButton buttonWithTitle:@"Resume Following" target:self action:@selector(resume:)];self.resumeButton.frame=NSMakeRect(320,96,136,26);[self helpView:self.resumeButton text:@"Go back to following Night Shift now." label:@"Resume Following Now"];[self.settings.contentView addSubview:self.resumeButton];
 self.loginButton=[NSButton checkboxWithTitle:@"Launch at login" target:self action:@selector(login:)];self.loginButton.frame=NSMakeRect(24,58,432,26);[self helpView:self.loginButton text:@"Open Less Pull when you sign in to your Mac. Install it in Applications first." label:@"Launch at login"];[self.settings.contentView addSubview:self.loginButton];
 NSButton *help=[NSButton buttonWithTitle:@"Help" target:self action:@selector(showHelp:)];help.bezelStyle=NSBezelStyleInline;help.frame=NSMakeRect(399,16,57,22);[self helpView:help text:@"A short guide to Less Pull." label:@"Help"];[self.settings.contentView addSubview:help];
 NSButton *diagnosticsButton=[NSButton buttonWithTitle:@"Diagnostics" target:self action:@selector(diagnostics:)];diagnosticsButton.bezelStyle=NSBezelStyleInline;diagnosticsButton.frame=NSMakeRect(300,16,95,22);[self helpView:diagnosticsButton text:@"Technical details for troubleshooting." label:@"Diagnostics"];[self.settings.contentView addSubview:diagnosticsButton];
 NSButton *about=[NSButton buttonWithTitle:@"About" target:self action:@selector(showAbout:)];about.bezelStyle=NSBezelStyleInline;about.frame=NSMakeRect(232,16,64,22);[self helpView:about text:@"Version, copyright and the author’s links." label:@"About Less Pull"];[self.settings.contentView addSubview:about];
 NSTextField *hint=[self label:@"Hover over a control for help." y:16 height:22];hint.font=[NSFont systemFontOfSize:11];hint.textColor=NSColor.secondaryLabelColor;hint.frame=NSMakeRect(24,16,200,22);
 for(NSView *view in self.settings.contentView.subviews){NSRect frame=view.frame;frame.origin.y+=26;view.frame=frame;}
 NSTextField *credit=[NSTextField labelWithString:@"© 2026 Jiri Arion Rose"];credit.font=[NSFont systemFontOfSize:10];credit.textColor=NSColor.secondaryLabelColor;credit.frame=NSMakeRect(24,10,185,18);[self.settings.contentView addSubview:credit];
 NSButton *website=[NSButton buttonWithTitle:@"jiriarion.com" target:self action:@selector(openWebsite:)];website.bezelStyle=NSBezelStyleInline;website.font=[NSFont systemFontOfSize:10];website.contentTintColor=NSColor.linkColor;website.frame=NSMakeRect(212,8,100,22);[self helpView:website text:@"Open jiriarion.com in your default browser." label:@"Visit Jiri Arion Rose’s website"];[self.settings.contentView addSubview:website];
 NSButton *support=[NSButton buttonWithTitle:@"Buy me a coffee" target:self action:@selector(openSupport:)];support.bezelStyle=NSBezelStyleInline;support.font=[NSFont systemFontOfSize:10];support.contentTintColor=NSColor.linkColor;support.frame=NSMakeRect(316,8,140,22);[self helpView:support text:@"Open buymeacoffee.com/HsERf62fiZ in your default browser." label:@"Support Jiri Arion Rose — Buy me a coffee"];[self.settings.contentView addSubview:support];
 for(NSView *view in self.settings.contentView.subviews){if(view.frame.origin.y>=84){NSRect f=view.frame;f.origin.y+=40;view.frame=f;}}
 self.exclusionText=[NSTextField labelWithString:@"Using your default settings"];self.exclusionText.font=[NSFont systemFontOfSize:11];self.exclusionText.textColor=NSColor.secondaryLabelColor;self.exclusionText.frame=NSMakeRect(24,84,282,24);[self.settings.contentView addSubview:self.exclusionText];
 NSButton *exclusions=[NSButton buttonWithTitle:@"App Exceptions…" target:self action:@selector(showExclusions:)];exclusions.frame=NSMakeRect(316,82,140,28);[self helpView:exclusions text:[self exclusionHelp] label:@"App exceptions"];[self.settings.contentView addSubview:exclusions];
 for(NSView *view in self.settings.contentView.subviews){if(view.frame.origin.y>=64){NSRect f=view.frame;f.origin.y+=40;view.frame=f;}}
 NSButton *browserInstall=[NSButton buttonWithTitle:@"Install Browser Extension…" target:self action:@selector(installBrowserExtension:)];browserInstall.frame=NSMakeRect(24,84,432,28);[self helpView:browserInstall text:@"Add the Less Pull extension to Brave or Chrome so websites can have their own settings. Less Pull must stay open." label:@"Install Browser Extension"];[self.settings.contentView addSubview:browserInstall];
 self.settings.initialFirstResponder=self.grayscaleButton;[self.settings recalculateKeyViewLoop];[self.settings center];
 }
 self.loginButton.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;[self sync];[NSApp activateIgnoringOtherApps:YES];[self.settings makeKeyAndOrderFront:nil];
}
- (void)installBrowserExtension:(id)sender {
 NSAlert *choose=[NSAlert new];choose.messageText=@"Install Browser Extension";choose.informativeText=@"Choose your browser. Less Pull will connect to it and open its extensions page. Until the extension is in the store, it is loaded from the folder inside the app. Less Pull must stay open for website exceptions to work.";[choose addButtonWithTitle:@"Brave"];[choose addButtonWithTitle:@"Chrome"];[choose addButtonWithTitle:@"Cancel"];[NSApp activateIgnoringOtherApps:YES];NSModalResponse choice=[choose runModal];if(choice!=NSAlertFirstButtonReturn&&choice!=NSAlertSecondButtonReturn)return;
 NSString *browser=choice==NSAlertFirstButtonReturn?@"Brave":@"Chrome",*identifier=choice==NSAlertFirstButtonReturn?@"com.brave.Browser":@"com.google.Chrome";NSURL *browserURL=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier];if(!browserURL){NSAlert *missing=[NSAlert new];missing.messageText=[browser stringByAppendingString:@" is not installed"];missing.informativeText=@"Install the browser, then return to Browser Extension setup.";[missing runModal];return;}
 NSTask *setup=[NSTask new];setup.executableURL=[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Contents/MacOS/LessPullBrowserHost"];setup.arguments=@[@"--install"];setup.standardOutput=[NSPipe pipe];setup.standardError=[NSPipe pipe];NSError *error=nil;BOOL started=[setup launchAndReturnError:&error];if(started)[setup waitUntilExit];if(!started||setup.terminationStatus!=0){NSAlert *failed=[NSAlert new];failed.messageText=@"Browser setup could not finish";failed.informativeText=error.localizedDescription?:@"Try again from a permanent local copy of Less Pull. The local bridge could not be registered.";[failed runModal];return;}
 NSURL *folder=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Browser Extension"];[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[folder]];
 [NSWorkspace.sharedWorkspace openURLs:@[[NSURL URLWithString:choice==NSAlertFirstButtonReturn?@"brave://extensions":@"chrome://extensions"]] withApplicationAtURL:browserURL configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:nil];
 NSAlert *guide=[NSAlert new];guide.messageText=[NSString stringWithFormat:@"Finish installation in %@",browser];guide.informativeText=@"1. Turn on Developer mode on the Extensions page.\n2. Click Load unpacked.\n3. Select the Browser Extension folder shown in Finder.\n4. Pin Less Pull in the browser toolbar.\n\nClick its icon on a website to give that site its own settings. Keep Less Pull where it is installed; run this setup again if you move it.";[guide addButtonWithTitle:@"Done"];[guide addButtonWithTitle:@"Copy extension folder path"];[NSApp activateIgnoringOtherApps:YES];if([guide runModal]==NSAlertSecondButtonReturn){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:folder.path forType:NSPasteboardTypeString];}
}
- (void)openWebsite:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://jiriarion.com"]];}
- (void)openSupport:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://buymeacoffee.com/HsERf62fiZ"]];}
- (void)showAbout:(id)sender {
 NSAlert *a=[NSAlert new];a.messageText=@"Less Pull";a.informativeText=[NSString stringWithFormat:@"Version %@\n\n© 2026 Jiri Arion Rose",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
 NSButton *website=[NSButton buttonWithTitle:@"jiriarion.com" target:self action:@selector(openWebsite:)];website.bezelStyle=NSBezelStyleInline;website.frame=NSMakeRect(0,0,200,28);website.contentTintColor=NSColor.linkColor;[self helpView:website text:@"Open jiriarion.com in your default browser." label:@"Visit Jiri Arion Rose’s website"];NSView *links=[[NSView alloc]initWithFrame:NSMakeRect(0,0,240,60)];website.frame=NSMakeRect(0,30,240,28);[links addSubview:website];NSButton *support=[NSButton buttonWithTitle:@"Buy me a coffee" target:self action:@selector(openSupport:)];support.bezelStyle=NSBezelStyleInline;support.frame=NSMakeRect(0,0,240,28);support.contentTintColor=NSColor.linkColor;[self helpView:support text:@"Open buymeacoffee.com/HsERf62fiZ in your default browser." label:@"Support Jiri Arion Rose — Buy me a coffee"];[links addSubview:support];a.accessoryView=links;[NSApp activateIgnoringOtherApps:YES];[a runModal];
}
- (NSArray<NSArray<NSString *> *> *)helpSections {
 return @[
  @[@"What Less Pull does",@"Less Pull takes the color out of your screen so it pulls at your attention less. You can add warmth, from amber to red, and keep color where you need it."],
  @[@"Grayscale",@"Shows everything in shades of gray, day and night. Turn it off to see color again."],
  @[@"Extra Warmth",@"Adds warmth on top of Night Shift. Off adds none; 100% is red. The slider is in the menu and in Settings."],
  @[@"Night Shift",@"Less Pull can turn Night Shift on or off now, or off for a while; your schedule in System Settings stays as it is. With “Extra Warmth follows Night Shift” on, the warmth you set comes on at night and goes away in the morning. If you move the slider by hand, that warmth stays until Night Shift next changes, or until you choose Resume Following."],
  @[@"Exceptions for apps",@"Give an app its own settings in Settings → App Exceptions, or choose “Exception for …” in the menu. They apply while that app is in front with a window open. Each setting can keep the default or get its own value."],
  @[@"Exceptions for websites",@"Install the browser extension from Settings, for Brave or Chrome. Click its icon on a website to give that site, or one exact page, its own settings. Pages inherit from their domain, and domains from the browser’s app exception. Private tabs are left alone."],
  @[@"Quitting",@"Quitting returns the display to normal and lets Night Shift follow its schedule again. Your settings and exceptions are kept."],
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
// First launch only: two sentences, where the icon is, and two choices that change
// nothing until clicked.
- (void)showWelcome:(id)sender {
 if(!self.welcomeWindow){
  self.welcomeWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,440,360) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];self.welcomeWindow.title=@"Welcome to Less Pull";self.welcomeWindow.releasedWhenClosed=NO;
  NSTextField *title=[NSTextField labelWithString:@"Welcome to Less Pull"];title.font=[NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
  NSTextField *intro=[NSTextField wrappingLabelWithString:@"Less Pull takes the color out of your screen so it pulls at your attention less. You can add warmth from amber to red, and keep color for the apps and websites that need it."];intro.preferredMaxLayoutWidth=392;
  NSImageView *icon=[NSImageView imageViewWithImage:[self menuBarImage:@"menubar-grayscale" symbol:@"circle.lefthalf.filled"]];icon.imageScaling=NSImageScaleProportionallyUpOrDown;[icon.widthAnchor constraintEqualToConstant:22].active=YES;[icon.heightAnchor constraintEqualToConstant:22].active=YES;icon.accessibilityLabel=@"The Less Pull menu-bar icon";
  NSTextField *where=[NSTextField wrappingLabelWithString:@"Less Pull lives in your menu bar, at the top right of the screen. Click this icon for Grayscale, Extra Warmth and Night Shift."];where.preferredMaxLayoutWidth=360;
  NSStackView *iconRow=[NSStackView stackViewWithViews:@[icon,where]];iconRow.alignment=NSLayoutAttributeTop;iconRow.spacing=10;
  self.welcomeSwitch=[NSButton checkboxWithTitle:@"Turn on Grayscale" target:self action:@selector(welcomeGrayscale:)];self.welcomeSwitch.state=(self.selectedMode==1||self.selectedMode==100);[self helpView:self.welcomeSwitch text:self.grayHelp label:@"Turn on Grayscale"];
  NSTextField *switchNote=[NSTextField wrappingLabelWithString:@"Everything on screen turns gray. The menu-bar icon switches it back any time."];switchNote.font=[NSFont systemFontOfSize:11];switchNote.textColor=NSColor.secondaryLabelColor;switchNote.preferredMaxLayoutWidth=392;
  NSStackView *switchRow=[NSStackView stackViewWithViews:@[self.welcomeSwitch,switchNote]];switchRow.orientation=NSUserInterfaceLayoutOrientationVertical;switchRow.alignment=NSLayoutAttributeLeading;switchRow.spacing=4;
  self.welcomeLogin=[NSButton checkboxWithTitle:@"Launch at login" target:self action:@selector(login:)];self.welcomeLogin.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;[self helpView:self.welcomeLogin text:@"Open Less Pull when you sign in to your Mac. Install it in Applications first." label:@"Launch at login"];
  NSButton *done=[NSButton buttonWithTitle:@"Done" target:self.welcomeWindow action:@selector(close)];done.keyEquivalent=@"\r";[self helpView:done text:@"Close this window. You can change everything later in Settings." label:@"Done"];
  NSView *spacer=[NSView new];[spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow-1 forOrientation:NSLayoutConstraintOrientationHorizontal];[done setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];[done setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
  NSStackView *doneRow=[NSStackView stackViewWithViews:@[spacer,done]];doneRow.alignment=NSLayoutAttributeCenterY;
  NSStackView *stack=[NSStackView stackViewWithViews:@[title,intro,iconRow,switchRow,self.welcomeLogin,doneRow]];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=16;stack.edgeInsets=NSEdgeInsetsMake(24,24,20,24);stack.translatesAutoresizingMaskIntoConstraints=NO;[stack setCustomSpacing:10 afterView:switchRow];
  NSView *content=self.welcomeWindow.contentView;[content addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:content.topAnchor],[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],[content.widthAnchor constraintEqualToConstant:440],[doneRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-48]]];
  [content layoutSubtreeIfNeeded];[self.welcomeWindow setContentSize:content.fittingSize];[self.welcomeWindow center];
 }
 self.welcomeSwitch.state=(self.selectedMode==1||self.selectedMode==100);[NSApp activateIgnoringOtherApps:YES];[self.welcomeWindow makeKeyAndOrderFront:nil];
}
- (void)welcomeGrayscale:(NSButton *)sender {BOOL gray=self.selectedMode==1||self.selectedMode==100;if((sender.state==NSControlStateValueOn)!=gray)[self toggleGrayscale:sender];}
- (void)login:(NSButton *)sender {
 NSError *error=nil;
 if(sender.state==NSControlStateValueOn)[SMAppService.mainAppService registerAndReturnError:&error];else [SMAppService.mainAppService unregisterAndReturnError:&error];
 if(error){NSAlert *a=[NSAlert new];a.messageText=@"Login setting needs attention";a.informativeText=error.localizedDescription;[a runModal];}
 sender.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;
}
- (void)resetWarmth:(id)sender {NSSlider *slider=[NSSlider new];slider.doubleValue=0;[self warmthChanged:slider];}
- (void)diagnostics:(id)sender {NSAlert *a=[NSAlert new];a.messageText=@"Diagnostics";NSString *betterDisplay=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"pro.betterdisplay.BetterDisplay"].count?@"\nBetterDisplay is running; it can change how displays look. HDR state is not read.":@"";a.informativeText=[NSString stringWithFormat:@"Less Pull %@ (%@)\n\n%@\n%@\nDisplay events: %lu; recoveries: %lu\nGrayscale setting: %@; grayscale showing now: %@; exception active: %@%@\n\nNight Shift drives “Extra Warmth follows Night Shift”; it does not prove the display looks warmer.",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"],self.engine.diagnostics,self.warmth.diagnostics,(unsigned long)self.pipelineEvents,(unsigned long)self.pipelineRestorations,(self.selectedMode==100||self.selectedMode==1)?@"On":@"Off",(self.effectiveMode==100||self.effectiveMode==1)?@"On":@"Off",(self.grayOverride||self.customWarmth)?@"yes":@"no",betterDisplay];[NSApp activateIgnoringOtherApps:YES];[a runModal];}
- (NSString *)warmthKey {return @"warmth";}
- (double)currentWarmth {return [NSUserDefaults.standardUserDefaults doubleForKey:[self warmthKey]];}
- (BOOL)applyMode:(NSInteger)mode {
 NSInteger effective=self.grayOverride==1?100:self.grayOverride==2?101:mode;
 BOOL nightOn=NO;BOOL known=[self logicalNightShift:&nightOn];
 BOOL warmthOff=self.automatic&&self.policy.overrideMode<0&&known&&!nightOn;
 double strength=self.customWarmth?self.appWarmth/100*3:((mode==100||mode==101)&&!warmthOff?[self currentWarmth]:0);
 if(mode!=self.selectedMode||effective!=self.effectiveMode||strength!=self.targetStrength)self.animateAppearance=YES;
 self.targetStrength=strength;
 BOOL gray=effective==100||effective==1;
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
- (void)displaysChanged:(id)sender {[self pipelineChanged:sender];}
- (void)applicationWillTerminate:(NSNotification *)note {self.quitting=YES;[self.eventTimer invalidate];[self.pipelineRecoveryTimer invalidate];[self.menuDismissal end];[self.browserBridge stop];[self.warmth cancelTransition];[self endPauseNow:nil];self.excludeNight=NO;[self reconcileExclusion];if(self.grayOverride||self.customWarmth){self.grayOverride=0;self.customWarmth=NO;self.excludeGray=NO;self.excludeWarmth=NO;self.animateAppearance=NO;[self.warmth cancelTransition];[self applyMode:self.selectedMode];}[self.warmth restore];}
- (void)quit:(id)sender {[NSApp terminate:nil];}
@end
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc>1&&strcmp(argv[1],"--diagnostics")==0){FilterEngine *e=[FilterEngine new];puts(e.diagnostics.UTF8String);return e.error?1:0;}
 NSApplication *app=NSApplication.sharedApplication;AppDelegate *delegate=[AppDelegate new];app.delegate=delegate;
 // --regular keeps a Dock icon so UI automation can reach a test build; production is a menu-bar-only app.
 if(![NSProcessInfo.processInfo.arguments containsObject:@"--regular"])[app setActivationPolicy:NSApplicationActivationPolicyAccessory];[app run];
}return 0;}
