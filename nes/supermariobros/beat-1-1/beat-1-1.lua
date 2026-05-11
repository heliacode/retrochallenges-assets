-- Super Mario Bros. (World) — Beat 1-1
-- Reach the flagpole of World 1-1 as fast as possible. One life: the
-- run ends if Mario dies (lives counter decrements) OR the in-game
-- timer hits 0.
--
-- Savestate target: title screen → press Start → at "WORLD 1-1" splash
-- (or first frame after splash, with Mario standing left edge of 1-1).
-- The framework's 3-2-1-GO countdown will play over the frozen first
-- frame.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map (Super Mario Bros., World — mapper 0)
-- Source: nes/supermariobros/RAM.md, derived from Data Crystal.
-- ---------------------------------------------------------------------------
local GAME_MODE    = 0x0770  -- 0x02 = in-level gameplay
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (we exploit this to freeze)
local WORLD        = 0x075F  -- 0-indexed: 0 = World 1, 1 = World 2, ...
local LEVEL        = 0x0760  -- 0-indexed within world: 0 = X-1, 1 = X-2, ...
local PLAYER_FLOAT = 0x001D  -- 0x03 = sliding down flagpole
local LIVES        = 0x075A
local TIMER_HI     = 0x07F8  -- BCD hundreds digit of in-game timer
local TIMER_MID    = 0x07F9  -- BCD tens
local TIMER_LO     = 0x07FA  -- BCD ones
local SCORE_BASE   = 0x07DD  -- 6 BCD bytes — see read_score()

-- ---------------------------------------------------------------------------
-- Freeze trick: $0776 is SMB's pause register. Writing 1 stops gameplay
-- (player, enemies, timer all freeze) while the renderer keeps running,
-- so our countdown / banners stay drawn. Inputs are neutralised to keep
-- the auto-unpause logic ($0777 cooldown) from kicking us out.
-- ---------------------------------------------------------------------------
local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

-- ---------------------------------------------------------------------------
-- Score is 6 BCD digits at $07DD-$07E2, one digit per byte (the in-game
-- value is always a multiple of 10 — the ones digit is unused and stays 0).
-- ---------------------------------------------------------------------------
local function read_score()
    local s = 0
    for i = 0, 5 do
        s = s * 10 + read_u8(SCORE_BASE + i)
    end
    return s * 10
end

-- Timer reaches 000 when all three digits are zero AND game is in level.
local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
--
-- `prev_lives` runs an edge-detector across the lives counter, NOT an
-- absolute compare against starting value. Reason: 1-1 has a famous
-- hidden 1-Up in the brick row above the first pipe — if a player
-- grabs it and *then* dies, lives goes 3 → 4 → 3 and an absolute
-- compare ("now < start") would miss the death. The edge pattern
-- also handles the (rarer) "die twice across the same 1-1 run"
-- scenario correctly because we update prev_lives after every read.
-- ---------------------------------------------------------------------------
local prev_lives = 0

-- ---------------------------------------------------------------------------
-- Run the challenge.
-- ---------------------------------------------------------------------------
challenge.run{
    savestate           = "savestates/beat-1-1.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },  -- SMB (World), iNES file SHA1

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    -- Win = Mario is sliding down the flagpole of 1-1. The flagpole-slide
    -- state ($001D == 0x03) is set the instant Mario touches the pole
    -- and only clears once he walks off into the castle, so it's a clean
    -- one-shot signal that the level is functionally complete. We also
    -- gate on still being in 1-1 (World==0, Level==0) so the predicate
    -- can't fire on the flagpole of any future level if the savestate
    -- ever gets re-recorded mid-run.
    win = function()
        return read_u8(PLAYER_FLOAT) == 0x03
           and read_u8(WORLD) == 0
           and read_u8(LEVEL) == 0
    end,

    -- Fail = dropped a life (any cause — pit, Goomba/Koopa/Piranha Plant
    -- contact as small Mario, timer-zero death). Watching the lives
    -- counter catches all of these uniformly.
    --
    -- Edge-trigger on decrement so a 1-Up before the death doesn't mask
    -- it (see prev_lives comment above). We also keep an explicit
    -- timer-zero check so the fail banner fires the frame the clock
    -- empties rather than waiting the ~30 frames for the death
    -- animation to actually decrement lives.
    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        gui.text(10, 6, "SCORE")
        hud.drawScore(48, 4, read_score(), 0)
        gui.text(10, 24, "TIME")
        hud.drawTime(48, 22, state.elapsed)
    end,

    result = function(state)
        return {
            score          = read_score(),
            completionTime = state.elapsed,
        }
    end,
}
