-- Super Mario Bros. (World) — Beat 1-2
--
-- Reach the World 1-2 flagpole as fast as you can. Warp pipes don't
-- count (they don't trigger the flagpole slide). Single life: pit /
-- enemy / timer-zero ends the run.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (freeze hook)
local PLAYER_FLOAT = 0x001D  -- 0x03 = sliding down flagpole
local GAME_MODE    = 0x0770  -- only used by the timer-zero fail check
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

local prev_lives = 0

-- Win = flagpole slide. $001D == 0x03 the instant Mario tags the pole.
-- NO GAME_MODE gate: during the flagpole/end-of-level sequence $0770
-- is NOT 0x02, so gating on it blocked the win (the bug that made 1-2
-- and 1-3 never end). 1-1 has always used this bare check and works.
-- The run ends on the first slide, so a later level's flagpole can't
-- false-fire.
local function flagpole_touched()
    return read_u8(PLAYER_FLOAT) == 0x03
end

challenge.run{
    savestate           = "savestates/beat-1-2.state",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
    end,

    win = flagpole_touched,

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
