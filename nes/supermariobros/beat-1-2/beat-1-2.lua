-- Super Mario Bros. (World) — Beat 1-2
--
-- Escape World 1-2 as fast as you can. 1-2 is underground and has no
-- flagpole — its only exit is the warp zone, so dropping down any of
-- the three warp pipes (World 2 / 3 / 4) finishes the run. Single
-- life: pit / enemy / timer-zero ends it.

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
-- Per-attempt state. setup() runs one emu.frameadvance() before reading
-- so the savestate's RAM is settled.
-- ---------------------------------------------------------------------------
local start_world = 0
local prev_lives  = 0

-- Win = Mario has left World 1-2.
--
-- IMPORTANT: World 1-2 has NO flagpole. It is an underground level
-- whose only exit is the warp zone — three pipes, leftmost to World 2,
-- the others to Worlds 3 and 4. You cannot "hit a flagpole" here; the
-- previous predicate watched $001D == 0x03 (flagpole slide) and so
-- could never be satisfied, which made this challenge impossible to
-- finish by any route.
--
-- The reliable "left 1-2" signal is the World byte changing from the
-- value captured at setup: each of the three warp pipes lands you in a
-- different world (2 / 3 / 4 -> byte 1 / 2 / 3), all != the starting 0.
-- Moving between 1-2's internal areas (underground -> warp-zone
-- surface) does NOT change $075F, so this can't false-fire before the
-- player actually warps out. The GAME_MODE == 0x02 gate means we only
-- latch once the destination world is being played, not mid-transition.
--
-- A flagpole branch ($001D == 0x03) is kept as defensive cover so the
-- script still works if a savestate is ever re-recorded in a level
-- that does end at a flagpole — it simply never triggers in 1-2.
local function left_world_1_2()
    if read_u8(GAME_MODE) ~= 0x02 then return false end
    if read_u8(PLAYER_FLOAT) == 0x03 then return true end
    return read_u8(WORLD) ~= start_world
end

challenge.run{
    savestate           = "savestates/beat-1-2.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        start_world = read_u8(WORLD)
        prev_lives  = read_u8(LIVES)
    end,

    win = left_world_1_2,

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
