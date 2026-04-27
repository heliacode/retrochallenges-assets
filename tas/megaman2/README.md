# Mega Man 2 — TAS archive

Reference TAS movies for Mega Man 2 / Rockman 2, kept for:

- Authoring savestates (fast-forward to a target moment, save state)
- Studying optimal routing / movement when designing challenges
- Cross-checking RAM behavior at known timestamps

> **Important:** all currently-published MM2 TASes target the **Japanese** ROM (Rockman 2 - Dr. Wily no Nazo). They will **not** sync against the US ROM (Mega Man 2). To use any of these, load the corresponding J ROM in BizHawk before importing the movie.

## Movies in this folder

| File | Source | Author(s) | Time | Format | Recorded with |
|---|---|---|---|---|---|
| `shinryuu-megaman2j.fm2` | [tasvideos.org/4410M](https://tasvideos.org/4410M) | Shinryuu | 23:38.98 | FCEUX `.fm2` | FCEUX 2.3.0 |
| `warmcabin-megaman2j-zipless.fm3` | [tasvideos.org/4057M](https://tasvideos.org/4057M) | warmCabin | 27:16.17 | FCEUX `.fm3` | FCEUX 2.2.3 |

## Target ROM (both movies)

```
Filename : Rockman 2 - Dr Wily no Nazo (J).nes
TASVideos game id : 10
TASVideos game version id : 491
GoodNES SHA1 (header-included) : FB51875D1FF4B0DEEE97E967E6434FF514F3C2F2
GoodNES MD5  (header-included) : 055FB8DC626FB1FBADC0A193010A3E3F
FCEUX checksum (base64)        : dw1VoZrpHcqpVg1qpzIXNw==
```

(See `nes/megaman2/RAM.md` for the No-Intro headerless SHA1s used by the challenge framework — those are the ones that match `gameinfo.getromhash()` in BizHawk.)

## Replaying in BizHawk

FCEUX `.fm2` / `.fm3` files import via:

```
File → Movie → Import → pick the .fm2 / .fm3
```

For reliable replay:

1. Switch the NES core to **NesHawk** (not QuickerNES) — `Config → Cores → NES → NES (NesHawk)`. NesHawk is BizHawk's accuracy core; QuickerNES is fast but cycle-imprecise and may desync.
2. Load the matching ROM (Rockman 2 J, not the US dump) before importing.
3. After import, `Tab` to fast-forward.
4. To save a state for use outside the movie, **stop the movie first** (`File → Movie → Stop`) before pressing F5 — savestates captured during movie playback record "currently replaying" mode and won't behave normally during regular play.

## Download script

If you ever need to re-fetch:

```bash
# Shinryuu any%
curl -sL "https://tasvideos.org/4410M?handler=Download" -o /tmp/mm2.zip && unzip -o /tmp/mm2.zip -d .

# warmCabin zipless
curl -sL "https://tasvideos.org/4057M?handler=Download" -o /tmp/mm2-zl.zip && unzip -o /tmp/mm2-zl.zip -d .
```

The TASVideos download URL pattern is `https://tasvideos.org/<id>M?handler=Download`. The publication metadata is also exposed via `https://tasvideos.org/api/v1/publications/<id>` (no auth needed for read).

## License

TASVideos publications are typically released under [Creative Commons Attribution-NoDerivs 2.0](https://creativecommons.org/licenses/by-nd/2.0/) (per their site terms). Author attribution preserved in the movie file metadata and the table above.
