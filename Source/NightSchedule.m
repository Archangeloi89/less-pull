#import "NightSchedule.h"
#include <math.h>
double LPNightFactor(NSInteger m, NSInteger start, NSInteger end, double ramp) {
 NSInteger length=((end-start)%1440+1440)%1440;if(length==0)return 0;
 double into=(double)(((m-start)%1440+1440)%1440);if(into>=length)return 0;
 double left=length-into;ramp=fmin(fmax(ramp,0),length/2.0);if(ramp<=0)return 1;
 return fmin(1,fmin(into/ramp,left/ramp));
}
BOOL LPSunTimes(NSDate *day, double lat, double lon, NSTimeZone *zone, NSInteger *sunset, NSInteger *sunrise) {
 NSCalendar *cal=[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];cal.timeZone=zone;
 NSInteger n=[cal ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:day];
 double g=2*M_PI/365*(n-1+.5);
 double eq=229.18*(.000075+.001868*cos(g)-.032077*sin(g)-.014615*cos(2*g)-.040849*sin(2*g));
 double decl=.006918-.399912*cos(g)+.070257*sin(g)-.006758*cos(2*g)+.000907*sin(2*g)-.002697*cos(3*g)+.00148*sin(3*g);
 double phi=lat*M_PI/180,c=cos(90.833*M_PI/180)/(cos(phi)*cos(decl))-tan(phi)*tan(decl);
 if(c<-1||c>1)return NO;
 double ha=acos(c)*180/M_PI,offset=[zone secondsFromGMTForDate:day]/60.0;
 double noon=720-4*lon-eq+offset;
 *sunrise=((NSInteger)lround(noon-4*ha)%1440+1440)%1440;*sunset=((NSInteger)lround(noon+4*ha)%1440+1440)%1440;return YES;
}
static double LPCoord(NSString *s,int degDigits) { // +DDMM or +DDMMSS, longitude with one more degree digit
 double sign=[s hasPrefix:@"-"]?-1:1;NSString *d=[s substringFromIndex:1];if(d.length<(NSUInteger)degDigits+2)return NAN;
 double v=[[d substringToIndex:degDigits] doubleValue]+[[d substringWithRange:NSMakeRange(degDigits,2)] doubleValue]/60;
 if(d.length>=(NSUInteger)degDigits+4)v+=[[d substringWithRange:NSMakeRange(degDigits+2,2)] doubleValue]/3600;return sign*v;
}
BOOL LPZoneCoordinates(NSString *name, double *lat, double *lon) {
 NSString *tab=[NSString stringWithContentsOfFile:@"/usr/share/zoneinfo/zone.tab" encoding:NSUTF8StringEncoding error:nil];if(!tab||!name)return NO;
 for(NSString *line in [tab componentsSeparatedByString:@"\n"]){if([line hasPrefix:@"#"])continue;NSArray *f=[line componentsSeparatedByString:@"\t"];if(f.count<3||![f[2] isEqualToString:name])continue;
  NSString *c=f[1];NSUInteger split=[c rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] options:0 range:NSMakeRange(1,c.length-1)].location;if(split==NSNotFound)return NO;
  double a=LPCoord([c substringToIndex:split],2),b=LPCoord([c substringFromIndex:split],3);if(isnan(a)||isnan(b))return NO;*lat=a;*lon=b;return YES;}
 return NO;
}
