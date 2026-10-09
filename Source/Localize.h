#import <Foundation/Foundation.h>
// Less Pull speaks the user's language. English is the source text and the key; a language
// table (<code>.lproj/Localizable.strings, plain strings format) is read once when chosen, so
// only the language in use is in memory, and switching needs no restart: the app rebuilds
// its windows and menus. L() returns the English text when a table has no entry.
NSString *L(NSString *english);
extern NSString *const LessPullLanguageChanged;
@interface LessPullLanguage : NSObject
+ (NSArray<NSString *> *)available;        // language codes with a table in the bundle, English first
+ (NSString *)preferred;                   // the saved choice, or nil for "follow the system"
+ (void)setPreferred:(NSString *)code;     // nil follows the system; posts LessPullLanguageChanged
+ (NSString *)current;                     // the code in use ("en" when the table is English)
+ (NSString *)systemChoice;                // what "follow the system" resolves to
+ (NSString *)nameOf:(NSString *)code;     // the language's own name
+ (void)load;
@end
