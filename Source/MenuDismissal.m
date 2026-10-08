#import "MenuDismissal.h"
@implementation MenuDismissal
+ (BOOL)shouldDismissPoint:(NSPoint)point menuFrames:(NSArray<NSValue *> *)frames {for(NSValue *value in frames)if(NSPointInRect(point,value.rectValue))return NO;return YES;}
- (void)begin:(NSMenu *)menu {
 [self end];self.menu=menu;__weak MenuDismissal *weak=self;
 self.globalMonitor=[NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^(NSEvent *event){[weak cancel];}];
 self.localMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event){MenuDismissal *owner=weak;if(!owner.menu)return event;NSMutableArray *frames=[NSMutableArray new];for(NSMenuItem *item in owner.menu.itemArray){NSWindow *window=item.view.window;if(window.visible)[frames addObject:[NSValue valueWithRect:window.frame]];}
  // Include attached submenus using their public popup-window level, so choosing
  // a timed pause/help item is not mistaken for a click outside the root menu.
  for(NSWindow *window in NSApp.windows)if(window.visible&&window.level==NSPopUpMenuWindowLevel)[frames addObject:[NSValue valueWithRect:window.frame]];
  if([MenuDismissal shouldDismissPoint:NSEvent.mouseLocation menuFrames:frames])[owner cancel];return event;}];
}
- (void)cancel {NSMenu *menu=self.menu;[self end];[menu cancelTracking];}
- (void)end {if(self.localMonitor)[NSEvent removeMonitor:self.localMonitor];if(self.globalMonitor)[NSEvent removeMonitor:self.globalMonitor];self.localMonitor=nil;self.globalMonitor=nil;self.menu=nil;}
- (void)dealloc {[self end];}
@end
