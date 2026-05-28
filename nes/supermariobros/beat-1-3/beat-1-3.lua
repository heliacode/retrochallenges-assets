-- Super Mario Bros. (World) — Beat 1-3
--
-- Reach the World 1-3 flagpole as fast as possible. 1-3 is the
-- bouncing-platforms-over-pits level — pits and Cheep-Cheeps will
-- end the run if you mistime a jump. Single life: pit / enemy /
-- timer-zero ends it.

local hud       = require("RcHud")
local challenge = require("RcChallenge")

local read_u8  = memory.read_u8  or memory.readbyte
local write_u8 = memory.write_u8 or memory.writebyte

-- ---------------------------------------------------------------------------
-- Memory map — Data Crystal SMB RAM map.
-- https://datacrystal.tcrf.net/wiki/Super_Mario_Bros./RAM_map
-- ---------------------------------------------------------------------------
local GAME_MODE    = 0x0770  -- 0x02 = in-level gameplay
local PAUSE_FLAG   = 0x0776  -- nonzero = paused (freeze hook)
local WORLD        = 0x075F  -- diagnostic only
local LEVEL        = 0x0760  -- diagnostic only
local PLAYER_FLOAT = 0x001D  -- 0x03 = sliding down flagpole
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

-- Diagnostic state (persists across frames so a brief flagpole moment
-- is still visible after the fact). Reset in setup().
local peak_float = 0
local win_ever   = false

-- Win = flagpole-slide while in active gameplay. No world/level gate.
-- See beat-1-2.lua for the long-form why; short version: $001D == 0x03
-- is unique to the flagpole slide, the run ends on first contact, so
-- no later level's flagpole can false-fire.
local function flagpole_touched()
    return read_u8(GAME_MODE)    == 0x02
       and read_u8(PLAYER_FLOAT) == 0x03
end

challenge.run{
    savestate           = "savestates/beat-1-3.State",
    expected_rom_hashes = { "EA343F4E445A9050D4B4FBAC2C77D0693B1D0922" },

    freeze_game  = freeze_game,
    release_game = release_game,

    setup = function(state)
        emu.frameadvance()
        prev_lives = read_u8(LIVES)
        peak_float = 0
        win_ever   = false
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
        -- Diagnostic — plain concatenation, no string.format (ruling
        -- that out as a crash source). peak/win_ever persist so the
        -- flagpole moment is readable after the fact. Remove once 1-3
        -- is confirmed firing.
        local f = read_u8(PLAYER_FLOAT)
        local g = read_u8(GAME_MODE)
        if f > peak_float then peak_float = f end
        if f == 0x03 and g == 0x02 then win_ever = true end
        gui.text(8, 200, "FLOAT now=" .. f .. " peak=" .. peak_float)
        gui.text(8, 214, "MODE=" .. g)
        gui.text(8, 228, "WIN HIT: " .. tostring(win_ever))
    end,

    result = function(state)
        return { completionTime = state.elapsed }
    end,
}
