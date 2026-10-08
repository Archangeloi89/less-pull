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
 if(self.excludeNight){BOOL target=self.nightOverride==1&&!self.pause;self.forcedNightOn=target;if(known&&actual!=target&&![self.engine setNightShiftEnabled:target])self.exclusionError=@"Could not apply the foreground Night Shift exception.";}
 else if(self.exclusion.active){
  if(!known){self.exclusionError=@"Night Shift unavailable; exclusion restoration pending.";return;}
  BOOL restore=!self.pause&&[self.exclusion mayRestoreAt:NSDate.date unchanged:[self guardUnchanged:self.exclusion.guard] calendar:NSCalendar.currentCalendar];
  if(actual!=restore&&![self.engine setNightShiftEnabled:restore]){self.exclusionError=@"Could not restore Night Shift after exclusion.";return;}
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
 NSMutableArray *effects=[NSMutableArray new];if(self.grayOverride)[effects addObject:self.grayOverride==1?@"Gray on":@"Gray off"];if(self.nightOverride)[effects addObject:self.pause?@"Night Shift paused":self.nightOverride==1?@"Night Shift on":@"Night Shift off"];if(self.customWarmth)[effects addObject:[NSString stringWithFormat:@"Warmth %.0f%%",self.appWarmth]];
 return effects.count?[NSString stringWithFormat:@"%@: %@",self.foregroundName,[effects componentsJoinedByString:@", "]]:@"Using global display settings";
}
- (NSString *)exclusionHelp {return @"App Exceptions apply only to the frontmost app with a visible, nonminimized regular window, across all displays. Use global setting inherits each effect independently. Global preferences and appearance overrides stay saved. Changes use the display matrix to avoid native Color Filter toggle indicators. Timed Night Shift off takes precedence over app Night Shift On. Restoration respects schedule eligibility. App warmth can still desaturate colors even with Grayscale Off; full color is not calibrated accuracy.";}
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
 if(!keys.count){NSTextField *empty=[NSTextField labelWithString:@"Add an app, then choose its display settings."];[self.exclusionsList addArrangedSubview:empty];}
 for(NSString *bundle in keys){NSDictionary *rule=self.exclusionRules[bundle];NSView *row=[[NSView alloc]initWithFrame:NSMakeRect(0,0,620,142)];[row.heightAnchor constraintEqualToConstant:142].active=YES;[row.widthAnchor constraintEqualToConstant:620].active=YES;
 NSTextField *name=[NSTextField labelWithString:rule[@"name"]?:bundle];name.font=[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];name.frame=NSMakeRect(8,112,480,20);name.toolTip=bundle;[row addSubview:name];
 NSArray *titles=@[@"Grayscale",@"Night Shift"];
 for(int i=0;i<2;i++){NSTextField *label=[NSTextField labelWithString:titles[i]];label.frame=NSMakeRect(8+i*300,77,80,20);[row addSubview:label];NSPopUpButton *choice=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(90+i*300,72,210,28) pullsDown:NO];[choice addItemsWithTitles:@[@"Use global setting",@"On",@"Off"]];[choice selectItemAtIndex:[rule[i==0?@"grayMode":@"nightMode"] integerValue]];choice.target=self;choice.action=@selector(ruleChanged:);choice.identifier=bundle;choice.tag=i;[self helpView:choice text:[self exclusionHelp] label:[NSString stringWithFormat:@"%@ — %@",rule[@"name"],titles[i]]];[row addSubview:choice];}
 NSButton *inherit=[NSButton checkboxWithTitle:@"Use global warmth" target:self action:@selector(ruleChanged:)];inherit.frame=NSMakeRect(8,35,160,26);inherit.identifier=bundle;inherit.tag=2;inherit.state=![rule[@"customWarmth"] boolValue];[self helpView:inherit text:@"Uncheck to set this app’s own warmth percentage. 0% adds no warmth; 100% reaches red. The global slider remains saved." label:[NSString stringWithFormat:@"%@ — Use global warmth",rule[@"name"]]];[row addSubview:inherit];
 NSSlider *slider=[NSSlider sliderWithValue:[rule[@"warmth"] doubleValue] minValue:0 maxValue:100 target:self action:@selector(ruleChanged:)];slider.frame=NSMakeRect(185,34,325,28);slider.identifier=bundle;slider.tag=3;slider.continuous=YES;slider.enabled=[rule[@"customWarmth"] boolValue];slider.numberOfTickMarks=5;[self helpView:slider text:@"App-specific Extra Warmth, Off 0% to Red 100%." label:[NSString stringWithFormat:@"%@ — Extra Warmth percent",rule[@"name"]]];[row addSubview:slider];
 NSTextField *percent=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[rule[@"warmth"] doubleValue]]];percent.tag=99;percent.frame=NSMakeRect(536,37,76,24);[row addSubview:percent];NSTextField *off=[NSTextField labelWithString:@"Off"];off.font=[NSFont systemFontOfSize:10];off.frame=NSMakeRect(185,15,40,16);[row addSubview:off];NSTextField *red=[NSTextField labelWithString:@"Red"];red.font=[NSFont systemFontOfSize:10];red.alignment=NSTextAlignmentRight;red.frame=NSMakeRect(470,15,40,16);[row addSubview:red];
 NSButton *remove=[NSButton buttonWithTitle:@"Remove" target:self action:@selector(removeRule:)];remove.identifier=bundle;remove.frame=NSMakeRect(536,109,76,26);[self helpView:remove text:@"Remove this app’s rule and restore any currently suspended effects safely." label:[NSString stringWithFormat:@"Remove %@ exception",rule[@"name"]]];[row addSubview:remove];[self.exclusionsList addArrangedSubview:row];}
}
- (void)showExclusions:(id)sender {
 if(!self.exclusionsWindow){self.exclusionsWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,680,510) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];self.exclusionsWindow.title=@"App Exceptions";self.exclusionsWindow.releasedWhenClosed=NO;self.exclusionsWindow.minSize=NSMakeSize(680,480);
 NSTextField *intro=[NSTextField wrappingLabelWithString:@"Choose app-specific display settings. They apply only while the app is frontmost with a visible, nonminimized regular window; global settings stay saved."];intro.frame=NSMakeRect(24,446,632,44);intro.autoresizingMask=NSViewMinYMargin|NSViewWidthSizable;[self.exclusionsWindow.contentView addSubview:intro];
 NSScrollView *scroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(24,142,632,294)];scroll.hasVerticalScroller=YES;scroll.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.exclusionsList=[ExceptionStack new];self.exclusionsList.orientation=NSUserInterfaceLayoutOrientationVertical;self.exclusionsList.alignment=NSLayoutAttributeLeading;self.exclusionsList.spacing=8;self.exclusionsList.edgeInsets=NSEdgeInsetsMake(8,0,8,0);scroll.documentView=self.exclusionsList;self.exclusionsList.translatesAutoresizingMaskIntoConstraints=NO;[self.exclusionsList.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active=YES;[self.exclusionsWindow.contentView addSubview:scroll];
 NSButton *add=[NSButton buttonWithTitle:@"Add app…" target:self action:@selector(addExclusionApp:)];add.frame=NSMakeRect(24,36,110,28);[self.exclusionsWindow.contentView addSubview:add];
 NSTextField *note=[NSTextField wrappingLabelWithString:@"Timed Night Shift off overrides app Night Shift On. Grayscale Off with warmth 0% and Night Shift Off removes these three effects; True Tone and other tools remain separate."];note.font=[NSFont systemFontOfSize:10];note.textColor=NSColor.secondaryLabelColor;note.frame=NSMakeRect(150,22,506,48);note.autoresizingMask=NSViewWidthSizable;[self.exclusionsWindow.contentView addSubview:note];[self.exclusionsWindow center];}
 [self rebuildExclusionsList];[NSApp activateIgnoringOtherApps:YES];[self.exclusionsWindow makeKeyAndOrderFront:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
 if([NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier].count>1){[NSApp terminate:nil];return;}
 NSMenu *main=[NSMenu new],*application=[NSMenu new];NSMenuItem *root=[NSMenuItem new];root.submenu=application;[main addItem:root];NSMenuItem *quit=[[NSMenuItem alloc]initWithTitle:@"Quit Less Pull" action:@selector(terminate:) keyEquivalent:@"q"];quit.target=NSApp;[application addItem:quit];NSMenuItem *settingsShortcut=[[NSMenuItem alloc]initWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];settingsShortcut.target=self;[application insertItem:settingsShortcut atIndex:0];NSApp.mainMenu=main;
 self.exclusionRules=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"appExclusions"] mutableCopy]?:[NSMutableDictionary new];self.exclusion=[ExclusionPolicy fromDictionary:[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"]]?:[ExclusionPolicy new];
 self.forcedNightOn=[[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"exclusionRecovery"] objectForKey:@"forcedNightOn"] boolValue];self.engine=[FilterEngine new];self.warmth=[WarmthEngine new];[self.warmth restore];self.selectedMode=self.engine.currentMode;
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
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
 self.item.button.image=[NSImage imageWithSystemSymbolName:@"circle.lefthalf.filled" accessibilityDescription:@"Less Pull"];
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
 if([NSProcessInfo.processInfo.arguments containsObject:@"--menu-test"]){[self showSettings:nil];main.itemArray.firstObject.submenu=self.item.menu;}

}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {[self showSettings:nil];return YES;}
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
 if(![self applyMode:target])self.status=self.warmth.error?:@"Could not verify appearance change; retrying.";
 else self.status=[NSString stringWithFormat:@"%@ · Extra Warmth following %@ · Night Shift %@",[self modeName:target],self.automatic?@"on":@"off",known?(on?@"on":@"off"):@"unavailable"];
 if(self.pause)self.status=[self.status stringByAppendingFormat:@" · Night Shift off until %@",[self timeLabel:self.pause.expiry]];
 if(self.exclusionError)self.status=self.exclusionError;
 [self refreshControlsKnown:known nightOn:on];
 NSArray *arguments=NSProcessInfo.processInfo.arguments;NSUInteger testIndex=[arguments indexOfObject:@"--test-state-path"];if(testIndex!=NSNotFound&&testIndex+1<arguments.count){BOOL actual=NO;[self.engine nightShift:&actual];NSDictionary *state=@{@"front":self.foregroundID?:@"",@"grayOverride":@(self.grayOverride),@"nightOverride":@(self.nightOverride),@"customWarmth":@(self.customWarmth),@"effectiveMode":@(self.effectiveMode),@"strength":@(self.targetStrength),@"logicalNight":@(on),@"actualNight":@(actual),@"override":@(self.policy.overrideMode),@"transitioning":@(self.warmth.transitioning),@"pause":@(self.pause!=nil)};[[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil] writeToFile:arguments[testIndex+1] atomically:YES];}

}
- (NSString *)modeName:(NSInteger)mode {return mode==101?@"Color":mode==100?@"Grayscale":mode==0?@"Natural Colors":mode==1?@"Grayscale":mode==16?@"System Color Tint":@"Other filter";}
- (NSString *)autoHelp {return @"Controls Extra Warmth only; never changes Grayscale or the system schedule. Night Shift off removes inherited Extra Warmth; on restores its saved amount. Manual warmth changes temporarily override following until the next transition or Resume Following. App and website exceptions retain their independent overrides.";}
- (NSString *)followHelpKnown:(BOOL)known nightOn:(BOOL)on {
 NSString *availability=!known?@"Night Shift status is unavailable; your preference is retained. ":@"";
 return [availability stringByAppendingString:self.autoHelp];
}
- (NSString *)grayHelp {return @"Checked keeps grayscale on day and night; unchecked keeps color. Night Shift and warmth following do not change this choice. App and website exceptions can override it.";}
- (NSString *)warmthHelp {return @"0% adds no warmth; 100% is red monochrome. Color and grayscale meet at the same red endpoint. The percentage is relative, not Kelvin. With warmth following enabled, changes temporarily override the schedule and are saved for night.";}
- (NSString *)nightHelp {return @"Manual on/off now; preserves the system schedule, which may change the state later. Off does not permanently disable scheduling. Cancels any timed pause; an actual transition ends a warmth override.";}
- (NSString *)pauseHelp {return @"Timed off; preserves the system schedule. Following removes inherited warmth and keeps Grayscale unchanged unless manually overridden. Resumes only while eligible; stays off in daytime. Until morning uses the custom end or shown 07:00 fallback. Quit ends the timed pause safely.";}
- (void)helpView:(NSView *)view text:(NSString *)text label:(NSString *)label {view.toolTip=text;view.accessibilityHelp=text;if(label)view.accessibilityLabel=label;}
- (NSString *)appearanceSummary {
 NSString *name=[self modeName:self.effectiveMode];double percent=self.targetStrength/3*100;
 return [NSString stringWithFormat:@"%@ · Warmth %@",name,percent>0?[NSString stringWithFormat:@"%.0f%%",percent]:@"Off"];
}
- (NSString *)automationSummaryKnown:(BOOL)known nightOn:(BOOL)on {
 if(self.pause)return [NSString stringWithFormat:@"Night Shift off until %@ · Following %@",[self timeLabel:self.pause.expiry],self.automatic?@"on":@"off"];
 if(self.exclusion.active){BOOL actual=NO;[self.engine nightShift:&actual];return [NSString stringWithFormat:@"App Night Shift %@ · global %@%@",actual?@"on":@"off",self.exclusion.desiredOn?@"on":@"off",self.policy.overrideMode>=0?@" · override":@""];}
 if(self.automatic&&self.policy.overrideMode>=0)return @"Temporary warmth override · Following stays on";
 return [NSString stringWithFormat:@"%@ · Night Shift %@",self.automatic?@"Warmth follows Night Shift":@"Manual",known?(on?@"on":@"off"):@"unavailable"];
}
- (void)refreshControlsKnown:(BOOL)known nightOn:(BOOL)on {
 NSString *summary=[self appearanceSummary],*detail=[self automationSummaryKnown:known nightOn:on];
 BOOL failed=[self.status containsString:@"Could not"]||[self.status containsString:@"unavailable"]||[self.status containsString:@"unsupported"];
 self.statusText.stringValue=failed?self.status:summary;self.statusDetail.stringValue=detail;self.exclusionText.stringValue=[self exclusionSummary];self.exclusionText.toolTip=[self exclusionHelp];self.exclusionText.accessibilityHelp=[self exclusionHelp];
 BOOL actualOn=NO;BOOL actualKnown=[self.engine nightShift:&actualOn];
 self.item.button.toolTip=[NSString stringWithFormat:@"%@\n%@\nClick for appearance, Night Shift, and Warmth-following controls.",summary,detail];
 self.autoButton.state=self.automatic;self.autoButton.enabled=actualKnown;[self helpView:self.autoButton text:[self followHelpKnown:actualKnown nightOn:actualOn] label:@"Extra Warmth follows Night Shift"];self.nightButton.state=actualKnown&&actualOn;self.nightButton.enabled=known;
 self.nightButton.state=self.exclusion.active?on:(actualKnown&&actualOn);
 self.nightButton.title=known?(self.exclusion.active?(on?@"Global Night Shift: On":@"Global Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable";[self helpView:self.nightButton text:self.exclusion.active?[[self exclusionHelp] stringByAppendingString:@" The toggle changes the underlying requested state; exception controls the actual Night Shift state."]:self.nightHelp label:nil];
 self.grayscaleButton.state=self.selectedMode==1||self.selectedMode==100;
 self.grayscaleButton.title=self.grayOverride?@"Global Grayscale":@"Grayscale";
 self.resumeButton.hidden=!(self.automatic&&self.policy.overrideMode>=0);
 self.endPauseButton.title=[self canResumePause]?@"Resume Night Shift now":@"End timed pause";[self helpView:self.endPauseButton text:[self endPauseHelp] label:self.endPauseButton.title];self.endPauseButton.hidden=self.pause==nil;self.pausePopup.hidden=self.pause!=nil;self.pausePopup.enabled=known&&(on||actualOn);
 self.resetButton.enabled=[self currentWarmth]>0;
 self.warmthSlider.doubleValue=[self currentWarmth]/3*100;NSString *percent=[NSString stringWithFormat:@"%.0f%%",[self currentWarmth]/3*100];self.warmthLabel.stringValue=percent;self.menuWarmthReadout.stringValue=percent;
 self.warmthLabel.accessibilityLabel=[NSString stringWithFormat:@"Extra Warmth %@",percent];
 self.warmthTitle.stringValue=self.customWarmth?@"Global Extra Warmth":(self.automatic&&self.policy.overrideMode<0&&known&&!on)?@"Extra Warmth · saved for night":@"Extra Warmth";
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
 else if(action==@selector(resume:))help=@"Apply the warmth for the current Night Shift state now. Warmth following stays enabled.";
 else if(action==@selector(showSettings:)){help=@"Open appearance, Night Shift, Extra Warmth follows Night Shift, and login settings.";i.keyEquivalent=@",";}
 else if(action==@selector(showAbout:))help=@"App version, copyright, and Jiri Arion Rose’s website.";
 else if(action==@selector(showHelp:))help=@"Read a short guide or open troubleshooting diagnostics.";
 else if(action==@selector(diagnostics:))help=@"Inspect system state and display requests for troubleshooting.";
 else if(action==@selector(quit:)){help=@"Quit the app, remove app-added warmth, and end an active Night Shift pause safely. The native system filter is restored.";i.keyEquivalent=@"q";}
 i.toolTip=help;[menu addItem:i];return i;
}
- (NSString *)morningPauseTitle {
 NSBlueStatus s={0};[self.engine readNightShiftStatus:&s];NSDate *morning=[PausePolicy nextMorningForDate:NSDate.date mode:s.mode endMinute:s.schedule.to.hour*60+s.schedule.to.minute calendar:NSCalendar.currentCalendar];
 return [NSString stringWithFormat:@"Off until morning · %@%@",[self timeLabel:morning],s.mode==2?@"":@" local fallback"];
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
 NSMenuItem *summary=[self add:[self appearanceSummary] action:nil to:menu];summary.toolTip=self.status;
 NSMenuItem *state=[self add:[self automationSummaryKnown:known nightOn:on] action:nil to:menu];state.toolTip=self.autoHelp;
 [menu addItem:NSMenuItem.separatorItem];
 NSMenuItem *gray=[self add:self.grayOverride?@"Global Grayscale":@"Grayscale" action:@selector(toggleGrayscale:) to:menu];gray.state=self.selectedMode==1||self.selectedMode==100;
 NSMenuItem *sliderItem=[NSMenuItem new];NSView *view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,300,78)];
 NSTextField *label=[NSTextField labelWithString:self.customWarmth?@"Global Extra Warmth":(self.automatic&&self.policy.overrideMode<0&&known&&!on)?@"Warmth · saved for night":@"Extra Warmth"];label.frame=NSMakeRect(18,54,210,18);[self helpView:label text:self.warmthHelp label:nil];[view addSubview:label];
 self.menuWarmthReadout=[NSTextField labelWithString:[NSString stringWithFormat:@"%.0f%%",[self currentWarmth]/3*100]];self.menuWarmthReadout.frame=NSMakeRect(242,54,48,18);self.menuWarmthReadout.alignment=NSTextAlignmentRight;[self helpView:self.menuWarmthReadout text:self.warmthHelp label:@"Extra Warmth percentage"];[view addSubview:self.menuWarmthReadout];
 NSSlider *slider=[NSSlider sliderWithValue:[self currentWarmth]/3*100 minValue:0 maxValue:100 target:self action:@selector(warmthChanged:)];slider.frame=NSMakeRect(18,26,260,26);slider.continuous=YES;slider.numberOfTickMarks=5;slider.allowsTickMarkValuesOnly=NO;[self helpView:slider text:self.warmthHelp label:@"Extra Warmth, percent"];[view addSubview:slider];
 for(int i=0;i<5;i++){NSTextField *r=[NSTextField labelWithString:@[@"Off",@"25",@"50",@"75",@"Red"][i]];r.font=[NSFont systemFontOfSize:10];r.alignment=NSTextAlignmentCenter;r.frame=NSMakeRect(28+60*i-20,4,40,16);[view addSubview:r];}
 [self helpView:view text:self.warmthHelp label:nil];sliderItem.view=view;sliderItem.toolTip=self.warmthHelp;[menu addItem:sliderItem];
 [menu addItem:NSMenuItem.separatorItem];
 NSMenuItem *night=[self add:known?(self.exclusion.active?(on?@"Global Night Shift: On":@"Global Night Shift: Off"):(on?@"Night Shift: On":@"Night Shift: Off")):@"Night Shift unavailable" action:known?@selector(toggleNightShift:):nil to:menu];night.state=known&&on;night.enabled=known;night.toolTip=self.exclusion.active?@"Changes the underlying requested Night Shift state; the foreground exception controls the actual Night Shift state.":self.nightHelp;
 if(self.pause)[self add:[self canResumePause]?@"Resume Night Shift now":@"End timed pause" action:@selector(endPauseNow:) to:menu];
 else if(known&&(on||actualOn)){NSMenuItem *pause=[self add:@"Turn Night Shift off for…" action:nil to:menu];pause.toolTip=self.pauseHelp;pause.submenu=[NSMenu new];[self populatePauses:pause.submenu];}
 NSMenuItem *automatic=[self add:@"Extra Warmth follows Night Shift" action:@selector(toggleAuto:) to:menu];automatic.state=self.automatic;automatic.enabled=actualKnown;automatic.toolTip=[self followHelpKnown:actualKnown nightOn:actualOn];
 if(self.automatic&&self.policy.overrideMode>=0)[self add:@"Resume Following" action:@selector(resume:) to:menu];
 [menu addItem:NSMenuItem.separatorItem];NSMenuItem *ex=[self add:[self exclusionSummary] action:nil to:menu];ex.toolTip=[self exclusionHelp];[self add:@"App Exceptions…" action:@selector(showExclusions:) to:menu];if(self.lastExternalApp.bundleIdentifier)[self add:[NSString stringWithFormat:@"Customize %@…",self.lastExternalApp.localizedName?:@"current app"] action:@selector(excludeCurrent:) to:menu];[self add:@"Install Browser Extension…" action:@selector(installBrowserExtension:) to:menu];[self add:@"Settings…" action:@selector(showSettings:) to:menu];
 NSMenuItem *help=[self add:@"Help" action:nil to:menu];help.toolTip=@"Usage help and troubleshooting.";help.submenu=[NSMenu new];[self add:@"How to Use…" action:@selector(showHelp:) to:help.submenu];[self add:@"Diagnostics…" action:@selector(diagnostics:) to:help.submenu];
 [self add:@"About Less Pull…" action:@selector(showAbout:) to:menu];
 [self add:@"Quit" action:@selector(quit:) to:menu];
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
- (NSString *)endPauseHelp {if(self.nightOverride)return @"Ends timed off. The global Night Shift state resumes only if eligible; the active app’s Night Shift override then applies again. App On can turn Night Shift on even when the global schedule is off; leaving restores the eligible global state.";return [self canResumePause]?@"End the timed pause and resume Night Shift now. The prior state and unchanged schedule are currently eligible. App appearance then follows actual Night Shift when enabled.":@"End the timed pause without turning Night Shift on: the prior state or schedule is not currently eligible, or status is unavailable. Night Shift stays off in daytime; its system schedule remains unchanged.";}
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
 NSAlert *alert=[NSAlert new];alert.messageText=@"Night Shift change could not be confirmed";
 alert.informativeText=@"Check Displays → Night Shift and Diagnostics. This display, HDR mode, or another display app may prevent activation. Your schedule and Extra Warmth follows Night Shift setting were not changed.";[NSApp activateIgnoringOtherApps:YES];[alert runModal];
}
- (void)enableAutomatic:(BOOL)value {self.automatic=value;self.policy.automatic=value;[self.policy resume];[self savePolicy];[NSUserDefaults.standardUserDefaults setBool:value forKey:@"automatic"];[self sync];}
- (BOOL)validateMenuItem:(NSMenuItem *)item {if(item.action==@selector(toggleAuto:)){BOOL on=NO;return [self.engine nightShift:&on];}return YES;}
- (void)toggleAuto:(id)sender {BOOL on=NO;if([self.engine nightShift:&on])[self enableAutomatic:!self.automatic];}
- (void)manual:(NSMenuItem *)sender {
 if(sender.tag==101||sender.tag==1||sender.tag==100)[NSUserDefaults.standardUserDefaults setInteger:sender.tag forKey:@"nightMode"];
 BOOL on=NO;BOOL known=[self logicalNightShift:&on];[self.policy observeKnown:known on:on];
 [self savePolicy];
 if(![self applyMode:sender.tag]){NSAlert *a=[NSAlert new];a.messageText=@"Filter change could not be verified";a.informativeText=self.warmth.error?:@"Open Accessibility → Display to check Color Filters. Your saved tint was not rewritten.";[a runModal];}
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
 self.resetButton=[NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetWarmth:)];self.resetButton.bezelStyle=NSBezelStyleInline;self.resetButton.frame=NSMakeRect(395,244,60,24);[self helpView:self.resetButton text:@"Set Extra Warmth to 0%. Keeps the current Color/Grayscale choice and does not switch Night Shift. With warmth following enabled, this is a temporary override and the new saved nighttime setting." label:@"Reset Extra Warmth"];[self.settings.contentView addSubview:self.resetButton];
 self.warmthSlider=[NSSlider sliderWithValue:[self currentWarmth]/3*100 minValue:0 maxValue:100 target:self action:@selector(warmthChanged:)];self.warmthSlider.frame=NSMakeRect(24,214,340,26);self.warmthSlider.continuous=YES;self.warmthSlider.numberOfTickMarks=5;self.warmthSlider.allowsTickMarkValuesOnly=NO;[self helpView:self.warmthSlider text:self.warmthHelp label:@"Extra Warmth, percent"];[self.settings.contentView addSubview:self.warmthSlider];
 for(int i=0;i<5;i++){NSTextField *r=[NSTextField labelWithString:@[@"Off",@"25",@"50",@"75",@"Red"][i]];r.font=[NSFont systemFontOfSize:10];r.alignment=NSTextAlignmentCenter;r.frame=NSMakeRect(34+80*i-20,190,40,18);[self.settings.contentView addSubview:r];}
 self.warmthLabel=[NSTextField labelWithString:@""];self.warmthLabel.frame=NSMakeRect(388,214,65,24);self.warmthLabel.alignment=NSTextAlignmentRight;self.warmthLabel.font=[NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightMedium];[self helpView:self.warmthLabel text:self.warmthHelp label:@"Extra Warmth percentage"];[self.settings.contentView addSubview:self.warmthLabel];
 [self separatorAt:176];
 self.nightButton=[NSButton checkboxWithTitle:@"Night Shift" target:self action:@selector(toggleNightShift:)];self.nightButton.frame=NSMakeRect(24,134,198,26);[self helpView:self.nightButton text:self.nightHelp label:@"Night Shift"];[self.settings.contentView addSubview:self.nightButton];
 self.pausePopup=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(226,134,230,26) pullsDown:YES];[self helpView:self.pausePopup text:self.pauseHelp label:@"Turn Night Shift off for…"];[self.settings.contentView addSubview:self.pausePopup];
 self.endPauseButton=[NSButton buttonWithTitle:@"End timed pause" target:self action:@selector(endPauseNow:)];self.endPauseButton.frame=NSMakeRect(226,134,230,26);[self helpView:self.endPauseButton text:self.pauseHelp label:@"End timed pause"];[self.settings.contentView addSubview:self.endPauseButton];
 self.autoButton=[NSButton checkboxWithTitle:@"Extra Warmth follows Night Shift" target:self action:@selector(toggleAuto:)];self.autoButton.frame=NSMakeRect(24,96,285,26);[self helpView:self.autoButton text:self.autoHelp label:@"Extra Warmth follows Night Shift"];[self.settings.contentView addSubview:self.autoButton];
 self.resumeButton=[NSButton buttonWithTitle:@"Resume Following" target:self action:@selector(resume:)];self.resumeButton.frame=NSMakeRect(320,96,136,26);[self helpView:self.resumeButton text:@"Apply your warmth for the current Night Shift state now and end the temporary override. Warmth following remains enabled." label:@"Resume Following Now"];[self.settings.contentView addSubview:self.resumeButton];
 self.loginButton=[NSButton checkboxWithTitle:@"Launch at login" target:self action:@selector(login:)];self.loginButton.frame=NSMakeRect(24,58,432,26);[self helpView:self.loginButton text:@"Start this menu-bar app when you sign in. Install it in Applications first. macOS may ask you to allow it in Login Items." label:@"Launch at login"];[self.settings.contentView addSubview:self.loginButton];
 NSButton *help=[NSButton buttonWithTitle:@"Help" target:self action:@selector(showHelp:)];help.bezelStyle=NSBezelStyleInline;help.frame=NSMakeRect(399,16,57,22);[self helpView:help text:@"Read usage help and access troubleshooting diagnostics." label:@"Help"];[self.settings.contentView addSubview:help];
 NSTextField *hint=[self label:@"Hover over a control for help." y:16 height:22];hint.font=[NSFont systemFontOfSize:11];hint.textColor=NSColor.secondaryLabelColor;hint.frame=NSMakeRect(24,16,300,22);
 for(NSView *view in self.settings.contentView.subviews){NSRect frame=view.frame;frame.origin.y+=26;view.frame=frame;}
 NSTextField *credit=[NSTextField labelWithString:@"© 2026 Jiri Arion Rose"];credit.font=[NSFont systemFontOfSize:10];credit.textColor=NSColor.secondaryLabelColor;credit.frame=NSMakeRect(24,10,185,18);[self.settings.contentView addSubview:credit];
 NSButton *website=[NSButton buttonWithTitle:@"jiriarion.com" target:self action:@selector(openWebsite:)];website.bezelStyle=NSBezelStyleInline;website.font=[NSFont systemFontOfSize:10];website.contentTintColor=NSColor.linkColor;website.frame=NSMakeRect(212,8,100,22);[self helpView:website text:@"Open jiriarion.com in your default browser." label:@"Visit Jiri Arion Rose’s website"];[self.settings.contentView addSubview:website];
 NSButton *support=[NSButton buttonWithTitle:@"Buy me a coffee" target:self action:@selector(openSupport:)];support.bezelStyle=NSBezelStyleInline;support.font=[NSFont systemFontOfSize:10];support.contentTintColor=NSColor.linkColor;support.frame=NSMakeRect(316,8,140,22);[self helpView:support text:@"Open buymeacoffee.com/HsERf62fiZ in your default browser." label:@"Support Jiri Arion Rose — Buy me a coffee"];[self.settings.contentView addSubview:support];
 for(NSView *view in self.settings.contentView.subviews){if(view.frame.origin.y>=84){NSRect f=view.frame;f.origin.y+=40;view.frame=f;}}
 self.exclusionText=[NSTextField labelWithString:@"No foreground exclusions"];self.exclusionText.font=[NSFont systemFontOfSize:11];self.exclusionText.textColor=NSColor.secondaryLabelColor;self.exclusionText.frame=NSMakeRect(24,84,282,24);[self.settings.contentView addSubview:self.exclusionText];
 NSButton *exclusions=[NSButton buttonWithTitle:@"App Exceptions…" target:self action:@selector(showExclusions:)];exclusions.frame=NSMakeRect(316,82,140,28);[self helpView:exclusions text:[self exclusionHelp] label:@"Configure foreground app exceptions"];[self.settings.contentView addSubview:exclusions];
 for(NSView *view in self.settings.contentView.subviews){if(view.frame.origin.y>=64){NSRect f=view.frame;f.origin.y+=40;view.frame=f;}}
 NSButton *browserInstall=[NSButton buttonWithTitle:@"Install Browser Extension…" target:self action:@selector(installBrowserExtension:)];browserInstall.frame=NSMakeRect(24,84,432,28);[self helpView:browserInstall text:@"Set up the local Less Pull bridge and install website exceptions in Brave or Chrome. The Mac app must stay running." label:@"Install Browser Extension"];[self.settings.contentView addSubview:browserInstall];
 self.settings.initialFirstResponder=self.grayscaleButton;[self.settings recalculateKeyViewLoop];[self.settings center];
 }
 self.loginButton.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;[self sync];[NSApp activateIgnoringOtherApps:YES];[self.settings makeKeyAndOrderFront:nil];
}
- (void)installBrowserExtension:(id)sender {
 NSAlert *choose=[NSAlert new];choose.messageText=@"Install Browser Extension";choose.informativeText=@"Choose your browser. Less Pull will set up its local connection and open the browser’s extension installer. This test build uses Load unpacked; the public release will use the official store. The extension needs this Mac app installed and running.";[choose addButtonWithTitle:@"Brave"];[choose addButtonWithTitle:@"Chrome"];[choose addButtonWithTitle:@"Cancel"];[NSApp activateIgnoringOtherApps:YES];NSModalResponse choice=[choose runModal];if(choice!=NSAlertFirstButtonReturn&&choice!=NSAlertSecondButtonReturn)return;
 NSString *browser=choice==NSAlertFirstButtonReturn?@"Brave":@"Chrome",*identifier=choice==NSAlertFirstButtonReturn?@"com.brave.Browser":@"com.google.Chrome";NSURL *browserURL=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier];if(!browserURL){NSAlert *missing=[NSAlert new];missing.messageText=[browser stringByAppendingString:@" is not installed"];missing.informativeText=@"Install the browser, then return to Browser Extension setup.";[missing runModal];return;}
 NSTask *setup=[NSTask new];setup.executableURL=[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Contents/MacOS/LessPullBrowserHost"];setup.arguments=@[@"--install"];setup.standardOutput=[NSPipe pipe];setup.standardError=[NSPipe pipe];NSError *error=nil;BOOL started=[setup launchAndReturnError:&error];if(started)[setup waitUntilExit];if(!started||setup.terminationStatus!=0){NSAlert *failed=[NSAlert new];failed.messageText=@"Browser setup could not finish";failed.informativeText=error.localizedDescription?:@"Try again from a permanent local copy of Less Pull. The local bridge could not be registered.";[failed runModal];return;}
 NSURL *folder=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Browser Extension"];[NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[folder]];
 [NSWorkspace.sharedWorkspace openURLs:@[[NSURL URLWithString:choice==NSAlertFirstButtonReturn?@"brave://extensions":@"chrome://extensions"]] withApplicationAtURL:browserURL configuration:NSWorkspaceOpenConfiguration.configuration completionHandler:nil];
 NSAlert *guide=[NSAlert new];guide.messageText=[NSString stringWithFormat:@"Finish installation in %@",browser];guide.informativeText=@"1. Turn on Developer mode on the Extensions page.\n2. Click Load unpacked.\n3. Select the Browser Extension folder shown in Finder.\n4. Pin Less Pull in the browser toolbar.\n\nClick its icon on a website to customize the domain or exact URL. Keep the app and extension folder in their installed locations. Rerun setup after moving the app.";[guide addButtonWithTitle:@"Done"];[guide addButtonWithTitle:@"Copy extension folder path"];[NSApp activateIgnoringOtherApps:YES];if([guide runModal]==NSAlertSecondButtonReturn){[NSPasteboard.generalPasteboard clearContents];[NSPasteboard.generalPasteboard setString:folder.path forType:NSPasteboardTypeString];}
}
- (void)openWebsite:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://jiriarion.com"]];}
- (void)openSupport:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://buymeacoffee.com/HsERf62fiZ"]];}
- (void)showAbout:(id)sender {
 NSAlert *a=[NSAlert new];a.messageText=@"Less Pull";a.informativeText=[NSString stringWithFormat:@"Version %@\n\n© 2026 Jiri Arion Rose",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
 NSButton *website=[NSButton buttonWithTitle:@"jiriarion.com" target:self action:@selector(openWebsite:)];website.bezelStyle=NSBezelStyleInline;website.frame=NSMakeRect(0,0,200,28);website.contentTintColor=NSColor.linkColor;[self helpView:website text:@"Open jiriarion.com in your default browser." label:@"Visit Jiri Arion Rose’s website"];NSView *links=[[NSView alloc]initWithFrame:NSMakeRect(0,0,240,60)];website.frame=NSMakeRect(0,30,240,28);[links addSubview:website];NSButton *support=[NSButton buttonWithTitle:@"Buy me a coffee" target:self action:@selector(openSupport:)];support.bezelStyle=NSBezelStyleInline;support.frame=NSMakeRect(0,0,240,28);support.contentTintColor=NSColor.linkColor;[self helpView:support text:@"Open buymeacoffee.com/HsERf62fiZ in your default browser." label:@"Support Jiri Arion Rose — Buy me a coffee"];[links addSubview:support];a.accessoryView=links;[NSApp activateIgnoringOtherApps:YES];[a runModal];
}
- (void)showHelp:(id)sender {
 NSAlert *a=[NSAlert new];a.messageText=@"Less Pull";a.informativeText=[NSString stringWithFormat:@"%@\n\n%@\n\nThe Night Shift checkbox and On/Off Now menu action change the current system state; the system schedule may change it later. Timed off is the pause function: its expiry stays visible, it survives unexpected restart, and safe schedule rules decide whether Night Shift can resume. Warmth following controls only Extra Warmth. While timed off, following stays enabled and uses the selected Color/Grayscale with warmth off; manual overrides remain available. At expiry the app follows actual Night Shift, without forcing daytime activation. Extra Warmth runs independently of Night Shift. Quit removes app-added warmth and ends the timed pause safely. Hover help is also available to accessibility tools.",self.autoHelp,self.pauseHelp];[a addButtonWithTitle:@"Done"];[a addButtonWithTitle:@"Diagnostics…"];[NSApp activateIgnoringOtherApps:YES];if([a runModal]==NSAlertSecondButtonReturn)[self diagnostics:nil];
}
- (void)login:(NSButton *)sender {
 NSError *error=nil;
 if(sender.state==NSControlStateValueOn)[SMAppService.mainAppService registerAndReturnError:&error];else [SMAppService.mainAppService unregisterAndReturnError:&error];
 if(error){NSAlert *a=[NSAlert new];a.messageText=@"Login setting needs attention";a.informativeText=error.localizedDescription;[a runModal];}
 sender.state=SMAppService.mainAppService.status==SMAppServiceStatusEnabled;
}
- (void)resetWarmth:(id)sender {NSSlider *slider=[NSSlider new];slider.doubleValue=0;[self warmthChanged:slider];}
- (void)diagnostics:(id)sender {NSAlert *a=[NSAlert new];a.messageText=@"Diagnostics";a.informativeText=[NSString stringWithFormat:@"%@\n\n%@\n\nBetterDisplay running: %@. HDR state is not read; check BetterDisplay/System Settings.\nNight Shift state drives Extra Warmth follows Night Shift; it does not prove visual warming on every display.",self.engine.diagnostics,[NSString stringWithFormat:@"%@\nPipeline events: %lu; bounded restorations: %lu\nGlobal Grayscale: %@; effective Grayscale: %@; appearance exception: %@",self.warmth.diagnostics,(unsigned long)self.pipelineEvents,(unsigned long)self.pipelineRestorations,(self.selectedMode==100||self.selectedMode==1)?@"On":@"Off",(self.effectiveMode==100||self.effectiveMode==1)?@"On":@"Off",(self.grayOverride||self.customWarmth)?@"active":@"none"],[NSRunningApplication runningApplicationsWithBundleIdentifier:@"pro.betterdisplay.BetterDisplay"].count?@"yes":@"no"];[a runModal];}
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
 self.grayscaleButton.title=self.grayOverride?@"Global Grayscale":@"Grayscale";}
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
 NSApplication *app=NSApplication.sharedApplication;AppDelegate *delegate=[AppDelegate new];app.delegate=delegate;[app setActivationPolicy:NSApplicationActivationPolicyAccessory];[app run];
}return 0;}
