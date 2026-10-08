# Privacy in Less Pull 1.4.4

The native app and extension have no analytics, telemetry, cloud sync, or application network service. Optional author/support buttons open external websites in your browser, where those websites have their own policies. GitHub distributes downloads under its own policies.

The browser extension requests `tabs` to identify the active website and `nativeMessaging` to talk to the local app. It does not inject scripts into pages or read page contents. Active public tab domains and URLs are sent through the native helper and a local Unix socket to the Mac app. Private tabs are excluded. Active contexts are held in memory and expire or clear when the browser disconnects.

Saved domain and exact-URL exceptions are stored in macOS user defaults under `local.nightshiftfilters.app`. Exact URLs preserve query strings and ignore fragments; avoid saving token-bearing or otherwise sensitive URLs. App exceptions store application identifiers and settings. No account is required.

Diagnostics record appearance choices and display-recovery counters. Production appearance logs contain no app identifiers or website URLs. Developer test-state output is opt-in through an explicit command-line flag.

Removing saved exceptions removes the corresponding preferences. Removing the app alone does not delete its user defaults. Questions: contact the author through https://jiriarion.com.
