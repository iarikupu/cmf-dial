# CMF Dial

A small macOS app that lets you decide what the **case dial of the CMF Buds Pro 2** does on your Mac: switch apps (with the real Cmd+Tab overlay), windows, desktops and browser tabs, skip tracks, scroll, zoom, change brightness, undo/redo, run any shell command — and remap single / double / triple dial presses too.

It also shows battery for each bud and the case, the current volume, everything currently set on your buds, and has quick shortcuts for when the buds reconnect.

> Unofficial and not affiliated with Nothing Technology Limited.

## Contents
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Build and run](#build-and-run)
- [Using the app](#using-the-app)
- [What the dial can do](#what-the-dial-can-do)
- [Keep permissions across rebuilds](#keep-permissions-across-rebuilds)
- [Troubleshooting](#troubleshooting)
- [Command line](#command-line)
- [Project layout](#project-layout)
- [Known limitations](#known-limitations)
- [Assets](#assets) · [Credits](#credits)

## How it works
- **Turning the dial.** With the dial's rotation set to **Volume**, the buds report every click as a small volume step (1/16). The app watches those steps, works out the direction, runs your action and puts the volume back, so the real volume doesn't drift.
- **Pressing the dial.** Presses reach the Mac as media keys (play/pause, next, previous). The app catches them with an event tap and runs your action instead.
- **Talking to the buds.** The buds' control channel (Bluetooth RFCOMM "NTAPP") speaks the community-documented Nothing protocol. The app uses it to read battery and the gesture table, and to set "dial rotate = volume" and the press actions — the same writes the Nothing X phone app makes. See [`docs/PROTOCOL.md`](docs/PROTOCOL.md).

## Requirements
- macOS 14 or newer
- Xcode Command Line Tools (`xcode-select --install`)
- CMF Buds Pro 2, paired with the Mac

## Build and run
```bash
./make-app.sh
open "CMF Dial.app"
```

First launch:
1. Allow Bluetooth when asked.
2. Switch **CMF Dial** on in System Settings → Privacy & Security → **Accessibility**.
3. Quit and reopen the app once. macOS only applies the Accessibility permission to a fresh launch.
4. If the banner says the dial is off, click **Turn on the dial** (or use **Reconnect → Switch dial to Volume**).
5. Make sure your Mac's sound is playing on the buds. Rotation is only reported while the buds are the audio output.

## Using the app
| Where | What it's for |
|---|---|
| **Sidebar** | Pick what turning the dial does (presets, or **Custom…** to choose each direction or a shell command). Reverse direction, light/dark theme. |
| **Status strip** | Connection, left / right / case battery, where sound is playing, and whether the dial is in Volume mode. |
| **Overview** | Live case view that reacts to each turn and press, a 16-step volume panel (remapped turns flash a "ghost" step), and recent actions. Preview buttons fire an action without touching the dial. |
| **Presses** | Choose what a single, double or triple press does on the Mac. Press-and-hold stays on the buds. |
| **Controls** | Everything currently set on the buds (dial and each earbud), editable. |
| **Reconnect** | Connect the buds, play sound on them, switch the dial to Volume, refresh, plus automatic options for when they reconnect. |
| **Menu bar** | Remapping on/off, **Connect buds** (⌘R), **Play sound on buds** (⌘O), **Switch dial to Volume** (⌘D), open the window, quit. |

## What the dial can do
**Presets for turning:** Switch Apps, Switch Windows, Switch Desktops, Browser Tabs, Skip Tracks, Scroll Page, Seek Video, Reels / Shorts, Brush Size, Zoom, Undo / Redo, Screen Brightness, Volume (stock), Custom.

**Actions available in Custom and for presses:**

| Category | Actions |
|---|---|
| Switching | Next / previous app (Cmd+Tab overlay), window (Cmd+\`), desktop (Ctrl+←/→), browser tab (Ctrl+Tab) |
| Media | Next / previous track, play/pause, mute, native volume |
| Navigation | Scroll up / down, arrow keys |
| Video | Seek forward / back, next / previous short or reel |
| Editing | Zoom in / out, undo, redo |
| Creative | Brush bigger / smaller (`]` / `[`) |
| Shortcuts | Spotlight, Mission Control, screenshot area, lock screen, new tab, close tab, reopen closed tab |
| Display | Brightness up / down |
| Basic | Do nothing, run a shell command (`/bin/sh -c …`) |

New actions go in `Catalog.actions` in [`Sources/cmfdial/App/Controls.swift`](Sources/cmfdial/App/Controls.swift); new presets in `Catalog.presets`.

## Keep permissions across rebuilds
macOS ties the Accessibility permission to the app's code signature. An ad-hoc signed app gets a new signature on every build, so macOS quietly stops trusting it. To avoid that, create a self-signed code-signing identity once. `make-app.sh` uses it automatically:

1. Open **Keychain Access** → menu **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: `CMF Dial Local Signing` · Identity Type: **Self-Signed Root** · Certificate Type: **Code Signing** → Create.
3. Run `./make-app.sh`. It prints `Signed with local identity`.
4. Turn Accessibility on for CMF Dial one last time and relaunch the app.

## Troubleshooting
The app logs every dial tick, press, permission check and Bluetooth event to `~/Library/Logs/CMFDial.log`:
```bash
tail -f ~/Library/Logs/CMFDial.log
```

| Symptom | Fix |
|---|---|
| Ticks appear in the log, but nothing happens on the Mac | Accessibility isn't active for this build. Log shows `Accessibility trusted: false`. Reset it, switch it on again, then relaunch: `tccutil reset Accessibility local.cmfdial.app` |
| CMF Dial isn't in the Accessibility list | Launch the app once (it asks to be added), or use the **+** button and pick `CMF Dial.app`. |
| Turning the dial does nothing at all | The dial must be in Volume mode (**Reconnect → Switch dial to Volume**) and sound must be playing on the buds. |
| The volume changes instead of running the action | The preset is **Volume (stock)** or remapping is switched off. |
| Buds won't connect | Open the case lid, then **Connect buds**. If they're connected to your phone, disconnect them there first. |
| Battery / Controls are empty | The control channel opens a few seconds after connecting. Click **Refresh** on the Reconnect tab. |
| Presses aren't picked up | Check the log for `media key … pid=…` lines. If presses show `pid=0`, switch off **Ignore keyboard media keys** on the Presses tab. |

## Command line
The same binary has helper commands. With no arguments it opens the app; `./.build/release/cmfdial help` lists the commands:

| Command | What it does |
|---|---|
| `devices` | List paired Bluetooth devices |
| `services [ADDR]` | List the buds' SDP services and RFCOMM channels |
| `sniff [ADDR] [--all] [--channel N]` | Log every volume, media-key and RFCOMM event to `captures/` (type a note + Enter to mark a step) |
| `ble [--name CMF] [--all]` | Dump the buds' Bluetooth LE services and notifications |
| `nt get [ADDR]` | Read the gesture table from the buds (read-only) |
| `nt set-dial-rotate volume\|none --yes [ADDR]` | Set the dial rotation on the buds |
| `run [config.json]` | Headless remapper for dial rotation, no window (see below) |
| `media KEY` | Fire a media key to test (`play_pause`, `next`, `previous`, `mute`, `volume_up`, `brightness_up`, …) |

### Headless config (`run`)
Copy `config.example.json` to `config.json` (ignored by git) and fill in your buds' address from `cmfdial devices`.

```json
{
  "device_address": "AA:BB:CC:DD:EE:FF",
  "device_name": "CMF",
  "dial": {
    "restore_volume": true,
    "up":   { "type": "app_switcher", "key": "next" },
    "down": { "type": "app_switcher", "key": "prev" }
  },
  "rfcomm": []
}
```

- `type`: `app_switcher` (`key`: `next` / `prev`), `media` (`key`: a media key name), `shell` (`command`: any shell command), or `log`.
- `restore_volume`: put the volume back after each tick (turn off to let the dial change volume too).
- `rfcomm`: optional raw triggers — `{ "name", "channel", "match": "55 20 01 ?? ??", "action" }`, matched anywhere in a received frame (`??` = any byte).

The headless remapper only handles rotation; press remapping lives in the app.

## Project layout
```
Sources/cmfdial/
  main.swift          entry point: no arguments opens the app, otherwise CLI commands
  Nothing.swift       protocol frames, CRC, gesture and battery decoding
  Bluetooth.swift     RFCOMM link (opens channels one at a time)
  Audio.swift         CoreAudio volume, output devices, volume watcher
  Actions.swift       Cmd+Tab switcher, media keys, headless actions
  Config.swift, Util.swift, BLE.swift
  App/
    Engine.swift      dial ticks, presses, buds state, reconnect helpers
    Controls.swift    action catalog and presets
    MediaKeyTap.swift event tap for dial presses
    ContentView.swift, Sidebar.swift, ProductStage.swift, CaseView.swift, Theme.swift
    CMFDialApp.swift  window + menu bar
    Snapshot.swift    `cmfdial snapshot out.png [tab] [light|dark]` for layout checks
tools/make-icon.swift app icon generator used by make-app.sh
Resources/            Nothing fonts and product images (private, see below)
docs/PROTOCOL.md      what's known about the buds' control protocol
```

## Known limitations
- Dial presses share media keys with the earbuds' own taps: if a double-tap on an earbud also sends "next", it triggers the double-press action too.
- Press-and-hold is handled by the buds (voice assistant, low-lag mode or nothing) and can't be mapped to a Mac action.
- Dial presses have only been lightly tested on real hardware. If presses don't reach the event tap on your macOS version, the log shows no `media key` lines.
- Each remapped tick briefly changes the volume before it's put back.
- Tested with CMF Buds Pro 2 only.

## Assets
`Resources/` contains Nothing's fonts and official product images, for personal use only. This repository must stay **private**; see [`Resources/README.md`](Resources/README.md). The app builds and runs without them: it falls back to a drawn dot-matrix font and a drawn case.

## Credits
Protocol details were cross-checked against the community project [radiance-project/ear-web](https://github.com/radiance-project/ear-web) and reverse-engineering notes for Nothing earbuds.
