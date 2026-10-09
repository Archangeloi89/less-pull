#import "Engine.h"
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CoreGraphics/CoreGraphics.h>
static long (*getType)(long);
static BOOL (*getEnabled)(long);
static void (*setType)(long,long);
static void (*setEnabled)(long,BOOL);
static double (*getHue)(void), (*getIntensity)(void);
static void filterPreferencesChanged(CFNotificationCenterRef center,void *observer,CFStringRef name,const void *object,CFDictionaryRef info) {
 __weak FilterEngine *engine=(__bridge FilterEngine *)observer;
 dispatch_async(dispatch_get_main_queue(),^{if(engine.changed)engine.changed();});
}
@implementation FilterEngine
- (instancetype)init {
 if((self=[super init])) {
  void *ma=dlopen("/System/Library/Frameworks/MediaAccessibility.framework/MediaAccessibility",RTLD_NOW);
  getType=dlsym(ma,"MADisplayFilterPrefGetType"); getEnabled=dlsym(ma,"MADisplayFilterPrefGetCategoryEnabled");
  setType=dlsym(ma,"MADisplayFilterPrefSetType"); setEnabled=dlsym(ma,"MADisplayFilterPrefSetCategoryEnabled");
  CFStringRef *filterNotification=dlsym(ma,"kMADisplayFilterSettingsChangedNotification");
  if(filterNotification&&*filterNotification)CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge void *)self,filterPreferencesChanged,*filterNotification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
  getHue=dlsym(ma,"MADisplayFilterPrefGetSingleColorHue"); getIntensity=dlsym(ma,"MADisplayFilterPrefGetSingleColorIntensity");
  dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",RTLD_NOW);
  Class c=NSClassFromString(@"CBBlueLightClient");
  Method method=class_getInstanceMethod(c,@selector(getBlueLightStatus:));
  const char *encoding=method ? method_getTypeEncoding(method) : "";
  if(!getType||!getEnabled||!setType||!setEnabled||!getHue||!getIntensity) self.error=@"Color Filters API unavailable. No settings were changed.";
  else if(strcmp(encoding,"B24@0:8^{?=BBBi{?={?=ii}{?=ii}}QB}16")!=0) self.error=@"Night Shift API layout is unsupported. Automatic switching is unavailable.";
  else {
   self.client=[[c alloc] init];
   if(![self.client respondsToSelector:@selector(supported)]||![self.client supported])self.error=@"Night Shift is unsupported on this Mac/display.";
   if([self.client respondsToSelector:@selector(setStatusNotificationBlock:)]) {
    __weak FilterEngine *weak=self;
    [self.client setStatusNotificationBlock:^{ dispatch_async(dispatch_get_main_queue(),^{ if(weak.changed)weak.changed(); }); }];
   }
  }
 }
 return self;
}
- (void)dealloc {CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),(__bridge void *)self);}
- (BOOL)nightShift:(BOOL *)enabled {
 if(!self.client||self.error)return NO;
 NSBlueStatus status={0};
 if(![self.client getBlueLightStatus:&status])return NO;
 if(!status.available)return NO;
 // enabled is actual current Night Shift state; mode is only the schedule policy.
 *enabled=status.enabled && status.disableFlags==0;
 return YES;
}
- (BOOL)readNightShiftStatus:(NSBlueStatus *)status {return self.client&&!self.error&&[self.client getBlueLightStatus:status]&&status->available;}
__attribute__((weak)) BOOL LessPullHandsOff=NO;
- (BOOL)setNightShiftEnabled:(BOOL)enabled {
 if(LessPullHandsOff)return YES;
 if(!self.client||self.error)return NO;
 Method method=class_getInstanceMethod([self.client class],@selector(setEnabled:));
 if(!method||strcmp(method_getTypeEncoding(method),"B20@0:8B16")!=0)return NO;
 return [self.client setEnabled:enabled];
}
- (NSInteger)currentMode { if(!getType||!getEnabled)return -1;return getEnabled(1)?getType(1):0; }
- (BOOL)applyMode:(NSInteger)mode {
 if(LessPullHandsOff)return YES;
 if(!getType||!getEnabled||!setType||!setEnabled||!getHue||!getIntensity)return NO;
 if(mode!=0&&mode!=1&&mode!=16)return NO;
 double hue=getHue(),intensity=getIntensity();
 if(mode==0){ if(getEnabled(1))setEnabled(1,NO); }
 else { if(getType(1)!=mode)setType(1,mode); if(!getEnabled(1))setEnabled(1,YES); }
 BOOL preserved=(hue==getHue()&&intensity==getIntensity());
 return preserved && [self currentMode]==mode;
}
- (NSString *)diagnostics {
 NSBlueStatus s={0}; BOOL ok=self.client&&[self.client getBlueLightStatus:&s];
 NSMutableString *displayInfo=[NSMutableString new];CGDirectDisplayID displays[32];uint32_t count=0;CGError displayError=CGGetOnlineDisplayList(32,displays,&count);
 [displayInfo appendFormat:@"Online display query=%d; count=%u\n",displayError,count];
 for(uint32_t i=0;i<count;i++)[displayInfo appendFormat:@"Display %u: %@, vendor=%u model=%u, %zu×%zu pixels\n",displays[i],CGDisplayIsBuiltin(displays[i])?@"built-in":@"external",CGDisplayVendorNumber(displays[i]),CGDisplayModelNumber(displays[i]),CGDisplayPixelsWide(displays[i]),CGDisplayPixelsHigh(displays[i])];
 return [NSString stringWithFormat:@"Night Shift read: %@; active=%d enabled=%d available=%d disableFlags=%llu mode=%d\nFilter mode=%ld; saved tint hue=%.6f intensity=%.6f\n%@\n%@",ok?@"OK":@"failed",s.active,s.enabled,s.available,s.disableFlags,s.mode,(long)[self currentMode],getHue?getHue():-1,getIntensity?getIntensity():-1,displayInfo,self.error?:@""];
}
@end
