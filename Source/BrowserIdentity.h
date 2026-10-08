// Chromium extension origins the native host answers: the unpacked extension (its id comes from the "key" in
// manifest.json), and the Chrome Web Store copy once its id is known (add it here; one line, one app build).
#define LESS_PULL_EXTENSION_ORIGIN "chrome-extension://ofgdgaekfiojllehpfiifheklikbgglb/"
#define LESS_PULL_STORE_EXTENSION_ORIGIN "chrome-extension://lfcjadlpflfdgbgpcbkmdkmnboaakimb/"  // the Chrome Web Store copy (item id)
#define LESS_PULL_EXTENSION_ORIGINS @[@LESS_PULL_EXTENSION_ORIGIN,@LESS_PULL_STORE_EXTENSION_ORIGIN]
#define LESS_PULL_FIREFOX_ID "lesspull@jiriarion.com"
