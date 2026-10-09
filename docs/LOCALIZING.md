# Less Pull in your language

Less Pull speaks the language of the Mac it runs on, and you can choose another under **Settings → General → Language**. The change happens at once: the windows and the menu are rebuilt, no restart.

## How it works

- English is the source text, and also the key. Every piece of text in the app goes through one small function, `L()`, that looks the English up in the table of the language in use.
- A language is one plain-text file: `Source/Localizations/<code>.lproj/Localizable.strings`, in Apple's strings format (`"English" = "Translation";`). It ships inside the app under `Contents/Resources/<code>.lproj/`.
- Only the language in use is read, once, when the app starts or when you switch. A table is about 60 KB on disk and about as much in memory; the other languages cost nothing while unused.
- Anything a table does not cover stays English, so a half-finished language is still usable.
- **Same as the Mac** follows `System Settings → General → Language & Region`, picking the first of your preferred languages that Less Pull has.

## Languages

| Code | Language | State |
|---|---|---|
| en | English | source, reviewed |
| de | Deutsch | reviewed |
| es | Español | experimental |
| fr | Français | experimental |
| it | Italiano | experimental |
| pt-BR | Português (Brasil) | experimental; pt-PT falls back to it |
| nl | Nederlands | experimental |

Languages added from here on are marked **experimental** in the Language menu until a native speaker has read them line by line: written with the same care and method, but not yet reviewed. If a line sounds wrong to you, Report a Problem on the About tab is the way to say so. The list of reviewed languages is `isReviewed:` in `Source/Localize.m`.

## Adding a language

1. Copy `Source/Localizations/de.lproj/Localizable.strings` to `<code>.lproj/Localizable.strings` (codes as macOS uses them: `fr`, `es`, `it`, `nl`, `pt-BR`, `ru`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, …).
2. Translate the right-hand side of each line. Keep the placeholders (`%@`, `%ld`, `%.0f%%`) and their order, or use positional ones (`%1$@`, `%2$@`) when the sentence needs them the other way round.
3. Do not translate the sentence; say the idea again in the new language. For each line, ask what the situation is and how a native speaker would put it, in the app's calm, plain tone, then translate your line back into English and compare it with the key: same meaning, same weight, nothing added. A line that only reads well in English is a line to rewrite. Keep product names (Less Pull, Night Shift) and the app's own terms consistent throughout.
4. Add the language's own name to `nameOf:` in `Source/Localize.m` if it is not there yet, and its word for "experimental" to `menuNameOf:`, so the Language menu shows it properly. A few places use a context key beside the English, such as `"Grayscale [rule row]"` or `"Default [segment]"`, for the compact rows where a language may need a shorter word; the German and Spanish files show them.
5. Build (`Source/build.sh` copies every `.lproj`), choose the language under Settings → General, and look at every tab, the tour and the menu. The settings window is 500 pt wide in every language. If a line pushes a row past that, shorten the line rather than the window; the German table shows where that was needed (buttons and row labels, never the explanations).

`plutil -lint` on the file catches a missing quote or semicolon.

## What the words stand for

Translate the function, not the line. Before naming anything, know what it does and how someone who uses it would describe it to a friend, in that language, without the English in their head. The names below are the functions; the English words are only one way of saying them.

- **Grayscale**: the whole screen in shades of gray, on or off. Name it the way the language names a black-and-white picture or a monochrome display.
- **Extra Warmth**: a slider that adds warmth on top of Night Shift, from none, through amber, to red. "Extra" means on top of what the system does; a language may simply say "warmth".
- **Night Shift**: Apple's own feature name; keep it as the system names it in that language.
- **Peek in color**: hold a shortcut and the screen is in color for exactly as long as you hold it; two quick presses keep it; one more press returns. Name the gesture: a glance, a quick look, a peek, whatever the language uses for looking at something briefly.
- **Plain display**: the screen as macOS shows it without any filter. Most languages say "without filter" or "the normal screen".
- **Exception**: an app or website that gets its own settings while it is in front. The word should feel like an exception to a rule, not a legal term.
- **Use this exception** (checkbox in a rule row): whether the rule is active; the settings stay saved either way. A single word for "active" or "on" fits the row.
- **Session**: a stretch of focused work with a chosen length; at the end a glow and a sound, then the count goes on past the end. Choose the word people use for a focused work block or timer in that language.
- **Call back** (after leaving a session): you leave, and once, after the minutes you chose, the app reminds you to come back. Name what it does to you: it fetches you back, reminds you, calls you.
- **Leave quietly**: end the session without the call back. **Keep going**: stay in it.
- **Count on / Stop quietly** (At the end): after the end, either the icon keeps counting the minutes past the end, or the session simply ends.
- **Strokes / Chords**: two sound styles; strokes are separate notes, chords are one soft chord.
- **Turn Grayscale off for…**: a timed exception for yourself: color back for an hour or four, then gray again by itself.
- **Pause Less Pull**: the plain display for a while, everything kept.
- **Shortcut**: a keyboard shortcut; use the word macOS uses in that language.
- **Suggest** (next to a shortcut): picks a free shortcut for you. **Record Shortcut**: press the keys you want.
- **Default**, in the rule-row segments: keep what the app or site would inherit. Short, as the segment is narrow.
- **On every display / Peek toggles**: with several displays, which displays an exception or the peek covers.
- **Support my work / Buy me a coffee / Tell a friend / Share**: the thank-you card and About; warm, not salesy, in the voice of the author speaking to one person.
- **Tour**: five short pages after the welcome; many languages simply say "tour".
- **Don’t show explanations**: hides the gray helper lines under the settings.

