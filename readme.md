# RetroChallenges Assets

The challenge bundle the [RetroChallenges desktop launcher](https://github.com/heliacode/RetroChallenges) downloads on every startup. Holds the `RcChallenge` Lua framework, all challenge `.lua` files + savestates, shared HUD assets (digits / banners / sounds), per-game RAM reference docs, and reference TAS movies.

The launcher fetches `https://github.com/heliacode/retrochallenges-assets/archive/refs/heads/main.zip` and extracts it into `%APPDATA%\retrochallenges\challenges\` — so anything you merge to `main` reaches every player on next launch (or Refresh).

---

## Repo layout

```
retrochallenges-assets/
├── TEMPLATE_challenge.lua          # Copy this when authoring a new challenge
├── challenges.json                 # Game/challenge index — hand-edited
├── utils/                          # Shared Lua framework
│   ├── RcChallenge.lua             # The challenge runner (savestate load,
│   │                                 countdown, win/fail loop, R-to-retry,
│   │                                 ROM-hash check, leaderboard submission)
│   ├── RcHud.lua                   # HUD primitives (timer, score, banner)
│   ├── SoundPlayer.lua             # Sound effect helper
│   └── ...
├── assets/                         # Shared HUD / SFX assets
│   ├── 3.png 2.png 1.png go.png    # Countdown sprites
│   ├── _sSmall<0-9>blue.png        # 18×22 score digits
│   ├── tock.wav challengecompleted.wav ...
│   └── completed.png failed.png    # Win / fail banners
├── nes/
│   ├── castlevania/
│   │   ├── 5000pts/
│   │   │   ├── 5000pts.lua
│   │   │   └── savestates/5000pts.state
│   │   ├── bigbridge/
│   │   ├── bat-boss-no-sub/
│   │   ├── medusa-boss-fight/
│   │   └── castlevania_raminfo.md
│   └── megaman2/
│       ├── boss-metalman/
│       └── RAM.md                  # Annotated MM2 RAM map
├── tas/                            # Reference TAS movies (for savestate authoring)
│   └── megaman2/
│       ├── shinryuu-megaman2j.fm2
│       └── README.md
└── .gitattributes                  # Pins .fm2/.fm3/.bk2/.state as binary
                                    #   (CRLF conversion would corrupt them)
```

---

## How a challenge is structured

A challenge is **one `.lua` file + one `.state` savestate file** under `nes/<game>/<slug>/`.

The `.lua` file calls `RcChallenge.run{...}` with a spec table. The framework handles every standard concern (savestate load, 3-2-1-GO countdown, win/fail loop, retry-anywhere R-key, ROM-hash check, leaderboard submission). Authors only fill in the per-game bits.

Minimal challenge:

```lua
local challenge = require("RcChallenge")
local read_u8   = memory.read_u8 or memory.readbyte

