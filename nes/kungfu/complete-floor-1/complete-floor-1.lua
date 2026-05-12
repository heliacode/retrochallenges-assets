-- Kung Fu (NES) — Complete Floor 1
--
-- Beat the entire first floor — clear the side-scrolling section AND
-- defeat the Stick Man boss at the end so the game advances Thomas to
-- Floor 2. Single life: any death (HP empty, fall, etc.) ends the run.
--
-- Win signal: $0058 (current stage) ticks past the savestate's
-- starting value. This catches the post-boss floor-advance regardless
-- of whether the byte is 0-indexed or 1-indexed (Data Crystal doesn't
-- specify) — we just need "the byte rolled forward".
--
-- Kung Fu has no documented single-byte pause register, so we rely on
-- the framework's universal RAM-snapshot freeze for the 3-2-1-GO
-- countdown. Same fallback as Mario Bros. (1983) and Pac-Man.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's Kung Fu RAM map.
-- https://datacrystal.tcrf.net/wiki/Kung_Fu/RAM_map
-- ---------------------------------------------------------------------------
local STAGE = 0x0058  -- current floor (indexing TBD; we track delta)
local LIVES = 0x005C  -- decrements on death

-- ---------------------------------------------------------------------------
-- Per-attempt state. Both values are captured in setup so the win/fail
-- predicates work relative to the savestate's starting point rather
-- than hard-coded numbers.
-- ---------------------------------------------------------------------------
local start_stage = 0
local prev_lives  = 0

challenge.run{
    savestate           = "savestates/complete-floor-1.state",
    expected_rom_hashes = { "9DF403DAC695B556ADBBF312DF37E3B76A2191AC" },  -- Kung Fu, iNES file SHA1

    setup = function(state)
        emu.frameadvance()
        start_stage = read_u8(STAGE)
        prev_lives  = read_u8(LIVES)
    end,

    -- Win = the engine advanced past the starting floor. In Kung Fu
    -- this only happens after Thomas defeats the floor's end-boss and
    -- the "floor cleared" transition completes, so this captures the
    -- intended completion moment without relying on the floor-cleared
    -- animation state byte (which isn't documented).
    win = function()
        return read_u8(STAGE) > start_stage
    end,

    -- Fail = death, via the lives counter edge. Mirrors the SMB / DK
    -- pattern; works for any death cause (HP empty from enemy hits,
    -- timer expiry, falling off Floor 5's pits, etc.) since they all
    -- route through the same lives-decrement.
    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        return false
    end,

    hud = function(state)
        hud.drawTime(10, 4, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
