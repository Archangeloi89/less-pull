#import "NightSchedule.h"
#define CHECK(x) do{if(!(x)){fprintf(stderr,"FAIL %s:%d %s\n",__FILE__,__LINE__,#x);return 1;}}while(0)
int main(void){@autoreleasepool{
 // 22:00-07:00 with a 30-minute ramp
 CHECK(LPNightFactor(12*60,1320,420,30)==0);CHECK(LPNightFactor(1320,1320,420,30)==0);CHECK(fabs(LPNightFactor(1335,1320,420,30)-.5)<1e-9);
 CHECK(LPNightFactor(1380,1320,420,30)==1);CHECK(LPNightFactor(0,1320,420,30)==1);CHECK(LPNightFactor(405,1320,420,30)==.5);CHECK(LPNightFactor(420,1320,420,30)==0);
 // a night inside one day, no ramp, and an empty window
 CHECK(LPNightFactor(150,60,300,0)==1);CHECK(LPNightFactor(30,60,300,0)==0);CHECK(LPNightFactor(500,600,600,30)==0);
 // Berlin: zone.tab coordinates and plausible sun times on 21 June and 21 December 2026
 double lat=0,lon=0;CHECK(LPZoneCoordinates(@"Europe/Berlin",&lat,&lon));CHECK(fabs(lat-52.5)<.1&&fabs(lon-13.37)<.1);
 NSTimeZone *z=[NSTimeZone timeZoneWithName:@"Europe/Berlin"];NSDateFormatter *f=[NSDateFormatter new];f.dateFormat=@"yyyy-MM-dd HH:mm";f.timeZone=z;
 NSInteger set=0,rise=0;CHECK(LPSunTimes([f dateFromString:@"2026-06-21 12:00"],lat,lon,z,&set,&rise));CHECK(labs(set-(21*60+33))<=8&&labs(rise-(4*60+43))<=8);
 CHECK(LPSunTimes([f dateFromString:@"2026-12-21 12:00"],lat,lon,z,&set,&rise));CHECK(labs(set-(15*60+54))<=8&&labs(rise-(8*60+15))<=8);
 // polar day in Longyearbyen
 NSTimeZone *a=[NSTimeZone timeZoneWithName:@"Arctic/Longyearbyen"];CHECK(!LPSunTimes([f dateFromString:@"2026-06-21 12:00"],78.2,15.6,a,&set,&rise));
 CHECK(!LPZoneCoordinates(@"Nowhere/Nothing",&lat,&lon));
 // the night points field, in several languages
 CHECK(LPParseNightPoints(@"12",@"Rot",@"Aus")==12);CHECK(LPParseNightPoints(@"+12 Punkte",@"Rot",@"Aus")==12);CHECK(LPParseNightPoints(@" 21 ",@"Rot",@"Aus")==21);
 CHECK(LPParseNightPoints(@"rot",@"Rot",@"Aus")==100);CHECK(LPParseNightPoints(@"Red",@"Rot",@"Aus")==100);CHECK(LPParseNightPoints(@"aus",@"Rot",@"Aus")==0);CHECK(LPParseNightPoints(@"0",@"Rot",@"Aus")==0);
 CHECK(LPParseNightPoints(@"150",@"Rot",@"Aus")==100);CHECK(LPParseNightPoints(@"hallo",@"Rot",@"Aus")==-1);CHECK(LPParseNightPoints(@"",@"Rot",@"Aus")==-1);
 CHECK(LPParseNightPoints(@"１２",@"赤",@"オフ")==12);CHECK(LPParseNightPoints(@"+12 ポイント",@"赤",@"オフ")==12);CHECK(LPParseNightPoints(@"赤",@"赤",@"オフ")==100);
 CHECK(LPParseNightPoints(@"红色",@"红色",@"关")==100);CHECK(LPParseNightPoints(@"+13 пунктов",@"Красный",@"Выкл.")==13);CHECK(LPParseNightPoints(@"красный",@"Красный",@"Выкл.")==100);
 CHECK(LPParseNightPoints(@"١٢",@"Red",@"Off")==12);
 printf("PASS: night window with ramps across midnight, zone.tab coordinates, sunset and sunrise in Berlin in June and December, polar day; night points typed as 12, +12 Punkte, １２, Rot, 赤, красный or Arabic digits.\n");}return 0;}
