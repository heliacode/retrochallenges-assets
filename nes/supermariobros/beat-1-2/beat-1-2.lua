-- Super Mario Bros. (World) — Beat 1-2
--
-- Get out of 1-2 alive — either by touching the regular flagpole at
-- the end OR by taking one of the warp-zone pipes. Both count.
-- Single life: pit / enemy / timer-zero ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — verified against Data Crystal's SMB RAM map.
-- ---------------------------------------------------------------------------
local GAME_MODE      = 0x0770  -- 0x02 = in-level gameplay
local OPERATION_MODE = 0x0772  -- 0x04 = end-of-level animation (flagpole→castle)
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

-- 1-2 has two completion paths: the regular flagpole at the end (which
-- triggers $0772 == 0x04, same as beat-1-1) AND the warp zone (three
-- pipes Mario drops into to skip ahead to W2/3/4). The warp-pipe path
-- doesn't fire the end-of-level animation — instead the world/level
-- bytes change directly when Mario enters one of the pipes. Detect
-- either:
--   - $0772 == 0x04 while still in 1-2  → flagpole completion
--   - world != 0 OR level != 1          → warp-zone completion (or
--                                          regular-path post-flagpole
--                                          transition)
local function left_1_2_alive()
    if read_u8(OPERATION_MODE) == 0x04
       and read_u8(WORLD) == 0 and read_u8(LEVEL) == 1 then
        return true
    end
    if read_u8(WORLD) ~= 0 or read_u8(LEVEL) ~= 1 then
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Per-attempt state.
-- ---------------------------------------------------------------------------
local prev_lives = 0

challenge.run{
    savestate           = "savestates/beat-1-2.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = left_1_2_alive,

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
