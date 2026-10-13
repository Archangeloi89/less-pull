#import <Foundation/Foundation.h>
// "Warmer at night": when the night is, without asking for a location.
// Times are minutes after midnight in the local time zone.
// How far into the night a moment is: 0 by day, 1 at night, rising over `ramp` minutes after the start
// and falling over `ramp` minutes before the end. Works for nights that cross midnight.
double LPNightFactor(NSInteger minuteOfDay, NSInteger start, NSInteger end, double ramp);
// Sunset and sunrise for a date at a place (NOAA approximation, about a minute off). NO in polar day or night.
BOOL LPSunTimes(NSDate *day, double latitude, double longitude, NSTimeZone *zone, NSInteger *sunset, NSInteger *sunrise);
// The coordinates macOS keeps for a time zone's main city (zone.tab). NO if the zone is not listed.
BOOL LPZoneCoordinates(NSString *zoneName, double *latitude, double *longitude);
// What someone typed into the night points field, in any language: the first number (also full-width or other
// scripts' digits), else the localized word for Red (or English "red") as 100, the word for Off as 0. -1 if nothing fits.
NSInteger LPParseNightPoints(NSString *text, NSString *redWord, NSString *offWord);
