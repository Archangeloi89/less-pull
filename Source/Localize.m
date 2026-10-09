#import "Localize.h"
NSString *const LessPullLanguageChanged=@"LessPullLanguageChanged";
static NSDictionary *table;static NSString *currentCode=@"en";
NSString *LX(NSString *key,NSString *english){NSString *t=table[key];return t.length?t:L(english);}
NSString *L(NSString *english){if(!english)return nil;NSString *t=table[english];return t.length?t:english;}
@implementation LessPullLanguage
+ (NSArray<NSString *> *)available {
 NSMutableArray *codes=[NSMutableArray arrayWithObject:@"en"];NSString *root=NSBundle.mainBundle.resourcePath;
 for(NSString *name in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:nil] sortedArrayUsingSelector:@selector(compare:)])if([name hasSuffix:@".lproj"]){NSString *code=[name stringByDeletingPathExtension];if(![code isEqual:@"en"]&&[NSFileManager.defaultManager fileExistsAtPath:[[root stringByAppendingPathComponent:name] stringByAppendingPathComponent:@"Localizable.strings"]])[codes addObject:code];}
 return codes;
}
+ (NSString *)preferred {NSString *p=[NSUserDefaults.standardUserDefaults stringForKey:@"language"];return p.length?p:nil;}
+ (void)setPreferred:(NSString *)code {if(code.length)[NSUserDefaults.standardUserDefaults setObject:code forKey:@"language"];else [NSUserDefaults.standardUserDefaults removeObjectForKey:@"language"];[self load];[NSNotificationCenter.defaultCenter postNotificationName:LessPullLanguageChanged object:nil];}
+ (NSString *)current {return currentCode;}
+ (NSString *)systemChoice {
 NSArray *have=[self available];
 for(NSString *pref in NSLocale.preferredLanguages){NSString *code=[pref componentsSeparatedByString:@"-"].firstObject.lowercaseString;if([have containsObject:pref])return pref;if([have containsObject:code])return code;for(NSString *h in have)if([h hasPrefix:[code stringByAppendingString:@"-"]])return h;}  // pt-PT falls back to pt-BR, zh to zh-Hans
 return @"en";
}
+ (NSString *)nameOf:(NSString *)code {
 NSDictionary *names=@{@"en":@"English",@"de":@"Deutsch",@"fr":@"Français",@"es":@"Español",@"it":@"Italiano",@"nl":@"Nederlands",@"pt":@"Português",@"pt-BR":@"Português (Brasil)",@"ru":@"Русский",@"zh-Hans":@"简体中文",@"zh-Hant":@"繁體中文",@"ja":@"日本語",@"ko":@"한국어",@"pl":@"Polski",@"uk":@"Українська",@"tr":@"Türkçe",@"sv":@"Svenska"};
 return names[code]?:[[NSLocale localeWithLocaleIdentifier:code] localizedStringForLanguageCode:code]?:code;
}
+ (BOOL)isReviewed:(NSString *)code {return [@[@"en",@"de"] containsObject:code];}
+ (NSString *)menuNameOf:(NSString *)code {
 if([self isReviewed:code])return [self nameOf:code];
 NSDictionary *word=@{@"es":@"experimental",@"fr":@"expérimental",@"it":@"sperimentale",@"pt":@"experimental",@"pt-BR":@"experimental",@"nl":@"experimenteel",@"ru":@"экспериментальный",@"pl":@"eksperymentalny",@"uk":@"експериментальний",@"ja":@"試験版",@"ko":@"실험 버전",@"zh-Hans":@"实验性",@"zh-Hant":@"實驗性",@"tr":@"deneysel",@"sv":@"experimentell"};
 return [NSString stringWithFormat:@"%@ (%@)",[self nameOf:code],word[code]?:@"experimental"];
}
+ (void)load {
 NSString *code=[self preferred]?:[self systemChoice];if(![[self available] containsObject:code])code=@"en";
 if([code isEqual:@"en"]){table=nil;currentCode=@"en";return;}
 NSString *path=[[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[code stringByAppendingString:@".lproj"]] stringByAppendingPathComponent:@"Localizable.strings"];
 NSString *text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
 NSDictionary *parsed=nil;@try{parsed=[text propertyListFromStringsFileFormat];}@catch(NSException *e){parsed=nil;}
 table=parsed;currentCode=parsed?code:@"en";
}
@end
