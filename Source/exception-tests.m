#define main utility_main
#import "main.m"
#undef main
@interface FakeFilter : FilterEngine
@property BOOL on;
@property NSInteger mode,nativeWrites,nightWrites;
@property NSBlueStatus state;
@end
@implementation FakeFilter
- (BOOL)nightShift:(BOOL *)on {*on=self.on;return YES;}
- (BOOL)readNightShiftStatus:(NSBlueStatus *)s {*s=self.state;return YES;}
- (BOOL)setNightShiftEnabled:(BOOL)on {self.on=on;self.nightWrites++;return YES;}
- (BOOL)applyMode:(NSInteger)mode {self.mode=mode;self.nativeWrites++;return YES;}
@end
@interface FakeWarmth : WarmthEngine
@property double value,lastDuration;
@property NSInteger transitions;
@property BOOL gray,lastReduced;
@end
@implementation FakeWarmth
- (BOOL)restore {self.value=0;return YES;}
- (BOOL)applyStrength:(double)s grayscale:(BOOL)g {self.value=s;self.gray=g;return YES;}
- (void)transitionStrength:(double)s grayscale:(BOOL)g reduceMotion:(BOOL)r duration:(double)d completion:(void (^)(void))c {self.transitions++;self.lastDuration=d;self.value=s;self.gray=g;self.lastReduced=r;c();}
- (void)invalidate {}
@end
@interface TestApp : AppDelegate
@end
@implementation TestApp
- (void)updateForeground {}
- (void)refreshControlsKnown:(BOOL)known nightOn:(BOOL)on {}
- (void)nightShiftFailure {abort();}
- (PausePolicy *)nightGuard {PausePolicy *p=[super nightGuard];p.nightEnd=[NSDate.date dateByAddingTimeInterval:3600];p.scheduleMode=0;return p;}
@end
static void check(BOOL value,const char *message){if(!value){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(){@autoreleasepool{
 [NSApplication sharedApplication];NSUserDefaults *d=NSUserDefaults.standardUserDefaults;[d setDouble:1.5 forKey:@"warmth"];[d setInteger:100 forKey:@"nightMode"];
 TestApp *a=[TestApp new];FakeFilter *e=[FakeFilter new];e.on=YES;e.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *w=[FakeWarmth new];a.engine=e;a.warmth=w;a.exclusion=[ExclusionPolicy new];a.policy=[SwitchingPolicy new];a.policy.known=YES;a.policy.nightShiftOn=YES;a.policy.automatic=YES;a.automatic=YES;a.policy.overrideMode=100;a.selectedMode=100;a.exclusionRules=[NSMutableDictionary new];
 [a sync];check(w.gray&&w.value==1.5,"global gray and warmth");
 NSInteger before=w.transitions;[a applyMode:101];check(w.transitions==before+1&&w.lastDuration==0.5&&!w.lastReduced&&!w.gray,"manual Color fades half second");
 [a applyMode:100];check(w.lastDuration==0.5&&!w.lastReduced&&w.gray,"manual Grayscale fades even with Night Shift on");
 before=w.transitions;[a sync];check(w.transitions==before,"unchanged sync does not restart fade");
 a.grayOverride=2;a.animateAppearance=YES;[a sync];check(w.value==1.5&&!w.gray,"gray off retains warmth");check(a.policy.overrideMode==100,"gray exception retains override");
 NSInteger nightWrites=e.nightWrites;a.grayOverride=0;a.animateAppearance=YES;[a sync];check(!w.lastReduced&&w.lastDuration==0.5&&e.nightWrites==nightWrites&&e.on,"Color to Gray with Night Shift on fades half second without Night Shift writes");
 a.grayOverride=2;a.customWarmth=YES;a.appWarmth=0;a.animateAppearance=YES;[a sync];
 nightWrites=e.nightWrites;a.grayOverride=0;a.customWarmth=NO;a.animateAppearance=YES;[a sync];check(w.gray&&w.value==1.5&&!w.lastReduced&&w.lastDuration==0.5&&e.nightWrites==nightWrites,"return from Color with warmth off fades to global grayscale and warmth");
 a.grayOverride=2;a.animateAppearance=YES;[a sync];check(!w.lastReduced,"enter Color keeps configured fade");

 a.grayOverride=1;a.customWarmth=YES;a.appWarmth=0;a.animateAppearance=YES;[a sync];check(w.gray&&w.value==0,"gray on with no warmth");
 a.appWarmth=80;a.animateAppearance=YES;[a sync];check(fabs(w.value-2.4)<1e-6&&w.gray,"custom warmth with gray");check([d doubleForKey:@"warmth"]==1.5,"global warmth retained");
 a.grayOverride=0;a.customWarmth=NO;a.excludeNight=YES;a.nightOverride=2;a.animateAppearance=YES;[a sync];check(!e.on&&a.exclusion.desiredOn,"night off exception captures desired on");[a sync];check(a.policy.overrideMode==100&&a.policy.nightShiftOn,"own off does not clear following override");
 a.nightOverride=1;[a sync];[a sync];check(e.on&&a.exclusion.desiredOn&&a.policy.overrideMode==100,"switch excluded apps off to on preserves underlying on");
 [a requestNightShift:NO];[a sync];check(a.exclusion.desiredOn==NO&&a.policy.nightShiftOn==NO&&a.policy.overrideMode==-1,"explicit underlying off is genuine transition");
 a.excludeNight=NO;[a sync];check(!e.on&&!a.exclusion.active,"leave forced on restores underlying off");
 a.excludeNight=YES;a.nightOverride=1;[a sync];[a sync];check(e.on&&!a.exclusion.desiredOn&&!a.policy.nightShiftOn,"forced on does not move follower into night");
 PausePolicy *pause=[a nightGuard];pause.expiry=[NSDate.date dateByAddingTimeInterval:3600];a.pause=pause;[a requestNightShift:NO];[a sync];[a sync];check(!e.on&&a.pause!=nil,"timed off wins over app on");
 [a endPauseNow:nil];[a sync];check(e.on&&a.exclusion.desiredOn&&a.pause==nil,"eligible pause expiry updates underlying state then app override");
 a.excludeNight=NO;[a sync];check(e.on,"exit restores eligible on");
 ExclusionPolicy *p=[ExclusionPolicy new];PausePolicy *guard=[a nightGuard];[p beginKnown:YES on:YES guard:guard];[p observeKnown:YES actualOn:NO expectedOn:NO guard:nil unchanged:YES date:NSDate.date calendar:NSCalendar.currentCalendar];check(p.desiredOn,"suppression ignored");
 guard.nightEnd=[NSDate.date dateByAddingTimeInterval:-1];[p observeKnown:YES actualOn:NO expectedOn:NO guard:nil unchanged:YES date:NSDate.date calendar:NSCalendar.currentCalendar];check(!p.desiredOn&&! [p mayRestoreAt:NSDate.date unchanged:YES calendar:NSCalendar.currentCalendar],"morning prevents restore");
 [p beginKnown:YES on:NO guard:nil];[p observeScheduleWindow:NO];[p observeScheduleWindow:YES];check(p.desiredOn,"real custom schedule boundary changes underlying state");
 p.guard=[a nightGuard];ExclusionPolicy *recovered=[ExclusionPolicy fromDictionary:p.dictionary];check(recovered.active&&recovered.desiredOn&&recovered.guard,"crash recovery snapshot");check(![recovered mayRestoreAt:NSDate.date unchanged:NO calendar:NSCalendar.currentCalendar],"changed schedule blocks resume");
 a.grayOverride=0;a.customWarmth=NO;a.animateAppearance=YES;[a sync];check([d doubleForKey:@"warmth"]==1.5&&a.automatic,"globals and following retained");

 // Global Grayscale is persistent; toggling it must not create a warmth override.
 for(int base=100;base<=101;base++){
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=YES;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=YES;t.policy.automatic=YES;t.automatic=YES;t.selectedMode=base;[d setInteger:base forKey:@"nightMode"];
  [t sync];check(fw.gray==(base==100)&&fw.value==1.5,"night uses saved grayscale and warmth");
  fe.on=NO;[t sync];check(fw.gray==(base==100)&&fw.value==0,"morning preserves grayscale and removes warmth");
  [t toggleGrayscale:nil];check(fw.gray==(base!=100)&&fw.value==0&&t.policy.overrideMode==-1,"daytime grayscale toggle stays permanent without activating warmth");
  fe.on=YES;[t sync];check(fw.gray==(base!=100)&&fw.value==1.5,"next night retains changed grayscale and restores warmth");
  fe.on=NO;[t sync];NSSlider *slider=[NSSlider new];slider.maxValue=100;slider.doubleValue=25;[t warmthChanged:slider];check(fabs(fw.value-.75)<1e-9&&t.policy.overrideMode>=0,"manual daytime warmth override");
  [t resume:nil];check(fw.value==0&&fw.gray==(base!=100),"resume follows warmth only");
  [d setDouble:1.5 forKey:@"warmth"];
 }

 // Pause Less Pull: the plain display with the normal fade, rules ignored, saved
 // settings kept, persisted for relaunch, expiry clears it.
 {
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=YES;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=YES;t.policy.automatic=YES;t.automatic=YES;t.selectedMode=100;[d setInteger:100 forKey:@"nightMode"];[d setDouble:1.5 forKey:@"warmth"];[d removeObjectForKey:@"lessPullPause"];
  t.grayOverride=1;t.customWarmth=YES;t.appWarmth=80;t.animateAppearance=YES;[t sync];check(fw.gray&&fabs(fw.value-2.4)<1e-9,"exception active before pause");
  NSInteger nightWrites=fe.nightWrites;[t pauseLessPullForMinutes:15];check(!fw.gray&&fw.value==0&&fw.lastDuration==0.5&&!fw.lastReduced,"pause shows the plain display with the normal fade");
  check([d doubleForKey:@"warmth"]==1.5&&[d integerForKey:@"nightMode"]==100,"pause keeps saved settings");check(fe.nightWrites==nightWrites&&fe.on,"pause leaves Night Shift alone");
  t.grayOverride=1;t.customWarmth=YES;t.appWarmth=80;t.animateAppearance=YES;[t sync];check(!fw.gray&&fw.value==0&&t.grayOverride==0&&!t.customWarmth,"rules are ignored while paused");
  double until=[[d dictionaryForKey:@"lessPullPause"][@"until"] doubleValue];check(until>NSDate.date.timeIntervalSince1970+14*60&&until<NSDate.date.timeIntervalSince1970+16*60,"timed pause persisted with its expiry");
  TestApp *again=[TestApp new];again.engine=fe;again.warmth=fw;again.exclusion=[ExclusionPolicy new];again.policy=t.policy;again.automatic=YES;again.selectedMode=100;[again restoreLessPullPause];check(again.pausedUntil!=nil&&fabs(again.pausedUntil.timeIntervalSince1970-until)<1,"pause survives relaunch");
  [t resumeLessPull:nil];check(fw.gray&&fw.value==1.5&&fw.lastDuration==0.5,"resume restores the saved appearance with the normal fade");check([d dictionaryForKey:@"lessPullPause"]==nil,"resume clears the saved pause");
  [t pauseLessPullForMinutes:0];check([t.pausedUntil isEqualToDate:NSDate.distantFuture]&&[[d dictionaryForKey:@"lessPullPause"][@"until"] doubleValue]==0,"until-I-resume pause persisted as open-ended");
  [again restoreLessPullPause];check([again.pausedUntil isEqualToDate:NSDate.distantFuture],"open-ended pause survives relaunch");
  [d setObject:@{@"until":@(NSDate.date.timeIntervalSince1970-5)} forKey:@"lessPullPause"];[again restoreLessPullPause];check(again.pausedUntil==nil&&[d dictionaryForKey:@"lessPullPause"]==nil,"an expired pause is cleared at launch");
  t.pausedUntil=[NSDate dateWithTimeIntervalSinceNow:-1];[t sync];check(t.pausedUntil==nil&&fw.gray&&fw.value==1.5,"expiry resumes on the next sync");
  [d removeObjectForKey:@"lessPullPause"];
 }

 // Peek in color: held shortcut shows the plain display, release restores; no
 // saved setting or exception changes. Shortcut rules: a real modifier is required.
 {
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=YES;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=YES;t.policy.automatic=YES;t.automatic=YES;t.selectedMode=100;[d setInteger:100 forKey:@"nightMode"];[d setDouble:1.5 forKey:@"warmth"];t.exclusionRules=[NSMutableDictionary new];
  t.grayOverride=1;t.customWarmth=YES;t.appWarmth=80;t.animateAppearance=YES;[t sync];NSDictionary *before=[d dictionaryRepresentation];
  t.peeking=YES;check(!fw.gray&&fw.value==0&&fw.lastDuration==0.5,"peek shows the plain display with the normal fade");check(t.grayOverride==1&&t.customWarmth,"peek keeps the exception state intact");
  t.peeking=NO;check(fw.gray&&fabs(fw.value-2.4)<1e-9&&fw.lastDuration==0.5,"release returns to the exception appearance");
  t.grayOverride=0;t.customWarmth=NO;t.animateAppearance=YES;[t sync];t.peeking=YES;t.peeking=NO;check(fw.gray&&fw.value==1.5,"release returns to the global appearance");
  check([[d dictionaryRepresentation] isEqualToDictionary:before]&&t.exclusionRules.count==0,"peek changes no saved setting and creates no exception");
  check([PeekShortcut isValidKeyCode:8 modifiers:NSEventModifierFlagCommand|NSEventModifierFlagOption],"command-option shortcut valid");
  check(![PeekShortcut isValidKeyCode:8 modifiers:0]&&![PeekShortcut isValidKeyCode:8 modifiers:NSEventModifierFlagShift],"bare key or shift-only rejected");
  check(![PeekShortcut isValidKeyCode:53 modifiers:NSEventModifierFlagCommand],"escape rejected");
  check([PeekShortcut carbonModifiers:NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift]==(cmdKey|controlKey|optionKey|shiftKey),"carbon modifier mapping");
  check([[PeekShortcut labelForKeyCode:49 modifiers:NSEventModifierFlagControl|NSEventModifierFlagOption] isEqual:@"⌃⌥Space"],"shortcut label order and key name");
 }

 // Update check: version comparison and release parsing only; no network in tests.
 check([UpdateCheck compareVersion:@"1.5.0" to:@"1.4.4"]==NSOrderedDescending&&[UpdateCheck compareVersion:@"1.4.4" to:@"1.4.4"]==NSOrderedSame&&[UpdateCheck compareVersion:@"1.4.10" to:@"1.4.9"]==NSOrderedDescending&&[UpdateCheck compareVersion:@"1.5" to:@"1.5.0"]==NSOrderedSame&&[UpdateCheck compareVersion:@"2" to:@"1.9.9"]==NSOrderedDescending,"numeric version comparison");
 check([[UpdateCheck versionFromTag:@"v1.5.0"] isEqual:@"1.5.0"]&&[[UpdateCheck versionFromTag:@" 1.5.1 "] isEqual:@"1.5.1"]&&[UpdateCheck versionFromTag:@""]==nil&&[UpdateCheck versionFromTag:(id)@[]]==nil,"tag to version");
 NSDictionary *release=@{@"tag_name":@"v1.5.0",@"html_url":@"https://github.com/Archangeloi89/less-pull/releases/tag/v1.5.0",@"body":@"Notes",@"draft":@NO,@"prerelease":@NO};
 NSDictionary *update=[UpdateCheck updateFromRelease:release currentVersion:@"1.4.4"];check([update[@"version"] isEqual:@"1.5.0"]&&[update[@"url"] isEqual:release[@"html_url"]]&&[update[@"notes"] isEqual:@"Notes"],"newer release is offered");
 check([UpdateCheck updateFromRelease:release currentVersion:@"1.5.0"]==nil&&[UpdateCheck updateFromRelease:release currentVersion:@"1.6.0"]==nil,"same or newer app gets no update");
 NSMutableDictionary *pre=[release mutableCopy];pre[@"prerelease"]=@YES;check([UpdateCheck updateFromRelease:pre currentVersion:@"1.4.4"]==nil,"prereleases are ignored");
 NSMutableDictionary *odd=[release mutableCopy];odd[@"html_url"]=@"http://evil.example/";odd[@"body"]=NSNull.null;update=[UpdateCheck updateFromRelease:odd currentVersion:@"1.4.4"];check([update[@"url"] isEqual:@"https://github.com/Archangeloi89/less-pull/releases"]&&[update[@"notes"] isEqual:@""],"non-GitHub link and missing notes fall back safely");
 check([UpdateCheck updateFromRelease:@"garbage" currentVersion:@"1.4.4"]==nil&&[UpdateCheck updateFromRelease:@{} currentVersion:@"1.4.4"]==nil,"malformed release rejected");

 // Build-numbered tags, compatibility metadata and the release asset link.
 check([UpdateCheck buildFromTag:@"v1.4.4-17"]==17&&[UpdateCheck buildFromTag:@"v1.4.4"]==0&&[UpdateCheck buildFromTag:@"v1.4.4-"]==0&&[UpdateCheck buildFromTag:@"v1.4.4-1x"]==0&&[UpdateCheck buildFromTag:(id)@3]==0,"build number from tag");
 NSDictionary *tagged=@{@"tag_name":@"v1.4.4-17",@"html_url":@"https://github.com/Archangeloi89/less-pull/releases/tag/v1.4.4-17",@"body":@"B",@"assets":@[@{@"name":@"lesspull-update.json",@"browser_download_url":@"https://github.com/Archangeloi89/less-pull/releases/download/v1.4.4-17/lesspull-update.json"},@{@"name":@"Less.Pull.zip",@"browser_download_url":@"https://github.com/x"}]};
 update=[UpdateCheck updateFromRelease:tagged currentVersion:@"1.4.4" currentBuild:16];check([update[@"version"] isEqual:@"1.4.4"]&&[update[@"build"] integerValue]==17&&[update[@"metadata"] hasSuffix:@"lesspull-update.json"],"same version with a higher build is an update, with its metadata link");
 check([UpdateCheck updateFromRelease:tagged currentVersion:@"1.4.4" currentBuild:17]==nil&&[UpdateCheck updateFromRelease:tagged currentVersion:@"1.4.4" currentBuild:20]==nil,"same or older build is not an update");
 check([UpdateCheck updateFromRelease:release currentVersion:@"1.4.4" currentBuild:16][@"metadata"]==nil,"untagged release has no metadata link and still compares by version");
 NSOperatingSystemVersion os={27,0,0};
 check([UpdateCheck metadata:@{@"minimumSystemVersion":@"26.0"} allowsSystem:os]&&[UpdateCheck metadata:@{@"minimumSystemVersion":@"27.0"} allowsSystem:os]&&![UpdateCheck metadata:@{@"minimumSystemVersion":@"27.1"} allowsSystem:os],"minimum macOS respected");
 check([UpdateCheck metadata:@{@"maximumSystemVersion":@"27"} allowsSystem:os]&&[UpdateCheck metadata:@{@"maximumSystemVersion":@"27.0"} allowsSystem:os]&&![UpdateCheck metadata:@{@"maximumSystemVersion":@"26"} allowsSystem:os]&&![UpdateCheck metadata:@{@"minimumSystemVersion":@"26",@"maximumSystemVersion":@"26.4"} allowsSystem:os],"maximum macOS respected, major or major.minor");
 check([UpdateCheck metadata:nil allowsSystem:os]&&[UpdateCheck metadata:@"garbage" allowsSystem:os]&&[UpdateCheck metadata:@{} allowsSystem:os]&&[UpdateCheck metadata:@{@"minimumSystemVersion":@3} allowsSystem:os],"missing or malformed metadata does not block");

 // Preferences move from the old bundle identifier once, without overwriting newer keys.
 {
  NSString *oldDomain=@"local.nightshiftfilters.migration-test";NSUserDefaults *fresh=[[NSUserDefaults alloc]initWithSuiteName:@"com.jiriarion.lesspull.migration-test"];[fresh removePersistentDomainForName:@"com.jiriarion.lesspull.migration-test"];
  [fresh setPersistentDomain:@{@"nightMode":@100,@"warmth":@1.5,@"appExclusions":@{@"com.example":@{@"name":@"Example"}}} forName:oldDomain];
  check([PreferenceMigration migrateFromDomain:oldDomain into:fresh]&&[fresh integerForKey:@"nightMode"]==100&&[fresh doubleForKey:@"warmth"]==1.5&&[fresh dictionaryForKey:@"appExclusions"][@"com.example"]!=nil&&[fresh boolForKey:@"migratedPreferences"],"old settings are copied once");
  [fresh setInteger:101 forKey:@"nightMode"];check(![PreferenceMigration migrateFromDomain:oldDomain into:fresh]&&[fresh integerForKey:@"nightMode"]==101,"a second launch does not migrate again");
  NSUserDefaults *empty=[[NSUserDefaults alloc]initWithSuiteName:@"com.jiriarion.lesspull.migration-empty"];[empty removePersistentDomainForName:@"com.jiriarion.lesspull.migration-empty"];check(![PreferenceMigration migrateFromDomain:@"local.nightshiftfilters.nothing-here" into:empty]&&![empty boolForKey:@"migratedPreferences"],"no old settings means a plain first launch");
  [fresh removePersistentDomainForName:oldDomain];[fresh removePersistentDomainForName:@"com.jiriarion.lesspull.migration-test"];[empty removePersistentDomainForName:@"com.jiriarion.lesspull.migration-empty"];
 }

 // Grayscale off for a while, Peek effects, and shortcut suggestions.
 {
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=YES;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=YES;t.policy.automatic=YES;t.automatic=YES;t.selectedMode=100;[d setInteger:100 forKey:@"nightMode"];[d setDouble:1.5 forKey:@"warmth"];t.exclusionRules=[NSMutableDictionary new];[d removeObjectForKey:@"grayscaleOff"];[d removeObjectForKey:@"peekEffects"];
  [t sync];check(fw.gray&&fw.value==1.5,"grayscale on before timed off");
  [t grayscaleOffForMinutes:60];check(!fw.gray&&fw.value==1.5&&fw.lastDuration==0.5&&[d integerForKey:@"nightMode"]==100&&t.selectedMode==100,"grayscale off for an hour shows color, keeps warmth and the saved choice");
  check([[d dictionaryForKey:@"grayscaleOff"][@"until"] doubleValue]>NSDate.date.timeIntervalSince1970+59*60,"timed grayscale off persisted");
  t.grayOverride=1;t.animateAppearance=YES;[t sync];check(fw.gray,"an app exception for grayscale still wins during timed off");t.grayOverride=0;t.animateAppearance=YES;[t sync];
  t.grayOffUntil=[NSDate dateWithTimeIntervalSinceNow:-1];[t sync];check(t.grayOffUntil==nil&&fw.gray&&[d dictionaryForKey:@"grayscaleOff"]==nil,"expiry brings grayscale back");
  [t grayscaleOffForMinutes:0];check(!fw.gray&&[t.grayOffUntil isEqualToDate:NSDate.distantFuture],"off until Night Shift changes");[t sync];check(!fw.gray,"stays off while Night Shift is unchanged");
  fe.on=NO;[t sync];check(t.grayOffUntil==nil&&fw.gray&&fw.value==0,"a Night Shift change ends it and the morning removes warmth as usual");fe.on=YES;[t sync];
  TestApp *again=[TestApp new];again.engine=fe;again.warmth=fw;again.exclusion=[ExclusionPolicy new];again.policy=t.policy;[d setObject:@{@"until":@0} forKey:@"grayscaleOff"];[again restoreGrayscaleOff];check([again.grayOffUntil isEqualToDate:NSDate.distantFuture],"open-ended grayscale off survives relaunch");[d removeObjectForKey:@"grayscaleOff"];
  [t grayscaleBackOn:nil];check(fw.gray&&t.grayOffUntil==nil,"back on now");
  // Peek effects: default grayscale+warmth; Night Shift when chosen.
  t.peeking=YES;check(!fw.gray&&fw.value==0&&fe.on,"peek turns off grayscale and warmth, leaves Night Shift");t.peeking=NO;
  [d setObject:@{@"grayscale":@NO,@"warmth":@YES,@"nightShift":@YES} forKey:@"peekEffects"];t.peeking=YES;[t sync];check(fw.gray&&fw.value==0&&!fe.on,"peek with Night Shift chosen turns it off and keeps grayscale when unticked");
  t.peeking=NO;t.nightOverride=0;t.excludeNight=NO;[t sync];[t sync];check(fe.on&&fw.gray&&fw.value==1.5,"release restores Night Shift and the appearance");[d removeObjectForKey:@"peekEffects"];
  // Suggestions avoid macOS and Less Pull's other shortcut.
  NSDictionary *first=[PeekShortcut suggestionAvoiding:[NSSet set] preferring:@[@{@"keyCode":@8,@"modifiers":@(NSEventModifierFlagControl|NSEventModifierFlagOption)},@{@"keyCode":@9,@"modifiers":@(NSEventModifierFlagControl|NSEventModifierFlagOption)}]];check([first[@"keyCode"] integerValue]==8,"first free candidate is suggested");
  NSDictionary *second=[PeekShortcut suggestionAvoiding:[NSSet setWithObject:[PeekShortcut keyForKeyCode:8 modifiers:NSEventModifierFlagControl|NSEventModifierFlagOption]] preferring:@[@{@"keyCode":@8,@"modifiers":@(NSEventModifierFlagControl|NSEventModifierFlagOption)},@{@"keyCode":@9,@"modifiers":@(NSEventModifierFlagControl|NSEventModifierFlagOption)}]];check([second[@"keyCode"] integerValue]==9,"a taken shortcut is skipped");
  check([PeekShortcut suggestionAvoiding:[NSSet set] preferring:@[@{@"keyCode":@8,@"modifiers":@0}]]==nil,"candidates without a real modifier are never suggested");
  check([[PeekShortcut systemShortcutKeys] isKindOfClass:NSSet.class],"system shortcut list reads without error");
 }

 // Website exception from the menu: the bridge's active tab, whole domain or exact page.
 {
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=YES;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=YES;t.automatic=YES;t.selectedMode=100;t.exclusionRules=[NSMutableDictionary new];
  BrowserBridge *bridge=[BrowserBridge new];bridge.rules=[NSMutableDictionary new];t.browserBridge=bridge;[bridge handle:@{@"type":@"context",@"browser":@"com.brave.Browser",@"session":@"m",@"site":@"example.com",@"url":@"https://example.com/reading?x=1",@"focused":@YES}];
  NSDictionary *tab=[bridge activeContextForBrowser:@"com.brave.Browser"];check([tab[@"site"] isEqual:@"example.com"]&&[bridge activeContextForBrowser:@"com.google.Chrome"]==nil,"active tab known per browser");
  check([[t websiteKeyForTab:tab] isEqual:@"example.com"],"whole domain by default");
  NSMenuItem *off=[NSMenuItem new];off.tag=2;t.lastExternalApp=nil;
  [t storeWebsiteRule:@{@"grayMode":@2} forTab:tab];check([bridge.rules[@"example.com"][@"grayMode"] integerValue]==2&&![bridge.rules[@"example.com"][@"customWarmth"] boolValue],"domain rule saved through the bridge");
  t.websiteScopeExact=YES;check([[t websiteKeyForTab:tab] isEqual:@"https://example.com/reading?x=1"],"exact page key");
  [t storeWebsiteRule:@{@"customWarmth":@YES,@"warmth":@40} forTab:tab];check([bridge.rules[@"https://example.com/reading?x=1"][@"warmth"] doubleValue]==40&&[bridge.rules[@"https://example.com/reading?x=1"][@"grayMode"] integerValue]==0,"page rule saved with its own warmth only");
  NSDictionary *inherited=[bridge inheritedForSite:@"https://example.com/reading?x=1" browser:@"com.brave.Browser"];check([inherited[@"grayMode"] integerValue]==2,"page inherits the domain's grayscale for the menu labels");
  t.websiteScopeExact=NO;bridge.rules=[NSMutableDictionary new];[bridge handle:@{@"type":@"clear",@"browser":@"com.brave.Browser",@"session":@"m"}];(void)off;
 }
 NSUInteger combinations=0;
 for(int follow=0;follow<2;follow++)for(int globalNight=0;globalNight<2;globalNight++)for(int base=100;base<=101;base++)for(int grayRule=0;grayRule<3;grayRule++)for(int nightRule=0;nightRule<3;nightRule++)for(int custom=0;custom<2;custom++)for(NSNumber *percent in @[@0,@25,@77,@100]){
  TestApp *t=[TestApp new];FakeFilter *fe=[FakeFilter new];fe.on=globalNight;fe.state=(NSBlueStatus){.mode=0,.available=YES};FakeWarmth *fw=[FakeWarmth new];t.engine=fe;t.warmth=fw;t.exclusion=[ExclusionPolicy new];t.policy=[SwitchingPolicy new];t.policy.known=YES;t.policy.nightShiftOn=globalNight;t.policy.automatic=follow;t.automatic=follow;t.policy.overrideMode=-1;t.selectedMode=base;[d setInteger:base forKey:@"nightMode"];t.grayOverride=grayRule;t.nightOverride=nightRule;t.excludeNight=nightRule!=0;t.customWarmth=custom;t.appWarmth=percent.doubleValue;t.animateAppearance=YES;
  [t sync];[t sync];NSInteger desired=base;BOOL expectedGray=grayRule?grayRule==1:(desired==1||desired==100);double expectedWarm=custom?percent.doubleValue/100*3:(follow&&!globalNight?0:1.5);
  check(fw.gray==expectedGray&&fabs(fw.value-expectedWarm)<1e-9,"combined gray/night/warmth inheritance");check(fe.on==(nightRule?nightRule==1:globalNight),"combined actual Night Shift");check(t.policy.nightShiftOn==globalNight&&t.policy.overrideMode==-1,"combined follower ignores app-driven on/off");
  t.grayOverride=0;t.nightOverride=0;t.excludeNight=NO;t.customWarmth=NO;t.animateAppearance=YES;[t sync];check(fe.on==globalNight&&!t.exclusion.active,"combined leave restores underlying state");check(fw.gray==(desired==1||desired==100)&&fabs(fw.value-(follow&&!globalNight?0:1.5))<1e-9,"combined leave restores global matrix");check(fe.nativeWrites==0&&[d doubleForKey:@"warmth"]==1.5,"combined preferences/HUD unchanged");combinations++;
 }
 printf("PASS: %lu combined following/global-state/base/grayscale/Night-Shift/warmth cases and restoration.\n",(unsigned long)combinations);
 check(e.nativeWrites==0,"no native filter toggles / HUD requests");
 puts("PASS: website exception from the menu; Grayscale off for a while, Peek effects, shortcut suggestions; preference migration; update check version/build/compatibility parsing; Peek in color (plain display while held, release restores, nothing saved, shortcut rules); Pause Less Pull (plain display, rules ignored, settings kept, relaunch, expiry); inheritance, independent gray/warmth, Night Shift on/off, own versus genuine transitions, manual off, timed-off precedence/expiry, schedule cutoff, recovery, rapid rule switches.");
}}