challenge.run{
    savestate           = "savestates/foo.state",
    expected_rom_hashes = { "7A20C44F302FB2F1B7ADFFA6B619E3E1CAE7B546" },
    win  = function() return read_u8(0x07FC) >= 0x50 end,
    hud  = function(state) gui.text(10, 6, "TIME " .. state.elapsed) end,
    result = function(state) return { completionTime = state.elapsed } end,
}
```

See [`TEMPLATE_challenge.lua`](./TEMPLATE_challenge.lua) for the full annotated scaffold.

### What `RcChallenge.run` accepts

| Field | Required | What |
|---|---|---|
| `savestate` | yes | Path (relative to challenge dir) to the starting `.state` |
| `expected_rom_hashes` | no | Allowlist of iNES file SHA1s. If set + mismatch → wrong-ROM screen |
| `setup` | no | Called per attempt before countdown — write loadout RAM here |
| `freeze_game` / `release_game` | no | Per-game pause trick (Castlevania writes `1` to `$0022`) |
| `win` | yes | `(state) -> bool` — true = challenge complete |
| `fail` | no | `(state) -> bool` — true = run failed (banner + retry prompt) |
| `hud` | no | Per-frame draw callback (timer, score, etc.) |
| `result` | no | Builds the leaderboard payload — usually `{ completionTime, score }` |
| `countdown` | no | Defaults true. Set false for challenges with cinematic intros |
| `play_on_frames` | no | Defaults 60. Frames game keeps running after win/fail before banner |

State passed to all callbacks: `{ attempt, elapsed, absolute_frame, phase }`.

---

## Currently shipping challenges

| Game | Folder | Description |
|---|---|---|
| Castlevania | `nes/castlevania/5000pts/` | Score 5000+ in a single run |
| Castlevania | `nes/castlevania/bigbridge/` | Reach the mummy stage and clear it |
| Castlevania | `nes/castlevania/bat-boss-no-sub/` | Phantom Bat, whip-only, one life |
| Castlevania | `nes/castlevania/medusa-boss-fight/` | Medusa, full HP / 49 hearts / triple holy water, one life |
| Mega Man 2 | `nes/megaman2/boss-metalman/` | Metal Man, full HP, one life |

---

## Adding a new challenge

1. Copy `TEMPLATE_challenge.lua` into `nes/<game>/<slug>/<slug>.lua`.
2. Capture a savestate using the **bundled** EmuHawk binary at `%APPDATA%\retrochallenges\bizhawk\EmuHawk.exe` — version stamps must match what the launcher runs, or BizHawk pops a "version mismatch" dialog. Drop the `.state` in `<slug>/savestates/`.
3. Fill in your game's RAM addresses, win predicate, optional fail predicate, HUD, and `result` payload.
4. **Pin the ROM hash.** Launch the challenge once; the framework logs `[RC] ROM SHA1: <HEX>` to the BizHawk Lua console. Paste that exact value into `expected_rom_hashes`. (BizHawk reports the **iNES file SHA1** — header included — not the headerless No-Intro convention.)
5. Add a row to `challenges.json` (top of repo).
6. PR it. Once merged to `main`, every launcher pulls it on next startup.

For multi-byte score reads, RAM byte tricks, death-detection patterns, etc., see the per-game `_raminfo.md` / `RAM.md` docs alongside the challenges.

---

## Conventions worth knowing

- **Lua filenames match the folder slug** (`5000pts/5000pts.lua`, not `main.lua`). The launcher reads the path from `challenges.json`'s `lua` field, but matching slugs keep things grep-friendly.
- **Savestates use the lowercase `.state` extension** (older ones in this repo are `.State`; that works on Windows but breaks on Linux clones — new states should be lowercase).
- **NES ROM hashes are iNES-file SHA1**, not headerless No-Intro. BizHawk's `gameinfo.getromhash()` reports the header-included value; pin that.
- **`.gitattributes` marks `.fm2` / `.fm3` / `.bk2` / `.state` as binary.** Don't override — Windows CRLF normalization corrupts the line-per-frame input logs and savestates.
- **Castlevania challenges use the `USER_PAUSED = 0x0022` freeze trick** — writing 1 stops gameplay while emulation continues, so `gui.draw*` keeps rendering during banners/countdowns. Other games need their own freeze byte (Mega Man 2 has none documented yet, so its challenges run unfrozen — usually fine).

---

## TAS archive

`tas/` holds reference TAS movies from [TASVideos](https://tasvideos.org), useful for fast-forwarding to specific game moments while authoring savestates. Currently:

- `tas/megaman2/` — both currently-published MM2 runs (any% by Shinryuu, zipless by warmCabin). **Both target the Japanese ROM** — see the folder's README for replay instructions.

These won't ship to end-users; they're authoring aids only.

---

## Legal

This repo contains no ROMs or copyrighted game content. Players bring their own legally-obtained dumps; the launcher matches them by SHA1.

## License

MIT — see [LICENSE](LICENSE) if added.
