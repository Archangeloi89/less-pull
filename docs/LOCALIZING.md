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

Languages added from here on are marked **experimental** in the Language menu until a native speaker has read them line by line: written with the same care and method, but not yet reviewed. If a line sounds wrong to you, Report a Problem on the About tab is the way to say so. The list of reviewed languages is `isReviewed:` in `Source/Localize.m`.

## Adding a language

1. Copy `Source/Localizations/de.lproj/Localizable.strings` to `<code>.lproj/Localizable.strings` (codes as macOS uses them: `fr`, `es`, `it`, `nl`, `pt-BR`, `ru`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, …).
2. Translate the right-hand side of each line. Keep the placeholders (`%@`, `%ld`, `%.0f%%`) and their order, or use positional ones (`%1$@`, `%2$@`) when the sentence needs them the other way round.
3. Do not translate the sentence; say the idea again in the new language. For each line, ask what the situation is and how a native speaker would put it, in the app's calm, plain tone, then translate your line back into English and compare it with the key: same meaning, same weight, nothing added. A line that only reads well in English is a line to rewrite. Keep product names (Less Pull, Night Shift) and the app's own terms consistent throughout.
4. Add the language's own name to `nameOf:` in `Source/Localize.m` if it is not there yet, and its word for "experimental" to `menuNameOf:`, so the Language menu shows it properly. A few places use a context key beside the English, such as `"Grayscale [rule row]"` or `"Default [segment]"`, for the compact rows where a language may need a shorter word; the German and Spanish files show them.
5. Build (`Source/build.sh` copies every `.lproj`), choose the language under Settings → General, and look at every tab, the tour and the menu. The settings window is 500 pt wide in every language. If a line pushes a row past that, shorten the line rather than the window; the German table shows where that was needed (buttons and row labels, never the explanations).

`plutil -lint` on the file catches a missing quote or semicolon.
