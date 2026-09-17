# Codex Profile Launcher

Run a second Codex Desktop account alongside your normal one, on macOS.

`Codex Personal.app` is a small native launcher. It starts the copy of Codex you
already have installed, but points it at a separate profile directory, so it
signs in independently and runs at the same time as your normal Codex.

```
/Applications/Codex.app             ->  your normal account, ~/.codex
/Applications/Codex Personal.app    ->  a second account,    ~/.codex-personal
```

Both run at once. Closing one does not affect the other, and each keeps its own
login between restarts.

## What it does not do

- **It does not include Codex.** You install Codex Desktop yourself.
- **It does not modify Codex.** No files in the Codex application bundle are
  touched, copied or redistributed.
- **It does not touch `~/.codex`.** Your existing profile is left exactly as it
  is. The launcher refuses to start if a profile is ever pointed at it.
- **It is not affiliated with OpenAI.** Codex is a product of OpenAI. This is an
  independent utility, not endorsed or sponsored by them.

## Install

1. Download `Codex-Profile-Launcher-vX.Y.Z.dmg` from
   [Releases](../../releases).
2. Open the DMG and drag **Codex Personal** into **Applications**.
3. Open **Codex Personal** and sign in with your second account.

### Gatekeeper

Public builds are **ad-hoc signed**, not signed with an Apple Developer ID and
not notarized. Apple charges for the certificate that would make the warning go
away, so the first launch shows:

> "Codex Personal" cannot be opened because Apple cannot check it for malicious
> software.

To open it, right-click **Codex Personal** in Applications, choose **Open**, and
confirm. macOS remembers the decision; subsequent launches are normal.

Do this only for a build you trust. Verify your download first:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

Building from source (below) produces a build signed on your own machine and
avoids the prompt entirely. Do **not** disable Gatekeeper system-wide.

If the maintainer later adds Developer ID secrets to the repository, the release
workflow signs, notarizes and staples automatically, and the warning disappears
with no code change.

## Usage

| Application | Account | Profile directory |
| --- | --- | --- |
| `Codex.app` | your default account | `~/.codex` |
| `Codex Personal.app` | second account | `~/.codex-personal` |

Open either from Finder, Spotlight, Launchpad or the Dock. The launcher exits as
soon as Codex is running, so what you see in the Dock is Codex itself.

## Data location

Everything the second profile stores lives under one directory:

```
~/.codex-personal/
├── config.toml, auth, logs, state, sessions   Codex's own profile data
└── electron-user-data/                        cookies, localStorage,
                                               IndexedDB, session data
```

Created on first launch with owner-only permissions (`0700`). Nothing is copied
from `~/.codex`, and no credentials move between profiles.

## Uninstall

Delete the launcher:

```
/Applications/Codex Personal.app
```

**Your profile data is deliberately left behind.** Removing the app does not
touch `~/.codex-personal`, so reinstalling restores your session.

To erase the second profile as well — this signs that account out and deletes
its history, and cannot be undone:

```bash
rm -rf ~/.codex-personal
```

Your normal Codex installation and `~/.codex` are unaffected either way.

## Creating more profiles

A profile is one JSON file. To add `Codex Work.app`:

```bash
cp profiles/work.json.example profiles/work.json
./scripts/build.sh --profile work     # -> dist/Codex Work.app
```

`profiles/work.json`:

```json
{
  "name": "Work",
  "slug": "work",
  "appName": "Codex Work",
  "bundleIdentifier": "com.local.codex-profile-launcher.work",
  "codexHome": "~/.codex-work",
  "electronUserDataPath": "~/.codex-work/electron-user-data",
  "icon": { "label": "CW", "tintTop": "#2FB3A5", "tintBottom": "#0C3A36" }
}
```

Give each profile its own `slug`, `bundleIdentifier`, `codexHome` and icon
colour. Nothing in `Sources/` needs to change — the build reads the profile and
bakes it into the generated bundle at `Contents/Resources/profile.json`.

## Building from source

Requirements:

- macOS 13 or newer to build (the built app runs on macOS 12+)
- Swift 5.9+ — Xcode 15+, or Command Line Tools (`xcode-select --install`)
- Apple Silicon or Intel; the build produces a universal binary

```bash
./scripts/test.sh                       # unit tests
./scripts/build.sh                      # -> dist/Codex Personal.app
./scripts/package.sh                    # -> dist/*.dmg, *.zip, SHA256SUMS.txt
```

Useful options:

```bash
./scripts/build.sh --profile work       # build a different profile
./scripts/build.sh --arch arm64         # skip the universal binary
./scripts/validate-bundle.sh "dist/Codex Personal.app"
```

To sign with your own Developer ID instead of ad-hoc:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh
```

## How it works

The launcher is a Swift/AppKit shim, around 500 lines. On launch it:

1. **Finds Codex.** It checks an explicit override, then the usual install
   locations, then asks LaunchServices for the `com.openai.codex` bundle. The
   executable name comes from the bundle's `Info.plist` rather than being
   assumed — Codex Desktop currently ships as `ChatGPT.app` with a `ChatGPT`
   executable, so a hardcoded path would not work.
2. **Creates the profile directories** if they do not already exist, mode
   `0700`. Existing data is never modified.
3. **Spawns Codex directly** with `Process`, passing:

   ```
   CODEX_HOME=~/.codex-personal
   CODEX_ELECTRON_USER_DATA_PATH=~/.codex-personal/electron-user-data
   --user-data-dir=~/.codex-personal/electron-user-data
   ```

Two details make this work, both of which are behaviours of Codex itself:

- **Codex is not launched via `open`.** Going through LaunchServices can route
  the request to an already-running Codex, which would ignore the profile
  entirely. A direct child process also guarantees the environment is in place
  before Electron initialises.
- **Both environment variables are required.** Codex loads your login shell's
  environment during startup, which would otherwise overwrite `CODEX_HOME`; it
  re-applies the launch-time value only when `CODEX_ELECTRON_USER_DATA_PATH` is
  also set. That same variable is what makes Codex take a single-instance lock
  scoped to the user-data directory, which is why a profile instance and normal
  Codex never collide.

If anything fails — Codex missing, executable unreadable, directory not
creatable, process refusing to start — the launcher shows a native alert saying
what went wrong. It never fails silently.

## Verifying isolation

Unit tests cover profile validation and launch-command construction. To confirm
the real thing, see [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Limitations

- This depends on how Codex Desktop handles `CODEX_HOME`,
  `CODEX_ELECTRON_USER_DATA_PATH` and `--user-data-dir`. Those are used by Codex
  itself, but they are not a public API, and a future Codex release could change
  them. If a Codex update breaks the launcher, it will report the failure rather
  than silently using the wrong profile.
- Both applications share one Dock icon identity while running, because the
  running process is Codex. The distinct icon identifies the launcher, not the
  running Codex window.
- macOS only.

## License

[MIT](LICENSE). Codex is a product of OpenAI; this project is an independent
utility and is not affiliated with or endorsed by OpenAI.
