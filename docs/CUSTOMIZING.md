# Customizing Less Pull

You may change your own copy of Less Pull to your heart's content. One condition, from the [source license](../LICENSE-SOURCE.txt): the author's name and links on the About tab stay as they are; add your own beside them.

This page is the contract for customizations that survive updates. The machine-readable version is [`compat.json`](compat.json); its `contract` number changes when something here changes, and the release notes say what.

## Three tiers

**Tier 1: no rebuild, survives every update.** Preferences, hooks and replaceable sounds. An agent or a script can set these up on a stock install.

- **Preferences** live in the `com.jiriarion.lesspull` domain. The stable keys and their meanings are listed in `compat.json`. Set them with `defaults write`, then quit and reopen Less Pull. Keys not listed there are internal.
- **Hooks** are executables in `~/Library/Application Support/Less Pull/hooks/`, named after the event: `session-started`, `session-ended`, `session-reminder`, `session-call-back`, `grayscale-changed`. The event name is the first argument, details follow (minutes, or `on`/`off`). Less Pull starts the hook and does not wait; output is ignored. Example, a hook that logs sessions:

  ```sh
  mkdir -p ~/Library/Application\ Support/Less\ Pull/hooks
  cat > ~/Library/Application\ Support/Less\ Pull/hooks/session-ended <<'EOS'
  #!/bin/sh
  echo "$(date) session of $2 minutes ended" >> ~/sessions.log
  EOS
  chmod +x ~/Library/Application\ Support/Less\ Pull/hooks/session-ended
  ```
- **Sounds**: a WAV file in `~/Library/Application Support/Less Pull/sounds/` named `session-end.wav`, `session-remind.wav` or `session-back.wav` replaces that sound in every style.

**Tier 2: a rebuild, still compatible.** Files under `Source/Sounds/`, `Source/MenuBar/`, `docs/`, `tools/` and `README.md`. Updates may add files there but do not rewrite yours, so a fork that changes only these paths merges cleanly. Your own icons and your own generated sounds belong here.

**Tier 3: internal.** `Source/main.m` and everything else. A change there may conflict with any future build. It is allowed; it is just not promised to survive.

## Checking a fork

```sh
zsh tools/compat-check.sh /path/to/your/fork v1.4.4-33
```

The script lists every file your fork changed since that release, sorted by tier, and ends with a plain sentence for each Tier 3 change: it leaves the compatible range, and a future update may conflict there. Run it before and after a change, and read the result to whoever owns the copy, so the decision is a conscious one.

## For agents

Before changing anything: read `compat.json`, prefer Tier 1, then Tier 2. After changing: run the check and tell the user which changes are in the compatible range and which are not. Record what you changed and why in `docs/MY-CHANGES.md` in the fork, so the next agent, or the next update, knows.

## What is coming

A `Source/Customization/` folder with code override points (texts, the tour, extra About links) and a local command interface over the app's socket (set warmth, start a session, add an exception) are planned as the next step of this contract.
