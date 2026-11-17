# CMF Buds Pro 2 control protocol (notes)

What this app relies on, from the community [ear-web](https://github.com/radiance-project/ear-web) project and captures with `cmfdial sniff` / `cmfdial nt get`. Unofficial; other Nothing / CMF models may differ.

## Transport
- Bluetooth Classic **RFCOMM**, SDP service **"NTAPP"**, channel **16** on the CMF Buds Pro 2.
- Bluetooth LE exposes nothing useful for the dial (`cmfdial ble` was used to check).
- The buds accept one control connection at a time. If the Nothing X app on a phone is connected, the Mac may not get the channel.

## Frame format
```
55 | 60 01 | cmd (LE16) | len | 00 | opId | payload (len bytes) | CRC16 (LE)
```
- Requests start `55 60 01`, responses and notifications start `55 20 01`.
- `opId` is a request counter; replies echo it.
- CRC is **CRC-16/MODBUS** (init `0xFFFF`, poly `0xA001` reflected) over every byte before the CRC.
- Implementation: `NT.frame`, `NT.crc16`, `NT.splitFrames` in [`Sources/cmfdial/Nothing.swift`](../Sources/cmfdial/Nothing.swift).

## Commands used
| Command | Direction | Payload |
|---|---|---|
| `0xC007` get battery | → buds | none |
| `0x4007` battery reply · `0xE001` battery notify | ← buds | `count, (id, level)…` — id 2 left, 3 right, 4 case; `level & 0x7F` = percent, `0x80` = charging |
| `0xC018` get gestures | → buds | none |
| `0x4018` gesture reply | ← buds | `count, (device, common, type, action)…` |
| `0xF003` set gesture | → buds | `01, device, common, type, action` |

## Gesture table values
**device:** 2 left bud · 3 right bud · 4 case dial

**common:** 1 for normal gestures; other values appear for in-call gestures (e.g. 9).

| type | gesture |
|---|---|
| 1 | single press |
| 2 | double press |
| 3 | triple press |
| 7 | press & hold |
| 9 | (earbud-only entry, hidden in the app) |
| 10 | rotate (dial) |

| action | meaning |
|---|---|
| 1 | no action |
| 2 | play / pause |
| 3 | answer call |
| 8 | previous track |
| 9 | next track |
| 11 | voice assistant |
| 17 | low-lag mode toggle |
| 22 | noise control |
| 23 | volume control (dial rotate) |
| 25 | answer / mute mic |
| 26 | hang up |

## How the Mac sees the dial
- **Rotate = volume (23):** each click arrives as an AVRCP absolute-volume change of 1/16 on the buds' audio output. Rotate = no action (1) sends nothing.
- **Presses** set to play/pause (2), next (9) or previous (8) arrive as the matching system media keys (codes 16, 17, 18).
- Examples: `cmfdial nt set-dial-rotate volume --yes` sends `F003` with payload `01 04 01 0a 17`.
