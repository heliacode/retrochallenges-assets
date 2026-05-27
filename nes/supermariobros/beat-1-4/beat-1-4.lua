-- Super Mario Bros. (World) — Beat 1-4 (Bowser castle)
--
-- Cross Bowser's castle and touch the axe at the end of the bridge.
-- 1-4 is a castle level, so there is no flagpole — the win signal is
-- the end-of-level animation kicking in, which the engine triggers
-- the moment Mario touches the axe. Single life: fire / Podoboo /
-- enemy / pit / timer-zero ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE    = 0x0770  -- 0x02 = in-level gameplay
local OP_MODE      = 0x0772  -- 0x04 = end-of-level animation (flagpole OR axe)
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (freeze hook)
local WORLD        = 0x075F  -- 0-indexed: 0 = World 1
local LEVEL        = 0x0760  -- 0-indexed within world: 3 = X-4 (castle)
local LIVES        = 0x075A
local TIMER_HI     = 0x07F8
local TIMER_MID    = 0x07F9
local TIMER_LO     = 0x07FA

local function freeze_game()
    write_u8(PAUSE_FLAG, 1)
    joypad.set({}, 1)
end

local function release_game()
    write_u8(PAUSE_FLAG, 0)
end

local function timer_expired()
    return read_u8(TIMER_HI)  == 0
       and read_u8(TIMER_MID) == 0
       and read_u8(TIMER_LO)  == 0
       and read_u8(GAME_MODE) == 0x02
end

-- Per-attempt baselines.
local start_world = 0
local start_level = 0
local prev_lives  = 0

-- Win = the end-of-level animation flag latches on the castle level
-- we started in. In a castle that flag is set the instant Mario walks
-- into the axe (kicks off the bridge-collapse / Bowser-fall outro), so
-- it captures the finish at the exact moment of contact — well before
-- the world/level bytes roll forward to 2-1. The (world, level) gate
-- means a later castle never false-fires this predicate.
local function axe_touched_in_starting_castle()
    return read_u8(OP_MODE) == 0x04
       and read_u8(WORLD)   == start_world
       and read_u8(LEVEL)   == start_level
end

challenge.run{
    savestate           = "savestates/beat-1-4.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_world = read_u8(WORLD)
        start_level = read_u8(LEVEL)
        prev_lives  = read_u8(LIVES)
    end,

    win = axe_touched_in_starting_castle,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTimeBg(10, 4, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
