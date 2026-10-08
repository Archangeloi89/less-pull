# Release preparation

1. Separate source and app licensing is now in place. Obtain legal review of the custom terms before broad public release.
2. README, screenshots, comparison, privacy and installation documents are prepared. Keep this preparation repository private until public release is explicitly approved.
3. Sign the app/helper using Developer ID, test Hardened Runtime, submit for notarization, staple and test a clean downloaded installation.
4. Complete clean Chrome and Brave installation, reconnect, sleep/wake and external-display validation.
5. Register the Chrome Web Store publisher, obtain the production extension identity, align native allowlists, prepare disclosures and reviewer instructions, then submit.
6. Publish versioned notarized downloads. Add Firefox/Safari/other browser ports only as explicitly scoped follow-up work.

Version 1.4.2 removes the old immediate Color-to-Grayscale return workaround at the user's request. The user confirmed the smooth fade works flawlessly. No universal optical or OS compatibility claim is made.

Do not commit credentials, user preferences, personal browser contexts, test states, or private conversation documents to the public repository.
