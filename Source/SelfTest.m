#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ServiceManagement/ServiceManagement.h>
#import <libproc.h>
#import <mach/mach_time.h>
#import <sys/sysctl.h>
#import "SelfTest.h"
#import "Engine.h"
#import "WarmthEngine.h"
extern BOOL LessPullHandsOff;
static NSMutableString *LPReport;static int LPPassed,LPFailed;
static FilterEngine *LPEngine;static WarmthEngine *LPWarmth;static NSUInteger LPChanges;
typedef struct {BOOL filterOn,nightKnown,strengthKnown;int filterType;NSBlueStatus night;float strength;} LPState;
static LPState LPBefore;static BOOL LPHaveBefore;
static void LPLine(NSString *mark,NSString *text) {
 NSString *line=[NSString stringWithFormat:@"%@%@\n",[mark stringByPaddingToLength:6 withString:@" " startingAtIndex:0],text];
 [LPReport appendString:line];fputs(line.UTF8String,stdout);fflush(stdout);
}
static BOOL LPCheck(BOOL ok,NSString *text) {if(ok)LPPassed++;else LPFailed++;LPLine(ok?@"ok":@"FAIL",text);return ok;}
static void LPNote(NSString *text) {LPLine(@"",text);}
static void LPWait(NSTimeInterval seconds) {[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];}
static NSString *LPSysctl(const char *name) {char value[256]={0};size_t size=sizeof value;return sysctlbyname(name,value,&size,NULL,0)==0?@(value):@"unknown";}
static NSString *LPSchedule(NSBlueStatus n) {return n.mode==1?@"sunset to sunrise":n.mode==2?[NSString stringWithFormat:@"custom %02d:%02d–%02d:%02d",n.schedule.from.hour,n.schedule.from.minute,n.schedule.to.hour,n.schedule.to.minute]:@"off";}
static NSString *LPFilterName(int type) {return type==1?@"Grayscale":type==16?@"Color Tint":type==2?@"Red/Green":type==4?@"Green/Red":type==8?@"Blue/Yellow":[NSString stringWithFormat:@"type %d",type];}
static LPState LPRead(void) {LPState s={0};[LPEngine systemFilterEnabled:&s.filterOn type:&s.filterType];s.nightKnown=[LPEngine readNightShiftStatus:&s.night];s.strengthKnown=[LPEngine nightShiftStrength:&s.strength];return s;}
static NSString *LPDescribe(LPState s) {
 NSString *night=s.nightKnown?[NSString stringWithFormat:@"Night Shift %@ (schedule %@%@)",s.night.enabled?@"on":@"off",LPSchedule(s.night),s.strengthKnown?[NSString stringWithFormat:@", strength %.0f%%",s.strength*100]:@""]:@"Night Shift unreadable";
 return [NSString stringWithFormat:@"%@ · Color Filters %@ (%@)",night,s.filterOn?@"on":@"off",LPFilterName(s.filterType)];
}
static BOOL LPSameSchedule(NSBlueStatus a,NSBlueStatus b) {return a.mode==b.mode&&a.schedule.from.hour==b.schedule.from.hour&&a.schedule.from.minute==b.schedule.from.minute&&a.schedule.to.hour==b.schedule.to.hour&&a.schedule.to.minute==b.schedule.to.minute;}
static BOOL LPSame(LPState a,LPState b) {
 BOOL night=a.nightKnown==b.nightKnown&&(!a.nightKnown||(a.night.enabled==b.night.enabled&&LPSameSchedule(a.night,b.night)));
 return night&&a.filterOn==b.filterOn&&a.filterType==b.filterType&&(!a.strengthKnown||!b.strengthKnown||fabsf(a.strength-b.strength)<.011f);
}
// The macOS Color Filter as it was: its type comes back too when it was off, so System Settings shows the same choice.
static void LPPutFilterBack(void) {
 BOOL on=NO;int type=0;[LPEngine systemFilterEnabled:&on type:&type];
 if(!LPBefore.filterOn&&type!=LPBefore.filterType)[LPEngine setSystemFilterEnabled:YES type:LPBefore.filterType];
 [LPEngine setSystemFilterEnabled:LPBefore.filterOn type:LPBefore.filterType];
}
static void LPPutNightBack(void) {
 if(!LPBefore.nightKnown)return;NSBlueStatus n=LPBefore.night;
 [LPEngine setNightShiftScheduleFrom:n.schedule.from.hour*60+n.schedule.from.minute to:n.schedule.to.hour*60+n.schedule.to.minute];[LPEngine setNightShiftScheduleMode:n.mode];
 LPWait(.4);[LPEngine setNightShiftEnabled:n.enabled];  // a schedule change can switch Night Shift by itself
 if(LPBefore.strengthKnown)[LPEngine setNightShiftStrength:LPBefore.strength];
}
static void LPPutBack(void) {[LPWarmth restore];if(!LPHaveBefore)return;LPPutFilterBack();LPPutNightBack();}
static NSArray<NSRunningApplication *> *LPOthers(void) {
 NSMutableArray *others=[NSMutableArray new];
 for(NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.jiriarion.lesspull"])if(app.processIdentifier!=getpid()&&!app.terminated)[others addObject:app];
 return others;
}
static NSString *LPDisplayName(uint32_t display,int index) {
 NSString *name=nil;for(NSScreen *s in NSScreen.screens)if([s.deviceDescription[@"NSScreenNumber"] unsignedIntValue]==display)name=s.localizedName;
 return [NSString stringWithFormat:@"Display %d (%@, %@)",index,name?:@"no name",CGDisplayIsBuiltin(display)?@"built-in":@"external"];
}
static NSArray<NSString *> *LPGraphics(void) {
 NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/sbin/system_profiler"];task.arguments=@[@"SPDisplaysDataType",@"-json"];
 NSPipe *pipe=[NSPipe pipe];task.standardOutput=pipe;task.standardError=NSFileHandle.fileHandleWithNullDevice;if(![task launchAndReturnError:nil])return @[];
 NSData *data=[pipe.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];
 id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];NSMutableArray *names=[NSMutableArray new];
 id list=[json isKindOfClass:NSDictionary.class]?json[@"SPDisplaysDataType"]:nil;
 if([list isKindOfClass:NSArray.class])for(id gpu in list)if([gpu isKindOfClass:NSDictionary.class]&&[gpu[@"sppci_model"] isKindOfClass:NSString.class])[names addObject:gpu[@"sppci_model"]];
 return names;
}
static BOOL LPRunsHere(NSBundle *bundle) {
 if(!bundle)return NO;
#if defined(__x86_64__)
 NSNumber *mine=@(NSBundleExecutableArchitectureX86_64);
#else
 NSNumber *mine=@(NSBundleExecutableArchitectureARM64);
#endif
 NSArray *parts=[bundle.infoDictionary[@"LSMinimumSystemVersion"] componentsSeparatedByString:@"."];
 NSOperatingSystemVersion need={parts.count>0?[parts[0] integerValue]:99,parts.count>1?[parts[1] integerValue]:0,parts.count>2?[parts[2] integerValue]:0};
 return [bundle.executableArchitectures containsObject:mine]&&[NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:need];
}
// One half-second fade from the current look to plain, as the app fades: on the display's refresh clock, or on a
// timer for all displays at once. Returns how long it took, or -1 if it did not finish or finished at once.
static double LPFade(uint32_t display) {
 __block BOOL done=NO;NSTimeInterval start=NSProcessInfo.processInfo.systemUptime;
 if(display)[LPWarmth transitionStrength:0 grayscale:NO display:display reduceMotion:NO duration:.5 completion:^{done=YES;}];
 else [LPWarmth transitionStrength:0 grayscale:NO reduceMotion:NO duration:.5 completion:^{done=YES;}];
 while(!done&&NSProcessInfo.processInfo.systemUptime-start<3)LPWait(.02);
 double took=NSProcessInfo.processInfo.systemUptime-start;return done&&took>=.4&&took<2&&!LPWarmth.error?took:-1;
}
static double LPCPUSeconds(pid_t pid) {
 struct rusage_info_v2 info;if(proc_pid_rusage(pid,RUSAGE_INFO_V2,(rusage_info_t *)&info)!=0)return -1;
 // The times count the hardware clock: 1 GHz on Intel, 24 MHz on Apple silicon. Under Rosetta the emulated timebase
 // claims 1 GHz while the ticks stay native, so the clock's own frequency is the one to divide by.
 uint64_t frequency=0;size_t size=sizeof frequency;if(sysctlbyname("hw.tbfrequency",&frequency,&size,NULL,0)!=0||!frequency){mach_timebase_info_data_t base;mach_timebase_info(&base);return (double)(info.ri_user_time+info.ri_system_time)*base.numer/base.denom/1e9;}
 return (double)(info.ri_user_time+info.ri_system_time)/frequency;
}
int LessPullSelfTest(void) {
 LessPullHandsOff=NO;LPReport=[NSMutableString new];[NSApplication sharedApplication];
 NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],*build=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
 NSDateFormatter *when=[NSDateFormatter new];when.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];when.dateFormat=@"yyyy-MM-dd HH:mm";
 LPNote([NSString stringWithFormat:@"Less Pull self-test · Less Pull %@ (build %@) · %@",version,build,[when stringFromDate:NSDate.date]]);
 uint64_t memory=0;size_t size=sizeof memory;sysctlbyname("hw.memsize",&memory,&size,NULL,0);
 LPNote([NSString stringWithFormat:@"Mac: %@ · %@ · %llu GB memory",LPSysctl("hw.model"),LPSysctl("machdep.cpu.brand_string"),memory>>30]);
 LPNote([NSString stringWithFormat:@"macOS %@ · %@",NSProcessInfo.processInfo.operatingSystemVersionString,LessPullProcessor()]);
 NSArray *graphics=LPGraphics();if(graphics.count)LPNote([NSString stringWithFormat:@"Graphics: %@",[graphics componentsJoinedByString:@" · "]]);
 uint32_t count=0;CGDirectDisplayID ids[32];CGGetActiveDisplayList(32,ids,&count);
 for(uint32_t i=0;i<count;i++){NSInteger hz=0;for(NSScreen *s in NSScreen.screens)if([s.deviceDescription[@"NSScreenNumber"] unsignedIntValue]==ids[i])hz=s.maximumFramesPerSecond;
  LPNote([NSString stringWithFormat:@"%@: %zu×%zu pixels, %ld Hz",LPDisplayName(ids[i],i+1),CGDisplayPixelsWide(ids[i]),CGDisplayPixelsHigh(ids[i]),(long)hz]);}
 // A running Less Pull paints the screen too: it steps aside for the test, putting its own look away first.
 // Before that, how much it does at rest, while nobody touches it.
 NSURL *relaunch=LPOthers().firstObject.bundleURL;
 if(relaunch){pid_t pid=LPOthers().firstObject.processIdentifier;LPNote(@"Less Pull is running. Measuring it at rest for 10 seconds, please leave the Mac alone…");
  double t0=LPCPUSeconds(pid);LPWait(10);double t1=LPCPUSeconds(pid);if(t0>=0&&t1>=t0)LPNote([NSString stringWithFormat:@"Less Pull at rest: %.2f%% of one processor core",(t1-t0)/10*100]);}
 for(NSRunningApplication *app in LPOthers())[app terminate];
 if(relaunch){NSDate *until=[NSDate dateWithTimeIntervalSinceNow:8];while(LPOthers().count&&until.timeIntervalSinceNow>0)LPWait(.2);
  if(LPOthers().count){LPCheck(NO,@"Less Pull did not quit for the test. Quit it from its menu, then run the test again.");return 1;}
  LPNote(@"Less Pull was running. It is quit for the test and starts again at the end.");LPWait(.6);}
 LPEngine=[FilterEngine new];LPWarmth=[WarmthEngine new];LPEngine.changed=^{LPChanges++;};
 LPBefore=LPRead();LPHaveBefore=YES;LPNote([NSString stringWithFormat:@"Before the test: %@",LPDescribe(LPBefore)]);
 // Stopped early (Control-C, a closed Terminal window): everything goes back first.
 static NSMutableArray *sources;sources=[NSMutableArray new];
 for(NSNumber *sig in @[@(SIGINT),@(SIGTERM),@(SIGHUP)]){signal(sig.intValue,SIG_IGN);dispatch_source_t source=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,sig.intValue,0,dispatch_get_main_queue());
  dispatch_source_set_event_handler(source,^{LPNote(@"Stopped early. Putting everything back.");LPPutBack();exit(130);});dispatch_resume(source);[sources addObject:source];}
 LPNote(@"");LPNote(@"The screen turns gray and warm for a few seconds, and Night Shift switches. Everything is put back at the end.");LPWait(2);

 LPNote(@"");LPNote(@"Programs");
 NSArray *archs=NSBundle.mainBundle.executableArchitectures;
 LPCheck([archs containsObject:@(NSBundleExecutableArchitectureX86_64)]&&[archs containsObject:@(NSBundleExecutableArchitectureARM64)],@"Less Pull holds Intel and Apple silicon code");
 {NSTask *helper=[NSTask new];helper.executableURL=[NSURL fileURLWithPath:@"/usr/bin/arch"];
#if defined(__x86_64__)
  NSString *mine=@"-x86_64";
#else
  NSString *mine=@"-arm64";
#endif
  helper.arguments=@[mine,[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/MacOS/LessPullBrowserHost"]];NSPipe *err=[NSPipe pipe];
  helper.standardInput=helper.standardOutput=NSFileHandle.fileHandleWithNullDevice;helper.standardError=err;BOOL started=[helper launchAndReturnError:nil];
  NSData *said=started?[err.fileHandleForReading readDataToEndOfFile]:nil;if(started)[helper waitUntilExit];
  LPCheck(started&&helper.terminationStatus==1&&!said.length,@"Browser helper starts on this processor (Chrome, Brave, Edge, Opera, Firefox)");}  // without arguments it ends at once with 1
 NSBundle *safari=[NSBundle bundleWithURL:[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Less Pull for Safari.app"]];
 if(!safari)LPNote(@"This build has no Safari companion.");
 else {NSBundle *extension=[NSBundle bundleWithURL:[safari.builtInPlugInsURL URLByAppendingPathComponent:@"Less Pull for Safari Extension.appex"]];
  LPCheck(LPRunsHere(safari)&&LPRunsHere(extension),[NSString stringWithFormat:@"Safari companion and its extension run here (they need macOS %@)",safari.infoDictionary[@"LSMinimumSystemVersion"]?:@"?"]);}

 LPNote(@"");LPNote(@"Screen");
 LPCheck(!LPWarmth.error,LPWarmth.error?:@"Screen matrix interface found");
 LPWarmth.perDisplay=YES;NSArray *displays=[LPWarmth displays];
 if(![displays.firstObject unsignedIntValue])LPNote(@"This macOS has no per-display matrices, so one matrix covers every display.");
 int index=0;for(NSNumber *dn in displays){uint32_t d=dn.unsignedIntValue;if(!d)break;NSString *name=LPDisplayName(d,++index);
  LPNote([NSString stringWithFormat:@"Watch %@: gray, warm gray, warm color, then plain again.",name]);
  LPCheck([LPWarmth applyStrength:0 grayscale:YES display:d],[NSString stringWithFormat:@"%@: Grayscale",name]);LPWait(.9);
  LPCheck([LPWarmth applyStrength:1.5 grayscale:YES display:d],[NSString stringWithFormat:@"%@: Grayscale with Extra Warmth 50%%",name]);LPWait(.9);
  LPCheck([LPWarmth applyStrength:1.5 grayscale:NO display:d],[NSString stringWithFormat:@"%@: Extra Warmth 50%% in color",name]);LPWait(.9);
  double took=LPFade(d);LPCheck(took>0,took>0?[NSString stringWithFormat:@"%@: half-second fade on the display's own clock (%.2f s)",name,took]:[NSString stringWithFormat:@"%@: the fade did not run (%@)",name,LPWarmth.error?:@"no end"]);
  LPWait(.4);}
 LPWarmth.perDisplay=NO;LPNote(@"Watch every display: warm gray, then plain again.");
 LPCheck([LPWarmth applyStrength:1.5 grayscale:YES],@"All displays at once: Grayscale with Extra Warmth");LPWait(.9);
 {double took=LPFade(0);LPCheck(took>0,took>0?[NSString stringWithFormat:@"All displays at once: half-second fade (%.2f s)",took]:[NSString stringWithFormat:@"All displays at once: the fade did not run (%@)",LPWarmth.error?:@"no end"]);}
 LPCheck([LPWarmth restore],@"Screen back to its own colors");

 LPNote(@"");LPNote(@"Lock screen (the macOS Color Filter)");
 {LPChanges=0;BOOL want=!(LPBefore.filterOn&&LPBefore.filterType==1),on=NO;int type=0;
  BOOL set=[LPEngine setSystemFilterEnabled:want type:1];LPWait(.8);[LPEngine systemFilterEnabled:&on type:&type];
  LPCheck(set&&on==want&&(!want||type==1),[NSString stringWithFormat:@"Color Filter Grayscale switches %@ (Less Pull uses it on the lock screen)",want?@"on":@"off"]);
  LPPutFilterBack();LPWait(.6);[LPEngine systemFilterEnabled:&on type:&type];
  LPCheck(on==LPBefore.filterOn&&type==LPBefore.filterType,[NSString stringWithFormat:@"Color Filter back as it was (%@, %@)",on?@"on":@"off",LPFilterName(type)]);
  LPCheck(LPChanges>0,@"Less Pull hears Color Filter changes");}

 LPNote(@"");LPNote(@"Night Shift");
 LPCheck(!LPEngine.error,LPEngine.error?:@"Night Shift and Color Filter interfaces recognized");
 if(!LPEngine.error){NSBlueStatus s0={0},s1={0};
  LPCheck([LPEngine readNightShiftStatus:&s0],[NSString stringWithFormat:@"Night Shift reads: %@, schedule %@",s0.enabled?@"on":@"off",LPSchedule(s0)]);
  float st0=0,st1=-1;if([LPEngine nightShiftStrength:&st0]){float target=st0>.5f?.25f:.75f;BOOL set=[LPEngine setNightShiftStrength:target period:.25];LPWait(.7);[LPEngine nightShiftStrength:&st1];
   LPCheck(set&&fabsf(st1-target)<.011f,[NSString stringWithFormat:@"Strength %.0f%% to %.0f%% with a quarter-second change (Less Pull does this at the lock screen)",st0*100,st1*100]);
   [LPEngine setNightShiftStrength:st0];LPWait(.4);[LPEngine nightShiftStrength:&st1];LPCheck(fabsf(st1-st0)<.011f,[NSString stringWithFormat:@"Strength back at %.0f%%",st1*100]);}
  else LPCheck(NO,@"Night Shift strength cannot be read");
  LPChanges=0;BOOL e0=s0.enabled;LPNote(e0?@"Watch the screen: Night Shift goes off for a moment.":@"Watch the screen: Night Shift comes on for a moment.");
  BOOL set=[LPEngine setNightShiftEnabled:!e0];LPWait(1.6);[LPEngine readNightShiftStatus:&s1];LPCheck(set&&s1.enabled==!e0,[NSString stringWithFormat:@"Night Shift switches %@",e0?@"off":@"on"]);
  set=[LPEngine setNightShiftEnabled:e0];LPWait(1.6);[LPEngine readNightShiftStatus:&s1];LPCheck(set&&s1.enabled==e0,[NSString stringWithFormat:@"Night Shift switches %@ again",e0?@"on":@"off"]);
  LPCheck(LPChanges>0,@"Less Pull hears Night Shift changes");
  BOOL a=[LPEngine setNightShiftScheduleFrom:21*60 to:6*60+30],b=[LPEngine setNightShiftScheduleMode:2];LPWait(.6);[LPEngine readNightShiftStatus:&s1];
  LPCheck(a&&b&&s1.mode==2&&s1.schedule.from.hour==21&&s1.schedule.from.minute==0&&s1.schedule.to.hour==6&&s1.schedule.to.minute==30,@"Schedule written: custom 21:00–06:30 (Automatic with your own hours does this)");
  LPPutNightBack();LPWait(.6);[LPEngine readNightShiftStatus:&s1];LPCheck(LPSameSchedule(s0,s1)&&s1.enabled==e0,[NSString stringWithFormat:@"Schedule back to %@, Night Shift %@",LPSchedule(s1),s1.enabled?@"on":@"off"]);
  LPNote(s0.sunSchedulePermitted?@"macOS allows sunset to sunrise here.":@"macOS does not allow sunset to sunrise yet (Location Services or Set time zone automatically is off); Less Pull works out sunset itself then.");}

 LPNote(@"");LPNote(@"The rest");
 {NSArray *sounds=[NSBundle.mainBundle pathsForResourcesOfType:@"wav" inDirectory:nil];NSUInteger loaded=0;for(NSString *p in sounds)if([[NSSound alloc] initWithContentsOfFile:p byReference:YES])loaded++;
  LPCheck(sounds.count>=6&&loaded==sounds.count,[NSString stringWithFormat:@"Session sounds load (%lu of %lu)",(unsigned long)loaded,(unsigned long)sounds.count]);}
 {NSUInteger languages=0;for(NSString *p in [NSBundle.mainBundle pathsForResourcesOfType:@"lproj" inDirectory:nil])if([NSFileManager.defaultManager fileExistsAtPath:[p stringByAppendingPathComponent:@"Localizable.strings"]])languages++;
  LPCheck(languages>=13,[NSString stringWithFormat:@"Languages: English and %lu more",(unsigned long)languages]);}
 {EventHotKeyRef ref=NULL;EventHotKeyID hotKey={'LPst',1};OSStatus status=RegisterEventHotKey(kVK_F19,cmdKey|optionKey|controlKey|shiftKey,hotKey,GetApplicationEventTarget(),0,&ref);if(ref)UnregisterEventHotKey(ref);
  LPCheck(status==noErr||status==eventHotKeyExistsErr,@"Keyboard shortcuts can be registered (Peek, Toggle Grayscale)");}
 {SMAppServiceStatus login=SMAppService.mainAppService.status;LPNote([NSString stringWithFormat:@"Launch at login: %@",login==SMAppServiceStatusEnabled?@"on":login==SMAppServiceStatusRequiresApproval?@"waiting for approval in System Settings":@"off"]);}

 LPNote(@"");LPPutBack();LPWait(.8);LPState after=LPRead();
 LPCheck(LPSame(LPBefore,after),[NSString stringWithFormat:@"Everything is as before: %@",LPDescribe(after)]);
 // Less Pull opens only once (a second copy quits at launch), and this test counts as one: it reopens after the test has ended.
 if(relaunch){NSTask *reopen=[NSTask new];reopen.executableURL=[NSURL fileURLWithPath:@"/bin/sh"];reopen.arguments=@[@"-c",@"trap '' HUP; while kill -0 \"$1\" 2>/dev/null; do sleep .2; done; exec /usr/bin/open -g \"$0\"",relaunch.path,@(getpid()).stringValue];
  reopen.standardInput=reopen.standardOutput=reopen.standardError=NSFileHandle.fileHandleWithNullDevice;if([reopen launchAndReturnError:nil])LPNote(@"Less Pull opens again in a moment.");}
 LPNote(@"");LPNote(LPFailed?[NSString stringWithFormat:@"%d of %d checks failed. Please send this report.",LPFailed,LPPassed+LPFailed]:[NSString stringWithFormat:@"All %d checks passed.",LPPassed]);
 when.dateFormat=@"yyyy-MM-dd HHmm";NSString *desktop=NSSearchPathForDirectoriesInDomains(NSDesktopDirectory,NSUserDomainMask,YES).firstObject;
 NSString *path=[desktop stringByAppendingPathComponent:[NSString stringWithFormat:@"Less Pull self-test %@.txt",[when stringFromDate:NSDate.date]]];
 if([LPReport writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil])printf("\nSaved on the Desktop: %s\n",path.lastPathComponent.UTF8String);
 return LPFailed?1:0;
}
