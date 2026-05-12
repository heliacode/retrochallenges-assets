-- Kung Fu (NES) — Complete Floor 1
--
-- Beat the entire first floor — clear the side-scrolling section AND
-- defeat the Stick Man boss at the end. Win locks the timer the
-- instant the boss dies, NOT when Thomas finishes the post-boss
-- staircase climb (the previous version waited for $0058 to tick
-- forward, which added ~5-10 seconds of climbing animation to every
-- run). Single life: any death ends the run.
--
-- Win signal: $04AF (enemy energy level — labelled in Data Crystal
-- with the "$FF = instant death" note) transitions from non-zero to
-- zero. That byte is almost certainly the boss-HP slot specifically:
-- regular Kung Fu enemies are one-hit kills with no HP byte, so the
-- only enemy that lives long enough to write to this register and
-- then have it counted down to zero is the floor boss. We latch the
-- transition in on_frame() rather than reading inside the win
-- predicate so the predicate stays pure.
--
-- Belt-and-suspenders fallback: if for some reason $04AF doesn't
-- transition cleanly (savestate hits the boss already at zero, my
-- hypothesis is wrong, etc.) the $0058 stage-advance still ends the
-- challenge — just back to slow.
--
-- Kung Fu has no documented single-byte pause register, so we rely
-- on the framework's universal RAM-snapshot freeze for the
-- 3-2-1-GO countdown. Same fallback as Mario Bros. (1983) and
-- Pac-Man.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8 = memory.read_u8 or memory.readbyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's Kung Fu RAM map.
-- https://datacrystal.tcrf.net/wiki/Kung_Fu/RAM_map
-- ---------------------------------------------------------------------------
local STAGE     = 0x0058  -- current floor (indexing TBD; we track delta)
local LIVES     = 0x005C  -- decrements on death
local ENEMY_HP  = 0x04AF  -- the floor boss's HP — see header comment

-- ---------------------------------------------------------------------------
-- Per-attempt state. Captured in setup() so the win/fail predicates
-- work relative to the savestate's starting point rather than hard-
-- coded numbers.
-- ---------------------------------------------------------------------------
local start_stage    = 0
local prev_lives     = 0
local prev_enemy_hp  = 0
local boss_just_died = false

challenge.run{
    savestate           = "savestates/complete-floor-1.state",
    expected_rom_hashes = { "9DF403DAC695B556ADBBF312DF37E3B76A2191AC" },  -- Kung Fu, iNES file SHA1

    setup = function(state)
        emu.frameadvance()
        start_stage    = read_u8(STAGE)
        prev_lives     = read_u8(LIVES)
        prev_enemy_hp  = read_u8(ENEMY_HP)
        boss_just_died = false
    end,

    -- Edge-detect ENEMY_HP transitioning from non-zero to zero. Runs
    -- every play frame, before win/fail.
    on_frame = function(state)
        local hp = read_u8(ENEMY_HP)
        if prev_enemy_hp > 0 and hp == 0 then
            boss_just_died = true
        end
        prev_enemy_hp = hp
    end,

    -- Win: boss HP just hit zero (primary, fast), OR the floor
    -- advanced (fallback, slower).
    win = function()
        if boss_just_died then return true end
        if read_u8(STAGE) > start_stage then return true end
        return false
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
