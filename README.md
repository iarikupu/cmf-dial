# CMF Dial

A small macOS app that lets you decide what the **case dial of the CMF Buds Pro 2** does on your Mac: switch apps (with the real Cmd+Tab overlay), windows, desktops and browser tabs, skip tracks, scroll, zoom, change brightness, undo/redo, run any shell command — and remap single / double / triple dial presses too.

It also shows battery for each bud and the case, volume, everything currently set on your buds, and has quick shortcuts for when the buds reconnect.

> Unofficial and not affiliated with Nothing Technology Limited.

## How it works
- With the dial's rotation set to **Volume**, the buds report every click as a small volume step (1/16). The app watches those steps, works out the direction, runs your action and puts the volume back.
- Dial presses reach the Mac as media keys (play/pause, next, previous). The app catches them with an event tap and runs your action instead.
- The buds' control channel (Bluetooth RFCOMM "NTAPP") speaks the community-documented Nothing protocol. The app uses it to read battery and the gesture table, and to set "dial rotate = volume" and the press actions — the same writes the Nothing X phone app makes.

## Requirements
- macOS 14 or newer, Xcode Command Line Tools (`xcode-select --install`)
- CMF Buds Pro 2, paired with the Mac

## Build and run
```bash
./make-app.sh
open "CMF Dial.app"
```
First launch: allow Bluetooth, then switch **CMF Dial** on in System Settings → Privacy & Security → Accessibility and relaunch once.

Tip: macOS forgets granted permissions whenever an ad-hoc signed app is rebuilt. If you have a local code-signing identity named `CMF Dial Local Signing` in your keychain, `make-app.sh` uses it, so permissions survive rebuilds.

## Command line
The same binary has helper commands (`./.build/release/cmfdial …`): `devices`, `services`, `sniff` (log everything the buds send), `nt get`, `nt set-dial-rotate volume|none --yes`, `run config.json` (headless remapper; see `config.example.json`).

## Assets
`Resources/` contains Nothing's fonts and official product images, for personal use only. This repository must stay **private**; see [`Resources/README.md`](Resources/README.md).

## Credits
Protocol details were cross-checked against the community project [radiance-project/ear-web](https://github.com/radiance-project/ear-web) and reverse-engineering notes for Nothing earbuds.
