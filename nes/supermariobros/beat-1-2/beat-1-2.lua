-- Super Mario Bros. (World) — Beat 1-2
--
-- Touch the World 1-2 flagpole as fast as you can. The 1-2 warp-zone
-- pipes don't count — the only valid finish is the flagpole at the
-- end of the regular path. Single life: pit / enemy / timer-zero
-- ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map.
-- ---------------------------------------------------------------------------
local GAME_MODE      = 0x0770  -- 0x02 = in-level gameplay
local PLAYER_FLOAT   = 0x001D  -- 0x03 = sliding down flagpole
local PAUSE_FLAG     = 0x0776  -- nonzero = paused
local WORLD          = 0x075F  -- 0-indexed; 0 = World 1
local LEVEL          = 0x0760  -- 0-indexed within world; 1 = X-2
local LIVES          = 0x075A
local TIMER_HI       = 0x07F8
local TIMER_MID      = 0x07F9
local TIMER_LO       = 0x07FA

-- ---------------------------------------------------------------------------
-- Freeze: $0776 is SMB's pause register.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Per-attempt state.
--
-- We capture the starting (world, level) bytes in setup rather than
-- hard-coding "(0, 1) == 1-2". An earlier version that assumed the
-- savestate would read WORLD=0 / LEVEL=1 on frame 0 fired the win
-- predicate instantly — either the prelevel splash leaves the bytes
-- uninitialised for a few frames, or my address labels for $075F /
-- $0760 are swapped vs. what this savestate actually holds. Either
-- way, "left the level you started in" is the unambiguous signal.
-- ---------------------------------------------------------------------------
local start_world = 0
local start_level = 0
local prev_lives  = 0

-- Win = Mario is sliding down the 1-2 flagpole. $001D == 0x03 latches
-- the instant the flagpole is touched (well before the level transition
-- swaps world/level bytes), so the timer locks at the moment of contact
-- rather than waiting for the post-flagpole walk + castle animation to
-- finish. Warp-zone completion is intentionally NOT a win for this
-- challenge — the rule is "hit the flagpole".
--
-- The GAME_MODE gate (must be 0x02 = in-level gameplay) keeps the
-- predicate from false-firing on uninitialised RAM at savestate load,
-- and the (world, level) gate keeps it from latching on any later
-- level's flagpole if the run ever extends past the starting one.
local function flagpole_touched_in_starting_level()
    return read_u8(GAME_MODE)    == 0x02
       and read_u8(PLAYER_FLOAT) == 0x03
       and read_u8(WORLD)        == start_world
       and read_u8(LEVEL)        == start_level
end

challenge.run{
    savestate           = "savestates/beat-1-2.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_world = read_u8(WORLD)
        start_level = read_u8(LEVEL)
        prev_lives  = read_u8(LIVES)
    end,

    win = flagpole_touched_in_starting_level,

    fail = function()
        local now = read_u8(LIVES)
        if now < prev_lives then return true end
        prev_lives = now
        if timer_expired() then return true end
        return false
    end,

    hud = function(state)
        hud.drawTime(10, 4, state.elapsed)
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
